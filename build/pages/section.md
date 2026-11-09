A section is a labelled block of elements inside a tab. It can collapse.

## Basic

```lua
local Section = Tab:Section({
    Title = "Aimbot settings",
})

Section:Toggle({ Title = "Enabled", Callback = function(state) end })
Section:Slider({ Title = "Smoothing", Value = { Min = 0, Max = 1, Default = 0.5 } })
```

## Full

```lua
local Section = Tab:Section({
    Title = "Advanced",
    Desc = "Touch nothing unless you mean it",
    Opened = false,
    Icon = "triangle-alert",
    IconThemed = true,
    TextSize = 14,
    TextTransparency = 0,
    FontWeight = "SemiBold",
    TextXAlignment = "Left",
    Box = true,
    BoxBorder = true,
    UICorner = 12,
})
```

## Parameters

| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `Title` | `string` | `"Section"` | |
| `Desc` | `string?` | — | Small line under the title |
| `Opened` | `boolean?` | `true` | Start expanded |
| `Icon` | `string?` | — | |
| `IconThemed` | `boolean?` | `false` | |
| `TextSize` | `number?` | — | |
| `TextTransparency` | `number?` | — | |
| `FontWeight` | `string?` | — | Any `Enum.FontWeight` name |
| `TextXAlignment` | `string?` | — | |
| `Box` | `boolean?` | — | Draw the section container |
| `BoxBorder` | `boolean?` | — | |
| `UICorner` | `number?` | — | |

## Methods

| Method | Notes |
| --- | --- |
| `Section:Toggle(state)` | Expand / collapse |
| `Section:SetTitle(text)` | |
| `Section:Destroy()` | Remove the section with its elements |

## Notes

- A section is a thin wrapper: elements created on it are normal tab elements with an indented frame.
- Collapsing hides the elements but keeps their state — toggles stay on.
