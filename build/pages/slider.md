A slider picks a number in a range. It can also show an inline textbox for exact values.

## Basic

```lua
local Slider = Tab:Slider({
    Title = "Volume",
    Value = {
        Min = 0,
        Max = 100,
        Default = 50,
    },
    Callback = function(value)
        print("Volume:", value)
    end,
})
```

## Full

```lua
local Slider = Tab:Slider({
    Title = "Field of view",
    Desc = "Degrees",
    Value = {
        Min = 60,
        Max = 120,
        Default = 90,
    },
    Step = 1,
    IsTextbox = true,
    Width = 130,
    Icons = { "minus", "plus" },
    Locked = false,
    Callback = function(value)
        print("FOV:", value)
    end,
})
```

## Parameters

| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `Title` | `string` | `"Slider"` | |
| `Desc` | `string?` | — | |
| `Value` | `table` | — | `{ Min, Max, Default }` |
| `Step` | `number?` | `1` | Snap increment; use `0.01` for floats |
| `IsTextbox` | `boolean?` | `true` with a title | Numeric field beside the track |
| `Width` | `number` | `130` | Track width |
| `Icons` | `table?` | `{ "minus", "plus" }` | Step buttons |
| `Locked` | `boolean?` | `false` | |
| `Callback` | `function` | — | Receives the number |

## Methods

| Method | Notes |
| --- | --- |
| `Slider:SetValue(value)` | Sets without firing the callback |
| `Slider:GetValue()` | Current value |
| `Slider:SetTitle(text)` | |
| `Slider:Destroy()` | |

## Notes

- Float values format to two decimals in the label.
- `Step` larger than the range clamps to `Max`.
- The track colour follows the theme's `Slider` key, not the accent.
