-- Music Mini Player — drop-in example.
--
-- Copy this into your hub script after the window is created. The widget is
-- not a tab element: it floats above everything, including a closed window.
--
-- Spotify: click the gear, paste an access token from
-- https://developer.spotify.com/dashboard with these scopes:
--   user-read-playback-state user-modify-playback-state user-read-currently-playing
-- The token lives in WindUI/<Folder>/music/spotify.json and refreshes itself
-- when you also paste a refresh token and client_id:client_secret.

local WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/QilexCrown/WindUI/main/dist/main.lua"))()

local Window = WindUI:CreateWindow({
	Title = "Music test",
	Folder = "MusicTest",
	Size = UDim2.fromOffset(520, 400),
})

Window:Tab({ Title = "Home" }):Paragraph({
	Title = "Drag the card",
	Desc = "Gear connects the source. Bottom right corner to start.",
})

local Player = WindUI:MusicMiniPlayer({
	Folder = "MusicTest",
	Position = UDim2.new(1, -376, 0, 80),
	PollInterval = 1.5,

	OnVolume = function(percent)
		print("volume:", percent)
	end,

	Callbacks = {
		State = function(state)
			-- state = { Title, Artist, Album, Cover, Position, Duration, Playing, Volume }
		end,
		Connect = function(provider)
			WindUI:Notify({ Title = "Connected", Content = provider.Name, Duration = 3 })
		end,
	},
})

-- Any of these work before a source is connected, for a screenshot or a demo:
-- Player:SetTrack({ Title = "Red Flags", Artist = "ny Howard", Duration = 267 })
-- Player:SetPlaying(true)
-- Player:SetVolume(72)

return Player
