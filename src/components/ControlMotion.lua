local Creator = require("../modules/Creator")
local Motion = {}
function Motion.New(owner, reduced)
    local self = {Active = {}, Destroyed = false}
    function self:Cancel(slot)
        local entry = self.Active[slot]
        if not entry then return end
        self.Active[slot] = nil
        if entry.Connection then entry.Connection:Disconnect() end
        entry.Tween:Cancel()
    end
    function self:To(slot, target, duration, props)
        if self.Destroyed then return end
        self:Cancel(slot)
        if reduced then for key, value in pairs(props) do target[key] = value end; return end
        local entry = {Tween = Creator.Tween(target, duration, props, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)}
        self.Active[slot] = entry
        entry.Connection = entry.Tween.Completed:Connect(function()
            if self.Active[slot] == entry then self.Active[slot] = nil end
            entry.Connection:Disconnect()
        end)
        entry.Tween:Play()
    end
    function self:Destroy()
        if self.Destroyed then return end
        self.Destroyed = true
        local slots = {}
        for slot in pairs(self.Active) do slots[#slots + 1] = slot end
        for _, slot in ipairs(slots) do self:Cancel(slot) end
        if self.Connection then self.Connection:Disconnect(); self.Connection = nil end
    end
    self.Connection = owner.Destroying:Connect(function() self:Destroy() end)
    return self
end
return Motion
