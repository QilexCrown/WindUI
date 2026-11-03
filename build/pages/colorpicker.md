A colorpicker returns a `Color3`, with optional alpha.

## Basic

```lua
local Colorpicker = Tab:Colorpicker({
    Title = "Select Color",
    Callback = function(color)
        print("color:", color)
    end,
})
```

## Full

```lua
local Colorpicker = Tab:Colorpicker({
    Title = "Accent",
    Desc = "Used on the highlight",
    Default = Color3.fromHex("#0091FF"),
    Transparency = 0,            -- adds an alpha slider when set
    Locked = false,
    Callback = function(color, transparency)
        print("color:", color, "alpha:", transparency)
    end,
})
```

## Parameters

| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `Title` | `string` | `"Colorpicker"` | |
| `Desc` | `string?` | — | |
| `Default` / `Value` | `Color3?` | `Color3.new(1, 1, 1)` | Initial colour |
| `Transparency` | `number?` | — | When set, renders an alpha slider |
| `Locked` | `boolean?` | `false` | |
| `Callback` | `function` | — | Receives `Color3` and alpha |

## Methods

| Method | Notes |
| --- | --- |
| `Colorpicker:SetValue(color)` | Sets without firing the callback |
| `Colorpicker:GetValue()` | Current `Color3` |
| `Colorpicker:Destroy()` | |

## Notes

- The picker opens as a popout anchored to the element; it is not a modal.
- HSV is kept internally, so dragging stays smooth instead of snapping per RGB step.
