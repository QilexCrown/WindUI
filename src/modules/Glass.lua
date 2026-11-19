local Glass = {Enabled = true}
local surfaces = setmetatable({}, {__mode = 'k'})
local roles = {ElementBackground = true, Button = true, Background = true,
    WindowBackground = true, TabBackground = true, Text = true}

function Glass.SetEnabled(enabled)
    Glass.Enabled = enabled ~= false
    for frame, overlay in pairs(surfaces) do
        if frame.Parent and overlay.Parent then overlay.Visible = Glass.Enabled end
    end
end

function Glass.Apply(creator, frame, radius, shape, properties)
    if shape ~= 'Squircle' or surfaces[frame] then return end
    local tags = properties and properties.ThemeTag
    if not tags or not roles[tags.ImageColor3] then return end
    if type(properties.ImageTransparency) == 'number' and properties.ImageTransparency >= 0.98 then return end
    if frame:FindFirstChildOfClass('UIListLayout') or frame:FindFirstChildOfClass('UIGridLayout') then return end
    -- One static image and gradient per visible semantic surface. No blur,
    -- pointer tracking, heartbeat task, or extra hover connection is needed.
    local overlay = creator.NewRoundFrame(radius, 'SquircleGlass', {
        Parent = frame, Name = 'LiquidGlass', Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1, ImageTransparency = 0.85, Active = false,
        ZIndex = frame.ZIndex, Visible = Glass.Enabled, ThemeTag = {ImageColor3 = 'White'},
    })
    creator.New('UIGradient', {Parent = overlay, Rotation = 115,
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.12),
            NumberSequenceKeypoint.new(0.46, 0.92),
            NumberSequenceKeypoint.new(1, 0.55),
        })})
    surfaces[frame] = overlay
end

return Glass
