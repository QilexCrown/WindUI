-- Native Roblox approximation of the iOS material hierarchy.
-- Chrome gets a single quiet translucent surface; content stays readable.
local Creator = require('../modules/Creator')
local Dock = require('./ToolbarDock')
local Motion = require('./PressMotion')
local IOS26 = {}
function IOS26.Attach(window, config)
    Motion.Reduced = config.ReducedMotion == true
    if not window.IOS26 then return end
    local topbar = window.UIElements.Main.Main.Topbar
    window.TagDock = Dock.New(topbar.Center.Holder, config.WindUI)
    local material = Creator.NewRoundFrame(18, 'Squircle', {
        Name = 'IOS26Toolbar', Parent = topbar,
        Size = UDim2.new(1, -12, 1, -8), Position = UDim2.new(0, 6, 0, 4),
        ImageTransparency = 0.94, ZIndex = 0,
        ThemeTag = {ImageColor3 = 'Text'},
    }, {
        Creator.NewRoundFrame(18, 'SquircleOutline', {
            Name = 'Bezel', Size = UDim2.new(1, 0, 1, 0),
            ImageTransparency = 0.88, ThemeTag = {ImageColor3 = 'Text'},
        }),
    })
    window.UIElements.IOS26Toolbar = material
end
return IOS26
