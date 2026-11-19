local Creator = require("../modules/Creator")
local Rail = {Width = 52}
function Rail.Attach(window)
    local self = {Buttons = {}, Connections = {}}
    local root = Creator.New("ScrollingFrame", {
        Name = "CollapsedTabRail", Parent = window.UIElements.Main.Main,
        Size = UDim2.new(0, Rail.Width, 1, -window.Topbar.Height),
        Position = UDim2.new(0, 0, 0, window.Topbar.Height),
        BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 0,
        CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y, Visible = false,
    }, {
        Creator.New("UIListLayout", {Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder,
            HorizontalAlignment = Enum.HorizontalAlignment.Center}),
        Creator.New("UIPadding", {PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 8)}),
    })
    self.Frame = root
    function self:Refresh()
        local module = window.TabModule
        if not module then return end
        for index, button in pairs(self.Buttons) do
            button.ImageTransparency = module.SelectedTab == index and 0.90 or 1
        end
    end
    function self:Sync()
        local module = window.TabModule
        if not module then return end
        for index, tab in ipairs(module.Tabs) do
            if not self.Buttons[index] then
                local button = Creator.NewRoundFrame(12, "Squircle", {
                    Name = "RailTab" .. index, Parent = root, Size = UDim2.new(0, 38, 0, 38),
                    LayoutOrder = index, ImageTransparency = 1, ThemeTag = {ImageColor3 = "Text"},
                }, nil, true)
                if tab.Icon then
                    local icon = Creator.Image(tab.Icon, tab.Icon, 0, window.Folder, "Tab", true, tab.IconThemed, "TabIcon")
                    icon.Size = UDim2.new(0, 18, 0, 18)
                    icon.AnchorPoint = Vector2.new(0.5, 0.5)
                    icon.Position = UDim2.new(0.5, 0, 0.5, 0)
                    icon.Parent = button
                    icon.ImageLabel.ImageTransparency = tab.Locked and 0.7 or 0.1
                else
                    Creator.New("TextLabel", {Parent = button, BackgroundTransparency = 1,
                        Size = UDim2.new(1, 0, 1, 0), Text = tostring(index), TextSize = 14,
                        ThemeTag = {TextColor3 = "Text"}})
                end
                self.Buttons[index] = button
                self.Connections[#self.Connections + 1] = button.MouseButton1Click:Connect(function()
                    module:SelectTab(index)
                end)
            end
        end
        self:Refresh()
    end
    root.Destroying:Once(function()
        for _, connection in ipairs(self.Connections) do connection:Disconnect() end
        self.Connections, self.Buttons = {}, {}
    end)
    window.IconRail = self
    self:Sync()
end
return Rail
