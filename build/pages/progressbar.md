A progress bar for downloads, loaders and any numeric value. It can also run indeterminate.

## Basic

```lua
local Progress = Tab:ProgressBar({
    Title = "Download",
    Desc = "Downloading files...",
    Value = {
        Min = 0,
        Max = 100,
        Default = 25,
    },
})
```

## Indeterminate

```lua
local Progress = Tab:ProgressBar({
    Title = "Loading",
    Indeterminate = true,
    IndeterminateText = "Working…",
})
```

## Full

```lua
local Progress = Tab:ProgressBar({
    Title = "Extracting",
    Desc = "assets.zip",
    Value = { Min = 0, Max = 100, Default = 0 },
    ShowValue = true,
    Format = function(value, min, max)
        return string.format("%d / %d", value, max)
    end,
    Width = 160,
    Animate = true,
    Speed = 8,
    AnimationDuration = 0.35,
    ControlGap = 6,
})
```

## Parameters

| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `Title` | `string` | `"Progress"` | |
| `Desc` | `string?` | — | |
| `Value` | `table` | — | `{ Min, Max, Default }` |
| `Indeterminate` | `boolean?` | `false` | Endless sweep |
| `IndeterminateText` | `string?` | `""` | Label while indeterminate |
| `ShowValue` | `boolean?` | `true` | Numeric readout |
| `Format` | `function?` | — | `(value, min, max) -> string` |
| `Width` | `number?` | auto | Bar width |
| `Animate` | `boolean?` | — | Ease between values |
| `Speed` | `number?` | — | Ease speed |
| `AnimationDuration` | `number?` | — | |
| `ControlGap` | `number?` | — | |
| `DisplayMode` | `string?` | — | Bar style |

## Methods

| Method | Notes |
| --- | --- |
| `Progress:SetValue(value)` | Sets without firing a callback |
| `Progress:GetValue()` | Current value |
| `Progress:Destroy()` | |

## Notes

- `Indeterminate` overrides `ShowValue` — the label becomes `IndeterminateText`.
- Floats format to two decimals unless `Format` says otherwise.
- There is no `Callback`: a progress bar is display-only.
