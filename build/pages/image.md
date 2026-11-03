A full-width image element.

## Basic

```lua
Tab:Image({
    Image = "https://example.com/image.png",
    AspectRatio = "16:9",
    Radius = 12,
})
```

## Parameters

| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `Image` | `string` | — | URL, `rbxassetid://`, or asset id |
| `AspectRatio` | `string?` | `"16:9"` | `"1:1"`, `"4:3"`, `"16:9"`, `"21:9"` |
| `Radius` | `number?` | `12` | Corner radius |

## Notes

- The element scales to the tab width and keeps the aspect ratio.
- `rbxthumb://type=Asset&id=...&w=420&h=420` works for Roblox assets and is the reliable path for thumbnails.
- For a small icon or a side thumbnail on a text row, use [`Paragraph`](./paragraph.html) instead.
