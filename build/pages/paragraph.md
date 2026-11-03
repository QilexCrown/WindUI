A paragraph is static content: text, an image, a thumbnail and optional buttons. Use it for info blocks, credits and status messages.

## Basic

```lua
Tab:Paragraph({
    Title = "Info",
    Desc = "Basic paragraph text",
})
```

## Full

```lua
Tab:Paragraph({
    Title = "Changelog",
    Desc = "v2.5 - wide card, instant open, wrong-key animation.",
    Image = "rbxassetid://0",
    ImageSize = 32,
    Thumbnail = "rbxassetid://0",
    ThumbnailSize = 64,
    Color = Color3.fromHex("#18181b"),
    Hover = false,
    Buttons = {
        {
            Title = "Copy",
            Icon = "copy",
            Callback = function() end,
        },
    },
})
```

## Parameters

| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `Title` | `string` | `""` | |
| `Desc` | `string` | `""` | Body text, wraps |
| `Image` | `string?` | — | Small leading image |
| `ImageSize` | `number?` | — | |
| `Thumbnail` | `string?` | — | Larger side image |
| `ThumbnailSize` | `number?` | — | |
| `Color` | `Color3?` | theme | |
| `Hover` | `boolean?` | `false` | Hover highlight |
| `Buttons` | `table?` | — | Array of `{ Title, Icon, Callback }` |

## Methods

| Method | Notes |
| --- | --- |
| `Paragraph:SetTitle(text)` | |
| `Paragraph:SetDesc(text)` | |
| `Paragraph:SetImage(id, size)` | |
| `Paragraph:SetThumbnail(id, size)` | |
| `Paragraph:Destroy()` | |

## Notes

- Rich text is not parsed; `Desc` renders as plain text.
- Buttons render inline on the right of the row and are full element buttons, not text links.
