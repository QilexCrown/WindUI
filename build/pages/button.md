A button runs a callback. It can carry an icon, a description, tags and a locked state.

## Basic

```lua
local Button = Tab:Button({
    Title = "Click Me",
    Callback = function()
        print("Button clicked")
    end,
})
```

## Full

```lua
local Button = Tab:Button({
    Title = "Execute",
    Desc = "Runs the selected script",
    Icon = "play",
    IconAlign = "Right",          -- "Left" | "Right"
    IconColor = Color3.fromHex("#4ade80"),
    IconThemed = false,
    Color = Color3.fromHex("#18181b"),
    Justify = "Between",          -- "Between" | "Center" | "Left" | "Right"
    Locked = false,
    LockedTitle = "Locked",
    Tags = { "new" },
    Callback = function()
        print("running")
    end,
})
```

## Parameters

| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `Title` | `string` | `"Button"` | |
| `Desc` | `string?` | — | |
| `Icon` | `string?` | `mouse-pointer-click` | Lucide name, asset or URL |
| `IconAlign` | `string?` | `"Right"` | |
| `IconColor` | `Color3?` | — | |
| `IconThemed` | `boolean?` | `false` | |
| `Color` | `Color3?` | theme | Element background |
| `Justify` | `string?` | `"Between"` | |
| `Size` | `UDim2?` | — | |
| `Locked` | `boolean?` | `false` | Blocks the callback |
| `LockedTitle` | `string?` | — | Shown while locked |
| `Tags` | `table?` | — | Pills beside the title |
| `Image` / `ImageSize` | `string?` / `number?` | — | Leading image |
| `Thumbnail` / `ThumbnailSize` | `string?` / `number?` | — | |
| `Callback` | `function` | — | Fires on click |

## Methods

| Method | Notes |
| --- | --- |
| `Button:SetTitle(text)` | |
| `Button:SetDesc(text)` | |
| `Button:SetLocked(state)` | Enable / disable |
| `Button:Lock()` / `Button:Unlock()` | Shorthand |
| `Button:Destroy()` | Remove |

## Notes

- A locked button still renders and can still be hovered; the callback simply does not fire.
- `IconAlign = "Left"` puts the icon before the title, which reads better for action rows.
