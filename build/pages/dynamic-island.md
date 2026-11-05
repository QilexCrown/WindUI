The DynamicIsland is the capsule at the top of the screen and the general surface for short-lived content: music is one mode it can show, a toast is another. Collapsed it is a black pill with the artwork on the left and a six-bar wave on the right. Click it and it springs into the full music card — header with the source and the ping, the now-playing block, the two chips, then the scrubber and the transport. Click the header again (or right-click the island) to close it.

The pill takes its colour from the sleeve: the six wave bars are plain solid bars tinted with the cover's dominant hue, and the glow under the cards is a single pixel of the artwork stretched flat. Nothing is guessed and no palette is fixed - it is the cover's own colour, taken at render time. No artwork, neutral white bars.

The pill never moves. It is anchored to the top centre at `Top`, and expanding changes its size, not its position.

## Floating

```lua
local Island = WindUI:DynamicIsland({
    Providers = { "files", "spotify", "demo" },
    Folder = "Ender Hub/songs",
})
```

Collapsed it is 212 x 40 with 28 px artwork at (6, 6) and six 3 px bars on the right edge. Opened it is 476 x 204: the now-playing card is 288 x 96 at (14, 36) with 72 px artwork, the Shuffle and Library chips are two 152 x 44 rows on the right, and the 448 x 50 scrubber with both times and the three transport discs sits under them. The bars keep animating while the pill is collapsed.

Drag the pill to move it, drag the header to move the open card.

## Inside a window

Pass `Parent` and the island docks in that frame instead of the screen:

```lua
local Island = WindUI:DynamicIsland({
    Parent = Tab.Frame,
    Providers = { "files" },
    Folder = "Ender Hub/songs",
})
```

It scales itself down to fit the parent, so a narrow tab still gets the whole card.

## Sources

`Providers` is an ordered list. The first entry boots; the Library chip opens the Sources pane, which grows the card to 752 wide and lists every provider. Shuffle toggles the active provider's shuffle. With the pane open both chips shrink to 30 x 30 icon buttons in a column beside it.

| Value | What it plays |
| --- | --- |
| `"files"` | Audio files in `Folder`, with sidecar cover art (`song.mp3` + `song.jpg`) |
| `"spotify"` | The Spotify Web API through PKCE — needs `Spotify = { ClientId = "..." }` |
| `"demo"` | A built-in preview track, no files or account needed |
| `"sound"` | A `Sound` instance you already own, via `Sound = sound` |
| `{ Id, Name, Url }` | A bridge to your own backend |

```lua
local Island = WindUI:DynamicIsland({
    Providers = {
        "files",
        { Id = "radio", Name = "Radio", Url = "https://example.com/now-playing" },
    },
    Folder = "Ender Hub/songs",
})
```

## Parameters

| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `Parent` | `Instance` | `nil` | Docks inside this frame instead of floating |
| `Top` | `number` | `12` | Floating only, distance from the top of the screen |
| `Providers` | `table` | `{ "files", "spotify", "demo" }` | Ordered source list |
| `Folder` | `string` | `"Ender Hub/songs"` | Where the files provider looks |
| `Source` | `number \| string` | `1` | Which source boots |
| `Expanded` | `boolean` | `false` | Boot with the card open |
| `Scale` | `number` | `1` | Multiplier on the fitted scale |
| `PollRate` | `number` | `0.25` | Seconds between provider polls |
| `AutoCollapse` | `boolean` | `true` | Count down to the pill after the pointer has been over the island; `false` keeps it open |
| `KeySystem` | `table` | `nil` | Loading-then-key flow on the island; see Key system |
| `OnExpand` | `function` | `nil` | `function(DynamicIsland)` |
| `OnCollapse` | `function` | `nil` | `function(DynamicIsland)` |

## Methods

```lua
Island:Expand()
Island:Collapse()
Island:Toggle()

Island:Toast({ Title = "Copied", Icon = "lucide:clipboard", Duration = 2 })
Island:Dismiss()

Island:Loading(5, "Loading")
Island:SetProgress(0.42)
Island:ShowKey()
Island:HideKey()
Island:KeyValid()
Island:DismissKey()

Island:Play()
Island:Pause()
Island:TogglePlay()
Island:Next()
Island:Previous()
Island:Seek(42)
Island:SetVolume(35)
Island:ToggleShuffle()
Island:ToggleSide()       -- sources pane
Island:ToggleSide(true)   -- force open, false to force closed

Island:CycleSource()
Island:SetSource("spotify")  -- index or provider id

Island:Show()
Island:Hide()
Island:Destroy()

local State = Island:GetState()
-- Title, Artist, Album, Cover, Position, Duration, Playing, Volume,
-- CanSeek, CanSkip, Link, Hint
```

## Toast

The pill is not music-only. Every mode is an element on the same surface: music, toast, loading, key. `Toast` swaps the artwork and the wave for a small card - an icon tile, a title and a description - and hands the pill back to now-playing when the timer runs out. The toast card is 300 x 76, slightly smaller than the 340 x 88 mini player, and it does not expand.

```lua
Island:Toast({
    Icon = "lucide:clipboard",
    Title = "Copied to clipboard",
    Description = "Paste it anywhere, it stays on the clipboard",
    Duration = 2,
})
Island:Toast({ Title = "Player joined", Icon = "sfsymbols:personFill", Duration = 4 })
Island:Dismiss()  -- back to now-playing right away
```

`Icon` takes any name `Creator.Icon` understands, `Description` is optional (the title centres itself when it is missing), `Duration` is in seconds (default 3), and `Color` tints the glyph and the title. `Text` and `Desc` are accepted as aliases so the old one-line toast still works. Clicking a toast dismisses it; the music keeps playing underneath.

## Loading

`Loading` grows the island into a 340 x 88 card — the mini player's footprint — and fills it with the hub name, what is loading, a percentage in the corner, and a progress bar along the bottom. No artwork, no icon, black and white. When the timer runs out the card collapses back to the pill and shows a green check with `Script Loaded` for `KeySystem.LoadedFor` seconds (default 1.8). After that the island flips to the key prompt when `Config.KeySystem` is set, or back to now-playing without one.

```lua
Island:Loading(5, "Loading modules, ui, services...")
Island:SetProgress(0.42)  -- drives the bar and the percentage
```

`SetProgress` pins the remaining time to the value shown, so a caller that reports real progress keeps the card honest. The title is `KeySystem.LoadingTitle` (default `Ender Hub`) and the line under it is the `Label` argument, falling back to `KeySystem.Loading`.

## Key system

The key prompt is a mode of the same capsule, not a dialog. While it is up the music sections fade out and the key card fades in on the same curve. The card carries the key tile and title top-left, live ping and mount time top-right, a field with the submit button inside it, a red error line with its alert glyph underneath, and three glass buttons: Get Key, Copy Key, Exit. Clicking the island collapses it to a `Key Required` pill with a white key glyph; clicking again brings the card back.

```lua
local Island = WindUI:DynamicIsland({
    Providers = { "files", "demo" },
    KeySystem = {
        Key = "WIND",                       -- or a list, or KeyValidator, or API
        Delay = 5,                          -- loading seconds before the prompt
        LoadedFor = 1.8,                    -- seconds "Script Loaded" stays on the pill
        LoadingTitle = "Ender Hub",
        Loading = "Loading modules, ui...",
        Title = "Key System",
        Note = "Enter your key to unlock the interface.",
        Placeholder = "Enter Your Key",
        Invalid = "Invalid key.",           -- custom error line
        Empty = "Enter a key first.",
        ValidFor = 4,                       -- seconds the green tick stays up
        GetKey = "https://example.com/key", -- string is copied, function runs
        Copy = nil,                         -- overrides what Copy Key copies
        OnExit = function(island) end,      -- falls back to collapsing the card
        SaveKey = false,
        File = "Ender Hub/key.key",
        Callback = function(valid) end,
    },
})
```

A wrong key flashes the error in red with an alert icon and shakes the whole input row; the row settles back on its own. Get Key copies `GetKey` to the clipboard (or calls it), Copy Key copies the key, Exit runs `OnExit`. A valid key closes the card, puts `Key Valid` on the pill in green with a check, then hands the pill back to now-playing after `ValidFor` seconds. `SavedKey` skips the prompt when it already validates. Without `Config.KeySystem` the island is music and toasts only.

## Header

The right side of the header is live: `wifi` shows the current server ping in milliseconds, `clock` shows how long the island has been mounted. Both come off `Stats.Network` and the clock, nothing to wire up.

## Cover art

The files provider looks for a sidecar image next to each track:

```
Ender Hub/songs/
    Bed the Cold Earth.mp3
    Bed the Cold Earth.jpg
```

`.jpg`, `.jpeg`, `.png` and `.webp` all work. No sidecar, no problem — the cover falls back to a music note on the black tile.

## Separate from the Miniplayer

The island is its own element. It does not open the Miniplayer and the two share nothing on screen — only the provider plumbing underneath. Use one, the other, or both.
