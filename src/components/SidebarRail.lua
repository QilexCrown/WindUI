local Creator = require("../modules/Creator")
local Motion = require("./ControlMotion")
local Rail = {Width = 52}
function Rail.Attach(window)
    local self = {Buttons = {}, Entries = {}, Connections = {}, Generation = 0, Destroyed = false, Collapsed = false}
    local reduced = window.ReducedMotion == true
    local root = Creator.New("CanvasGroup", {
        Name = "CollapsedTabRail", Parent = window.UIElements.Main.Main,
        Size = UDim2.new(0, Rail.Width, 1, -window.Topbar.Height),
        Position = UDim2.new(0, 0, 0, window.Topbar.Height),
        BackgroundTransparency = 1, GroupTransparency = 1, Visible = false,
    })
    local scroller = Creator.New("ScrollingFrame", {
        Name = "Icons", Parent = root, Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 0,
        CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y,
    }, {
        Creator.New("UIListLayout", {Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center}),
        Creator.New("UIPadding", {PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 8)}),
    })
    self.Frame, self.Scroller = root, scroller
    self.Motion = Motion.New(root, reduced)
    local function bind(entry, event, fn) entry.Connections[#entry.Connections + 1] = event:Connect(fn) end
    local function paint(entry)
        if self.Destroyed then return end
        local selected = window.TabModule and window.TabModule.SelectedTab == entry.Index
        local locked = entry.Tab.Locked == true
        if entry.LastSelected == selected and entry.LastLocked == locked and entry.LastHover == entry.Hover and entry.LastPressed == entry.Pressed then return end
        entry.LastSelected, entry.LastLocked, entry.LastHover, entry.LastPressed = selected, locked, entry.Hover, entry.Pressed
        entry.Motion:To("fill", entry.Button, 0.18, {ImageTransparency = selected and 0.9 or entry.Hover and 0.97 or 1})
        entry.Motion:To("rim", entry.Rim, 0.18, {ImageTransparency = selected and 0.72 or 1})
        entry.Motion:To("scale", entry.Scale, 0.18, {Scale = entry.Pressed and 0.94 or entry.Hover and 1.08 or selected and 1.04 or 1})
        entry.Motion:To("position", entry.Icon, 0.18, {Position = UDim2.new(0.5, entry.Hover and 1 or 0, 0.5, 0)})
        entry.Motion:To("icon", entry.Icon.ImageLabel, 0.18, {ImageTransparency = locked and 0.7 or selected and 0 or entry.Hover and 0.05 or 0.3})
        entry.Button.Selectable = not locked
    end
    local function remove(index)
        local entry = self.Entries[index]
        if not entry then return end
        for _, connection in ipairs(entry.Connections) do connection:Disconnect() end
        entry.Motion:Destroy()
        entry.Button:Destroy()
        self.Entries[index], self.Buttons[index] = nil, nil
    end
    function self:Refresh()
        if self.Destroyed then return end
        for _, entry in pairs(self.Entries) do paint(entry) end
    end
    function self:Sync()
        if self.Destroyed or not window.TabModule then return end
        local tabs, present, indexes = window.TabModule.Tabs, {}, {}
        -- Sparse tab indices must not drop every icon after the first gap.
        for index, tab in pairs(tabs) do
            local source = type(tab) == "table" and tab.UIElements and tab.UIElements.Main
            if type(tab) == "table" and type(index) == "number" and (not source or source.Parent ~= nil) then
                indexes[#indexes + 1] = index; present[index] = true
            end
        end
        table.sort(indexes)
        local stale = {}
        for index in pairs(self.Entries) do if not present[index] then stale[#stale + 1] = index end end
        for _, index in ipairs(stale) do remove(index) end
        for rank, index in ipairs(indexes) do
            local tab = tabs[index]
            local entry = self.Entries[index]
            if entry and (entry.Tab ~= tab or entry.IconName ~= tab.Icon) then remove(index); entry = nil end
            if not entry then
                local button = Creator.NewRoundFrame(13, "Squircle", {
                    Name = "RailTab" .. index, Parent = scroller, Size = UDim2.new(0, 38, 0, 38),
                    LayoutOrder = rank, ImageTransparency = 1, ThemeTag = {ImageColor3 = "Text"},
                }, nil, true)
                local rim = Creator.NewRoundFrame(13, "SquircleGlass", {Parent = button, Size = UDim2.new(1, 0, 1, 0),
                    ImageTransparency = 1, ThemeTag = {ImageColor3 = "Text"}})
                local iconName = tab.Icon or "circle"
                local icon = Creator.Image(iconName, iconName, 0, window.Folder, "Tab", not tab.IconColor, tab.IconThemed, "TabIcon")
                icon.Size = UDim2.new(0, 18, 0, 18)
                icon.AnchorPoint, icon.Position = Vector2.new(0.5, 0.5), UDim2.new(0.5, 0, 0.5, 0)
                icon.Parent = button
                if tab.IconColor then icon.ImageLabel.ImageColor3 = tab.IconColor end
                entry = {Tab = tab, Index = index, IconName = tab.Icon, Button = button, Rim = rim, Icon = icon,
                    Scale = Creator.New("UIScale", {Parent = icon, Scale = 1}), Connections = {}}
                entry.Motion = Motion.New(button, reduced)
                self.Entries[index], self.Buttons[index] = entry, button
                local source = tab.UIElements and tab.UIElements.Main
                if source then bind(entry, source.Destroying, function() if not self.Destroyed then remove(index) end end) end
                bind(entry, button.Activated, function() if not self.Destroyed and not tab.Locked then window.TabModule:SelectTab(index) end end)
                bind(entry, button.MouseEnter, function() entry.Hover = true; paint(entry) end)
                bind(entry, button.MouseLeave, function() entry.Hover, entry.Pressed = false, false; paint(entry) end)
                bind(entry, button.SelectionGained, function() entry.Hover = true; paint(entry) end)
                bind(entry, button.SelectionLost, function() entry.Hover, entry.Pressed = false, false; paint(entry) end)
                bind(entry, button.InputBegan, function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then entry.Pressed = true; paint(entry) end
                end)
                bind(entry, button.InputEnded, function() entry.Pressed = false; paint(entry) end)
            end
            entry.Button.LayoutOrder = rank
        end
        self:Refresh()
    end
    function self:SetCollapsed(value)
        if self.Destroyed then return end
        self.Collapsed = value == true
        self.Generation = self.Generation + 1
        local generation = self.Generation
        self:Sync()
        if self.Collapsed then
            if not root.Visible then root.Position = UDim2.new(0, -5, 0, window.Topbar.Height); root.GroupTransparency = 1 end
            root.Visible = true
            self.Motion:To("visibility", root, 0.20, {GroupTransparency = 0, Position = UDim2.new(0, 0, 0, window.Topbar.Height)})
        else
            self.Motion:To("visibility", root, 0.16, {GroupTransparency = 1, Position = UDim2.new(0, -5, 0, window.Topbar.Height)})
            if reduced then root.Visible = false
            else task.delay(0.17, function() if not self.Destroyed and generation == self.Generation and not self.Collapsed then root.Visible = false end end) end
        end
    end
    self.Connections[1] = root.Destroying:Connect(function()
        self.Destroyed = true; self.Generation = self.Generation + 1
        for _, connection in ipairs(self.Connections) do connection:Disconnect() end
        local indexes = {}; for index in pairs(self.Entries) do indexes[#indexes + 1] = index end
        for _, index in ipairs(indexes) do remove(index) end
        self.Motion:Destroy()
    end)
    window.IconRail = self
    self:Sync()
end
return Rail
