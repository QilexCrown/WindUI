local Creator = require('../modules/Creator')
local Motion = {Active = setmetatable({}, {__mode = 'k'})}
function Motion.Select(containers, selected, reduced)
    for index, container in pairs(containers) do
        local active = Motion.Active[container]
        if active then
            active.Tween:Cancel()
            active.Connection:Disconnect()
            Motion.Active[container] = nil
        end
        container.Visible = index == selected
        container.AnchorPoint = Vector2.new(0, 0)
    end
    local target = containers[selected]
    if not target or reduced then return end
    target.AnchorPoint = Vector2.new(0, 0.012)
    local tween = Creator.Tween(target, 0.24, {AnchorPoint = Vector2.new(0, 0)}, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    local entry = {Tween = tween}
    entry.Connection = target.Destroying:Connect(function()
        tween:Cancel(); entry.Connection:Disconnect(); Motion.Active[target] = nil
    end)
    Motion.Active[target] = entry
    tween.Completed:Once(function()
        if Motion.Active[target] == entry then
            entry.Connection:Disconnect(); Motion.Active[target] = nil
        end
    end)
    tween:Play()
end
return Motion
