local Creator = require("../modules/Creator")
local Motion = require("./ControlMotion")
local Glass = {}
function Glass.New(config)
    config = config or {}
    local radius = config.Radius or 18
    local self = {Selected = config.Selected == true, Destroyed = false, Connections = {}}
    local button = Creator.New("TextButton", {
        Name = config.Name or "GlassButton", Parent = config.Parent, Text = "",
        Size = config.Size or UDim2.new(1, 0, 0, 36), Position = config.Position,
        BackgroundTransparency = 1, BorderSizePixel = 0, AutoButtonColor = false, Selectable = true,
    })
    self.Button = button
    self.Fill = Creator.NewRoundFrame(radius, "Squircle", {
        Name = "GlassFill", Parent = button, Size = UDim2.new(1, 0, 1, 0),
        ImageTransparency = 0.9, ThemeTag = {ImageColor3 = "Text"},
    })
    self.Bezel = Creator.NewRoundFrame(radius, "SquircleGlass", {
        Name = "GlassBezel", Parent = button, Size = UDim2.new(1, 0, 1, 0),
        ImageTransparency = 0.72, ThemeTag = {ImageColor3 = "Text"},
    })
    local inset = 10
    if config.Icon then
        local data = Creator.Icon(config.Icon)
        if data and data[1] then
            local rect = data[2] or {}
            self.Icon = Creator.New("ImageLabel", {
                Name = "Icon", Parent = button, BackgroundTransparency = 1,
                Size = UDim2.new(0, 14, 0, 14), AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, 0),
                Image = data[1], ImageRectOffset = rect.ImageRectPosition or Vector2.new(0, 0), ImageRectSize = rect.ImageRectSize or Vector2.new(0, 0),
                ImageTransparency = 0.15, ThemeTag = {ImageColor3 = "ElementIcon"},
            })
            inset = 28
        end
    end
    self.Label = Creator.New("TextLabel", {
        Name = "Title", Parent = button, Text = config.Title or "", TextSize = config.TextSize or 12,
        BackgroundTransparency = 1, BorderSizePixel = 0, RichText = false,
        TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd, TextXAlignment = Enum.TextXAlignment.Center,
        FontFace = Font.new(Creator.Font, Enum.FontWeight.Medium),
        Position = UDim2.new(0, inset, 0, 0), Size = UDim2.new(1, -inset - 10, 1, 0),
        ThemeTag = {TextColor3 = "ElementTitle"},
    })
    if self.Icon and (config.Title or "") == "" then
        self.Icon.AnchorPoint = Vector2.new(0.5, 0.5)
        self.Icon.Position = UDim2.new(0.5, 0, 0.5, 0)
    end
    self.Scale = Creator.New("UIScale", {Parent = button, Scale = 1})
    local reduced = config.ReducedMotion or (config.Window and config.Window.ReducedMotion)
    self.Motion = Motion.New(button, reduced)
    local hovered, pressed = false, false
    local function paint()
        if self.Destroyed then return end
        local segment = config.Mode == "Segment"
        local fill = segment and (self.Selected and 0.90 or 1) or 0.90
        local rim = segment and (self.Selected and 0.68 or 1) or 0.76
        if hovered then fill = segment and (self.Selected and 0.85 or 0.96) or 0.84; rim = math.min(rim, 0.72) end
        if pressed then fill = 0.81 end
        self.Motion:To("fill", self.Fill, 0.16, {ImageTransparency = fill})
        self.Motion:To("bezel", self.Bezel, 0.16, {ImageTransparency = rim})
        self.Motion:To("label", self.Label, 0.16, {TextTransparency = segment and not self.Selected and 0.45 or 0.03})
        self.Motion:To("press", self.Scale, pressed and 0.10 or 0.20, {Scale = pressed and 0.975 or 1})
    end
    local function bind(event, fn) self.Connections[#self.Connections + 1] = event:Connect(fn) end
    bind(button.MouseEnter, function() hovered = true; paint() end)
    bind(button.MouseLeave, function() hovered, pressed = false, false; paint() end)
    bind(button.SelectionGained, function() hovered = true; paint() end)
    bind(button.SelectionLost, function() hovered, pressed = false, false; paint() end)
    local function isPress(input)
        return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
            or input.KeyCode == Enum.KeyCode.ButtonA or input.KeyCode == Enum.KeyCode.Return
    end
    bind(button.InputBegan, function(input) if isPress(input) then pressed = true; paint() end end)
    bind(button.InputEnded, function(input) if isPress(input) then pressed = false; paint() end end)
    bind(button.Activated, function() if not self.Destroyed and config.Callback then config.Callback() end end)
    bind(button.Destroying, function()
        self.Destroyed = true
        for _, connection in ipairs(self.Connections) do connection:Disconnect() end
        self.Connections = {}
        self.Motion:Destroy()
    end)
    function self:SetSelected(value)
        value = value == true
        if self.Selected == value then return end
        self.Selected = value; paint()
    end
    function self:Destroy() if not self.Destroyed then button:Destroy() end end
    paint()
    return self
end
return Glass
