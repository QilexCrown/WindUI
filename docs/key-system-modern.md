# Modern key screen

An opt-in replacement for the stock WindUI key dialog. Everything on the card —
layout, thumbnail, header, note, input, footer, status line and every button —
is driven from one table.

- **Opt-in only.** Passing `KeySystem.Layout` switches to the modern screen. No `Layout`,
  no change: the stock dialog renders exactly as it always has.
- **Reversible.** Delete the four-line dispatch at the top of `src/components/KeySystem.lua`
  (or just stop passing `Layout`) and the stock key system is back, untouched. Deleting
  `src/components/KeySystemModern.lua` as well leaves no trace.

```lua
function KeySystem.new(Config, Filename, func, keyValidator)
    if type(Config.KeySystem.Layout) == "table" then
        return require("./KeySystemModern").new(Config, Filename, func, keyValidator)
    end
    -- ... stock path
```

## Quick start

```lua
local WindUI = loadstring(game:HttpGet("..."))()

WindUI:CreateWindow({
    Title = "Premium Tool",
    Author = "you",
    Folder = "PremiumTool",
    Icon = "sparkles",
    KeySystem = {
        Title = "Access Required",
        Note = "Get your key at discord.gg/example - one key per account.",
        KeyValidator = function(key)
            return key == "TEST-KEY"
        end,
        SaveKey = false,
        URL = "https://discord.gg/example",
        Thumbnail = {
            Image = "rbxthumb://type=Avatar&id=" .. game:GetService("Players").LocalPlayer.UserId .. "&w=420&h=420",
            Title = "Premium Member",
        },
        Layout = {
            Accent = "Slider",
            Radius = 28,
            Padding = 24,
            Gap = 18,
            BodyWidth = 392,
            Header = {
                Kicker = "Secure Access",
                Title = "Access Required",
                Subtitle = "Enter your license key to continue",
                Badge = "Premium",
                Icon = "key",
            },
            Thumbnail = {
                Position = "Left",
                Size = 240,
                Title = "Premium Member",
                Subtitle = "Lifetime license",
                Badge = "VIP",
            },
            Input = { Placeholder = "XXXX-XXXX-XXXX" },
            Footer = { Align = "Left", Text = "WindUI key system" },
            Status = {
                Error = "That key is not valid.",
                Success = "Key accepted - loading",
                Duration = 20,
            },
            Buttons = {
                {
                    ID = "Discord",
                    Icon = "external-link",
                    IconOnly = true,
                    Slot = "Header",
                    Style = "Ghost",
                    Action = "CopyText",
                    Text = "https://discord.gg/example",
                },
                {
                    ID = "Copy",
                    Title = "Copy key",
                    Icon = "copy",
                    Slot = "Footer",
                    Style = "Secondary",
                    Action = "CopyKey",
                },
                {
                    ID = "Exit",
                    Title = "Exit",
                    Icon = "log-out",
                    Slot = "Footer",
                    Style = "Tertiary",
                    Action = "Exit",
                },
            },
        },
    },
})
```

## Stock keys still work

The modern screen reads the regular key-system config first, so an existing setup needs
no new fields:

| Key | Effect |
| --- | --- |
| `Title` | Fallback card title |
| `Note` | Note under the header (`**bold**` works) |
| `Key` / `KeyValidator` / `API` | Validation, unchanged |
| `SaveKey` | Saved-key flow, unchanged |
| `URL` | Adds the built-in "Get key" button |
| `Thumbnail.Image` / `Thumbnail.Title` / `Thumbnail.Width` | Fallback thumbnail |

## `Layout`

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| `Accent` | `string` \| `Color3` | `"Button"` | Theme key or a raw colour. Drives chip, submit, badges, focus ring, glow |
| `Width` | `number` | auto | Card width. Auto = padding + thumbnail + gap + body + padding |
| `BodyWidth` | `number` | `386` | Width of the text column |
| `Radius` | `number` | `26` | Card corner radius |
| `Padding` | `number` | `22` | Inner padding |
| `Gap` | `number` | `16` | Thumbnail-to-body gap |
| `Shadow` | `boolean` | `true` | `false` drops the drop shadow |
| `ShadowTransparency` | `number` | `0.5` | |
| `Glow` | `boolean` | `true` | `false` drops the accent glow |
| `GlowTransparency` | `number` | `0.76` | |
| `ShowNote` | `boolean` | `true` | `false` hides the note |
| `NoteStyle` | `string` | `"Plain"` | `"Plain"` or `"Box"` (boxed panel) |
| `NoteSize` | `number` | `14` | |
| `Buttons` | `table` | `{}` | Array of button entries, see below |
| `ShowURL` | `boolean` | `true` | `false` hides the auto "Get key" button |
| `URLTitle` | `string` | `"Get key"` | |
| `URLIcon` | `string` \| `false` | `"key"` | |
| `URLStyle` | `string` | `"Secondary"` | |
| `URLSlot` | `string` | `"Footer"` | |
| `ShowServices` | `boolean` | `true` | `false` hides auto buttons for `KeySystem.API` services |
| `ServicesSlot` | `string` | `"Footer"` | |
| `Shake` | `boolean` | `true` | `false` disables the invalid-key shake |
| `EnterToSubmit` | `boolean` | `true` | `false` ignores Enter in the input |
| `Notify` | `boolean` | `true` | Toast fallback when `Status.Show == false` |
| `Debug` | `boolean` | `false` | Publishes the controller to `getgenv().WindUIKeySystem` / `WindUIKeySystems` |

## `Layout.Thumbnail`

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| `Enabled` | `boolean` | `true` | `false` removes the panel entirely |
| `Position` | `string` | `"Left"` | `"Left"`, `"Right"`, `"Top"`, `"None"` |
| `Size` | `number` | `236` | Panel width for `Left` / `Right` |
| `Height` | `number` | `176` | Panel height for `Top` |
| `Image` | `string` | stock | Asset id or `rbxthumb://` |
| `Title` | `string` | stock | |
| `Subtitle` | `string` | — | |
| `Badge` | `boolean` \| `string` | — | `true` renders `"Premium"`, a string renders itself |
| `Radius` | `number` | `Radius - 8` | |
| `ScaleType` | `string` | `"Crop"` | Any `ImageLabel.ScaleType` |
| `Transparency` | `number` | `0` | |
| `Gradient` | `number` | `0.82` | Bottom scrim strength for the caption |
| `TitleSize` | `number` | `20` | |
| `SubtitleSize` | `number` | `13` | |

## `Layout.Header`

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| `Icon` | `string` \| `false` | `"key"` | Lucide name, any icon in WindUI's set |
| `IconSize` | `number` | `44` | Accent chip size |
| `IconRadius` | `number` | `13` | |
| `ChipIconSize` | `number` | `22` | |
| `ShowIcon` | `boolean` | `true` | `false` removes the chip |
| `Kicker` | `string` | — | Small uppercase line above the title |
| `Badge` | `boolean` \| `string` | — | Pill next to the kicker |
| `Title` | `string` | `KeySystem.Title` | |
| `Subtitle` | `string` | — | |
| `TitleSize` | `number` | `23` | |
| `SubtitleSize` | `number` | `13` | |
| `Close` | `boolean` | `true` | `false` removes the corner close button |

## `Layout.Input`

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| `Placeholder` | `string` | `"Enter Key"` | |
| `Height` | `number` | `54` | |
| `Radius` | `number` | `14` | |
| `TextSize` | `number` | `16` | |
| `Icon` | `string` \| `false` | `"key"` | Leading icon |
| `IconSize` | `number` | `20` | |
| `Submit` | `boolean` | `true` | `false` moves submit to the footer |
| `SubmitText` | `string` | `"Submit"` | |
| `SubmitBusyText` | `string` | `"Checking…"` | Shown while validating |
| `SubmitIcon` | `string` \| `false` | `"arrow-right"` | |
| `SubmitStyle` | `string` | `"Solid"` | |
| `SubmitWidth` | `number` | `112` | |
| `SubmitHeight` | `number` | `40` | |
| `SubmitRadius` | `number` | — | |
| `ClearButton` | `boolean` | `true` | The inline `x` |
| `Clearance` | `number` | `15` | Padding around the icon cluster |
| `AutoFocus` | `boolean` | `true` | |

## `Layout.Footer`

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| `Text` | `string` | — | Small caption under the buttons |
| `TextSize` | `number` | `12` | |
| `Align` | `string` | `"Left"` | `"Left"`, `"Center"`, `"Right"` |
| `Divider` | `boolean` | `true` | The hairline above the footer |
| `Gap` | `number` | `12` | |
| `Show` | `boolean` | `true` | `false` hides the whole footer |

## `Layout.Status`

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| `Show` | `boolean` | `true` | `false` uses a `WindUI:Notify` toast instead |
| `Error` | `string` | `"Invalid key."` | |
| `Empty` | `string` | `"Enter a key to continue."` | |
| `Success` | `string` | `"Key accepted. Loading…"` | |
| `Duration` | `number` | `3.2` | Seconds before the line fades |
| `TextSize` | `number` | `13` | |

## `Layout.Buttons`

Each entry is one button. Order inside a slot is `Order`, then declaration order.

| Field | Type | Notes |
| --- | --- | --- |
| `ID` | `string` | Exposed as `controller.Buttons[ID]` |
| `Title` | `string` | Label; omit with `IconOnly` for a square button |
| `Name` | `string` | Instance name, defaults to `Title` → `ID` |
| `Icon` | `string` | Lucide name |
| `IconSize` | `number` | |
| `IconOnly` | `boolean` | Square icon button |
| `Slot` | `string` | `Header`, `Input`, `Body`, `Thumbnail`, `Footer`, `Hidden` |
| `Order` | `number` | Sort inside the slot |
| `Style` / `Variant` | `string` | `Solid`, `Soft`, `Ghost`, `White` (`Primary` → Solid, `Secondary` → Soft, `Tertiary` → Ghost) |
| `Width` | `number` | |
| `Height` | `number` | Slot defaults: header 32, input 36, thumbnail 34, footer 38 |
| `Radius` | `number` | |
| `Disabled` | `boolean` | Dimmed, ignores clicks |
| `Action` | `string` | `Submit`, `Exit`, `CopyURL`, `CopyKey`, `CopyText` |
| `Text` | `string` | Payload for `CopyText` |
| `URL` | `string` | Payload for `CopyURL`, defaults to `KeySystem.URL` |
| `Callback` | `function(controller)` | Overrides `Action` |

**Slots**

- `Header` — right side of the title row, before the close button.
- `Input` — inside the key field, right of the clear button.
- `Body` — full-width row under the status line.
- `Thumbnail` — inside the thumbnail panel, bottom aligned.
- `Footer` — footer row.
- `Hidden` — never rendered, still reachable through `controller.Buttons`.

## Controller

```lua
local controller = getgenv().WindUIKeySystem -- requires Layout.Debug = true
controller.Submit()               -- run validation with the current text
controller.SetKey("XXXX")         -- set the field's text
controller.SetStatus("error", "Nope")
controller.SetBusy(true)
controller.Shake()
controller.Close()

controller.Buttons.Discord        -- TextButton
controller.Input                  -- TextBox
controller.Frame                  -- CanvasGroup card
controller.Mount                  -- full-screen Frame
```
