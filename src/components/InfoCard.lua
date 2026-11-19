local Creator = require("../modules/Creator")
local Layout = require("./InfoCardLayout")
local New = Creator.New
local InfoCard = {}

local function radius(config)
    local window = config.Window
    return window and window.ElementConfig and window.ElementConfig.UICorner or 23
end
local function surface(config, name, height, button)
    local modern = not config.Window or config.Window.NewElements
    return Creator.NewRoundFrame(radius(config), "Squircle", {
        Parent = config.Parent, Name = name, Size = UDim2.new(1, 0, 0, height),
        BackgroundTransparency = 1, BorderSizePixel = 0,
        ImageTransparency = not modern and 0.93 or nil,
        ThemeTag = {
            ImageColor3 = modern and "ElementBackground" or "Text",
            ImageTransparency = modern and "ElementBackgroundTransparency" or nil,
        },
    }, nil, button)
end
local function label(parent, name, text, size, transparency, weight)
    return New("TextLabel", {
        Parent = parent, Name = name, BackgroundTransparency = 1, BorderSizePixel = 0,
        Text = text or "", TextSize = size, TextTransparency = transparency or 0,
        TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center,
        TextTruncate = Enum.TextTruncate.AtEnd, RichText = false,
        FontFace = Font.new(Creator.Font, weight or Enum.FontWeight.Medium),
        ThemeTag = { TextColor3 = "ElementTitle" },
    })
end
local function icon(parent, name, x, y, size)
    local data = Creator.Icon(name)
    if not data or not data[1] then return nil end
    local rect = data[2] or {}
    return New("ImageLabel", {
        Parent = parent, Name = "Icon", BackgroundTransparency = 1,
        Image = data[1], ImageRectOffset = rect.ImageRectPosition or Vector2.new(0, 0),
        ImageRectSize = rect.ImageRectSize or Vector2.new(0, 0),
        Position = UDim2.new(0, x, 0, y), Size = UDim2.new(0, size, 0, size),
        ImageTransparency = 0.3, ThemeTag = { ImageColor3 = "ElementIcon" },
    })
end
local function disconnect(list)
    for _, connection in ipairs(list) do connection:Disconnect() end
    for i = #list, 1, -1 do list[i] = nil end
end
local function actionButton(parent, name, text, iconName, config)
    local button = New("TextButton", { Parent = parent, Name = name, Text = "",
        BackgroundTransparency = 1, AutoButtonColor = false, Selectable = true, BorderSizePixel = 0 })
    local fill = Creator.NewRoundFrame(12, "Squircle", {
        Parent = button, Name = "Surface", Size = UDim2.new(1, 0, 1, 0),
        ImageTransparency = 0.9, ThemeTag = { ImageColor3 = "Button" },
    })
    Creator.NewRoundFrame(12, "SquircleGlass", {
        Parent = button, Name = "Outline", Size = UDim2.new(1, 0, 1, 0),
        ImageTransparency = 0.92, ThemeTag = { ImageColor3 = "White" },
    })
    local textLabel = label(button, "Title", text, 12, 0.1)
    textLabel.Size = UDim2.new(1, -28, 1, 0)
    textLabel.Position = UDim2.new(0, 22, 0, 0)
    textLabel.TextXAlignment = Enum.TextXAlignment.Center
    icon(button, iconName, 9, 9, 14)
    local connections = {}
    local function hover(on)
        if button.Parent then Creator.Tween(fill, 0.14, { ImageTransparency = on and 0.8 or 0.9 }):Play() end
    end
    for _, event in ipairs({ "MouseEnter", "SelectionGained" }) do
        connections[#connections + 1] = button[event]:Connect(function() hover(true) end)
    end
    for _, event in ipairs({ "MouseLeave", "SelectionLost" }) do
        connections[#connections + 1] = button[event]:Connect(function() hover(false) end)
    end
    connections[#connections + 1] = button.Activated:Connect(function()
        if button.Parent and config.Callback then config.Callback() end
    end)
    connections[#connections + 1] = button.Destroying:Connect(function() disconnect(connections) end)
    return button, textLabel
end

function InfoCard.New(config)
    assert(config and config.Parent, "InfoCard requires a Parent")
    local card = { Values = {}, Labels = {}, Chips = {}, Destroyed = false, Actions = {} }
    local connections, cells, chips = {}, {}, {}
    local lastWidth
    card.Frame = surface(config, "InfoCard", 212)
    card.Version = label(card.Frame, "Version", config.Version, 10, 0.5)
    card.Version.Visible = false
    local avatar = New("ImageLabel", { Parent = card.Frame, Name = "Avatar", Image = config.Avatar or "",
        BackgroundTransparency = 1, BorderSizePixel = 0 })
    New("UICorner", { Parent = avatar, CornerRadius = UDim.new(1, 0) })
    New("UIStroke", { Parent = avatar, Thickness = 1, Transparency = 0.75,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border, ThemeTag = { Color = "ElementTitle" } })
    card.Welcome = label(card.Frame, "Welcome", config.Welcome or "Welcome,", 12, 0.4)
    card.Display = label(card.Frame, "DisplayName", config.DisplayName or "Player", 22, 0.02, Enum.FontWeight.SemiBold)
    card.User = label(card.Frame, "Username", config.Username, 11, 0.5)
    for i, key in ipairs({ "server", "region" }) do
        local holder = New("Frame", { Parent = card.Frame, Name = key, BackgroundTransparency = 1 })
        icon(holder, i == 1 and "server" or "globe", 0, 2, 12)
        local text = label(holder, "Text", "--", 10, 0.4)
        text.Position, text.Size = UDim2.new(0, 17, 0, 0), UDim2.new(1, -17, 1, 0)
        chips[i], card.Chips[key] = holder, text
    end
    local divider = New("Frame", { Parent = card.Frame, Name = "Divider", BorderSizePixel = 0,
        BackgroundTransparency = 0.92, ThemeTag = { BackgroundColor3 = "Text" } })
    local names = { "activity", "gauge", "users", "timer" }
    for i, key in ipairs({ "ping", "fps", "players", "session" }) do
        local cell = New("Frame", { Parent = card.Frame, Name = key, BackgroundTransparency = 1 })
        icon(cell, names[i], 0, 2, 12)
        local value = label(cell, "Value", "--", 14, 0.04, Enum.FontWeight.SemiBold)
        value.Position, value.Size = UDim2.new(0, 17, 0, 0), UDim2.new(1, -17, 0, 19)
        local caption = label(cell, "Caption", "", 9, 0.5)
        caption.Position, caption.Size = UDim2.new(0, 0, 0, 21), UDim2.new(1, 0, 0, 13)
        cells[i], card.Values[key], card.Labels[key] = cell, value, caption
    end
    local function reflow()
        if card.Destroyed then return end
        local width = card.Frame.AbsoluteSize.X
        if width == lastWidth then return end
        lastWidth = width
        local shape = Layout.Calculate(width, #card.Actions)
        card.Frame.Size = UDim2.new(1, 0, 0, shape.Height)
        avatar.Position, avatar.Size = UDim2.new(0, shape.Padding, 0, 17), UDim2.new(0, shape.AvatarSize, 0, shape.AvatarSize)
        card.Welcome.Position, card.Welcome.Size = UDim2.new(0, shape.IdentityX, 0, 15), UDim2.new(0, shape.IdentityWidth, 0, 16)
        card.Display.Position, card.Display.Size = UDim2.new(0, shape.IdentityX, 0, 31), UDim2.new(0, shape.IdentityWidth, 0, 28)
        card.Display.TextSize = shape.NameSize
        card.User.Position, card.User.Size = UDim2.new(0, shape.IdentityX, 0, 61), UDim2.new(0, shape.IdentityWidth, 0, 15)
        for i, chip in ipairs(chips) do
            local w = (shape.Width - shape.Padding * 2 - shape.Gap) / 2
            chip.Position, chip.Size = UDim2.new(0, shape.Padding + (i - 1) * (w + shape.Gap), 0, 86), UDim2.new(0, w, 0, 18)
        end
        divider.Position, divider.Size = UDim2.new(0, shape.Padding, 0, 111), UDim2.new(1, -shape.Padding * 2, 0, 1)
        for i, cell in ipairs(cells) do
            local column, row = (i - 1) % shape.Columns, math.floor((i - 1) / shape.Columns)
            cell.Position = UDim2.new(0, shape.Padding + column * (shape.CellWidth + shape.Gap), 0, shape.StatsY + row * (shape.CellHeight + shape.Gap))
            cell.Size = UDim2.new(0, shape.CellWidth, 0, shape.CellHeight)
        end
        for i, action in ipairs(card.Actions) do
            action.Button.Position = UDim2.new(0, shape.Padding + (i - 1) * (shape.ActionWidth + shape.Gap), 0, shape.ActionsY)
            action.Button.Size = UDim2.new(0, shape.ActionWidth, 0, 32)
        end
    end
    function card:SetStats(stats)
        if self.Destroyed then return end
        for key, value in pairs(stats or {}) do
            local target = self.Values[key] or self.Chips[key]
            if target then target.Text = tostring(value) end
        end
    end
    function card:SetActions(actions)
        if self.Destroyed then return end
        assert(type(actions) == "table" and #actions <= 2, "InfoCard supports up to two actions")
        for _, action in ipairs(self.Actions) do action.Button:Destroy() end
        self.Actions = {}
        for i, spec in ipairs(actions) do
            local button, text = actionButton(self.Frame, spec.Id or "Action", spec.Title,
                spec.Icon or (i == 1 and "rotate-cw" or "refresh-cw"), spec)
            self.Actions[#self.Actions + 1] = { Button = button, Label = text }
        end
        lastWidth = nil
        reflow()
    end
    function card:Destroy()
        if self.Destroyed then return end
        self.Destroyed = true
        disconnect(connections)
        self.Frame:Destroy()
    end
    connections[#connections + 1] = card.Frame.Destroying:Connect(function()
        card.Destroyed = true
        disconnect(connections)
    end)
    connections[#connections + 1] = card.Frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(reflow)
    card:SetActions(config.Actions or {})
    return card
end

function InfoCard.Credits(config)
    local rows = config.Rows or {}
    local panel = { Roles = {} }
    panel.Frame = surface(config, "Credits", 44 + #rows * 24 + 12)
    panel.Header = label(panel.Frame, "Title", config.Title or "Credits", 14, 0.08, Enum.FontWeight.SemiBold)
    panel.Header.Position, panel.Header.Size = UDim2.new(0, 16, 0, 13), UDim2.new(1, -32, 0, 20)
    for i, row in ipairs(rows) do
        local y = 42 + (i - 1) * 24
        icon(panel.Frame, row.Icon or "user", 16, y + 3, 13)
        local role = label(panel.Frame, "Role", row.Role, 11, 0.45)
        role.Position, role.Size = UDim2.new(0, 38, 0, y), UDim2.new(0.44, -38, 0, 20)
        local handle = label(panel.Frame, "Handle", row.Handle, 13, 0.05, Enum.FontWeight.SemiBold)
        handle.AnchorPoint, handle.Position = Vector2.new(1, 0), UDim2.new(1, -16, 0, y)
        handle.Size, handle.TextXAlignment = UDim2.new(0.53, -16, 0, 20), Enum.TextXAlignment.Right
        panel.Roles[i] = role
    end
    function panel:Destroy() self.Frame:Destroy() end
    return panel
end

function InfoCard.Feedback(config)
    local button = actionButton(config.Parent, "FeedbackFloat", "", config.Icon or "message-square", {})
    button.AnchorPoint, button.Position = Vector2.new(1, 1), UDim2.new(1, -14, 1, -14)
    button.Size, button.Visible, button.ZIndex = UDim2.new(0, 42, 0, 42), false, 40
    for _, child in ipairs(button:GetDescendants()) do
        if child:IsA("GuiObject") then child.ZIndex = 41 end
        if child.Name == "Icon" then child.Position, child.Size = UDim2.new(0.5, -8, 0.5, -8), UDim2.new(0, 16, 0, 16) end
    end
    return button
end

return InfoCard
