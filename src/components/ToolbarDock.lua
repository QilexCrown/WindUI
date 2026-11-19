local Layout = require('./ToolbarLayout')
local Dock = {}
function Dock.New(parent, windui)
    local self = {Tags = {}, Connections = {}, Destroyed = false}
    local list = parent:FindFirstChildOfClass('UIListLayout')
    if list then list:Destroy() end
    parent.ClipsDescendants = true
    parent.ScrollingEnabled = false
    parent.AutomaticCanvasSize = Enum.AutomaticSize.None
    parent.CanvasSize = UDim2.new(0, 0, 0, 0)
    function self:Layout()
        if self.Destroyed then return end
        local entries = {}
        for i, tag in ipairs(self.Tags) do entries[i] = tag:GetMetrics() end
        local scale = math.max(0.1, tonumber(windui.UIScale) or 1)
        local states = Layout.Calculate(math.max(0, parent.AbsoluteSize.X / scale - 2), entries)
        for i, state in ipairs(states) do self.Tags[i]:SetLayout(state) end
    end
    function self:Add(tag)
        table.insert(self.Tags, tag)
        tag.OnLayoutChanged = function() self:Layout() end
        tag.OnDestroyed = function()
            for i, item in ipairs(self.Tags) do
                if item == tag then table.remove(self.Tags, i); break end
            end
            self:Layout()
        end
        self:Layout()
    end
    function self:Destroy()
        if self.Destroyed then return end
        self.Destroyed = true
        for _, connection in ipairs(self.Connections) do connection:Disconnect() end
        for _, tag in ipairs(self.Tags) do tag.OnLayoutChanged = nil; tag.OnDestroyed = nil end
        self.Tags, self.Connections = {}, {}
    end
    self.Connections[1] = parent:GetPropertyChangedSignal('AbsoluteSize'):Connect(function() self:Layout() end)
    self.Connections[2] = parent.Destroying:Connect(function() self:Destroy() end)
    return self
end
return Dock
