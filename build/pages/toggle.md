A toggle is a binary control. It renders as a switch or a checkbox.

## Basic

```lua
local Toggle = Tab:Toggle({
    Title = "Enable Feature",
    Callback = function(state)
        print("state:", state)
    end,
})
```

## Full

```lua
local Toggle = Tab:Toggle({
    Title = "Auto execute",
    Desc = "Runs on injection",
    Icon = "zap",
    Value = true,
    Type = "Toggle",          -- "Toggle" | "Checkbox"
    Locked = false,
    LockedTitle = "Locked",
    Callback = function(state)
        print("auto execute:", state)
    end,
})
```

## Parameters

| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `Title` | `string` | `"Toggle"` | |
| `Desc` | `string?` | — | |
| `Icon` | `string?` | — | |
| `Value` | `boolean?` | `false` | Initial state |
| `Type` | `string?` | `"Toggle"` | `"Toggle"` or `"Checkbox"` |
| `Locked` | `boolean?` | `false` | |
| `LockedTitle` | `string?` | — | |
| `Image` / `ImageSize` | `string?` / `number?` | — | Leading image |
| `Thumbnail` / `ThumbnailSize` | `string?` / `number?` | — | |
| `Tags` | `table?` | — | |
| `Callback` | `function` | — | Receives the new boolean |

## Methods

| Method | Notes |
| --- | --- |
| `Toggle:SetValue(state)` | Sets without firing the callback |
| `Toggle:GetValue()` | Current boolean |
| `Toggle:SetTitle(text)` | |
| `Toggle:SetDesc(text)` | |
| `Toggle:Lock()` / `Toggle:Unlock()` | |
| `Toggle:Destroy()` | |

## Notes

- `SetValue` updates the visual without calling your callback; that is the one to use when loading saved config so you do not re-run side effects.
- The switch colour follows the theme's `Toggle` key.
