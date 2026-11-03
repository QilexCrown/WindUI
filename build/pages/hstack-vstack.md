`HStack` lays elements out horizontally, `VStack` vertically. Both are real layout containers: children flow and size themselves.

## Basic

```lua
local HStack = Tab:HStack()

HStack:Button({ Title = "A" })
HStack:Button({ Title = "B" })
HStack:Button({ Title = "C" })
```

```lua
local VStack = Tab:VStack()

VStack:Button({ Title = "Top" })
VStack:Button({ Title = "Bottom" })
```

## Parameters

| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `AutoSpace` | `boolean?` | — | Let children share the row evenly |

## Nesting

```lua
local Row = Tab:HStack({ AutoSpace = true })

local Left = Row:VStack()
Left:Toggle({ Title = "Enabled" })
Left:Slider({ Title = "Speed", Value = { Min = 0, Max = 10, Default = 5 } })

local Right = Row:VStack()
Right:Button({ Title = "Apply" })
Right:Button({ Title = "Reset" })
```

## Notes

- Every element works inside a stack: buttons, toggles, sliders, inputs, dropdowns.
- `AutoSpace = true` is the usual choice for two half-width columns.
- Stacks can nest as deep as you like, but past two levels the layout gets cramped on small windows.
- A stack inside an `HStack` gets an equal share of the row only when `AutoSpace` is on.
