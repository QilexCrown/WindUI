local Glass = assert(loadfile('src/modules/Glass.lua'))()
local made, creator = 0, {}
function creator.NewRoundFrame(_, shape, props)
    made = made + 1
    assert(shape == 'SquircleGlass', 'glass recursively requested an opaque surface')
    return {Parent = props.Parent, Visible = true}
end
function creator.New() return {} end
UDim2 = {new = function() return {} end}
NumberSequence = {new = function() return {} end}
NumberSequenceKeypoint = {new = function() return {} end}
local function frame(layout)
    return {Parent = true, ZIndex = 1, FindFirstChildOfClass = function(_, class) return layout and class == 'UIListLayout' end}
end
local properties = {ThemeTag = {ImageColor3 = 'ElementBackground'}}
local target = frame()
for i = 1, 1000 do Glass.Apply(creator, target, 16, 'Squircle', properties) end
assert(made == 1, 'duplicate surface layers accumulated')
Glass.Apply(creator, frame(), 16, 'SquircleGlass', properties)
Glass.Apply(creator, frame(true), 16, 'Squircle', properties)
Glass.Apply(creator, frame(), 16, 'Squircle', {ImageTransparency = 1, ThemeTag = properties.ThemeTag})
assert(made == 1, 'decorative/hidden/layout surfaces gained overlays')
Glass.SetEnabled(false)
Glass.Apply(creator, frame(), 16, 'Squircle', properties)
assert(made == 2)
Glass.SetEnabled(true)
Glass.Apply(creator, frame(), 16, 'Squircle', properties)
assert(made == 3)
print('Glass: deduplication, invisible/decorative/layout exclusions and performance toggle passed')
