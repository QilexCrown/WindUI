-- Pure logical-pixel layout. Lower priorities compact and disappear first.
local Layout = {}
local function finite(value, fallback)
    return type(value) == 'number' and value == value and math.abs(value) < math.huge and value or fallback
end
function Layout.Calculate(available, entries)
    available = math.max(0, finite(available, 0))
    local states, order = {}, {}
    local function total()
        local width, count = 0, 0
        for _, item in ipairs(states) do
            if item.Visible then width = width + item.Width; count = count + 1 end
        end
        return width + math.max(0, count - 1) * 6
    end
    for index, entry in ipairs(entries) do
        local width = math.max(28, math.min(144, finite(entry.Width, 28)))
        states[index] = {Width = width, Compact = false, Visible = true,
            CompactWidth = math.max(28, math.min(width, finite(entry.CompactWidth, width)))}
        order[index] = index
    end
    table.sort(order, function(a, b)
        local pa, pb = finite(entries[a].Priority, 0), finite(entries[b].Priority, 0)
        return pa == pb and a > b or pa < pb
    end)
    for _, index in ipairs(order) do
        if total() <= available then break end
        local item = states[index]
        if item.CompactWidth < item.Width then item.Width = item.CompactWidth; item.Compact = true end
    end
    for _, index in ipairs(order) do
        if total() <= available then break end
        states[index].Visible = false
    end
    local x = math.max(0, available - total())
    for _, item in ipairs(states) do
        item.X = x
        if item.Visible then x = x + item.Width + 6 end
    end
    return states
end
return Layout
