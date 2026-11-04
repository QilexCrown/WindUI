The Miniplayer is the dynamic island: a black pill that springs into a full music card. It reads real cover art, plays local files, Spotify or a bound sound, and it works floating over the game or docked inside a window.

## Floating

```lua
local Music = WindUI:Miniplayer({
    Providers = { "files", "spotify", "demo" },
    Folder = "Ender Hub/songs",
})
```

Collapsed it is 212 x 40 — artwork on the left, a six-bar wave on the right. Tap it and the artwork grows into a 752 x 204 card: title, transport, scrubber, four chips and a source column. Tap the artwork again to close it.

## Inside a window

Pass `Parent` and the island docks in that frame instead of the screen:

```lua
local Music = WindUI:Miniplayer({
    Parent = Tab.Frame,
    Providers = { "files" },
    Folder = "Ender Hub/songs",
})
```

It scales itself down to fit the parent, so a narrow tab still gets the whole card.

## Sources

`Providers` is an ordered list. The first entry boots; the rest show up in the library tab.

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
| `Top` | `number` | `12` | Floating only, distance from the top of the screen |
| `Providers` | `table` | `{ "files", "spotify", "demo" }` | Ordered source list |
| `Folder` | `string` | `"Ender Hub/songs"` | Where the files provider looks |
| `Source` | `number \| string` | `1` | Which source boots |
| `Expanded` | `boolean` | `false` | Boot with the card open |
| `Scale` | `number` | `1` | Multiplier on the fitted scale |
| `PollRate` | `number` | `0.25` | Seconds between provider polls |
| `OnExpand` | `function` | `nil` | `function(Miniplayer)` |
| `OnCollapse` | `function` | `nil` | `function(Miniplayer)` |
| `OnLike` | `function` | `nil` | `function(Liked, State)` |

## Methods

```lua
Music:Expand()
Music:Collapse()
Music:Toggle()

Music:Play()
Music:Pause()
Music:TogglePlay()
Music:Next()
Music:Previous()
Music:Seek(42)
Music:SetVolume(35)
Music:ToggleMute()

Music:SetTab("library")     -- "player" or "library"
Music:SetSource("spotify")  -- index or provider id
Music:ToggleShuffle()
Music:ToggleLike()

Music:Show()
Music:Hide()
Music:Destroy()

local State = Music:GetState()
-- Title, Artist, Album, Cover, Position, Duration, Playing, Volume,
-- CanSeek, CanSkip, Link, Hint
```

## The wave

The six bars follow `State.Playing`: full amplitude while a track runs, a low idle breath when it is paused. Nothing to wire up — the element reads the provider state it already polls.

## Cover art

The files provider looks for a sidecar image next to each track:

```
Ender Hub/songs/
    Bed the Cold Earth.mp3
    Bed the Cold Earth.jpg
```

`.jpg`, `.jpeg`, `.png` and `.webp` all work. No sidecar, no problem — the cover falls back to a music note on the black tile.
