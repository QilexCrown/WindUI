A tab is a page inside the window. Every element is built from a tab object.

## Basic

```lua
local Tab = Window:Tab({
    Title = "Main",
    Icon = "bird",
})
```

## Full

```lua
local Tab = Window:Tab({
    Title = "Combat",
    Desc = "Everything that goes bang",
    Icon = "swords",
    IconColor = Color3.fromHex("#f87171"),
    IconThemed = false,
    IconShape = "Squircle",     -- "Circle" | "Squircle" | "Square" | "None"
    Locked = false,
    LockedTitle = "Locked",
    ShowTabTitle = true,
    TabTitleAlign = "Left",     -- "Left" | "Center" | "Right"
    Border = true,
    CustomEmptyPage = {
        Icon = "frown",
        IconSize = 48,
        Title = "Nothing here yet",
        Desc = "Add an element",
    },
})
```

## Parameters

| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `Title` | `string` | `"Tab"` | Sidebar and page title |
| `Desc` | `string?` | — | Sidebar tooltip |
| `Icon` | `string?` | — | Lucide name |
| `IconColor` | `Color3?` | — | |
| `IconThemed` | `boolean?` | `false` | |
| `IconShape` | `string?` | — | Icon frame shape |
| `Locked` | `boolean?` | `false` | Element cannot be used until unlocked |
| `LockedTitle` | `string?` | — | |
| `ShowTabTitle` | `boolean?` | — | Renders the title inside the page |
| `TabTitleAlign` | `string` | `"Left"` | |
| `Border` | `boolean?` | — | |
| `CustomEmptyPage` | `table?` | built-in | Empty-state icon, size, title, desc |

## Methods

| Method | Notes |
| --- | --- |
| `Tab:OnChange(fn)` | Fires when the tab is selected |
| `Tab:Select()` | Select this tab |
| `Tab:Destroy()` | Remove the tab |

## Elements

Each call returns the element object (`SetTitle`, `SetDesc`, `Destroy`, … on it).

```lua
Tab:Paragraph{ Title = "Info", Desc = "Text block" }
Tab:Button{ Title = "Click", Callback = function() end }
Tab:Toggle{ Title = "Enabled", Callback = function(state) end }
Tab:Slider{ Title = "Volume", Value = { Min = 0, Max = 100, Default = 50 } }
Tab:Input{ Title = "Name", Placeholder = "username" }
Tab:Dropdown{ Title = "Mode", Values = { "A", "B" } }
Tab:Keybind{ Title = "Toggle UI", Value = "V" }
Tab:Colorpicker{ Title = "Colour", Default = Color3.new(1, 1, 1) }
Tab:Code{ Title = "Example", Code = "print('hi')" }
Tab:ProgressBar{ Title = "Download", Value = { Min = 0, Max = 100, Default = 25 } }
Tab:Image{ Image = "rbxassetid://0", AspectRatio = "16:9" }
Tab:Divider()
Tab:Space({ Columns = 1 })
Tab:HStack()
Tab:VStack()
Tab:Section({ Title = "Group" })
```

## Searching

The window search bar filters across every tab and element title; `HideSearchBar = false` keeps it visible, `false` hides it. Selecting a result switches to the owning tab and highlights the element.
