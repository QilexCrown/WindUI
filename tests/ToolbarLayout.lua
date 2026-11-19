local Layout = assert(loadfile('src/components/ToolbarLayout.lua'))()
local tags = {
    {Width = 72, CompactWidth = 60, Priority = 100},
    {Width = 68, CompactWidth = 38, Priority = 90},
    {Width = 92, CompactWidth = 28, Priority = 10},
}
for _, width in ipairs({0, 12, 28, 60, 92, 120, 180, 232, 300, 1024}) do
    local states = Layout.Calculate(width, tags)
    local last = -1
    for index, item in ipairs(states) do
        if item.Visible then
            assert(item.Width > 0 and item.X >= 0 and item.X >= last)
            assert(item.X + item.Width <= width + 0.001, 'overflow at '..width)
            last = item.X + item.Width
        end
    end
end
local full = Layout.Calculate(300, tags)
assert(full[1].Width == 72 and full[3].Width == 92 and not full[3].Compact)
local compact = Layout.Calculate(180, tags)
assert(compact[1].Visible and not compact[1].Compact)
assert(compact[3].Compact, 'lowest priority compacts first')
local tiny = Layout.Calculate(70, tags)
assert(tiny[1].Visible and not tiny[3].Visible, 'version remains before GitHub')
assert(not Layout.Calculate(0, tags)[1].Visible)
local invalid = Layout.Calculate(-10, {{Width = 1/0, CompactWidth = 0}})
assert(not invalid[1].Visible)
print('Toolbar layout: 10 widths, priority, compaction and bounds passed')
