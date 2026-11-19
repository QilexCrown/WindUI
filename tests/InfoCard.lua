-- Headless behavioral checks: luajit tests/InfoCard.lua
local active = 0
local function signal()
    local handlers = {}
    return {
        Connect = function(_, fn)
            local connection = {Connected = true}
            active = active + 1
            function connection:Disconnect()
                if self.Connected then self.Connected = false; active = active - 1 end
            end
            handlers[#handlers + 1] = {connection, fn}
            return connection
        end,
        Fire = function(_, ...)
            for _, entry in ipairs(handlers) do if entry[1].Connected then entry[2](...) end end
        end,
    }
end
local function node(class)
    local object = {ClassName = class, AbsoluteSize = {X = 600, Y = 300}, Children = {}, Signals = {}}
    for _, event in ipairs({'Destroying', 'MouseEnter', 'MouseLeave', 'SelectionGained', 'SelectionLost', 'Activated', 'InputBegan', 'InputEnded'}) do
        object[event] = signal()
    end
    function object:GetPropertyChangedSignal(name)
        self.Signals[name] = self.Signals[name] or signal()
        return self.Signals[name]
    end
    function object:Destroy()
        if self.Destroyed then return end
        self.Destroying:Fire()
        self.Destroyed, self.Parent = true, nil
        for _, child in ipairs(self.Children) do child:Destroy() end
    end
    function object:IsA(name) return name == 'GuiObject' or self.ClassName == name end
    function object:GetDescendants()
        local result = {}
        for _, child in ipairs(self.Children) do
            result[#result + 1] = child
            for _, nested in ipairs(child:GetDescendants()) do result[#result + 1] = nested end
        end
        return result
    end
    return object
end
local enum = setmetatable({}, {__index = function(tbl, key)
    local values = setmetatable({}, {__index = function(_, name) return name end})
    tbl[key] = values
    return values
end})
local Creator = {Font = 'test-font'}
function Creator.New(class, props)
    local item = node(class)
    for key, value in pairs(props) do item[key] = value end
    if props.Parent then table.insert(props.Parent.Children, item) end
    return item
end
function Creator.NewRoundFrame(_, shape, props) local item = Creator.New('ImageLabel', props); item.Shape = shape; return item end
function Creator.Icon() return {'icon', {}} end
function Creator.Tween(item, _, props)
    local t = {Completed = signal()}
    function t:Play()for key,value in pairs(props)do item[key]=value end;self.Completed:Fire()end
    function t:Cancel()self.Completed:Fire()end
    return t
end
local Layout = assert(loadfile('src/components/InfoCardLayout.lua'))()
local components={}
local environment
environment = setmetatable({
    Enum = enum,
    UDim = {new = function(scale, offset) return {Scale = scale, Offset = offset} end},
    UDim2 = {new = function(x, xo, y, yo) return {X = {Scale = x, Offset = xo}, Y = {Scale = y, Offset = yo}} end},
    Font = {new = function() return {} end},
    Vector2 = {new = function(x, y) return {X = x, Y = y} end},
    Color3 = {new = function(...) return {...} end, fromRGB = function(...) return {...} end},
    ColorSequence = {new = function(...) return {...} end},
    require = function(id)
        if id == '../modules/Creator' then return Creator end
        if id == './InfoCardLayout' then return Layout end
        local name=id:match('([^/]+)$')
        if not components[name] then
            local c=assert(loadfile('src/components/'..name..'.lua'));setfenv(c,environment);components[name]=c()
        end
        return components[name]
    end,
}, {__index = _G})
local chunk = assert(loadfile('src/components/InfoCard.lua'))
setfenv(chunk, environment)
local InfoCard = chunk()
local calls = 0
local card = InfoCard.New({Parent = node('Frame'), DisplayName = 'A long multilingual display name',
    Actions = {{Title = 'Rejoin', Callback = function() calls = calls + 1 end}, {Title = 'Hop'}}})
assert(card.Frame.Shape == 'Squircle' and card.Frame.ThemeTag.ImageColor3 == 'ElementBackground')
for _, width in ipairs({180, 240, 300, 375, 479, 480, 600, 1024}) do
    card.Frame.AbsoluteSize = {X = width}
    card.Frame:GetPropertyChangedSignal('AbsoluteSize'):Fire()
    local shape = Layout.Calculate(width, 2)
    assert(card.Frame.Size.Y.Offset == shape.Height)
    assert(card.Display.Size.X.Offset > 0)
    for _, value in pairs(card.Values) do
        local cell = value.Parent
        assert(cell.Position.X.Offset >= shape.Padding)
        assert(cell.Position.X.Offset + cell.Size.X.Offset <= width - shape.Padding + 0.001)
        assert(cell.Position.Y.Offset + cell.Size.Y.Offset < shape.ActionsY)
    end
    for _, action in ipairs(card.Actions) do
        assert(action.Button.Size.X.Offset > 0)
        assert(action.Button.Position.X.Offset + action.Button.Size.X.Offset <= width - shape.Padding + 0.001)
    end
end
card:SetStats({ping = '215 ms', fps = '27', players = '30/30', session = '1:02:03', region = 'Europe', server = 'Reserved'}, {ping = 'Poor'})
assert(card.Values.ping.Text == '215 ms' and card.Chips.server.Text == 'Reserved')
card.Actions[1].Button.Activated:Fire()
assert(calls == 1)
local oldButton = card.Actions[1].Button
card:SetActions({{Title = 'New', Callback = function() calls = calls + 10 end}})
oldButton.Activated:Fire()
assert(calls == 1, 'old action callback leaked')
card.Actions[1].Button.Activated:Fire()
assert(calls == 11)
card:Destroy()
card:Destroy()
card:SetStats({ping = 'ignored'})
assert(card.Values.ping.Text == '215 ms' and active == 0, 'destroy left listeners or updates alive')
local second = InfoCard.New({Parent = node('Frame')})
second.Frame:Destroy()
assert(second.Destroyed and active == 0, 'parent destruction left listeners alive')
local credits = InfoCard.Credits({Parent = node('Frame'), Rows = {{Role = 'Owner', Handle = '@Owner'}, {Role = 'Developer', Handle = '@Developer'}}})
assert(credits.Frame.Shape == 'Squircle' and credits.Header.Text == 'Credits' and #credits.Roles == 2)
local feedback = InfoCard.Feedback({Parent = node('Frame')})
assert(feedback.Name == 'FeedbackFloat' and feedback.Size.X.Offset == 42 and feedback.AnchorPoint.X == 1)
for _, child in ipairs(feedback:GetDescendants()) do
    if child.Name == 'Icon' then
        assert(child.AnchorPoint.X == 0.5 and child.Position.X.Offset == 0 and child.Position.Y.Offset == 0, 'feedback icon is off center')
    end
end
feedback:Destroy()
credits:Destroy()
assert(active == 0, 'native controls left listeners alive')
for _, width in ipairs({0, -1, math.huge, 0/0}) do assert(Layout.Calculate(width, 0).Height > 0) end
print('InfoCard: eight widths, stats, action replacement and both cleanup paths passed')
