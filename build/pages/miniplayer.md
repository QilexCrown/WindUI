The Miniplayer is the compact now-playing strip: 340 x 88, radius 18, floating over the game. The 56 px artwork sits at (14, 16), the title and artist beside it, five level bars on the right that only move while a track is running, then bare previous / play / next glyphs and a hairline progress bar along the bottom edge. Black and white only — the cover colour lives on the dynamic island, not here. Drag it anywhere with the library's own drag, the same one every other WindUI surface uses.

It is not the dynamic island and it does not open it — that is a separate element (`WindUI:DynamicIsland`). Both share the same provider set when they are given the same `Providers` and `Folder`, so a track started on one shows, pauses and skips on the other.

## Floating

```lua
local Music = WindUI:Miniplayer({
    Providers = { "files", "spotify", "demo" },
    Folder = "Ender Hub/songs",
})
```

Grab the strip anywhere that is not a control and drag it.

## Inside a window

Pass `Parent` and the card docks in that frame instead of the screen:

```lua
local Music = WindUI:Miniplayer({
    Parent = Tab.Frame,
    Providers = { "files" },
    Folder = "Ender Hub/songs",
})
```

It scales itself down to fit the parent, so a narrow tab still gets the whole card.

## Sources

`Providers` is an ordered list. The first entry boots. The card itself has no source list — that lives on the dynamic island's Library chip; switch here with `SetSource`.

| Value | What it plays |
| --- | --- |
| `"files"` | Audio files in `Folder`, with sidecar cover art (`song.mp3` + `song.jpg`) |
| `"spotify"` | The Spotify Web API through PKCE — needs `Spotify = { ClientId = "..." }` |
| `"demo"` | A built-in preview track, no files or account needed |
| `"sound"` | A `Sound` instance you already own, via `Sound = sound` |
| `{ Id, Name, Url }` | A bridge to your own backend |

```lua
local Music = WindUI:Miniplayer({
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
| `X` | `number` | `18` | Floating only, distance from the left of the screen |
| `Top` | `number` | `0` | Floating only, distance from the top of the screen |
| `Providers` | `table` | `{ "files", "spotify", "demo" }` | Ordered source list |
| `Folder` | `string` | `"Ender Hub/songs"` | Where the files provider looks |
| `Source` | `number \| string` | `1` | Which source boots |
| `Scale` | `number` | `1` | Multiplier on the fitted scale |
| `PollRate` | `number` | `0.25` | Seconds between provider polls |

## Methods

```lua
Music:Play()
Music:Pause()
Music:TogglePlay()
Music:Next()
Music:Previous()
Music:Seek(42)
Music:SetVolume(35)
Music:ToggleMute()

Music:SetSource("spotify")  -- index or provider id

Music:Show()
Music:Hide()
Music:Destroy()

local State = Music:GetState()
-- Title, Artist, Album, Cover, Position, Duration, Playing, Volume,
-- CanSeek, CanSkip, Link, Hint
```

## Cover art

The files provider looks for a sidecar image next to each track:

```
Ender Hub/songs/
    Bed the Cold Earth.mp3
    Bed the Cold Earth.jpg
```

`.jpg`, `.jpeg`, `.png` and `.webp` all work. No sidecar, no problem — the cover falls back to a music note on the black tile.
