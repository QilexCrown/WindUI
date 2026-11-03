Tags are small pills in the window topbar centre. The key screen reuses the same renderer for its `Header.Tag`.

## Basic

```lua
Window:Tag({
    Title = "v2.5",
    Color = Color3.fromHex("#315dff"),
})
```

## Full

```lua
Window:Tag({
    Title = "v2.5",
    Icon = "sparkles",
    Color = WindUI:Gradient({
        ["0"]   = { Color = Color3.fromHex("#6B8E23"), Transparency = 0 },
        ["100"] = { Color = Color3.fromHex("#2F4F4F"), Transparency = 0 },
    }, { Rotation = 45 }),
    Radius = 999,
    Border = true,
})
```

## Parameters

| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `Title` | `string` | `"Tag"` | |
| `Icon` | `string?` | — | Lucide name |
| `Color` | `Color3` \| `string` \| gradient | `#315dff` | Theme key or `WindUI:Gradient` also accepted |
| `Radius` | `number` | `999` | `999` = full pill |
| `Border` | `boolean?` | `false` | |

## Text contrast

The label colour is computed from the fill with `Creator.GetTextColorForHSB`, so a dark tag gets white text and a light tag gets black text, gradients included.

## Notes

- `Window:Tag` reveals the topbar centre automatically if it was hidden.
- Only one tag slot is rendered per window; calling it again replaces the previous tag.
- Tags are static after creation — rebuild the tag to change it.
