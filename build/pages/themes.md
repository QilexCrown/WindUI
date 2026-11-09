Themes are colour tables. Every element resolves its colours through the active theme, so switching themes restyles the whole interface — window chrome, elements, key screen and all.

## Built-in themes

`Dark`, `Light`, `Rose`, `Plant`, `Red`, `Indigo`, `Sky`, `Violet`, `Amber`, `Emerald`, `Midnight`, `Crimson`, `MonokaiPro`, `CottonCandy`, `Mellowsi`, `Rainbow`.

`Dark` is applied on load.

## Set a theme

At window creation:

```lua
local Window = WindUI:CreateWindow({
    Title = "My Hub",
    Theme = "Dark",
})
```

Or globally, before or after creating the window:

```lua
WindUI:SetTheme("Midnight")
```

## Read the current theme

```lua
print(WindUI:GetCurrentTheme().Name)
print(WindUI:GetThemes()) -- array of theme names
```

## Create a theme

```lua
WindUI:AddTheme({
    Name = "MyTheme",

    Accent = Color3.fromHex("#18181b"),
    Background = Color3.fromHex("#101010"),
    Dialog = Color3.fromHex("#1a1a1a"),
    Outline = Color3.fromHex("#ffffff"),
    Text = Color3.fromHex("#ffffff"),
    Placeholder = Color3.fromHex("#a1a1a1"),

    Button = Color3.fromHex("#52525b"),
    Icon = Color3.fromHex("#a1a1aa"),
    Toggle = Color3.fromHex("#33C759"),
    Slider = Color3.fromHex("#0091FF"),
    Checkbox = Color3.fromHex("#0091FF"),
    SliderIcon = Color3.fromHex("#908F95"),
    Primary = Color3.fromHex("#ffffff"),

    PanelBackground = Color3.fromHex("#ffffff"),
    PanelBackgroundTransparency = 0.95,
    LabelBackground = Color3.fromHex("#000000"),
    LabelBackgroundTransparency = 0.83,

    ElementBackground = Color3.fromHex("#2A2A2C"),
    ElementBackgroundTransparency = 0,
})

WindUI:SetTheme("MyTheme")
```

## React to a theme change

```lua
WindUI:OnThemeChange(function(theme)
    print("theme is now", theme.Name)
end)
```

## Gradients

`WindUI:Gradient` builds a `UIGradient`-shaped table. Elements that accept a fill — key-screen submit button, header tag, custom buttons — accept a `Color3`, a theme key, or this table.

```lua
local fill = WindUI:Gradient({
    ["0"]   = { Color = Color3.fromHex("#6B8E23"), Transparency = 0 },
    ["100"] = { Color = Color3.fromHex("#2F4F4F"), Transparency = 0 },
}, { Rotation = 45 })
```

## Theme keys used by the key screen

| Key | Dark value |
| --- | --- |
| `Background` | `#101010` |
| `Text` | `#FFFFFF` |
| `Icon` | `#a1a1aa` |
| `Button` | `#52525b` |
| `Toggle` | `#33C759` |
| `Slider` | `#0091FF` |
| `LabelBackground` | `#000000` at 0.83 transparency |
