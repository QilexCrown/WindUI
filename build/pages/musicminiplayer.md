A draggable glass card that floats on its own, outside the window — cover art bleeding behind the text, hairline highlight, progress you can scrub, and a gear that swaps the source. Spotify is wired end to end; Apple Music and YouTube Music ride a local bridge; a `Sound` and a demo preview need no service at all.

It is a widget, not a tab element: `WindUI:MusicMiniPlayer()` hangs off the library itself, so it works with the window closed, minimised, or never created.

## Basic

```lua
local WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/QilexCrown/WindUI/main/dist/main.lua"))()

local Player = WindUI:MusicMiniPlayer({
    Position = UDim2.new(1, -376, 0, 96),
})

-- Optional: drive it by hand before anything is connected.
Player:SetTrack({
    Title = "Red Flags",
    Artist = "ny Howard",
    Album = "What Now",
    Cover = "https://i.scdn.co/image/ab67616d0000b273...",
    Duration = 267,
})
```

## Full

```lua
local Player = WindUI:MusicMiniPlayer({
    Width = 348,
    Height = 178,
    Radius = 22,
    Scale = 1,
    Position = UDim2.new(1, -376, 0, 96),
    Draggable = true,
    SavePosition = true,
    Folder = "MyHub",
    PollInterval = 1.5,

    -- Which rows the gear shows. A table means "this exact set, this order".
    Providers = {
        "spotify",
        { Id = "apple", Name = "Apple Music", Url = "http://127.0.0.1:5764" },
        { Id = "youtube", Name = "YouTube Music", Url = "http://127.0.0.1:5765" },
        "local",
        "demo",
    },

    -- local source (optional)
    Sound = workspace.Jukebox.Sound,
    Playlist = {
        { Title = "Static Bloom", Artist = "Vesper Lane", SoundId = "rbxassetid://1837879082" },
        { Title = "Chrome Garden", Artist = "Mira Sextant", SoundId = "rbxassetid://1836194892" },
    },

    -- fire once per change; connect it to your own backend if you like
    OnVolume = function(percent)
        print("volume", percent)
    end,

    Callbacks = {
        Play = function() end,
        Pause = function() end,
        Next = function() end,
        Previous = function() end,
        Seek = function(seconds) end,
        Connect = function(provider) end,
        State = function(state) end,
    },
})
```

## Settings

The gear in the top-right corner opens the source panel. Each row carries a status dot: grey when idle, green when the source answered.

| Row | Connects with |
| --- | --- |
| Spotify | Access token, or refresh token + `client_id:client_secret` |
| Apple Music | JSON bridge on `http://127.0.0.1:5764` |
| YouTube Music | JSON bridge on `http://127.0.0.1:5765` |
| Local audio | The `Sound` you passed in `Config.Sound` |
| Demo | Nothing — three preview tracks on a clock |

The panel is 306px tall when open and the card grows to fit it, then shrinks back on close.

## Spotify

Create an app at the [Spotify developer dashboard](https://developer.spotify.com/dashboard), add `http://127.0.0.1:8888/callback` as a redirect URI, then run the PKCE authorize flow once and paste the result into the widget:

1. Authorize with scopes `user-read-playback-state user-modify-playback-state user-read-currently-playing`.
2. Paste the access token into the first field, submit.
3. To survive the token's one-hour life, paste the refresh token and `client_id:client_secret` into the two remaining fields.

With credentials stored, the widget refreshes on its own and the token is written to `WindUI/<Folder>/music/spotify.json`.

The widget polls `GET /me/player` every `PollInterval` seconds and mirrors whatever device is active — phone, desktop app, speaker. Controls go to `player/play`, `player/pause`, `player/next`, `player/previous`, `player/seek` and `player/volume`, so dragging the volume slider changes the volume of the device you are actually hearing, not just an in-game number.

```lua
-- drive it yourself: the same calls the widget makes
local spotify = Player.ByProviderId.spotify
spotify:Connect({ AccessToken = "BQ..." }, function(ok, message)
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

`bridge/server.js` in the repository is a working reference: an AppleScript adapter for the Music app on macOS and an iTunes COM adapter for Windows, both behind the same routes.

## Methods

| Method | Notes |
| --- | --- |
| `Player:SetTrack(track)` | Manual state: `{ Title, Artist, Album, Cover, Duration }` |
| `Player:SetProgress(elapsed, duration)` | Seconds |
| `Player:SetPlaying(bool)` | Flips the transport icon only |
| `Player:SetVolume(percent)` | 0-100, routed through the active provider |
| `Player:ToggleMute()` | Zero, then back to the previous level |
| `Player:Seek(seconds)` | Same path the progress bar uses |
| `Player:Toggle()` | Play / pause |
| `Player:SelectProvider(provider)` | Swap the active source |
| `Player:ToggleSettings(bool)` | Open or close the source panel |
| `Player:SetPosition(UDim2)` | Moves the card |
| `Player:GetPosition()` | Current `UDim2` |
| `Player:SetScale(number)` | `UIScale` on the widget only |
| `Player:Show()` / `Player:Hide()` | Visibility |
| `Player:Destroy()` | Stops the poll loop, disconnects, removes the card |
| `Player:Fire(name, ...)` | Fires a `Callbacks` entry |

## Parameters

| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `Width` | `number` | `348` | |
| `Height` | `number` | `178` | Grows to 306 while settings are open |
| `Radius` | `number` | `22` | Squircle radius |
| `Scale` | `number` | `1` | `UIScale` on the card |
| `Position` | `UDim2?` | top-right | Remembered when `SavePosition` is on |
| `Draggable` | `boolean?` | `true` | Drag anywhere that is not a control |
| `SavePosition` | `boolean?` | `true` | Needs `writefile` |
| `Folder` | `string?` | window folder | Folder under `WindUI/` for cache and tokens |
| `PollInterval` | `number?` | `1.5` | Seconds between provider polls |
| `Providers` | `table?` | all five | `"spotify"`, `"local"`, `"demo"`, or `{ Id, Name, Url }` |
| `Sound` | `Sound?` | — | Local source |
| `Playlist` | `table?` | — | `{ Title, Artist, Cover, SoundId }` entries |
| `OnVolume` | `function?` | — | Receives 0-100 |
| `Callbacks` | `table?` | — | `Play`, `Pause`, `Next`, `Previous`, `Seek`, `Connect`, `State`, `Source`, `Settings` |

## Notes

- The card is a `ScreenGui` widget parented to `WindUI.ScreenGui`, not to a window, a tab or a section — it survives `Window:Destroy()` only if you re-create it, and it never appears in `Window.AllElements`.
- Cover art goes through the same image pipeline as every other element: HTTP covers are downloaded once, cached under `WindUI/<Folder>/assets`, and re-used.
- Drag starts on the card surface only, so scrubbing the progress bar or clicking a control never moves the widget. On release the card is clamped inside the viewport.
- The progress readout is interpolated between polls, so the bar moves every frame even at a 1.5s poll interval.
- A volume slider can only change the Spotify device volume, the bridge's own gain, or the `Sound.Volume` of the local source. Roblox cannot touch the operating system's master volume; use the bridge for that.
- Right-click the speaker to mute without opening the slider.
