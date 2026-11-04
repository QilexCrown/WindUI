A floating player that lives outside the window: collapsed it is a black pill docked at the top of the screen — artwork on the left, a six-bar wave on the right, no text. Tap it and it springs open into a glass card with the cover, title, transport, scrubber, volume and a source picker. `DynamicIsland = false` boots the card instead and keeps it there.

It is a widget, not a tab element: `WindUI:MusicMiniPlayer()` hangs off the library itself, so it works with the window closed, minimised, or never created.

## Basic

```lua
local WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/QilexCrown/WindUI/main/dist/main.lua"))()

local Player = WindUI:MusicMiniPlayer({
    SongsFolder = "Ender Hub/songs",
})

-- Drop mp3, ogg, wav or flac into the folder and it shows up on the next scan.
Player:Scan()
```

Nothing else is needed for local playback: the widget scans the folder, splits `Artist - Title.mp3` filenames, and plays through a `Sound` it creates under `SoundService`.

## Always Open

```lua
local Player = WindUI:MusicMiniPlayer({
    DynamicIsland = false,   -- no pill, no expanding: the card from frame one
    Top = 10,
    Scale = 1,
})

-- Switch back at runtime.
Player:SetDynamicIsland(true)
```

`SetDynamicIsland(false)` freezes the card open and disables the outside-click collapse. `SetDynamicIsland(true)` drops it back to the pill and collapses it. The chevron in the top-right corner is hidden while the island is off.

## Full

```lua
local Player = WindUI:MusicMiniPlayer({
    DynamicIsland = true,
    SongsFolder = "Ender Hub/songs",
    Folder = "MyHub",          -- cache folder under WindUI/
    Top = 10,                  -- px from the top of the screen
    Scale = 1,
    PollInterval = 1.25,
    Position = UDim2.new(0.5, 0, 0, 10),

    -- Which rows the gear shows. A table means "this exact set, this order".
    Providers = {
        "spotify",
        "files",
        { Id = "apple", Name = "Apple Music", Url = "http://127.0.0.1:5764" },
        { Id = "youtube", Name = "YouTube Music", Url = "http://127.0.0.1:5765" },
        "sound",
        "demo",
    },

    -- "sound" source: mirror a Sound object the game already plays.
    Sound = workspace.Jukebox.Sound,

    OnVolume = function(percent)
        print("volume", percent)
    end,

    Callbacks = {
        Connect = function(provider) end,   -- a source came online
        Provider = function(provider) end,  -- the active source changed
        Update = function(state) end,       -- every poll
        Expanded = function(open) end,      -- pill <-> card
        Settings = function(open) end,
        Toggle = function(playing) end,
        Seek = function(seconds) end,
        Scrub = function(seconds) end,
        Volume = function(percent) end,
        CoverClick = function(state) end,   -- artwork tapped, after the link opens
        Error = function(message) end,
    },
})
```

Leaving `Providers` out gives all five in the order above.

## Settings

The gear in the top-right corner opens the source panel. Each row carries a status dot: grey when idle, green when the source answered. The sheet is 752x300; the right-hand pane is a short overview of the player.

| Row | Connects with |
| --- | --- |
| Spotify | PKCE authorize link, then the pasted redirect URL |
| My files | The folder in `SongsFolder`, scanned with `listfiles` |
| Apple Music | JSON bridge on `http://127.0.0.1:5764` |
| YouTube Music | JSON bridge on `http://127.0.0.1:5765` |
| Sound object | The `Sound` you passed in `Config.Sound` |
| Demo | Nothing — preview tracks on a clock |

## Songs Folder

Any executor with `listfiles` works. The scan keeps the extensions `.mp3`, `.ogg`, `.wav`, `.flac`, `.m4a` and `.aac`, and reads the name two ways:

```
Artist - Title.mp3   -> Artist, Title
Luv(sic).mp3         -> "Local file", "Luv(sic)"
```

Playback is `getcustomasset(path)` into a `Sound` parented to `SoundService`, named `WindUIMusicFile`, so the widget never steals the game's own audio.

### Cover art

Art is resolved in this order, and only the first miss costs a network call:

1. A sidecar image next to the audio with the same stem — `Luv(sic).jpg` (`.png`, `.jpeg`, `.webp`).
2. An iTunes Search lookup from the filename (`no key, no account`), the first `artworkUrl100` rewritten to 600x600, downloaded and written as `<stem>.jpg` beside the mp3.
3. Nothing — the placeholder glyph stays.

The write is what makes it cheap: the next `Scan()` finds the jpg through the sidecar check and no request goes out. Attempts are also cached per path for the session, so a track with no match is not searched twice.

```lua
local files = Player.ByProviderId.files
files.OnCover = function(track, asset)
    -- asset is an rbxasset:// URL that now also feeds the pill and the card
end
```

Tap the artwork to open the track link, if the source provided one.

### playlists.json

The folder carries its library state next to the audio, in the same shape the reference player writes:

```json
{"playlists":[],"shuffle":false,"selected":[]}
```

The file is created on the first scan if it is missing, and shuffle is written back when the toggle flips. Existing files are read, not overwritten.

## Spotify

Create an app at the [Spotify developer dashboard](https://developer.spotify.com/dashboard), add `http://127.0.0.1:8888/callback` as a redirect URI, then open the Spotify row in the widget:

1. Hit the authorize link with scopes `user-read-playback-state user-modify-playback-state user-read-currently-playing`.
2. Paste the redirect URL back into the field — the PKCE exchange happens in the executor.
3. Credentials land in `WindUI/<Folder>/music/spotify.json` and refresh on their own.

The widget polls `GET /me/player` every `PollInterval` seconds and mirrors whatever device is active — phone, desktop app, speaker. Controls go to `player/play`, `player/pause`, `player/next`, `player/previous`, `player/seek` and `player/volume`, so dragging the volume changes the volume of the device you are actually hearing. Cover art comes from the API response, not a placeholder.

```lua
-- drive it yourself: the same calls the widget makes
local spotify = Player.ByProviderId.spotify
spotify:Connect({}, function(ok, message)
    print(ok, message)
end)
```

## Bridge

Anything that is not Spotify speaks four read routes and six write routes over plain JSON. Point a row at your own server and it behaves like a first-class source.

```
GET  /now        -> { title, artist, album, cover, position, duration, playing, volume, canSkip }
POST /play
POST /pause
POST /next
POST /previous
POST /seek       <- { position = seconds }
POST /volume     <- { volume = 0-100 }
```

## Methods

| Method | Notes |
| --- | --- |
| `Player:Expand()` / `Player:Collapse()` | Pill <-> card, spring driven |
| `Player:ToggleSettings(bool)` | Open or close the source sheet |
| `Player:SetDynamicIsland(bool)` | Swap between pill mode and always-open card |
| `Player:Scan()` | Re-read the songs folder |
| `Player:Toggle()` | Play / pause |
| `Player:Next()` / `Player:Previous()` | Skip on the active source |
| `Player:Seek(seconds)` | Same path the scrubber uses |
| `Player:SetVolume(percent)` | 0-100, routed through the active provider |
| `Player:ToggleShuffle()` | Writes `shuffle` back to `playlists.json` |
| `Player:SetPlaying(bool)` | Flips the transport icon only |
| `Player:ApplyState(state)` | Push a whole state table by hand |
| `Player:OpenTrack()` | Open the current track link and fire `CoverClick` |
| `Player:SelectProvider(provider)` | Swap the active source |
| `Player:SetScale(number)` | `UIScale` on the widget only |
| `Player:Show()` / `Player:Hide()` | Visibility |
| `Player:Destroy()` | Stops the poll loop, disconnects, removes the shell |
| `Player:Fire(name, ...)` | Fires a `Callbacks` entry |

## Parameters

| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `DynamicIsland` | `boolean?` | `true` | `false` boots the expanded card and keeps it there |
| `SongsFolder` | `string?` | `Ender Hub/songs` | Folder the `files` source scans |
| `Folder` | `string?` | window folder | Cache folder under `WindUI/` for tokens and state |
| `Top` | `number?` | `10` | Px from the top of the screen |
| `Scale` | `number?` | `1` | `UIScale` on the widget |
| `Position` | `UDim2?` | top-centre | Overrides the dock position |
| `Parent` | `Instance?` | `WindUI.ScreenGui` | Where the shell is parented |
| `PollInterval` | `number?` | `1.25` | Seconds between provider polls, floor 0.5 |
| `Provider` | `string?` | first with a track | Id of the source to make active |
| `Providers` | `table?` | all five | `"spotify"`, `"files"`, `"sound"`, `"demo"`, or `{ Id, Name, Url }` |
| `Sound` | `Sound?` | — | Bound `Sound` for the `sound` source |
| `AppleBridge` | `string?` | `127.0.0.1:5764` | Default Apple bridge URL |
| `YouTubeBridge` | `string?` | `127.0.0.1:5765` | Default YouTube bridge URL |
| `OnVolume` | `function?` | — | Receives 0-100 |
| `Callbacks` | `table?` | — | `Connect`, `Provider`, `Update`, `Expanded`, `Settings`, `Toggle`, `Seek`, `Scrub`, `Volume`, `CoverClick`, `Error` |

## Notes

- The shell is 212x40 collapsed, 752x204 expanded, 752x300 with settings open, radius 20. Expansion is a real spring (stiffness scaled by duration, damping ratio 0.82), not an ease — it overshoots a couple of pixels and settles.
- Glass is four layers: a north sheen that fades before the middle, a specular band that sweeps on hover and expand, a 1px hairline stroke and a second rim one pixel in. Roblox has no refraction, so the moving highlight is what sells it.
- The widget is parented to `WindUI.ScreenGui`, not to a window, a tab or a section, and never appears in `Window.AllElements`.
- Local art also tints the shell: a 1.9x copy at 84% transparency behind a scrim, which reads as the blurred backdrop without a blur pass.
- A volume change can only touch the Spotify device, the bridge's own gain, or the local `Sound.Volume`. Roblox cannot reach the OS master volume; use the bridge for that.
