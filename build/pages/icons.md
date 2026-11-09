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
| Apple SF Symbol | `"sfsymbols:playFill"`, `"sf:playFill"`, `"apple:playFill"` |
| Roblox asset | `"rbxassetid://123456789"` |
| Remote URL | `"https://example.com/icon.png"` |
| Roblox thumbnail | `"rbxthumb://type=Asset&id=123&w=150&h=150"` |

## Apple icons

The SF Symbols pack ships with the library — 6,984 symbols, drawn for Roblox at 100 x 100. Names are Apple's own, in camelCase, with `Fill` variants where Apple has them:

```lua
Tab:Button({ Title = "Play", Icon = "sf:playFill" })
Tab:Button({ Title = "Library", Icon = "apple:musicNoteList" })
Tab:Button({ Title = "Volume", Icon = "sf:speakerWave3Fill" })

-- whole pack as the default, so bare names resolve to Apple:
WindUI:SetIconPack("sfsymbols")
Tab:Button({ Title = "Heart", Icon = "heartFill" })
```

`sf:`, `apple:` and `sfsymbols:` are the same pack. A name that does not exist renders as nothing rather than erroring, so a typo costs one icon, not the window.

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
