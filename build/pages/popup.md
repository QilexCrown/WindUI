Popups are standalone windows outside the main interface. Use them for announcements, confirmations and anything that should survive the window closing.

## Basic

```lua
local Popup = WindUI:Popup({
    Title = "Welcome",
    Content = "Welcome to the hub!",
    Buttons = {
        { Title = "Get Started", Callback = function() print("go") end },
    },
})
```

## Full

```lua
local Popup = WindUI:Popup({
    Title = "Update available",
    Content = "Version 2.5 is out. Reload the script to update.",
    Icon = "sparkles",
    IconThemed = true,
    Thumbnail = "rbxassetid://0",
    Buttons = {
        { Title = "Reload", Callback = function() end },
        { Title = "Later",  Callback = function() Popup:Close() end },
    },
})
```

## Parameters

| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `Title` | `string` | `"Popup"` | |
| `Content` | `string?` | — | Body text |
| `Icon` | `string?` | — | Lucide name, asset or URL |
| `IconThemed` | `boolean?` | `false` | |
| `Thumbnail` | `string?` | — | Image above the content |
| `Buttons` | `table` | `{}` | Array of `{ Title, Callback }` |

## Methods

| Method | Notes |
| --- | --- |
| `Popup:Close()` | Dismiss |
| `Popup:Open()` | Show again |

## Notes

- Popups render into `WindUI.ScreenGui.Popups`, so they do not depend on a window existing.
- A popup with no buttons still closes from its own close control.
