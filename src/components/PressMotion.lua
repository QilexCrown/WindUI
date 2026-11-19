-- A finite, local press. No render loop and no changes to Creator.Tween.
local Creator = require('../modules/Creator')
local Motion = {}
function Motion.Bind(button, reduced, ownedScale)
    local scale = ownedScale or button:FindFirstChildOfClass('UIScale')
    if (scale and not ownedScale) or reduced then return end
    -- Reuse is explicit, after replacing that control's previous motion owner.
    scale = scale or Creator.New('UIScale', {Parent = button, Scale = 1})
    local connections, current, destroyed, pressed = {}, nil, false, false
    local function animate(value, duration)
        if destroyed then return end
        if current then current:Cancel() end
        if Motion.Reduced then scale.Scale = 1; current = nil; return end
        current = Creator.Tween(scale, duration, {Scale = value}, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
        current:Play()
    end
    local function bind(event, callback) connections[#connections + 1] = event:Connect(callback) end
    local function isPress(input)
        return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
            or input.KeyCode == Enum.KeyCode.ButtonA or input.KeyCode == Enum.KeyCode.Return
    end
    bind(button.InputBegan, function(input)
        if isPress(input) then
            pressed = true; animate(0.97, 0.10)
        end
    end)
    bind(button.InputEnded, function(input)
        if pressed and isPress(input) then pressed = false; animate(1, 0.22) end
    end)
    bind(button.MouseLeave, function() pressed = false; animate(1, 0.18) end)
    bind(button.SelectionLost, function() pressed = false; animate(1, 0.18) end)
    bind(button.Destroying, function()
        destroyed = true
        if current then current:Cancel(); current = nil end
        for _, connection in ipairs(connections) do connection:Disconnect() end
        connections = {}
    end)
end
return Motion
