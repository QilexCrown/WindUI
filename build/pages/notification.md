Notifications are short toasts in the corner. They stack, animate in, and disappear on a timer.

## Basic

```lua
WindUI:Notify({
    Title = "Success",
    Content = "Operation completed",
    Duration = 3,
})
```

## Full

```lua
WindUI:Notify({
    Title = "Config loaded",
    Content = "Profile 'main' applied.",
    Icon = "check",
    IconThemed = true,
    Duration = 4,
    CanClose = true,
    Buttons = {
        { Title = "Undo", Callback = function() end },
    },
})
```

## Parameters

| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `Title` | `string` | `"Notification"` | |
| `Content` | `string?` | — | Body text |
| `Icon` | `string?` | — | Lucide name, asset or URL |
| `IconThemed` | `boolean?` | `false` | Tints with the theme's `Icon` |
| `Duration` | `number?` | `3` | Seconds on screen |
| `CanClose` | `boolean?` | `false` | Show the close control |
| `Buttons` | `table?` | — | Array of `{ Title, Callback }` |
| `Background` | `Color3?` | theme | |
| `BackgroundImageTransparency` | `number?` | — | |

## Notes

- Notifications live in `WindUI.NotificationGui` — they survive window close.
- `WindUI:SetNotificationLower(true)` moves the stack down, away from the topbar.
- Long content wraps; there is no truncation.
- A toast is also the fallback for a failed key when `Layout.Status.Show = false`.
