WindUI ships a bundled icon set: Lucide, Craft, Geist, Solar and SF Symbols, addressed by name.

## Use an icon

Anywhere a config takes an `Icon`:

```lua
Tab:Button({ Title = "Run", Icon = "play" })
Tab:Tab({ Title = "Home", Icon = "house" })
Window:Tag({ Title = "v2.5", Icon = "sparkles" })
```

## Formats

| Form | Example |
| --- | --- |
| Lucide name | `"play"`, `"key"`, `"sparkles"`, `"external-link"` |
| Pack prefix | `"lucide:play"`, `"solar:star"` |
| Roblox asset | `"rbxassetid://123456789"` |
| Remote URL | `"https://example.com/icon.png"` |
| Roblox thumbnail | `"rbxthumb://type=Asset&id=123&w=150&h=150"` |

## Add your own pack

```lua
WindUI:AddIcons("MyPack", {
    Star = "rbxassetid://123456789",
    Bolt = "rbxassetid://987654321",
})

Tab:Button({ Title = "Favourite", Icon = "mypack:star" })
```

## Look up an icon

```lua
local image, rect = WindUI:GetIcon("play")
print(image, rect.ImageRectSize, rect.ImageRectOffset)
```

## Notes

- Names are case-sensitive and lowercase.
- A missing icon renders an empty frame — it does not error, so a typo is silent. Check the name if an element looks bare.
- Icons in the key screen use `Header.Icon`, `Input.Icon`, `Input.SubmitIcon`, `Header.LinkIcon` and `Layout.Buttons[].Icon`.
