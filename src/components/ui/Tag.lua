local Creator = require("../../modules/Creator")
local TextService = game:GetService("TextService")
local Tag = {}
function Tag:New(config, parent)
    config = config or {}
    local glass = config.Style == "Glass" or (config.Style == nil and config.Window and config.Window.IOS26)
    local self = {Title = config.Title or "Tag", Icon = config.Icon, Color = config.Color or Color3.fromHex("#315dff"),
        Height = 26, Priority = config.Priority or 0, CompactTitle = config.CompactTitle, Destroyed = false}
    local connections, icon, gradient, foreground = {}, nil, nil, Color3.new(1, 1, 1)
    local compact = false
    local frame = Creator.NewRoundFrame(13, "Squircle", {
        Name = glass and "IOS26Tag" or "Tag", Parent = parent,
        Size = UDim2.new(0, 80, 0, self.Height),
        AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0),
        ImageTransparency = glass and 0.90 or 0,
        ThemeTag = glass and {ImageColor3 = "Text"} or nil,
    }, {
        Creator.NewRoundFrame(13, "SquircleOutline", {
            Size = UDim2.new(1, 0, 1, 0), ImageTransparency = glass and 0.83 or 0.88,
            ThemeTag = {ImageColor3 = "Text"}, Name = "Bezel",
        }),
    })
    self.TagFrame, self.Frame = frame, frame
    local title = Creator.New("TextLabel", {
        Name = "Title", Parent = frame, Text = self.Title,
        FontFace = Font.new(Creator.Font, Enum.FontWeight.Medium), TextSize = 12,
        BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Center,
        TextTruncate = Enum.TextTruncate.AtEnd, TextWrapped = false,
        Size = UDim2.new(1, -20, 1, 0), Position = UDim2.new(0, 10, 0, 0),
        ThemeTag = glass and {TextColor3 = "Text"} or nil,
    })
    self.Title = title.Text
    local compactLabel
    if self.CompactTitle then
        compactLabel = Creator.New("TextLabel", {
            Name = "CompactTitle", Parent = frame, Text = self.CompactTitle,
            FontFace = Font.new(Creator.Font, Enum.FontWeight.Medium), TextSize = 12,
            BackgroundTransparency = 1, TextTruncate = Enum.TextTruncate.AtEnd,
            Size = UDim2.new(1, -20, 1, 0), Position = UDim2.new(0, 10, 0, 0), Visible = false,
            ThemeTag = glass and {TextColor3 = "Text"} or nil,
        })
        self.CompactTitle = compactLabel.Text
    end
    local function measure(text)
        return TextService:GetTextSize(tostring(text or ""), 12, Enum.Font.GothamMedium, Vector2.new(10000, 26)).X
    end
    local function refreshMetrics()
        self.Width = math.max(32, math.min(144, math.ceil(measure(self.Title)) + (icon and 40 or 20)))
        self.CompactWidth = icon and 30 or self.CompactTitle and math.max(32, math.ceil(measure(self.CompactTitle)) + 20) or self.Width
    end
    local function applyColor()
        if gradient then gradient:Destroy(); gradient = nil end
        if glass then return end
        local color = self.Color
        if typeof(color) == "string" then color = Creator.GetThemeProperty(color, Creator.Theme) end
        if typeof(color) == "table" then
            gradient = Creator.New("UIGradient", {Parent = frame})
            for key, value in pairs(color) do gradient[key] = value end
            frame.ImageColor3 = Color3.new(1, 1, 1)
            color = Creator.GetAverageColor(gradient)
        else frame.ImageColor3 = color end
        foreground = Creator.GetTextColorForHSB(color)
        title.TextColor3 = foreground
        if compactLabel then compactLabel.TextColor3 = foreground end
        if icon then icon.ImageLabel.ImageColor3 = foreground end
    end
    function self:GetMetrics()
        return {Width = self.Width, CompactWidth = self.CompactWidth, Priority = self.Priority}
    end
    function self:SetLayout(state)
        if self.Destroyed then return self end
        compact = state.Compact
        frame.Visible = state.Visible
        frame.Size = UDim2.new(0, state.Width, 0, self.Height)
        frame.Position = UDim2.new(0, state.X or 0, 0.5, 0)
        local inset = icon and not compact and 30 or 10
        title.Position = UDim2.new(0, inset, 0, 0)
        title.Size = UDim2.new(1, -inset - 10, 1, 0)
        title.Visible = not (compact and (icon ~= nil or compactLabel ~= nil))
        if compactLabel then compactLabel.Visible = compact and icon == nil end
        if icon then
            icon.AnchorPoint = Vector2.new(compact and 0.5 or 0, 0.5)
            icon.Position = UDim2.new(compact and 0.5 or 0, compact and 0 or 10, 0.5, 0)
        end
        return self
    end
    local function changed()
        refreshMetrics()
        if self.OnLayoutChanged then self.OnLayoutChanged()
        else self:SetLayout({Width = self.Width, Compact = false, Visible = true}) end
    end
    function self:SetTitle(text)
        self.Title = tostring(text or "")
        title.Text = self.Title
        changed()
        return self
    end
    function self:SetColor(color)
        self.Color = color
        applyColor()
        return self
    end
    function self:SetIcon(value)
        self.Icon = value
        if icon then icon:Destroy(); icon = nil end
        if value then
            icon = Creator.Image(value, value, 0, config.Window, "Tag", false)
            icon.Size, icon.Parent = UDim2.new(0, 14, 0, 14), frame
            if glass then Creator.AddThemeObject(icon.ImageLabel, {ImageColor3 = "Text"})
            else icon.ImageLabel.ImageColor3 = foreground end
        end
        changed()
        return self
    end
    local function cleanup()
        if self.Destroyed then return end
        self.Destroyed = true
        for _, connection in ipairs(connections) do connection:Disconnect() end
        connections = {}
        if self.OnDestroyed then self.OnDestroyed() end
        self.OnLayoutChanged, self.OnDestroyed = nil, nil
    end
    function self:Destroy()
        if not self.Destroyed then frame:Destroy() end
        return self
    end
    self:SetIcon(config.Icon)
    applyColor()
    connections[#connections + 1] = title:GetPropertyChangedSignal("Text"):Connect(function()
        if self.Destroyed then return end
        self.Title = title.Text; changed()
    end)
    if compactLabel then
        connections[#connections + 1] = compactLabel:GetPropertyChangedSignal("Text"):Connect(function()
            if self.Destroyed then return end
            self.CompactTitle = compactLabel.Text; changed()
        end)
    end
    connections[#connections + 1] = frame.Destroying:Connect(cleanup)
    connections[#connections + 1] = Creator:OnThemeChange(function() if not self.Destroyed then applyColor() end end)
    return self
end
return Tag
