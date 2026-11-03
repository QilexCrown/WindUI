# Modern key screen

An opt-in replacement for the stock WindUI key dialog. Everything on the card —
layout, thumbnail, header, note, input, footer, status line and every button —
is driven from one table.

- **Opt-in only.** Passing `KeySystem.Layout` switches to the modern screen. No `Layout`,
  no change: the stock dialog renders exactly as it always has.
- **Reversible.** Delete the four-line dispatch at the top of `src/components/KeySystem.lua`
  (or just stop passing `Layout`) and the stock key system is back, untouched. Deleting
  `src/components/KeySystemModern.lua` as well leaves no trace.
- **Theme-first.** Every colour resolves through `ThemeTag`, so the card follows the
  user's active theme. The default accent is the theme's `Button` key — grey on Dark,
  not blue. Only `Layout.Accent` overrides that.
- **Nothing is fixed.** Thumbnail, header icon, buttons, note, footer and each block's
  position are all config fields. A block can be nudged with `Offset` without breaking
  the flow.

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
        Layout = {
            Accent = "Button",
            Radius = 26,
            Padding = 22,
            Gap = 16,
            BodyWidth = 420,
            Header = {
                Kicker = "Secure Access",
                Title = "Access Required",
                Icon = "key",
                Tag = {
                    Title = "v2.5",
                    Color = WindUI:Gradient({
                        ["0"] = { Color = Color3.fromHex("#6B8E23"), Transparency = 0 },
                        ["100"] = { Color = Color3.fromHex("#2F4F4F"), Transparency = 0 },
                    }, { Rotation = 45 }),
                },
            },
            Input = {
                Placeholder = "XXXX-XXXX-XXXX",
                Label = "License key",
                SubmitFill = WindUI:Gradient({
                    ["0"] = { Color = Color3.fromHex("#6B8E23"), Transparency = 0 },
                    ["100"] = { Color = Color3.fromHex("#2F4F4F"), Transparency = 0 },
                }, { Rotation = 45 }),
            },
            Footer = { Align = "Left", Text = "example.com" },
            Status = {
                Success = "Key accepted - loading",
                Duration = 20,
                Errors = {
                    already_used = "This key is already used.",
                    expired = "This key has expired.",
                    revoked = "This key has been revoked.",
                },
            },
            -- Footer defaults to Get Key / Copy key / Exit; passing Buttons
            -- replaces that cluster outright.
            Buttons = {
                {
                    ID = "Copy",
                    Title = "Copy key",
                    Icon = "copy",
                    Slot = "Footer",
                    Style = "Secondary",
                    Action = "CopyKey",
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
| `URL` | Adds the built-in "Get Key" button and the top-right link icon |
| `Thumbnail.Image` / `Thumbnail.Title` / `Thumbnail.Width` | Fallback thumbnail |

## Error reasons

A validator can hand back a reason as the second value and the card maps it to a
message. `Layout.Status.Errors` overrides or extends the built-in set:

```lua
KeyValidator = function(key)
    local res = HttpGet("check?key=" .. key)
    if res.ok then return true end
    return false, res.reason    -- "already_used" | "expired" | "revoked" | ...
end

Layout = {
    Status = {
        Errors = {
            already_used = "This key is already used.",
            expired      = "This key has expired.",
            revoked      = "This key has been revoked.",
            banned       = "This key is banned.",
            wrong_account = "This key belongs to a different account.",
            limit        = "Key limit reached, try again later.",
        },
    },
}
```

Built-in reasons: `invalid`, `already_used`, `expired`, `revoked`, `banned`,
`wrong_account`, `limit`. Any other string returned as the reason is shown as-is.

## `Layout`

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| `Accent` | `string` \| `Color3` | `"Button"` | Theme key or a raw colour. Defaults to the theme's `Button` colour so the card matches whatever theme is loaded |
| `Width` | `number` | auto | Card width. Auto = padding + thumbnail + gap + body + padding |
| `BodyWidth` | `number` | `420` | Width of the text column |
| `Radius` | `number` | `26` | Card corner radius |
| `Padding` | `number` | `22` | Inner padding |
| `Gap` | `number` | `16` | Vertical gap between blocks, and thumbnail-to-body gap |
| `Offsets` | `table` | — | Per-block nudges, see [Moving elements](#moving-elements) |
| `Shadow` | `boolean` | `true` | `false` drops the drop shadow |
| `ShadowTransparency` | `number` | `0.5` | |
| `Glow` | `boolean` | `false` | Opt-in accent glow behind the card and inside the top-left corner |
| `GlowTransparency` | `number` | `0.76` | |
| `ShowNote` | `boolean` | `true` | `false` hides the note |
| `NoteStyle` | `string` | `"Plain"` | `"Plain"` or `"Box"` (boxed panel) |
| `NoteSize` | `number` | `14` | |
| `Buttons` | `table` | `Copy key`, `Exit` | Array of button entries, see below. Replaces the default cluster |
| `ShowURL` | `boolean` | `true` | `false` hides the auto link button |
| `URLTitle` | `string` | `"Get Key"` | Label of the auto link button |
| `URLIcon` | `string` \| `false` | `"key"` | |
| `URLOrder` | `number` | `10` | Sort order of the auto link button |
| `URLStyle` | `string` | `"Secondary"` | |
| `URLSlot` | `string` | `"Footer"` | |
| `URLAction` | `string` | `"OpenURL"` | `"OpenURL"` opens `KeySystem.URL`, `"CopyURL"` copies it |
| `ShowServices` | `boolean` | `true` | `false` hides auto buttons for `KeySystem.API` services |
| `ServicesSlot` | `string` | `"Footer"` | |
| `Shake` | `boolean` | `true` | `false` disables the invalid-key shake |
| `EnterToSubmit` | `boolean` | `true` | `false` ignores Enter in the input |
| `Notify` | `boolean` | `true` | Toast fallback when `Status.Show == false` |
| `Debug` | `boolean` | `false` | Publishes the controller to `getgenv().WindUIKeySystem` / `WindUIKeySystems` |

## Moving elements

Every block can be nudged without breaking the flow. The nudge is visual only —
the block draws shifted, its neighbours keep their slots.

```lua
Layout = {
    Header    = { Offset = { 0, -2 } },
    Input     = { Offset = { 0, 14 } },   -- default is { 0, 8 }
    Footer    = { Offset = { 0, 4 } },
    Thumbnail = { Offset = { -8, 0 } },
    Offsets   = {
        Note   = { 0, 6 },
        Status = { 0, -2 },
    },
}
```

`Offset` accepts `{ X, Y }` or `{ X = 0, Y = 6 }`. `Thumbnail.Offset` moves the
panel inside the row; `Layout.Thumbnail.Position` still decides which side it
lives on.

## `Layout.LoadingPill`

The busy pill replaces the status line while a key is being validated. It is on
by default; the spinner only animates while it is visible.

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| `Show` | `boolean` | `true` | `false` falls back to the inline "Checking…" submit label |
| `Text` | `string` | `"Checking key…"` | |
| `Height` | `number` | `24` | Also sets the status row height |
| `TextSize` | `number` | `12` | |
| `Style` | `string` | `"Soft"` | `Soft` (theme pill), `Solid` (accent pill), `Ghost` |
| `Icon` | `string` | `"loader"` | Lucide name, spins at 30 fps |

## `Layout.Thumbnail`

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| `Enabled` | `boolean` | `true` | `false` removes the panel entirely |
| `Position` | `string` | `"None"` | `"None"`, `"Left"`, `"Right"`, `"Top"` |
| `Size` | `number` | `236` | Panel width for `Left` / `Right` |
| `Height` | `number` | `176` | Panel height for `Top` |
| `Image` | `string` | stock | Asset id or `rbxthumb://` (no panel unless `Position` is set) |
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
| `IconBackground` | `boolean` | `false` | `true` draws the accent chip behind the icon; `false` is a bare theme-coloured icon |
| `IconSize` | `number` | `44` | Accent chip size (only used when `IconBackground = true`) |
| `IconRadius` | `number` | `13` | |
| `ChipIconSize` | `number` | `22` | Icon size inside the chip; bare icon defaults to `26` |
| `ShowIcon` | `boolean` | `true` | `false` removes the chip |
| `Kicker` | `string` | — | Small uppercase line above the title |
| `Badge` | `boolean` \| `string` | — | Pill inside the kicker row |
| `Tag` | `table` | — | `{ Title, Color, Icon, Height, TextSize }`. `Color` takes a `Color3`, theme key or `WindUI:Gradient`; renders inline beside the title |
| `Link` | `boolean` | `true` | Top-right icon that opens `KeySystem.URL` |
| `LinkIcon` | `string` | `"external-link"` | |
| `Title` | `string` | `KeySystem.Title` | |
| `Subtitle` | `string` \| `false` | `"License is required to use the script"` | `false` removes the line |
| `TitleSize` | `number` | `23` | |
| `SubtitleSize` | `number` | `13` | |
| `Close` | `boolean` | `true` | `false` removes the corner close button |

## `Layout.Input`

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| `Placeholder` | `string` | `"Enter Key"` | |
| `Label` | `string` \| `false` | `"License key"` | Small description line above the field |
| `LabelSize` | `number` | `12` | |
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
| `SubmitFill` | `Color3` \| `string` \| gradient | — | Custom submit colour. `WindUI:Gradient({...})` works; theme key or `Color3` also accepted |
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
| `Errors` | `table` | built-in | Reason code → message map, see [Error reasons](#error-reasons) |
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
| `FillColor` | `Color3` \| `string` \| gradient | Overrides the fill for any style; gradient tables work |
| `Width` | `number` | |
| `Height` | `number` | Slot defaults: header 32, input 36, thumbnail 34, footer 38 |
| `Radius` | `number` | |
| `Disabled` | `boolean` | Dimmed, ignores clicks |
| `Action` | `string` | `Submit`, `Exit`, `OpenURL`, `CopyURL`, `CopyKey`, `CopyText` |
| `Text` | `string` | Payload for `CopyText` |
| `URL` | `string` | Payload for `OpenURL` / `CopyURL`, defaults to `KeySystem.URL` |
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
