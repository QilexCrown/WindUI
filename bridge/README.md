# Music bridge

The Music Mini Player talks to Spotify directly. Everything else goes through
this little HTTP server, because desktop players do not expose a usable REST
API: Apple Music on macOS only answers AppleScript, and iTunes on Windows only
answers COM.

## Run it

```
node bridge/server.js                 # auto-detect the platform, port 5764
node bridge/server.js --port 5765     # second player / second source
node bridge/server.js --adapter macos # force an adapter
```

No dependencies, Node 16+.

Then open the widget's gear, pick **Apple Music**, and leave the default
`http://127.0.0.1:5764`. The row turns green when the bridge answers.

## Routes

```
GET  /now        { title, artist, album, cover, position, duration, playing, volume, canSkip }
GET  /art        current artwork, image/jpeg
POST /play
POST /pause
POST /next
POST /previous
POST /seek       { position: seconds }
POST /volume     { volume: 0-100 }
```

`position` and `duration` are seconds. `volume` is 0-100. `cover` may be a path
relative to the bridge — the widget prefixes the base URL for you.

## Write your own adapter

Any process that answers those four routes is a source. A hub backend, a
YouTube Music watcher, a phone on the same LAN, a Discord bot. Copy the
contract, not the code:

```js
app.get("/now", (request, response) => {
	response.end(
		JSON.stringify({
			title: "Red Flags",
			artist: "ny Howard",
			album: "What Now",
			cover: "https://example.com/cover.jpg",
			position: 33,
			duration: 267,
			playing: true,
			volume: 62,
		})
	);
});
```

## Notes

- The bridge binds to `127.0.0.1` only. Do not expose it; it executes player
  commands with your user's rights.
- macOS: the terminal needs Automation permission for Music.app the first time.
- Windows: iTunes must be running, and the Apple Music app that replaced it has
  no COM surface — use iTunes, or write your own adapter against the player you
  actually use.
- Artwork is written to the temp directory and served from `/art` with a
  cache-busting query, so a track change swaps the cover without a stale cache.
