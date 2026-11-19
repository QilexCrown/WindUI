local Layout = {}

function Layout.Calculate(width, actionCount)
    width = tonumber(width) or 600
    if width ~= width or width <= 0 or width == math.huge then width = 600 end
    width = math.max(180, width)
    local compact = width < 280
    local padding = width < 280 and 12 or 16
    local gap = 8
    local columns = compact and 2 or 4
    local inner = width - padding * 2
    local statsY = 121
    local cellHeight = 38
    local rows = math.ceil(4 / columns)
    local actionsY = statsY + rows * cellHeight + (rows - 1) * gap + 8
    local hasActions = (actionCount or 0) > 0
    return {
        Width = width, Padding = padding, Gap = gap, Columns = columns,
        CellWidth = (inner - (columns - 1) * gap) / columns,
        CellHeight = cellHeight, StatsY = statsY, ActionsY = actionsY,
        Height = hasActions and (actionsY + 32 + padding) or (actionsY - 8 + padding),
        AvatarSize = compact and 48 or 54,
        NameSize = width < 320 and 19 or 22,
        IdentityX = padding + (compact and 48 or 54) + 14,
        IdentityWidth = inner - (compact and 48 or 54) - 14,
        ActionWidth = hasActions and (inner - ((actionCount or 0) - 1) * gap) / actionCount or 0,
    }
end

return Layout
