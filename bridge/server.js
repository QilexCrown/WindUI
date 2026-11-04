// WindUI Music Mini Player — reference bridge.
//
// The widget speaks one JSON contract, so anything that can answer HTTP can be
// a source. This server implements it for the two desktop players that have no
// usable REST API of their own:
//
//   macOS   Music.app    (AppleScript)
//   Windows iTunes / Music (COM via PowerShell)
//
//   GET  /now        -> { title, artist, album, cover, position, duration, playing, volume, canSkip }
//   POST /play
//   POST /pause
//   POST /next
//   POST /previous
//   POST /seek       <- { position = seconds }
//   POST /volume     <- { volume = 0-100 }
//
//   node server.js                       auto-detect platform
//   node server.js --adapter macos
//   node server.js --port 5764
//   node server.js --port 5765 --adapter windows   (second player, second port)
//
// No dependencies, Node 16+.

const http = require("http");
const { execFile } = require("child_process");
const fs = require("fs");
const os = require("os");
const path = require("path");

const args = process.argv.slice(2);
const flag = (name, fallback) => {
	const index = args.indexOf(`--${name}`);
	return index >= 0 && args[index + 1] ? args[index + 1] : fallback;
};

const PORT = Number(flag("port", 5764));
const HOST = flag("host", "127.0.0.1");
const ADAPTER = flag("adapter", process.platform === "darwin" ? "macos" : "windows");
const ART_FILE = path.join(os.tmpdir(), "windui-now-playing.jpg");

// ---------------------------------------------------------------- adapters

const adapters = {
	// Music.app on macOS. Every call is one AppleScript, and every AppleScript
	// is wrapped so a stopped player answers with an idle state instead of an
	// error the widget has to understand.
	macos: {
		async now() {
			const script = `
tell application "Music"
  set st to player state as text
  if st is "stopped" then
    return "stopped"
  end if
  set t to current track
  set nameText to name of t
  set artistText to artist of t
  set albumText to album of t
  set dur to duration of t
  set pos to player position
  set vol to sound volume
  try
    set art to raw data of artwork 1 of t
    set f to open for access POSIX file "${ART_FILE}" with write permission
    set eof f to 0
    write art to f
    close access f
  end try
  return st & "\\n" & nameText & "\\n" & artistText & "\\n" & albumText & "\\n" & dur & "\\n" & pos & "\\n" & vol
end tell`;

			const raw = await run("osascript", ["-e", script]);
			if (raw.trim() === "stopped") return idle();

			const [state, title, artist, album, duration, position, volume] = raw.split("\n");
			const hasArt = fs.existsSync(ART_FILE);

			return {
				title,
				artist,
				album,
				cover: hasArt ? `/art?t=${Date.now()}` : "",
				position: Number(position) || 0,
				duration: Number(duration) || 0,
				playing: state.trim() === "playing",
				volume: Number(volume) || 0,
			};
		},
		play: () => osa('tell application "Music" to play'),
		pause: () => osa('tell application "Music" to pause'),
		next: () => osa('tell application "Music" to next track'),
		previous: () => osa('tell application "Music" to previous track'),
		seek: (seconds) =>
			osa(`tell application "Music" to set player position to ${Number(seconds) || 0}`),
		volume: (percent) => osa(`tell application "Music" to set sound volume to ${clamp(percent)}`),
	},

	// iTunes / Apple Music on Windows, through COM. PlayerState: 0 stopped,
	// 1 playing, 2 paused, 3 fast-forwarding, 4 rewinding.
	windows: {
		async now() {
			const script = `
$ErrorActionPreference = "Stop"
try {
  $i = New-Object -ComObject iTunes.Application
} catch {
  Write-Output "stopped"
  exit 0
}
if ($i.PlayerState -eq 0 -or $null -eq $i.CurrentTrack) { Write-Output "stopped"; exit 0 }
$t = $i.CurrentTrack
$art = ""
try {
  if ($t.Artwork.Count -gt 0) {
    $art = "${ART_FILE.replace(/\\/g, "\\\\")}"
    $t.Artwork.Item(1).SavePicture($art, $art)
  }
} catch { $art = "" }
$state = if ($i.PlayerState -eq 1) { "playing" } else { "paused" }
Write-Output ($state)
Write-Output ($t.Name)
Write-Output ($t.Artist)
Write-Output ($t.Album)
Write-Output ($t.Duration)
Write-Output ($i.PlayerPosition)
Write-Output ($i.SoundVolume)`;

			const raw = await run("powershell", [
				"-NoProfile",
				"-NonInteractive",
				"-Command",
				script,
			]);

			if (raw.trim() === "stopped") return idle();

			const [state, title, artist, album, duration, position, volume] = raw
				.split(/\r?\n/)
				.map((line) => line.trim())
				.filter(Boolean);

			return {
				title,
				artist,
				album,
				cover: fs.existsSync(ART_FILE) ? `/art?t=${Date.now()}` : "",
				position: Number(position) || 0,
				duration: Number(duration) || 0,
				playing: state === "playing",
				volume: Number(volume) || 0,
			};
		},
		play: () => powershell('$i = New-Object -ComObject iTunes.Application; $i.Play()'),
		pause: () => powershell('$i = New-Object -ComObject iTunes.Application; $i.Pause()'),
		next: () => powershell('$i = New-Object -ComObject iTunes.Application; $i.NextTrack()'),
		previous: () =>
			powershell('$i = New-Object -ComObject iTunes.Application; $i.PreviousTrack()'),
		seek: (seconds) =>
			powershell(
				`$i = New-Object -ComObject iTunes.Application; $i.PlayerPosition = ${Number(seconds) || 0}`
			),
		volume: (percent) =>
			powershell(
				`$i = New-Object -ComObject iTunes.Application; $i.SoundVolume = ${clamp(percent)}`
			),
	},
};

// ----------------------------------------------------------------- helpers

function clamp(percent) {
	return Math.max(0, Math.min(100, Math.round(Number(percent) || 0)));
}

function idle() {
	return {
		title: "Nothing playing",
		artist: "",
		album: "",
		cover: "",
		position: 0,
		duration: 0,
		playing: false,
		volume: 0,
		canSkip: false,
	};
}

function run(file, argv) {
	return new Promise((resolve) => {
		execFile(file, argv, { windowsHide: true, maxBuffer: 4 * 1024 * 1024 }, (error, stdout) => {
			if (error && !stdout) {
				resolve("stopped");
				return;
			}
			resolve(String(stdout || "").trim());
		});
	});
}

function osa(script) {
	return run("osascript", ["-e", script]);
}

function powershell(script) {
	return run("powershell", ["-NoProfile", "-NonInteractive", "-Command", script]);
}

function json(response, code, body) {
	const payload = JSON.stringify(body || {});
	response.writeHead(code, {
		"Content-Type": "application/json",
		"Content-Length": Buffer.byteLength(payload),
		"Access-Control-Allow-Origin": "*",
		"Access-Control-Allow-Methods": "GET, POST, OPTIONS",
		"Access-Control-Allow-Headers": "Content-Type",
	});
	response.end(payload);
}

function readBody(request) {
	return new Promise((resolve) => {
		let body = "";
		request.on("data", (chunk) => {
			body += chunk;
			if (body.length > 64 * 1024) {
				body = body.slice(0, 64 * 1024);
				request.destroy();
			}
		});
		request.on("end", () => {
			try {
				resolve(body ? JSON.parse(body) : {});
			} catch {
				resolve({});
			}
		});
	});
}

// ------------------------------------------------------------------ routes

const adapter = adapters[ADAPTER];
if (!adapter) {
	console.error(`unknown adapter "${ADAPTER}", expected macos or windows`);
	process.exit(1);
}

const app = http.createServer(async (request, response) => {
	const url = new URL(request.url, `http://${HOST}:${PORT}`);

	if (request.method === "OPTIONS") {
		json(response, 204, {});
		return;
	}

	try {
		if (url.pathname === "/now" && request.method === "GET") {
			const state = await adapter.now();
			json(response, 200, { ...state, app: ADAPTER === "macos" ? "Apple Music" : "iTunes" });
			return;
		}

		if (url.pathname === "/art" && request.method === "GET") {
			if (!fs.existsSync(ART_FILE)) {
				json(response, 404, { error: "no artwork" });
				return;
			}
			const data = fs.readFileSync(ART_FILE);
			response.writeHead(200, {
				"Content-Type": "image/jpeg",
				"Content-Length": data.length,
				"Cache-Control": "no-store",
			});
			response.end(data);
			return;
		}

		if (request.method === "POST") {
			const body = await readBody(request);

			if (url.pathname === "/play") {
				await adapter.play();
				return json(response, 200, { ok: true });
			}
			if (url.pathname === "/pause") {
				await adapter.pause();
				return json(response, 200, { ok: true });
			}
			if (url.pathname === "/next") {
				await adapter.next();
				return json(response, 200, { ok: true });
			}
			if (url.pathname === "/previous") {
				await adapter.previous();
				return json(response, 200, { ok: true });
			}
			if (url.pathname === "/seek") {
				await adapter.seek(body.position);
				return json(response, 200, { ok: true });
			}
			if (url.pathname === "/volume") {
				await adapter.volume(body.volume);
				return json(response, 200, { ok: true });
			}
		}

		json(response, 404, { error: "not found" });
	} catch (error) {
		json(response, 500, { error: String(error && error.message ? error.message : error) });
	}
});

app.listen(PORT, HOST, () => {
	console.log(`WindUI music bridge on http://${HOST}:${PORT} (${ADAPTER})`);
	console.log("point the widget's row at that url, or set Config.Providers");
});
