-- Music mini player - drop-in example.
--
-- Copy this into your hub script after the window is created. The widget is
-- not a tab element: it floats above everything, including a closed window.
-- Collapsed it is a top-docked pill; tap it and it springs into the card.
--
-- Local audio: drop mp3 / ogg / wav into the folder below. Covers are fetched
-- from iTunes the first time a track plays and written beside the mp3, so the
-- next scan finds them offline.
--
-- Spotify: open the gear, hit the authorize link, paste the redirect URL back.

local WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/QilexCrown/WindUI/main/dist/main.lua"))()

local Window = WindUI:CreateWindow({
	Title = "Music test",
	Folder = "MusicTest",
	Size = UDim2.fromOffset(520, 400),
})

Window:Tab({ Title = "Home", Icon = "music-2" }):Paragraph({
	Title = "Tap the pill",
	Desc = "Top of the screen. The gear inside connects the source.",
})

local Player = WindUI:MusicMiniPlayer({
	Folder = "MusicTest",
	SongsFolder = "Ender Hub/songs",
	DynamicIsland = true,
	Top = 10,
	PollInterval = 1.25,

	Providers = {
		"files",
		"spotify",
		"demo",
	},

	OnVolume = function(percent)
		print("volume:", percent)
	end,

	Callbacks = {
		Update = function(state)
			-- state = { Title, Artist, Album, Cover, Position, Duration, Playing, Volume }
		end,
		Connect = function(provider)
			WindUI:Notify({ Title = "Connected", Content = provider.Name, Duration = 3 })
		end,
		Expanded = function(open)
			-- open == true when the pill grew into the card
		end,
	},
})

-- Any of these work by hand, before a source answers:
-- Player:Expand()
-- Player:ToggleSettings(true)
-- Player:SetVolume(72)
-- Player:ToggleShuffle()
--
-- Always-open card instead of the pill:
-- Player:SetDynamicIsland(false)

return Player
