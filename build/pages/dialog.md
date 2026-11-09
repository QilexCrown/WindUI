Dialogs are modal panels inside the window. They block the rest of the UI until a button is pressed.

## Basic

```lua
local Dialog = Window:Dialog({
    Title = "Confirm Action",
    Content = "Are you sure?",
    Buttons = {
        { Title = "Yes", Callback = function() print("confirmed") end },
        { Title = "No",  Callback = function() print("cancelled") end },
    },
})
```

## Full

```lua
local Dialog = Window:Dialog({
    Title = "Delete config",
    Content = "This removes the saved config permanently.",
    Width = 340,
    Buttons = {
        {
            Title = "Delete",
            Callback = function()
                -- do the thing
            end,
        },
        {
            Title = "Cancel",
            Callback = function()
                Dialog:Close()
            end,
        },
    },
})
```

## Parameters

| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `Title` | `string` | `"Dialog"` | |
| `Content` | `string?` | — | Body text |
| `Width` | `number` | `320` | |
| `Buttons` | `table` | `{}` | Array of `{ Title, Callback }` |

## Methods

| Method | Notes |
| --- | --- |
| `Dialog:Close()` | Dismiss |
| `Dialog:Open()` | Re-open |

## Notes

- Dialogs live inside the window; if the window is closed the dialog goes with it.
- Buttons close the dialog automatically unless the callback keeps it open.
- For a standalone popup use [`WindUI:Popup`](./popup.html).
