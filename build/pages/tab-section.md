Sections group tabs in the sidebar under a heading. They are purely organisational — a tab belongs to one section.

## Basic

```lua
local Section = Window:Section({
    Title = "Combat",
    Opened = true,
})

Section:Tab({ Title = "Aimbot", Icon = "crosshair" })
Section:Tab({ Title = "ESP", Icon = "eye" })
Section:Tab({ Title = "Misc", Icon = "settings" })
```

## Collapsed by default

```lua
local Section = Window:Section({
    Title = "Experimental",
    Opened = false,
    Icon = "flask-conical",
    IconThemed = true,
})
```

## Parameters

| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `Title` | `string` | `"Section"` | Sidebar heading |
| `Opened` | `boolean?` | `true` | Start expanded |
| `Icon` | `string?` | — | Small icon beside the heading |
| `IconThemed` | `boolean?` | `false` | |

## Methods

| Method | Notes |
| --- | --- |
| `Section:Tab(config)` | Create a tab inside the section |
| `Section:Toggle(state)` | Expand / collapse |
| `Section:Destroy()` | Remove the section and its tabs |

## Element-level sections

There is also `Tab:Section({ Title = "..." })`, which groups elements **inside** a tab into a labelled block. Same name, different place:

| Call | Renders |
| --- | --- |
| `Window:Section` | Sidebar group of tabs |
| `Tab:Section` | Labelled block of elements inside a page |
| `Tab:Divider()` | Hairline separator |

## Notes

- Tabs created with `Window:Tab` land in the default (unsectioned) group.
- Search results keep their section label, so filtering still tells you where a tab lives.
