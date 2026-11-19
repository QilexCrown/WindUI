local Motion = {}

function Motion.New(service, makeInfo)
    local self = {ReducedMotion = false, Enabled = true}
    local states = setmetatable({}, {__mode = 'k'})
    local dead = setmetatable({}, {__mode = 'k'})
    local count = 0
    function self:GetActiveCount() return count end
    function self:Create(object, duration, properties, ...)
        local info
        if self.ReducedMotion or not self.Enabled then info = makeInfo(0) else info = makeInfo(duration, ...) end
        local native = service:Create(object, info, properties)
        local proxy, owned, completed, destroyed = {}, false, nil, false
        local generation = 0
        local function release()
            if not owned then return end
            owned = false
            count = count - 1
            if completed then completed:Disconnect(); completed = nil end
            local state = states[object]
            if not state then return end
            state.tweens[proxy] = nil
            for property in pairs(properties) do
                if state.channels[property] == proxy then state.channels[property] = nil end
            end
            if not next(state.tweens) then
                if state.destroying then state.destroying:Disconnect() end
                states[object] = nil
            end
        end
        function proxy:Play()
            if destroyed or dead[object] then return end
            local playback = tostring(native.PlaybackState):match('([^%.]+)$')
            if owned and (playback == 'Completed' or playback == 'Cancelled') then release() end
            if not owned then
                local state = states[object]
                if not state then
                    state = {channels = {}, tweens = {}}
                    states[object] = state
                    if object.Destroying then
                        state.destroying = object.Destroying:Connect(function()
                            dead[object] = true
                            local pending = {}
                            for tween in pairs(state.tweens) do pending[#pending + 1] = tween end
                            for _, tween in ipairs(pending) do tween:Cancel() end
                        end)
                    end
                end
                local conflicts = {}
                for property in pairs(properties) do
                    local previous = state.channels[property]
                    if previous and previous ~= proxy then conflicts[previous] = true end
                end
                -- Claim the new channels first so cancelling the final previous
                -- tween cannot tear down the object state underneath us.
                owned = true
                count = count + 1
                state.tweens[proxy] = true
                for property in pairs(properties) do state.channels[property] = proxy end
                generation = generation + 1
                local playingGeneration = generation
                completed = native.Completed:Connect(function()
                    local state = tostring(native.PlaybackState):match('([^%.]+)$')
                    if generation == playingGeneration and state ~= 'Playing' and state ~= 'Delayed' then release() end
                end)
                for previous in pairs(conflicts) do previous:Cancel() end
            end
            if owned and not destroyed and not dead[object] then native:Play() end
        end
        function proxy:Cancel() if not destroyed then release(); native:Cancel() end end
        function proxy:Pause() if not destroyed then native:Pause() end end
        function proxy:Destroy()
            if destroyed then return end
            destroyed = true
            release()
            native:Cancel()
            native:Destroy()
        end
        return setmetatable(proxy, {__index = function(_, key)
            local value = native[key]
            if type(value) == 'function' then return function(_, ...) return value(native, ...) end end
            return value
        end})
    end
    return self
end

return Motion
