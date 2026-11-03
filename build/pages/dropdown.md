A dropdown picks one value, or several with `Multi`.

## Basic

```lua
local Dropdown = Tab:Dropdown({
    Title = "Select Value",
    Values = { "Option 1", "Option 2", "Option 3" },
    Callback = function(selected)
        print("selected:", selected)
    end,
})
```

## Full

```lua
local Dropdown = Tab:Dropdown({
    Title = "Regions",
    Desc = "Pick any that apply",
    Values = { "EU", "NA", "ASIA", "OCE" },
    Value = { "EU" },
    Multi = true,
    AllowNone = true,
    SearchBarEnabled = true,
    MenuWidth = 180,
    Locked = false,
    Callback = function(selected, index)
        print("selected:", selected, index)
    end,
})
```

## Parameters

| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `Title` | `string` | `"Dropdown"` | |
| `Desc` | `string?` | — | |
| `Values` | `table` | `{}` | Array of strings |
| `Value` | `string` \| `table?` | — | Initial selection; table when `Multi` |
| `Multi` | `boolean?` | `false` | Multiple selection |
| `AllowNone` | `boolean?` | — | Allow an empty selection |
| `SearchBarEnabled` | `boolean?` | `false` | Search field in the menu |
| `MenuWidth` | `number` | `180` | |
| `Locked` | `boolean?` | `false` | |
| `Callback` | `function` | — | Receives the value(s) and index |

## Methods

| Method | Notes |
| --- | --- |
| `Dropdown:SetValue(value)` | Sets without firing the callback |
| `Dropdown:GetValue()` | Current value |
| `Dropdown:Refresh(values)` | Replace the option list |
| `Dropdown:SetTitle(text)` | |
| `Dropdown:Destroy()` | |

## Notes

- With `Multi = true`, `Callback` receives an array of the selected values.
- The menu renders into `WindUI.DropdownGui`, so it is never clipped by the window.
- `SearchBarEnabled` pays for itself past ~12 options.
