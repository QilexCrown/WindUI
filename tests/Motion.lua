local Controller = assert(loadfile('src/modules/Motion.lua'))()
local function signal()
    local listeners = {}
    return {Connect = function(_, fn)
        local c = {Connected = true}
        function c:Disconnect() self.Connected = false end
        listeners[#listeners + 1] = {c, fn}
        return c
    end, Fire = function(_, ...)
        for _, item in ipairs(listeners) do if item[1].Connected then item[2](...) end end
    end}
end
local service = {created = {}}
function service:Create(object, info, props)
    local tween = {Completed = signal(), Cancelled = false, Duration = info, Instance = object}
    function tween:Play() self.Played = true; self.PlaybackState = 'Playing' end
    function tween:Cancel() self.Cancelled = true; self.PlaybackState = 'Cancelled'; self.Completed:Fire('Cancelled') end
    function tween:Pause() self.Paused = true end
    function tween:Destroy() self:Cancel() end
    function tween:Complete() self.PlaybackState = 'Completed'; self.Completed:Fire('Completed') end
    self.created[#self.created + 1] = tween
    return tween
end
local motion = Controller.New(service, function(time) return time end)
local target = {Destroying = signal()}
local first = motion:Create(target, 0.2, {Transparency = 0})
first:Play()
local pending = motion:Create(target, 0.2, {Transparency = 1})
assert(not service.created[1].Cancelled, 'creating an unplayed tween interrupted motion')
pending:Play()
assert(service.created[1].Cancelled, 'conflicting tween was not cancelled')
local position = motion:Create(target, 0.2, {Position = 12})
position:Play()
assert(not service.created[2].Cancelled, 'independent properties were cancelled')
target.Destroying:Fire()
assert(service.created[2].Cancelled and service.created[3].Cancelled)
assert(motion:GetActiveCount() == 0, 'destroy leaked active motion')
motion.ReducedMotion = true
local reduced = motion:Create({Destroying = signal()}, 0.3, {X = 1})
assert(service.created[#service.created].Duration == 0)
reduced:Play(); reduced:Cancel()
for i = 1, 1000 do
    local item = {Destroying = signal()}
    local tween = motion:Create(item, 0.2, {X = i})
    tween:Play()
    service.created[#service.created]:Complete()
end
assert(motion:GetActiveCount() == 0, 'completed tweens accumulated')
local replay = motion:Create({Destroying = signal()}, 0.2, {X = 1})
replay:Play(); replay:Cancel(); replay:Play(); replay:Destroy()
assert(motion:GetActiveCount() == 0)
local raceTarget = {Destroying = signal()}
local a = motion:Create(raceTarget, 0.2, {X = 1})
local b = motion:Create(raceTarget, 0.2, {X = 2})
local bNative = service.created[#service.created]
local c = motion:Create(raceTarget, 0.2, {X = 3})
a.Completed:Connect(function(state) if state == 'Cancelled' then c:Play() end end)
a:Play(); b:Play()
assert(not bNative.Played, 'cancel handler resurrected an untracked superseded tween')
assert(motion:GetActiveCount() == 1)
c:Destroy()
assert(motion:GetActiveCount() == 0)
local reentrant = motion:Create({Destroying = signal()}, 0.2, {X = 1})
local native = service.created[#service.created]
local repeats = 0
reentrant.Completed:Connect(function(state)
    if state == 'Completed' and repeats == 0 then repeats = 1; reentrant:Play() end
end)
reentrant:Play()
native.PlaybackState = 'Completed'
native.Completed:Fire('Completed')
assert(motion:GetActiveCount() == 1, 'completion callback lost ownership of replayed tween')
reentrant:Destroy()
assert(motion:GetActiveCount() == 0)
print('Motion: deferred ownership, conflicts, independent channels, reduced motion, destruction and 1000 completions passed')
