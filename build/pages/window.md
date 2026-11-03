`CreateWindow` builds the frame, topbar, sidebar, search and the container every tab lives in. One window per loaded bundle.

## Basic

```lua
local Window = WindUI:CreateWindow({
    Title = "My Super Hub",
    Icon = "door-open",       -- lucide name, rbxassetid:// or URL
    Author = "by you",
})
```

## Full

```lua
local Window = WindUI:CreateWindow({
    Title = "My Super Hub",
    Author = "by you",
    Icon = "sparkles",
    IconSize = 22,
    IconThemed = true,
    Folder = "MyHub",              -- config folder under WindUI/
    Theme = "Dark",

    Size = UDim2.new(0, 620, 0, 460),
    MinSize = Vector2.new(560, 350),
    MaxSize = Vector2.new(850, 560),
    Resizable = true,

    ToggleKey = Enum.KeyCode.RightShift,
    Radius = 16,
    Transparent = false,
    SideBarWidth = 200,
    Acrylic = false,

    User = {
        Enabled = true,
        Anonymous = false,
        Callback = function() end,
    },

    Topbar = {
        Height = 52,
        ButtonsType = "Default",   -- "Default" or "Mac"
        Center = true,
    },
})
```

## Parameters

| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `Title` | `string` | `"UI Library"` | Window title (also the opt-in splash title) |
| `Author` | `string?` | — | Subtitle under the title |
| `Icon` | `string?` | - | Lucide name, `rbxassetid://`, or URL. Also the opt-in key-screen splash icon |
| `IconSize` | `number` | `22` | |
| `IconThemed` | `boolean?` | `false` | Tints the icon with the theme's `Icon` |
| `IconRadius` | `number` | `0` | |
| `Folder` | `string?` | — | Config folder name under `WindUI/` |
| `Theme` | `string?` | `"Dark"` | Any theme name |
| `Size` | `UDim2?` | `580x460` | Clamped by `MinSize` / `MaxSize` |
| `MinSize` | `Vector2?` | `560, 350` | |
| `MaxSize` | `Vector2?` | `850, 560` | |
| `Resizable` | `boolean?` | `true` | |
| `ToggleKey` | `Enum.KeyCode?` | — | Hotkey to show/hide |
| `Radius` | `number` | `16` | Window corner radius |
| `Transparent` | `boolean?` | `false` | |
| `SideBarWidth` | `number` | `200` | |
| `Acrylic` | `boolean?` | `false` | Blur behind the window |
| `User` | `table?` | — | `Enabled`, `Anonymous`, `Callback` |
| `Topbar` | `table?` | — | `Height`, `ButtonsType`, `Center`, `Left`, `Right` |
| `KeySystem` | `table?` | — | See [Key System](./key-system.html) |
| `OpenButton` | `table?` | — | Floating open button config |

## Methods

| Method | Notes |
| --- | --- |
| `Window:Tab(config)` | Create a tab, returns the tab object |
| `Window:Section(config)` | Create a sidebar section that groups tabs |
| `Window:SelectTab(tab)` | Switch the active tab |
| `Window:Dialog(config)` | Modal dialog inside the window |
| `Window:Tag(config)` | Pill in the topbar centre |
| `Window:Notify(config)` | Shortcut for `WindUI:Notify` |
| `Window:Close()` / `Window:Open()` | Hide / show |
| `Window:Destroy()` | Tear the window down |
| `Window:SetTitle(text)` | |
| `Window:SetSize(udim2)` | |
| `Window:SetUIScale(scale)` / `Window:GetUIScale()` | |
| `Window:SetToggleKey(keycode)` | |
| `Window:ToggleFullscreen()` | |
| `Window:ToggleTransparency()` | |
| `Window:SetBackgroundImage(id)` | |
| `Window:SetBackgroundTransparency(value)` | |
| `Window:SetBackgroundImageTransparency(value)` | |
| `Window:SetPanelBackground(enabled)` | |
| `Window:SetIconSize(size)` | |
| `Window:SetAuthor(author)` | |
| `Window:SetToTheCenter()` | |
| `Window:LockAll()` / `Window:UnlockAll()` | Lock every element |
| `Window:GetLocked()` / `Window:GetUnlocked()` | |
| `Window:CreateTopbarButton(config)` | |
| `Window:DisableTopbarButtons(state)` | |
| `Window:EditOpenButton(config)` | |
| `Window:OnOpen(fn)` / `Window:OnClose(fn)` / `Window:OnDestroy(fn)` | Lifecycle hooks |
| `Window:Divider()` | Sidebar divider |
| `Window:IsResizable(state)` | |

## Open button

```lua
local Window = WindUI:CreateWindow({
    Title = "My Hub",
    OpenButton = {
        Title = "Open",
        Icon = "mouse-pointer-2",
        Radius = 12,
        Position = UDim2.new(0, 20, 0, 20),
    },
})
```
