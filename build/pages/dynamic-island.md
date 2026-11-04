The DynamicIsland is the capsule at the top of the screen. Collapsed it is a black pill with the artwork on the left and a six-bar wave on the right. Click it and it springs into the full music card — header with the source and the ping, the now-playing block, the two chips, then the scrubber and the transport. Click the header again (or right-click the island) to close it.

## Floating

```lua
local Island = WindUI:DynamicIsland({
    Providers = { "files", "spotify", "demo" },
    Folder = "Ender Hub/songs",
})
```

Collapsed it is 212 x 40 with 28 px artwork at (6, 6). Opened it is 540 x 204: the now-playing card is 320 x 114 at (24, 50) with 84 px artwork, the Shuffle and Library chips are 160 x 54 on the right, and the scrubber with both times and the three transport discs sits under them.

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

`Providers` is an ordered list. The first entry boots; the Library chip cycles through the rest.

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
| `OnExpand` | `function` | `nil` | `function(DynamicIsland)` |
| `OnCollapse` | `function` | `nil` | `function(DynamicIsland)` |

## Methods

```lua
Island:Expand()
Island:Collapse()
Island:Toggle()

Island:Play()
Island:Pause()
Island:TogglePlay()
Island:Next()
Island:Previous()
Island:Seek(42)
Island:SetVolume(35)
Island:ToggleShuffle()

Island:CycleSource()
Island:SetSource("spotify")  -- index or provider id

Island:Show()
Island:Hide()
Island:Destroy()

local State = Island:GetState()
-- Title, Artist, Album, Cover, Position, Duration, Playing, Volume,
-- CanSeek, CanSkip, Link, Hint
```

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
