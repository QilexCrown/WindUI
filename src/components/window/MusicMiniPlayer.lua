-- Music mini player — a floating now-playing pill, not a window element.
--
--   local Music = WindUI:MusicMiniPlayer({
--       DynamicIsland = true,
--       Providers = { "spotify", "files", "demo" },
--   })
--
-- Geometry, palette and type are lifted from the island running in the client
-- (CoreGui.RobloxGui.ytbrlfiugpzscm): 212 x 40 collapsed, 752 x 204 expanded,
-- radius 20, #000000 shell, #F2F2F4 hairline, Gotham SSm. Collapsed it is the
-- phone's dynamic island — artwork on the left, six-bar wave on the right, no
-- text. Tapped it springs into the full player: artwork, title, transport,
-- scrubber, two chips and a source column. DynamicIsland = false boots the
-- expanded card instead and keeps it there. Everything service-specific lives
-- in modules/MusicProviders.

local cloneref = (cloneref or clonereference or function(instance)
	return instance
end)

local RunService = cloneref(game:GetService("RunService"))
local UserInputService = cloneref(game:GetService("UserInputService"))
local GuiService = cloneref(game:GetService("GuiService"))
local HttpService = cloneref(game:GetService("HttpService"))

local Creator = require("../../modules/Creator")
local Providers = require("../../modules/MusicProviders")

local New = Creator.New
local Tween = Creator.Tween

local MusicMiniPlayer = {}
MusicMiniPlayer.__index = MusicMiniPlayer

local IslandSize = Vector2.new(212, 40)
local CardSize = Vector2.new(752, 204)
local SettingsSize = Vector2.new(752, 300)
local IslandRadius = 20
local CardRadius = 20

local Shell = Color3.fromRGB(0, 0, 0)
local Text = Color3.fromRGB(242, 242, 244)
local Sub = Color3.fromRGB(150, 150, 156)
local Wave = Color3.fromRGB(226, 226, 232)
local Glass = Color3.fromRGB(242, 242, 244)
local Sheen = Color3.fromRGB(255, 255, 255)

local Gotham = "rbxasset://fonts/families/GothamSSm.json"

local function Face(Weight)
	return Font.new(Gotham, Weight or Enum.FontWeight.Medium)
end

local Bold = Face(Enum.FontWeight.Bold)
local Medium = Face(Enum.FontWeight.Medium)
local SemiBold = Face(Enum.FontWeight.SemiBold)
local Regular = Face(Enum.FontWeight.Regular)

local function Merge(Base, Extra)
	local Out = {}
	for Key, Value in next, Base do
		Out[Key] = Value
	end
	for Key, Value in next, Extra or {} do
		Out[Key] = Value
	end
	return Out
end

local function Icon(Name, Size, Extra)
	local Data = Creator.Icon(Name) or {}
	local Rect_ = Data[2] or {}
	local Clean = {}

	for Key, Value in next, Extra or {} do
		if Key ~= "Transparency" then
			Clean[Key] = Value
		end
	end

	return New(
		"ImageLabel",
		Merge({
			Image = Data[1] or "",
			ImageRectOffset = Rect_.ImageRectPosition or Vector2.new(0, 0),
			ImageRectSize = Rect_.ImageRectSize or Vector2.new(0, 0),
			Size = UDim2.fromOffset(Size, Size),
			BackgroundTransparency = 1,
			ImageTransparency = (Extra and Extra.Transparency) or 0,
			ImageColor3 = Text,
		}, Clean)
	)
end

local function Label(Properties)
	return New("TextLabel", Merge({
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = Text,
		TextSize = 11,
		TextXAlignment = "Left",
		TextYAlignment = "Center",
		TextTruncate = "AtEnd",
		FontFace = Medium,
	}, Properties))
end

local function CacheName(Url)
	local Hash = 2166136261
	for Index = 1, #Url do
		Hash = bit32.bxor(Hash, string.byte(Url, Index))
		Hash = bit32.band(Hash * 16777619, 0xFFFFFFFF)
	end
	return string.format("%08x", Hash)
end

local function OpenUrl(Url)
	if type(Url) ~= "string" or Url == "" then
		return false
	end
	if type(setclipboard) == "function" then
		pcall(setclipboard, Url)
	end
	return pcall(function()
		GuiService:OpenBrowserWindow(Url)
	end)
end

--------------------------------------------------------------------- widget

function MusicMiniPlayer.New(Config)
	Config = Config or {}

	local WindUI = Config.WindUI
	if not WindUI then
		error("MusicMiniPlayer needs WindUI: use WindUI:MusicMiniPlayer()")
	end

	local Folder = Config.Folder or (WindUI.Window and WindUI.Window.Folder) or "Widgets"
	local DynamicIsland = Config.DynamicIsland ~= false

	local Widget = setmetatable({
		WindUI = WindUI,
		Config = Config,
		Folder = Folder,
		Scale = Config.Scale or 1,
		Top = Config.Top or 10,
		DynamicIsland = DynamicIsland,
		PollInterval = math.max(tonumber(Config.PollInterval) or 1.25, 0.5),
		Providers = {},
		ByProviderId = {},
		ActiveProvider = nil,
		Connections = {},
		Callbacks = Config.Callbacks or {},
		State = Providers.Idle("Nothing playing"),
		DisplayPosition = 0,
		StateAt = tick(),
		Playing = false,
		Volume = 60,
		LastVolume = 60,
		Expanded = false,
		SettingsOpen = false,
		View = "providers",
		Destroyed = false,
		Polling = false,
		IconName = nil,
		CoverUrl = nil,
		ArtFrame = nil,
		BleedFrame = nil,
		CurrentSize = IslandSize,
		CurrentRadius = IslandRadius,
		Rows = {},
		Shuffle = false,
	}, MusicIsland)

	Widget.OnVolume = Config.OnVolume

	function Widget:Connect(Signal, Callback)
		local Connection = Signal:Connect(Callback)
		self.Connections[#self.Connections + 1] = Connection
		return Connection
	end

	function Widget:Fire(Name, ...)
		local Callback = self.Callbacks[Name]
		if Callback then
			Creator.SafeCallback(Callback, ...)
		end
	end

	--------------------------------------------------------------- providers

	local function BuildProviders()
		local List = {}

		local function Add(Provider)
			if not Provider then
				return
			end
			List[#List + 1] = Provider
			Widget.ByProviderId[Provider.Id] = Provider
		end

		local Requested = Config.Providers
		if type(Requested) == "table" and #Requested > 0 then
			for _, Entry in ipairs(Requested) do
				if type(Entry) == "table" and Entry.Poll then
					Add(Entry)
				elseif Entry == "spotify" then
					Add(Providers.NewSpotify())
				elseif Entry == "files" then
					Add(Providers.NewFolder({
						Path = Config.SongsFolder or "Ender Hub/songs",
					}))
				elseif Entry == "sound" then
					Add(Providers.NewSound({
						Sound = Config.Sound,
						Title = Config.Title,
						Artist = Config.Artist,
						Cover = Config.Cover,
					}))
				elseif Entry == "demo" then
					Add(Providers.NewDemo())
				elseif type(Entry) == "table" and Entry.Url then
					Add(Providers.NewBridge(Entry))
				end
			end
		else
			Add(Providers.NewSpotify())
			Add(Providers.NewFolder({
				Path = Config.SongsFolder or "Ender Hub/songs",
			}))
			Add(Providers.NewBridge({
				Id = "apple",
				Name = "Apple Music",
				Url = Config.AppleBridge or "http://127.0.0.1:5764",
			}))
			Add(Providers.NewBridge({
				Id = "youtube",
				Name = "YouTube Music",
				Url = Config.YouTubeBridge or "http://127.0.0.1:5765",
			}))
			Add(Providers.NewDemo())
		end

		if Config.Provider and Widget.ByProviderId[Config.Provider] then
			Widget.ActiveProvider = Widget.ByProviderId[Config.Provider]
		elseif #List > 0 then
			Widget.ActiveProvider = List[1]
		end

		return List
	end

	Widget.Providers = BuildProviders()

	--------------------------------------------------------------------- ui

	local Parent = Config.Parent or WindUI.ScreenGui

	local Container = New("Frame", {
		Name = "MusicIsland",
		Parent = Parent,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(IslandSize.X, IslandSize.Y),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, Widget.Top),
		ZIndex = 40,
	})

	local ScaleObject = New("UIScale", {
		Scale = Widget.Scale,
		Parent = Container,
	})

	-- Soft halo: a 9-slice shadow bitmap instead of stacked rounded frames. The
	-- reference drop shadow has a real falloff; four hard-alpha layers still
	-- band against a bright sky, a slice does not.
	local Shadow = New("ImageLabel", {
		Parent = Container,
		Name = "Shadow",
		Image = "rbxassetid://84825982946844",
		ImageColor3 = Color3.fromRGB(0, 0, 0),
		ImageTransparency = 0.42,
		ScaleType = "Slice",
		SliceCenter = Rect.new(512, 512, 512, 512),
		SliceScale = IslandRadius / 512,
		Size = UDim2.new(1, 64, 1, 64),
		Position = UDim2.fromOffset(-32, -32),
		BackgroundTransparency = 1,
		ZIndex = 1,
	})

	local Fill = New("Frame", {
		Parent = Container,
		Name = "Shell",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = Shell,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 2,
	}, {
		New("UICorner", { CornerRadius = UDim.new(0, IslandRadius) }),
	})

	-- Liquid glass, layer one: a white-north sheen that fades before the middle
	-- so the shell reads as a rounded pane catching the room light.
	local SheenLayer = New("Frame", {
		Parent = Fill,
		Name = "Sheen",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = Sheen,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, {
		New("UICorner", { CornerRadius = UDim.new(0, IslandRadius) }),
		New("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.85),
				NumberSequenceKeypoint.new(0.38, 0.968),
				NumberSequenceKeypoint.new(0.62, 0.996),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}),
	})

	-- Layer two: a narrow specular band that sweeps across on hover. Roblox has
	-- no refraction, so moving highlight is what sells "glass" instead.
	local Specular = New("Frame", {
		Parent = Fill,
		Name = "Specular",
		Size = UDim2.fromScale(0.55, 1),
		Position = UDim2.fromScale(-0.75, 0),
		BackgroundColor3 = Sheen,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, {
		New("UIGradient", {
			Rotation = 18,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.42, 1),
				NumberSequenceKeypoint.new(0.5, 0.93),
				NumberSequenceKeypoint.new(0.58, 1),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}),
	})

	local Outline = New("Frame", {
		Parent = Fill,
		Name = "Outline",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		ZIndex = 3,
	}, {
		New("UICorner", { CornerRadius = UDim.new(0, IslandRadius) }),
		New("UIStroke", {
			Color = Text,
			Thickness = 1,
			Transparency = 0.86,
			ApplyStrokeMode = "Border",
		}),
	})

	-- Inner rim, one pixel in: the second highlight that makes the edge look
	-- thick rather than drawn on.
	local Rim = New("Frame", {
		Parent = Fill,
		Name = "Rim",
		Size = UDim2.new(1, -2, 1, -2),
		Position = UDim2.fromOffset(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 3,
	}, {
		New("UICorner", { CornerRadius = UDim.new(0, IslandRadius - 1) }),
		New("UIStroke", {
			Color = Text,
			Thickness = 1,
			Transparency = 0.94,
			ApplyStrokeMode = "Border",
		}),
	})

	-- Cover bleed: the playing art cropped behind the whole shell.
	local Bleed = New("Frame", {
		Parent = Fill,
		Name = "Bleed",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Visible = false,
		ZIndex = 2,
	}, {
		New("UICorner", { CornerRadius = UDim.new(0, IslandRadius) }),
	})

	local BleedScrim = New("Frame", {
		Parent = Bleed,
		Name = "Scrim",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = Color3.fromRGB(4, 4, 6),
		BorderSizePixel = 0,
		ZIndex = 3,
	}, {
		New("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.62),
				NumberSequenceKeypoint.new(1, 0.9),
			}),
		}),
	})

	------------------------------------------------------------- collapsed

	-- Stolen shape: 28 x 28 artwork at 6,6 (r9) and a 24 x 18 wave anchored
	-- right, both inside the 212 x 40 shell. No text — the reference has none.
	local IslandGroup = New("CanvasGroup", {
		Parent = Fill,
		Name = "Island",
		Size = UDim2.fromOffset(IslandSize.X, IslandSize.Y),
		Position = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 1,
		GroupTransparency = 0,
		ZIndex = 4,
	})

	local IslandScale = New("UIScale", {
		Parent = IslandGroup,
		Scale = 1,
	})

	local CoverButtonSmall = New("TextButton", {
		Parent = IslandGroup,
		Name = "Cover",
		Size = UDim2.fromOffset(28, 28),
		Position = UDim2.fromOffset(6, 6),
		BackgroundColor3 = Color3.fromRGB(32, 32, 35),
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		ClipsDescendants = true,
		ZIndex = 5,
	}, {
		New("UICorner", { CornerRadius = UDim.new(0, 9) }),
		New("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(46, 46, 49)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(32, 32, 35)),
			}),
		}),
		Icon("music-2", 12, {
			Name = "Placeholder",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			ImageColor3 = Sub,
			ZIndex = 5,
		}),
		New("ImageLabel", {
			Name = "Art",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ScaleType = "Crop",
			Image = "",
			ZIndex = 6,
		}, {
			New("UICorner", { CornerRadius = UDim.new(0, 9) }),
		}),
	})

	local WaveBox = New("Frame", {
		Parent = IslandGroup,
		Name = "Wave",
		Size = UDim2.fromOffset(24, 18),
		Position = UDim2.fromOffset(176, 20),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
		ZIndex = 5,
	})

	local BarHeights = { 14, 11, 13, 16, 14, 13 }
	local Bars = {}

	for Index = 1, 6 do
		Bars[Index] = New("Frame", {
			Parent = WaveBox,
			Name = "Bar" .. Index,
			Size = UDim2.fromOffset(2, BarHeights[Index]),
			Position = UDim2.new(0, Index * 4 - 2, 0.5, 0),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Wave,
			BorderSizePixel = 0,
			ZIndex = 6,
		}, {
			New("UICorner", { CornerRadius = UDim.new(1, 0) }),
		})
	end

	------------------------------------------------------------------ card

	local CardGroup = New("CanvasGroup", {
		Parent = Fill,
		Name = "Card",
		Size = UDim2.fromOffset(CardSize.X, CardSize.Y),
		Position = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 1,
		GroupTransparency = 1,
		Visible = false,
		ZIndex = 10,
	})

	-- The card body arrives scaled up from 96%, the same pop the phone island
	-- gives its content while the shell is still growing.
	local CardScale = New("UIScale", {
		Parent = CardGroup,
		Scale = 0.96,
	})

	-- Top strip: tab pill, section name, live status on the right.
	local TabPill = New("Frame", {
		Parent = CardGroup,
		Name = "Tab",
		Size = UDim2.fromOffset(32, 22),
		Position = UDim2.fromOffset(20, 9),
		BackgroundColor3 = Glass,
		BackgroundTransparency = 0.94,
		BorderSizePixel = 0,
		ZIndex = 11,
	}, {
		New("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Icon("music-2", 11, {
			Name = "Glyph",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			ImageColor3 = Text,
			ZIndex = 12,
		}),
	})

	local SectionLabel = Label({
		Parent = CardGroup,
		Name = "Section",
		Position = UDim2.fromOffset(60, 9),
		Size = UDim2.fromOffset(200, 22),
		Text = "Library",
		TextSize = 11,
		TextColor3 = Sub,
		ZIndex = 11,
	})

	local StatusLabel = Label({
		Parent = CardGroup,
		Name = "Status",
		Position = UDim2.new(1, -84, 0, 9),
		AnchorPoint = Vector2.new(1, 0),
		Size = UDim2.fromOffset(160, 22),
		Text = "",
		TextSize = 11,
		TextColor3 = Sub,
		TextXAlignment = "Right",
		ZIndex = 11,
	})

	local function GlassButton(Name, GlyphName, GlyphSize, Position, Callback)
		local Button = New("TextButton", {
			Parent = CardGroup,
			Name = Name,
			Size = UDim2.fromOffset(26, 26),
			Position = Position,
			AnchorPoint = Vector2.new(1, 0),
			BackgroundColor3 = Glass,
			BackgroundTransparency = 0.92,
			BorderSizePixel = 0,
			Text = "",
			AutoButtonColor = false,
			ZIndex = 14,
		}, {
			New("UICorner", { CornerRadius = UDim.new(1, 0) }),
			New("UIStroke", {
				Color = Text,
				Thickness = 1,
				Transparency = 0.9,
				ApplyStrokeMode = "Border",
			}),
			Icon(GlyphName, GlyphSize, {
				Name = "Glyph",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				ImageTransparency = 0.1,
				ZIndex = 15,
			}),
		})

		Widget:Connect(Button.MouseEnter, function()
			Tween(Button, 0.12, { BackgroundTransparency = 0.84 }):Play()
		end)
		Widget:Connect(Button.MouseLeave, function()
			Tween(Button, 0.12, { BackgroundTransparency = 0.92 }):Play()
		end)
		Widget:Connect(Button.MouseButton1Click, Callback)

		return Button
	end

	local SettingsButton = GlassButton("Settings", "settings", 13, UDim2.new(1, -18, 0, 6), function()
		Widget:ToggleSettings(true)
	end)

	local CollapseButton = GlassButton("Collapse", "chevron-up", 14, UDim2.new(1, -50, 0, 6), function()
		Widget:Collapse()
	end)

	-- Artwork: 88 x 88 at 16,38, the same rounded square as the reference.
	local NowPanel = New("Frame", {
		Parent = CardGroup,
		Name = "NowPlaying",
		Size = UDim2.fromOffset(288, 96),
		Position = UDim2.fromOffset(14, 36),
		BackgroundColor3 = Sheen,
		BackgroundTransparency = 0.982,
		BorderSizePixel = 0,
		ZIndex = 11,
	}, {
		New("UICorner", { CornerRadius = UDim.new(0, 16) }),
		New("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.965),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}),
		New("UIStroke", {
			Color = Text,
			Thickness = 1,
			Transparency = 0.86,
			ApplyStrokeMode = "Border",
		}),
	})

	local CoverButton = New("TextButton", {
		Parent = CardGroup,
		Name = "Cover",
		Size = UDim2.fromOffset(88, 88),
		Position = UDim2.fromOffset(18, 40),
		BackgroundColor3 = Color3.fromRGB(32, 32, 35),
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		ClipsDescendants = true,
		ZIndex = 12,
	}, {
		New("UICorner", { CornerRadius = UDim.new(0, 14) }),
		Icon("music-2", 24, {
			Name = "Placeholder",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			ImageColor3 = Color3.fromRGB(120, 120, 128),
			ZIndex = 13,
		}),
		New("ImageLabel", {
			Name = "Art",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ScaleType = "Crop",
			Image = "",
			ZIndex = 14,
		}, {
			New("UICorner", { CornerRadius = UDim.new(0, 14) }),
		}),
		New("Frame", {
			Name = "Lift",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Text,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 15,
		}, {
			New("UICorner", { CornerRadius = UDim.new(0, 14) }),
		}),
		Icon("arrow-up-right", 12, {
			Name = "Open",
			Position = UDim2.new(1, -8, 0, 8),
			AnchorPoint = Vector2.new(1, 0),
			ImageTransparency = 1,
			ZIndex = 16,
		}),
	})

	local CoverArt = CoverButton.Art

	Widget:Connect(CoverButton.MouseEnter, function()
		Tween(CoverButton.Lift, 0.14, { BackgroundTransparency = 0.88 }):Play()
		Tween(CoverButton.Open, 0.14, { ImageTransparency = 0.05 }):Play()
	end)
	Widget:Connect(CoverButton.MouseLeave, function()
		Tween(CoverButton.Lift, 0.14, { BackgroundTransparency = 1 }):Play()
		Tween(CoverButton.Open, 0.14, { ImageTransparency = 1 }):Play()
	end)
	Widget:Connect(CoverButton.MouseButton1Click, function()
		Widget:OpenTrack()
	end)

	local TitleText = Label({
		Parent = CardGroup,
		Name = "Title",
		Position = UDim2.fromOffset(112, 63),
		Size = UDim2.fromOffset(180, 20),
		Text = "Nothing playing",
		TextSize = 15,
		FontFace = Bold,
		ZIndex = 12,
	})

	local ArtistText = Label({
		Parent = CardGroup,
		Name = "Artist",
		Position = UDim2.fromOffset(112, 82),
		Size = UDim2.fromOffset(180, 14),
		Text = "",
		TextSize = 10,
		TextColor3 = Sub,
		ZIndex = 12,
	})

	-- Play state line: tiny glyph then the word, exactly like the reference.
	local StateGlyph = Icon("play", 11, {
		Parent = CardGroup,
		Name = "StateGlyph",
		Position = UDim2.fromOffset(118, 110),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ImageColor3 = Sub,
		ZIndex = 12,
	})

	local StateText = Label({
		Parent = CardGroup,
		Name = "StateText",
		Position = UDim2.fromOffset(128, 103),
		Size = UDim2.fromOffset(160, 14),
		Text = "Paused",
		TextSize = 11,
		TextColor3 = Sub,
		ZIndex = 12,
	})

	-------------------------------------------------------------- chips

	local function Chip(Name, Text_, GlyphName, Position, Callback)
		local Button = New("TextButton", {
			Parent = CardGroup,
			Name = Name,
			Size = UDim2.fromOffset(152, 44),
			Position = Position,
			BackgroundColor3 = Glass,
			BackgroundTransparency = 0.94,
			BorderSizePixel = 0,
			Text = "",
			AutoButtonColor = false,
			ZIndex = 13,
		}, {
			New("UICorner", { CornerRadius = UDim.new(0, 14) }),
			New("UIStroke", {
				Color = Text,
				Thickness = 1,
				Transparency = 0.9,
				ApplyStrokeMode = "Border",
			}),
			Icon(GlyphName, 15, {
				Name = "Glyph",
				Position = UDim2.fromOffset(14, 9),
				ImageColor3 = Text,
				ImageTransparency = 0.25,
				ZIndex = 14,
			}),
			Label({
				Name = "Label",
				Position = UDim2.fromOffset(14, 26),
				Size = UDim2.new(1, -28, 0, 14),
				Text = Text_,
				TextSize = 11,
				FontFace = Bold,
				ZIndex = 14,
			}),
		})

		Widget:Connect(Button.MouseEnter, function()
			Tween(Button, 0.12, { BackgroundTransparency = 0.89 }):Play()
		end)
		Widget:Connect(Button.MouseLeave, function()
			Tween(Button, 0.12, { BackgroundTransparency = 0.94 }):Play()
		end)
		Widget:Connect(Button.MouseButton1Click, Callback)

		return Button
	end

	local ShuffleButton = Chip("Shuffle", "Shuffle", "shuffle", UDim2.fromOffset(310, 48), function()
		Widget:ToggleShuffle()
	end)

	local LibraryButton = Chip("Library", "Library", "list-music", UDim2.fromOffset(310, 100), function()
		Widget:ToggleSettings(true)
	end)

	--------------------------------------------------------------- scrub

	local Track = New("Frame", {
		Parent = CardGroup,
		Name = "Track",
		Position = UDim2.fromOffset(28, 170),
		Size = UDim2.fromOffset(298, 4),
		BackgroundColor3 = Glass,
		BackgroundTransparency = 0.8,
		BorderSizePixel = 0,
		ZIndex = 12,
	}, {
		New("UICorner", { CornerRadius = UDim.new(1, 0) }),
	})

	local TrackFill = New("Frame", {
		Parent = Track,
		Name = "Fill",
		Size = UDim2.new(0, 0, 1, 0),
		BackgroundColor3 = Glass,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		ZIndex = 13,
	}, {
		New("UICorner", { CornerRadius = UDim.new(1, 0) }),
	})

	local SeekHit = New("TextButton", {
		Parent = CardGroup,
		Name = "SeekHit",
		Position = UDim2.fromOffset(24, 156),
		Size = UDim2.fromOffset(306, 28),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 16,
	})

	local ElapsedText = Label({
		Parent = CardGroup,
		Name = "Elapsed",
		Position = UDim2.fromOffset(28, 178),
		Size = UDim2.fromOffset(60, 16),
		Text = "0:00",
		TextSize = 12,
		TextColor3 = Sub,
		ZIndex = 12,
	})

	local RemainingText = Label({
		Parent = CardGroup,
		Name = "Remaining",
		Position = UDim2.fromOffset(266, 178),
		Size = UDim2.fromOffset(60, 16),
		Text = "-0:00",
		TextSize = 12,
		TextColor3 = Sub,
		TextXAlignment = "Right",
		ZIndex = 12,
	})

	------------------------------------------------------------- transport

	local function Disc(Name, GlyphName, Size, Position, GlyphSize, Filled, Callback)
		local Button = New("TextButton", {
			Parent = CardGroup,
			Name = Name,
			Size = UDim2.fromOffset(Size, Size),
			Position = Position,
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Glass,
			BackgroundTransparency = Filled and 0 or 0.94,
			BorderSizePixel = 0,
			Text = "",
			AutoButtonColor = false,
			ZIndex = 14,
		}, {
			New("UICorner", { CornerRadius = UDim.new(1, 0) }),
			New("UIStroke", {
				Color = Text,
				Thickness = 1,
				Transparency = 0.9,
				ApplyStrokeMode = "Border",
			}),
			Icon(GlyphName, GlyphSize, {
				Name = "Glyph",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				ImageColor3 = Filled and Color3.fromRGB(10, 10, 12) or Text,
				ZIndex = 15,
			}),
		})

		local Rest = Filled and 0 or 0.94
		Widget:Connect(Button.MouseEnter, function()
			Tween(Button, 0.12, { BackgroundTransparency = Filled and 0.12 or 0.86 }):Play()
		end)
		Widget:Connect(Button.MouseLeave, function()
			Tween(Button, 0.12, { BackgroundTransparency = Rest }):Play()
		end)
		Widget:Connect(Button.MouseButton1Click, Callback)

		return Button
	end

	local PreviousButton = Disc("Previous", "skip-back", 30, UDim2.fromOffset(357, 177), 13, false, function()
		Widget:Previous()
	end)

	local PlayButton = Disc("Play", "play", 38, UDim2.fromOffset(395, 177), 15, true, function()
		Widget:Toggle()
	end)

	local NextButton = Disc("Next", "skip-forward", 30, UDim2.fromOffset(433, 177), 13, false, function()
		Widget:Next()
	end)

	------------------------------------------------------------ side column

	local SideCaption = Label({
		Parent = CardGroup,
		Name = "SideCaption",
		Position = UDim2.fromOffset(486, 44),
		Size = UDim2.fromOffset(240, 12),
		Text = "SOURCE",
		TextSize = 10,
		TextColor3 = Sub,
		FontFace = SemiBold,
		ZIndex = 12,
	})

	local SideValue = Label({
		Parent = CardGroup,
		Name = "SideValue",
		Position = UDim2.fromOffset(486, 60),
		Size = UDim2.fromOffset(240, 20),
		Text = "Nothing playing",
		TextSize = 15,
		FontFace = Bold,
		ZIndex = 12,
	})

	local SideDetail = Label({
		Parent = CardGroup,
		Name = "SideDetail",
		Position = UDim2.fromOffset(486, 82),
		Size = UDim2.fromOffset(240, 14),
		Text = "",
		TextSize = 10,
		TextColor3 = Sub,
		ZIndex = 12,
	})

	local VolumeGlyph = Icon("volume-2", 13, {
		Parent = CardGroup,
		Name = "VolumeGlyph",
		Position = UDim2.fromOffset(486, 110),
		AnchorPoint = Vector2.new(0, 0.5),
		ImageColor3 = Sub,
		ZIndex = 13,
	})

	local VolumeTrack = New("Frame", {
		Parent = CardGroup,
		Name = "VolumeTrack",
		Position = UDim2.fromOffset(508, 110),
		Size = UDim2.fromOffset(200, 4),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = Glass,
		BackgroundTransparency = 0.8,
		BorderSizePixel = 0,
		ZIndex = 12,
	}, {
		New("UICorner", { CornerRadius = UDim.new(1, 0) }),
	})

	local VolumeFill = New("Frame", {
		Parent = VolumeTrack,
		Name = "Fill",
		Size = UDim2.new(0.6, 0, 1, 0),
		BackgroundColor3 = Glass,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		ZIndex = 13,
	}, {
		New("UICorner", { CornerRadius = UDim.new(1, 0) }),
	})

	local VolumeHit = New("TextButton", {
		Parent = CardGroup,
		Name = "VolumeHit",
		Position = UDim2.fromOffset(502, 100),
		Size = UDim2.fromOffset(216, 22),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 16,
	})

	local SideHint = Label({
		Parent = CardGroup,
		Name = "SideHint",
		Position = UDim2.fromOffset(486, 134),
		Size = UDim2.fromOffset(240, 52),
		Text = "",
		TextSize = 10,
		TextColor3 = Sub,
		TextWrapped = true,
		TextYAlignment = "Top",
		ZIndex = 12,
	})

	--------------------------------------------------------------- settings

	local SettingsGroup = New("CanvasGroup", {
		Parent = Fill,
		Name = "Settings",
		Size = UDim2.fromOffset(SettingsSize.X, SettingsSize.Y),
		Position = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 1,
		GroupTransparency = 1,
		Visible = false,
		ZIndex = 20,
	})

	local BackButton = New("TextButton", {
		Parent = SettingsGroup,
		Name = "Back",
		Size = UDim2.fromOffset(26, 26),
		Position = UDim2.fromOffset(18, 8),
		BackgroundColor3 = Glass,
		BackgroundTransparency = 0.92,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		Visible = false,
		ZIndex = 22,
	}, {
		New("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Icon("arrow-left", 14, {
			Name = "Glyph",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			ImageTransparency = 0.1,
			ZIndex = 23,
		}),
	})

	Widget:Connect(BackButton.MouseButton1Click, function()
		Widget:ShowCase("providers")
	end)

	local SettingsTitle = Label({
		Parent = SettingsGroup,
		Name = "Title",
		Position = UDim2.fromOffset(20, 8),
		Size = UDim2.fromOffset(600, 26),
		Text = "Library",
		TextSize = 13,
		FontFace = Bold,
		ZIndex = 22,
	})

	local SettingsClose = New("TextButton", {
		Parent = SettingsGroup,
		Name = "Close",
		Size = UDim2.fromOffset(26, 26),
		Position = UDim2.new(1, -18, 0, 8),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = Glass,
		BackgroundTransparency = 0.92,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 22,
	}, {
		New("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Icon("x", 13, {
			Name = "Glyph",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			ImageTransparency = 0.2,
			ZIndex = 23,
		}),
	})

	Widget:Connect(SettingsClose.MouseEnter, function()
		Tween(SettingsClose, 0.12, { BackgroundTransparency = 0.84 }):Play()
	end)
	Widget:Connect(SettingsClose.MouseLeave, function()
		Tween(SettingsClose, 0.12, { BackgroundTransparency = 0.92 }):Play()
	end)
	Widget:Connect(SettingsClose.MouseButton1Click, function()
		Widget:ToggleSettings(false)
	end)

	local SettingsRule = New("Frame", {
		Parent = SettingsGroup,
		Name = "Rule",
		Position = UDim2.fromOffset(18, 44),
		Size = UDim2.new(1, -36, 0, 1),
		BackgroundColor3 = Text,
		BackgroundTransparency = 0.9,
		BorderSizePixel = 0,
		ZIndex = 21,
	})

	local SettingsBody = New("Frame", {
		Parent = SettingsGroup,
		Name = "Body",
		Position = UDim2.fromOffset(18, 56),
		Size = UDim2.new(1, -36, 1, -74),
		BackgroundTransparency = 1,
		ZIndex = 21,
	})

	local RowColumn = New("Frame", {
		Parent = SettingsBody,
		Name = "Providers",
		Size = UDim2.fromOffset(356, 220),
		BackgroundTransparency = 1,
		ZIndex = 22,
	}, {
		New("UIListLayout", {
			Padding = UDim.new(0, 6),
			SortOrder = "LayoutOrder",
		}),
	})

	local Page = New("Frame", {
		Parent = SettingsBody,
		Name = "Page",
		Position = UDim2.fromOffset(374, 0),
		Size = UDim2.new(1, -374, 1, 0),
		BackgroundColor3 = Glass,
		BackgroundTransparency = 0.96,
		Visible = false,
		ZIndex = 22,
	}, {
		New("UICorner", { CornerRadius = UDim.new(0, 14) }),
	})

	local PagePad = New("Frame", {
		Parent = Page,
		Name = "Pad",
		Size = UDim2.new(1, -24, 1, -24),
		Position = UDim2.fromOffset(12, 12),
		BackgroundTransparency = 1,
		ZIndex = 23,
	})

	local PageHint = Label({
		Parent = Page,
		Name = "Hint",
		Position = UDim2.new(0, 12, 1, -36),
		Size = UDim2.new(1, -24, 0, 26),
		Text = "",
		TextSize = 10,
		TextColor3 = Sub,
		TextWrapped = true,
		TextYAlignment = "Top",
		ZIndex = 24,
	})

	local function SetHint(Message)
		PageHint.Text = tostring(Message or "")
	end

	-- Right-hand pane while the source list is showing: fills the 342px the
	-- reference leaves for an inspector instead of a dead black margin.
	local Overview = New("Frame", {
		Parent = SettingsBody,
		Name = "Overview",
		Position = UDim2.fromOffset(374, 0),
		Size = UDim2.new(1, -374, 1, 0),
		BackgroundColor3 = Glass,
		BackgroundTransparency = 0.965,
		ZIndex = 22,
	}, {
		New("UICorner", { CornerRadius = UDim.new(0, 14) }),
		New("UIStroke", {
			Color = Text,
			Thickness = 1,
			Transparency = 0.93,
			ApplyStrokeMode = "Border",
		}),
		New("Frame", {
			Name = "Sheen",
			Size = UDim2.new(1, 0, 0, 54),
			BackgroundColor3 = Sheen,
			BackgroundTransparency = 0.94,
			BorderSizePixel = 0,
			ZIndex = 22,
		}, {
			New("UICorner", { CornerRadius = UDim.new(0, 14) }),
			New("UIGradient", {
				Rotation = 90,
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0),
					NumberSequenceKeypoint.new(1, 1),
				}),
			}),
		}),
		Icon("music-2", 18, {
			Name = "Mark",
			Position = UDim2.fromOffset(16, 16),
			ImageColor3 = Text,
			ZIndex = 23,
		}),
		Label({
			Name = "Name",
			Position = UDim2.fromOffset(44, 14),
			Size = UDim2.new(1, -60, 0, 22),
			Text = "Music mini player",
			TextSize = 13,
			FontFace = Bold,
			ZIndex = 23,
		}),
		Label({
			Name = "Body",
			Position = UDim2.fromOffset(16, 48),
			Size = UDim2.new(1, -32, 0, 120),
			Text = "Local audio, Spotify, or a bridge.\nArtwork is fetched into the songs folder the first time a track plays.",
			TextSize = 10,
			TextColor3 = Sub,
			TextWrapped = true,
			TextYAlignment = "Top",
			ZIndex = 23,
		}),
		Label({
			Name = "Foot",
			Position = UDim2.new(0, 16, 1, -40),
			Size = UDim2.new(1, -32, 0, 28),
			Text = "Pick a source on the left",
			TextSize = 10,
			TextColor3 = Sub,
			TextXAlignment = "Right",
			TextYAlignment = "Bottom",
			ZIndex = 23,
		}),
	})

	function Widget:SetOverviewHint(Message)
		Overview.Foot.Text = tostring(Message or "Pick a source on the left")
	end

	local Rows = {}
	Widget.Rows = Rows

	local function MakeRow(Provider_, Order)
		local Row = New("TextButton", {
			Parent = RowColumn,
			Name = Provider_.Id,
			Size = UDim2.new(1, 0, 0, 44),
			BackgroundColor3 = Glass,
			BackgroundTransparency = 0.95,
			BorderSizePixel = 0,
			Text = "",
			AutoButtonColor = false,
			LayoutOrder = Order,
			ZIndex = 23,
		}, {
			New("UICorner", { CornerRadius = UDim.new(0, 12) }),
			New("Frame", {
				Name = "Dot",
				Size = UDim2.fromOffset(6, 6),
				Position = UDim2.new(0, 14, 0.5, 0),
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundColor3 = Sub,
				BackgroundTransparency = 0.4,
				BorderSizePixel = 0,
				ZIndex = 24,
			}, {
				New("UICorner", { CornerRadius = UDim.new(1, 0) }),
			}),
			Label({
				Name = "Name",
				Position = UDim2.fromOffset(30, 7),
				Size = UDim2.new(1, -70, 0, 16),
				Text = Provider_.Name,
				TextSize = 12,
				FontFace = SemiBold,
				ZIndex = 24,
			}),
			Label({
				Name = "Status",
				Position = UDim2.fromOffset(30, 23),
				Size = UDim2.new(1, -46, 0, 14),
				Text = Provider_.Status or "",
				TextSize = 10,
				TextColor3 = Sub,
				ZIndex = 24,
			}),
			Icon("arrow-left", 12, {
				Name = "Chevron",
				Position = UDim2.new(1, -16, 0.5, 0),
				AnchorPoint = Vector2.new(1, 0.5),
				ImageTransparency = 0.5,
				Rotation = 180,
				ZIndex = 24,
			}),
		})

		Widget:Connect(Row.MouseEnter, function()
			Tween(Row, 0.1, { BackgroundTransparency = 0.9 }):Play()
		end)
		Widget:Connect(Row.MouseLeave, function()
			Tween(Row, 0.1, { BackgroundTransparency = 0.95 }):Play()
		end)
		Widget:Connect(Row.MouseButton1Click, function()
			Widget:OpenProvider(Provider_)
		end)

		Rows[#Rows + 1] = Row
		return Row
	end

	for Index, Provider_ in ipairs(Widget.Providers) do
		MakeRow(Provider_, Index)
	end

	------------------------------------------------------------------- forms

	local PageChildren = {}

	local function ClearPage()
		for _, Child in ipairs(PageChildren) do
			Child:Destroy()
		end
		PageChildren = {}
	end

	local function Track(Object)
		PageChildren[#PageChildren + 1] = Object
		return Object
	end

	local function Field(Placeholder, Value, Y)
		return Track(New("TextBox", {
			Parent = PagePad,
			Name = "Field",
			Position = UDim2.fromOffset(0, Y),
			Size = UDim2.new(1, 0, 0, 30),
			BackgroundColor3 = Glass,
			BackgroundTransparency = 0.94,
			BorderSizePixel = 0,
			Text = Value or "",
			PlaceholderText = Placeholder,
			PlaceholderColor3 = Color3.fromRGB(120, 120, 128),
			TextColor3 = Text,
			TextSize = 11,
			TextXAlignment = "Left",
			ClearTextOnFocus = false,
			FontFace = Regular,
			ZIndex = 24,
		}, {
			New("UICorner", { CornerRadius = UDim.new(0, 10) }),
			New("UIPadding", {
				PaddingLeft = UDim.new(0, 10),
				PaddingRight = UDim.new(0, 10),
			}),
		}))
	end

	local function Button(Text_, Y, Filled, Callback)
		local Object = Track(New("TextButton", {
			Parent = PagePad,
			Name = "Button",
			Position = UDim2.fromOffset(0, Y),
			Size = UDim2.new(1, 0, 0, 30),
			BackgroundColor3 = Glass,
			BackgroundTransparency = Filled and 0 or 0.94,
			BorderSizePixel = 0,
			Text = Text_,
			TextColor3 = Filled and Color3.fromRGB(10, 10, 12) or Text,
			TextSize = 11,
			FontFace = Bold,
			AutoButtonColor = false,
			ZIndex = 24,
		}, {
			New("UICorner", { CornerRadius = UDim.new(0, 10) }),
		}))

		Widget:Connect(Object.MouseEnter, function()
			Tween(Object, 0.1, { BackgroundTransparency = Filled and 0.12 or 0.88 }):Play()
		end)
		Widget:Connect(Object.MouseLeave, function()
			Tween(Object, 0.1, { BackgroundTransparency = Filled and 0 or 0.94 }):Play()
		end)
		Widget:Connect(Object.MouseButton1Click, Callback)

		return Object
	end

	local function Caption(Text_, Y)
		return Track(Label({
			Parent = PagePad,
			Position = UDim2.fromOffset(0, Y),
			Size = UDim2.new(1, 0, 0, 12),
			Text = Text_,
			TextSize = 9,
			TextColor3 = Sub,
			FontFace = SemiBold,
			ZIndex = 24,
		}))
	end

	------------------------------------------------------------------- files

	local function BuildFilesPage(Provider_)
		ClearPage()

		Caption("SONGS FOLDER", 0)

		Button("Rescan folder", 16, false, function()
			Provider_:Connect({}, function(Ok, Message)
				SetHint(Message)
				if Ok then
					Widget:RefreshRows()
					Widget:ShowCase("files", Provider_)
				end
			end)
		end).Size = UDim2.fromOffset(110, 24)

		local Scroller = Track(New("ScrollingFrame", {
			Parent = PagePad,
			Name = "Tracks",
			Position = UDim2.fromOffset(0, 46),
			Size = UDim2.new(1, 0, 1, -46),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 2,
			ScrollBarImageColor3 = Text,
			ScrollBarImageTransparency = 0.7,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = "Y",
			ZIndex = 24,
		}, {
			New("UIListLayout", {
				Padding = UDim.new(0, 4),
				SortOrder = "LayoutOrder",
			}),
		}))

		for Index, Track_ in ipairs(Provider_.Tracks) do
			local Row = New("TextButton", {
				Parent = Scroller,
				Name = "Track" .. Index,
				Size = UDim2.new(1, -6, 0, 38),
				BackgroundColor3 = Glass,
				BackgroundTransparency = 0.95,
				BorderSizePixel = 0,
				Text = "",
				AutoButtonColor = false,
				LayoutOrder = Index,
				ZIndex = 25,
			}, {
				New("UICorner", { CornerRadius = UDim.new(0, 10) }),
				Label({
					Name = "Title",
					Position = UDim2.fromOffset(10, 4),
					Size = UDim2.new(1, -50, 0, 16),
					Text = Track_.Title,
					TextSize = 11,
					FontFace = SemiBold,
					ZIndex = 26,
				}),
				Label({
					Name = "Artist",
					Position = UDim2.fromOffset(10, 20),
					Size = UDim2.new(1, -50, 0, 13),
					Text = Track_.Artist,
					TextSize = 9,
					TextColor3 = Sub,
					ZIndex = 26,
				}),
			})

			Widget:Connect(Row.MouseEnter, function()
				Tween(Row, 0.1, { BackgroundTransparency = 0.9 }):Play()
			end)
			Widget:Connect(Row.MouseLeave, function()
				Tween(Row, 0.1, { BackgroundTransparency = 0.95 }):Play()
			end)
			Widget:Connect(Row.MouseButton1Click, function()
				local Ok, Message = Provider_:Load(Index, true)
				if not Ok then
					SetHint("Could not play: " .. tostring(Message))
					return
				end
				Widget:SelectProvider(Provider_)
				Widget:ToggleSettings(false)
			end)
		end

		if #Provider_.Tracks == 0 then
			SetHint("No audio files yet. Drop mp3, ogg or wav into " .. Provider_.Path .. ".")
		else
			SetHint(#Provider_.Tracks .. " tracks — tap one to play it.")
		end
	end

	----------------------------------------------------------------- spotify

	local function BuildSpotifyPage(Provider_)
		ClearPage()

		Caption("SPOTIFY CLIENT ID", 0)
		local ClientField = Field("paste the id from the developer dashboard", Provider_.ClientId, 14)

		Button("Sign in with Spotify", 50, true, function()
			local ClientId = ClientField.Text:gsub("%s", "")
			if ClientId == "" then
				SetHint("Paste the client id first.")
				return
			end

			local Url, Error = Provider_:AuthUrl(ClientId)
			if not Url then
				SetHint(Error)
				return
			end

			if type(setclipboard) == "function" then
				pcall(setclipboard, Url)
			end
			pcall(function()
				GuiService:OpenBrowserWindow(Url)
			end)

			Widget:SaveProvider(Provider_)
			SetHint("Link copied and opened. Approve it, then paste the localhost URL it lands on below.")
		end)

		Caption("REDIRECT URL", 88)
		local RedirectField = Field("http://127.0.0.1:8888/callback?code=...", "", 102)

		Button("Finish sign-in", 138, false, function()
			local Value = RedirectField.Text
			if Value == "" then
				SetHint("Paste the URL the browser landed on.")
				return
			end

			SetHint("Exchanging the code...")
			Provider_:Exchange(Value, function(Ok, Message)
				if not Ok then
					SetHint("Spotify: " .. tostring(Message))
					return
				end

				Widget:SaveProvider(Provider_)
				Widget:SelectProvider(Provider_)
				Widget:RefreshRows()
				SetHint("Connected — " .. tostring(Message))
				Widget:Fire("Connect", Provider_)
			end)
		end)

		Track(Label({
			Parent = PagePad,
			Position = UDim2.fromOffset(0, 178),
			Size = UDim2.new(1, 0, 0, 28),
			Text = "Redirect URI to whitelist in the dashboard:  " .. Provider_.RedirectUri,
			TextSize = 9,
			TextColor3 = Sub,
			TextWrapped = true,
			TextYAlignment = "Top",
			ZIndex = 24,
		}))

		SetHint("Spotify reads whatever device is playing and drives its volume.")
	end

	------------------------------------------------------------------ bridge

	local function BuildBridgePage(Provider_)
		ClearPage()

		Caption(string.upper(Provider_.Name), 0)
		local UrlField = Field("http://127.0.0.1:5764", Provider_.Url, 14)

		Button("Connect bridge", 50, true, function()
			SetHint("Talking to the bridge...")
			Provider_:Connect({ Url = UrlField.Text }, function(Ok, Message)
				if not Ok then
					SetHint("Bridge: " .. tostring(Message))
					return
				end
				Widget:SelectProvider(Provider_)
				Widget:RefreshRows()
				SetHint("Connected to " .. tostring(Message))
			end)
		end)

		SetHint("Run bridge/server.js, then point this at its port. Volume reaches the app that is playing.")
	end

	------------------------------------------------------------------- demo

	local function BuildDemoPage(Provider_)
		ClearPage()

		Caption("PREVIEW", 0)
		Track(Label({
			Parent = PagePad,
			Position = UDim2.fromOffset(0, 16),
			Size = UDim2.new(1, 0, 0, 32),
			Text = "Three fake tracks with real cover art. Pick it as a source to see the island animate without a service attached.",
			TextSize = 10,
			TextColor3 = Sub,
			TextWrapped = true,
			TextYAlignment = "Top",
			ZIndex = 24,
		}))

		Button("Use the demo player", 58, true, function()
			Widget:SelectProvider(Provider_)
			Widget:RefreshRows()
			SetHint("Demo is driving the island.")
		end)

		SetHint("Demo never touches the network.")
	end

	--------------------------------------------------------------- behaviour

	function Widget:ShowCase(View, Provider_)
		self.View = View

		local IsRoot = View == "providers"
		RowColumn.Visible = IsRoot
		Overview.Visible = IsRoot
		Page.Visible = not IsRoot
		BackButton.Visible = not IsRoot
		SettingsTitle.Position = IsRoot and UDim2.fromOffset(20, 8) or UDim2.fromOffset(54, 8)

		if IsRoot then
			self:RefreshRows()
			return
		end

		if View == "spotify" and Provider_ then
			BuildSpotifyPage(Provider_)
		elseif View == "files" and Provider_ then
			BuildFilesPage(Provider_)
		elseif View == "bridge" and Provider_ then
			BuildBridgePage(Provider_)
		else
			BuildDemoPage(Provider_ or self.ActiveProvider or {})
		end
	end

	function Widget:OpenProvider(Provider_)
		if Provider_.Kind == "files" then
			Provider_:Connect({}, function()
				self:RefreshRows()
			end)
			self:Scan()
			self:ShowCase("files", Provider_)
			return
		end

		if Provider_.Kind == "spotify" or Provider_.Id == "spotify" then
			self:ShowCase("spotify", Provider_)
			return
		end

		if Provider_.Kind == "bridge" then
			self:ShowCase("bridge", Provider_)
			return
		end

		Provider_:Connect({}, function()
			self:SelectProvider(Provider_)
			self:RefreshRows()
		end)
		self:ShowCase("providers")
	end

	function Widget:Scan()
		local Files = self.ByProviderId.files
		if Files and type(Files.Scan) == "function" then
			Files:Scan()
			self:RefreshRows()
		end
	end

	function Widget:RefreshRows()
		for _, Row in ipairs(Rows) do
			local Provider_ = self.ByProviderId[Row.Name]
			if Provider_ then
				Row.Status.Text = Provider_.Status or ""
				Row.Dot.BackgroundColor3 = Provider_.Connected and Color3.fromRGB(51, 199, 89) or Sub
				Row.Dot.BackgroundTransparency = Provider_.Connected and 0 or 0.4
			end
		end

		if self.ActiveProvider then
			SideValue.Text = self.ActiveProvider.Name
			SideDetail.Text = self.ActiveProvider.Status or ""
		end
	end

	------------------------------------------------------------------- state

	function Widget:SetCover(Url)
		if Url == self.CoverUrl then
			return
		end

		self.CoverUrl = Url
		CoverArt.Image = ""
		CoverButtonSmall.Art.Image = ""

		if self.ArtFrame then
			self.ArtFrame:Destroy()
			self.ArtFrame = nil
		end
		if self.BleedFrame then
			self.BleedFrame:Destroy()
			self.BleedFrame = nil
		end

		if type(Url) ~= "string" or Url == "" then
			Bleed.Visible = false
			CoverButtonSmall.Placeholder.ImageTransparency = 0
			CoverButton.Placeholder.ImageTransparency = 0
			return
		end

		CoverButtonSmall.Placeholder.ImageTransparency = 1
		CoverButton.Placeholder.ImageTransparency = 1

		if Url:match("^rbxasset") or Url:match("^rbxassetid") then
			CoverArt.Image = Url
			CoverButtonSmall.Art.Image = Url

			-- Local art also tints the shell. A 1.9x copy at low alpha reads as
			-- the blurred backdrop Apple Music uses; no blur pass needed. The
			-- pill stays pure black like the reference, so only the card gets it.
			local Glow = New("ImageLabel", {
				Name = "LocalGlow",
				Parent = Bleed,
				Image = Url,
				Size = UDim2.fromScale(1.9, 1.9),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				ImageTransparency = 0.84,
				ScaleType = "Crop",
				ZIndex = 2,
			})
			Bleed.Visible = self.Expanded == true
			self.BleedFrame = Glow
			return
		end

		local Small = Creator.Image(Url, CacheName(Url) .. "-sm", 9, self.Folder, "MusicArt", false)
		Small.Size = UDim2.fromScale(1, 1)
		Small.ZIndex = 6
		if Small.ImageLabel then
			Small.ImageLabel.ZIndex = 6
		end
		Small.Parent = CoverButtonSmall
		self.SmallArtFrame = Small

		local Big = Creator.Image(Url, CacheName(Url) .. "-lg", 14, self.Folder, "MusicArt", false)
		Big.Size = UDim2.fromScale(1, 1)
		Big.ZIndex = 14
		if Big.ImageLabel then
			Big.ImageLabel.ZIndex = 14
		end
		Big.Parent = CoverButton
		self.ArtFrame = Big

		local Glow = Creator.Image(Url, CacheName(Url) .. "-bg", 0, self.Folder, "MusicArt", false)
		Glow.Size = UDim2.fromScale(1.8, 1.8)
		Glow.Position = UDim2.fromScale(0.5, 0.5)
		Glow.AnchorPoint = Vector2.new(0.5, 0.5)
		Glow.ZIndex = 2
		if Glow.ImageLabel then
			Glow.ImageLabel.ImageTransparency = 0.72
			Glow.ImageLabel.ZIndex = 2
		end
		Glow.Parent = Bleed
		self.BleedFrame = Glow

		Bleed.Visible = self.Expanded == true
	end

	local function PaintGlyph(Object, Name)
		local Data = Creator.Icon(Name) or {}
		local Rect_ = Data[2] or {}
		Object.Image = Data[1] or ""
		Object.ImageRectOffset = Rect_.ImageRectPosition or Vector2.new(0, 0)
		Object.ImageRectSize = Rect_.ImageRectSize or Vector2.new(0, 0)
	end

	function Widget:SetIcon(Name)
		if self.IconName == Name then
			return
		end
		self.IconName = Name

		PaintGlyph(PlayButton.Glyph, Name)
		PaintGlyph(StateGlyph, Name)
	end

	function Widget:SetPlaying(Playing)
		self.Playing = Playing == true
		self.State.Playing = self.Playing
		self.StateAt = tick()
		self:SetIcon(self.Playing and "pause" or "play")
		StateText.Text = self.Playing and "Playing" or "Paused"
	end

	function Widget:SetVolumeIcon(Name)
		if self.VolumeIcon == Name then
			return
		end
		self.VolumeIcon = Name
		PaintGlyph(VolumeGlyph, Name)
	end

	function Widget:UpdateClock()
		local State = self.State
		local Duration = tonumber(State.Duration) or 0

		local Position = self.DisplayPosition
		if self.Playing and Duration > 0 and not self.Scubbing then
			Position = math.min(Position + (tick() - self.StateAt), Duration)
		end

		self.DisplayPosition = Position

		local Fraction = Duration > 0 and math.clamp(Position / Duration, 0, 1) or 0
		TrackFill.Size = UDim2.new(Fraction, 0, 1, 0)

		ElapsedText.Text = Providers.FormatTime(Position)
		RemainingText.Text = Duration > 0 and ("-" .. Providers.FormatTime(math.max(Duration - Position, 0))) or "-0:00"

		self.StateAt = tick()
	end

	function Widget:ApplyState(State)
		if type(State) ~= "table" then
			return
		end

		self.State = State

		local Title = (type(State.Title) == "string" and State.Title ~= "") and State.Title or "Nothing playing"
		TitleText.Text = Title
		ArtistText.Text = State.Artist or ""
		StatusLabel.Text = string.upper(self.ActiveProvider and self.ActiveProvider.Name or "offline")
		SideHint.Text = tostring(State.Hint or "")

		if State.Cover ~= self.CoverUrl then
			self:SetCover(State.Cover or "")
		end

		-- Local folders: a bare mp3 has no art until one is fetched. Ask once per
		-- track; the provider answers through OnCover.
		if (State.Cover or "") == "" then
			local Provider_ = self.ActiveProvider
			if Provider_ and type(Provider_.FetchCover) == "function" and type(Provider_.Current) == "function" then
				Provider_:FetchCover(Provider_:Current())
			end
		end

		self:SetPlaying(State.Playing == true)

		self.DisplayPosition = tonumber(State.Position) or 0
		self.StateAt = tick()
		self:UpdateClock()

		if State.Volume ~= nil then
			local Percent = math.clamp(tonumber(State.Volume) or 0, 0, 100)
			self.Volume = Percent
			VolumeFill.Size = UDim2.new(Percent / 100, 0, 1, 0)
		end
	end

	function Widget:Poll()
		local Provider_ = self.ActiveProvider
		if not Provider_ or self.Destroyed or self.Polling then
			return
		end

		self.Polling = true
		Provider_:Poll(function(Ok, Result)
			self.Polling = false
			if self.Destroyed or self.ActiveProvider ~= Provider_ then
				return
			end

			if not Ok then
				if type(Result) == "string" then
					StatusLabel.Text = tostring(Result)
				end
				self:Fire("Error", Result)
				return
			end

			self:ApplyState(Result)
			self:Fire("Update", Result)
		end)
	end

	----------------------------------------------------------------- actions

	function Widget:Toggle()
		local Provider_ = self.ActiveProvider
		if not Provider_ then
			return
		end

		if self.Playing then
			Provider_:Pause(function() end)
			self:SetPlaying(false)
		else
			Provider_:Play(function() end)
			self:SetPlaying(true)
		end

		self:Fire("Toggle", self.Playing)
	end

	function Widget:Next()
		if self.ActiveProvider then
			self.ActiveProvider:Next(function() end)
			task.delay(0.35, function()
				self:Poll()
			end)
		end
	end

	function Widget:Previous()
		if self.ActiveProvider then
			self.ActiveProvider:Previous(function() end)
			task.delay(0.35, function()
				self:Poll()
			end)
		end
	end

	function Widget:Seek(Seconds)
		if self.ActiveProvider then
			self.ActiveProvider:Seek(Seconds, function() end)
		end
		self.DisplayPosition = Seconds
		self.StateAt = tick()
		self:UpdateClock()
		self:Fire("Seek", Seconds)
	end

	function Widget:SetVolume(Percent, Silent)
		local Value = math.clamp(tonumber(Percent) or 0, 0, 100)
		self.Volume = Value
		VolumeFill.Size = UDim2.new(Value / 100, 0, 1, 0)

		if Value == 0 then
			self:SetVolumeIcon("volume-x")
		elseif Value < 50 then
			self:SetVolumeIcon("volume-1")
		else
			self:SetVolumeIcon("volume-2")
		end

		if self.ActiveProvider then
			self.ActiveProvider:SetVolume(Value, function() end)
		end

		if self.OnVolume then
			Creator.SafeCallback(self.OnVolume, Value)
		end
		if not Silent then
			self:Fire("Volume", Value)
		end
	end

	function Widget:ToggleShuffle()
		local Provider_ = self.ActiveProvider
		if not Provider_ or Provider_.Shuffle == nil then
			self.Shuffle = not self.Shuffle
		else
			Provider_.Shuffle = not Provider_.Shuffle
			self.Shuffle = Provider_.Shuffle
			if type(Provider_.SavePlaylists) == "function" then
				Provider_:SavePlaylists()
			end
		end

		Tween(ShuffleButton.Glyph, 0.12, { ImageTransparency = self.Shuffle and 0.02 or 0.25 }):Play()
		ShuffleButton.Label.TextColor3 = self.Shuffle and Text or Sub
	end

	function Widget:OpenTrack()
		local State = self.State
		if State and State.Link and State.Link ~= "" then
			OpenUrl(State.Link)
		end
		self:Fire("CoverClick", State)
	end

	function Widget:SelectProvider(Provider_)
		if not Provider_ then
			return
		end

		self.ActiveProvider = Provider_
		StatusLabel.Text = string.upper(Provider_.Name)
		SideValue.Text = Provider_.Name
		SideDetail.Text = Provider_.Status or ""
		self:Fire("Provider", Provider_)
		self:Poll()
	end

	--------------------------------------------------------------- persisted

	function Widget:Folder_()
		local Base = "WindUI/" .. tostring(self.Folder) .. "/music"

		if type(makefolder) == "function" and type(isfolder) == "function" then
			for _, Part in ipairs({ "WindUI", "WindUI/" .. tostring(self.Folder), Base }) do
				if not isfolder(Part) then
					pcall(makefolder, Part)
				end
			end
		end

		return Base
	end

	function Widget:Persist(Name, Data)
		if type(writefile) ~= "function" then
			return
		end

		local Ok, Body = pcall(function()
			return HttpService:JSONEncode(Data)
		end)
		if not Ok then
			return
		end

		pcall(writefile, self:Folder_() .. "/" .. tostring(Name) .. ".json", Body)
	end

	function Widget:LoadPersisted(Name)
		if type(readfile) ~= "function" or type(isfile) ~= "function" then
			return nil
		end

		local Path_ = self:Folder_() .. "/" .. tostring(Name) .. ".json"
		if not isfile(Path_) then
			return nil
		end

		local Ok, Data = pcall(function()
			return HttpService:JSONDecode(readfile(Path_))
		end)

		if Ok and type(Data) == "table" then
			return Data
		end

		return nil
	end

	function Widget:SaveProvider(Provider_)
		if not Provider_ or type(Provider_.Save) ~= "function" then
			return
		end
		self:Persist("provider-" .. Provider_.Id, Provider_:Save())
	end

	--------------------------------------------------------------- animation

	local IslandHit

	local function ApplyShell(Width, Height, Radius)
		Container.Size = UDim2.fromOffset(Width, Height)

		Fill.UICorner.CornerRadius = UDim.new(0, Radius)
		Outline.UICorner.CornerRadius = UDim.new(0, Radius)
		Bleed.UICorner.CornerRadius = UDim.new(0, Radius)
		SheenLayer.UICorner.CornerRadius = UDim.new(0, Radius)
		Rim.UICorner.CornerRadius = UDim.new(0, math.max(Radius - 1, 0))
	end

	-- Spring, not a tween: the reference island overshoots a hair and settles,
	-- which a linear ease does not. Semi-implicit Euler at frame rate; damping
	-- ratio 0.82 keeps the bounce to a couple of pixels.
	function Widget:AnimateTo(TargetSize, TargetRadius, Duration)
		if self.Animating then
			self.Animating:Disconnect()
			self.Animating = nil
		end

		local Duration_ = math.max(tonumber(Duration) or 0.28, 0.08)
		local Stiffness = 380 * (0.28 / Duration_)
		local Damping = 2 * math.sqrt(Stiffness) * 0.82

		local Position = { self.CurrentSize.X, self.CurrentSize.Y, self.CurrentRadius or IslandRadius }
		local Velocity = { 0, 0, 0 }
		local Target = { TargetSize.X, TargetSize.Y, TargetRadius }

		self.Animating = RunService.Heartbeat:Connect(function(Delta)
			Delta = math.clamp(Delta, 1 / 240, 1 / 20)

			for Axis = 1, 3 do
				local Force = (Target[Axis] - Position[Axis]) * Stiffness - Velocity[Axis] * Damping
				Velocity[Axis] = Velocity[Axis] + Force * Delta
				Position[Axis] = Position[Axis] + Velocity[Axis] * Delta
			end

			local Settled = true
			for Axis = 1, 3 do
				if math.abs(Target[Axis] - Position[Axis]) > 0.3 or math.abs(Velocity[Axis]) > 2 then
					Settled = false
					break
				end
			end

			if Settled then
				Position = { Target[1], Target[2], Target[3] }
			end

			self.CurrentSize = Vector2.new(Position[1], Position[2])
			self.CurrentRadius = Position[3]

			ApplyShell(Position[1], Position[2], Position[3])

			if Settled then
				self.Animating:Disconnect()
				self.Animating = nil
			end
		end)
	end

	-- Specular sweep across the shell. Two of them: hover and every expand.
	function Widget:Sweep(Strength)
		Specular.Position = UDim2.fromScale(-0.75, 0)
		Specular.BackgroundTransparency = Strength == "soft" and 0.55 or 0
		Tween(Specular, 0.78, { Position = UDim2.fromScale(1.15, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out):Play()
	end

	function Widget:Expand()
		if self.Expanded or self.Destroyed or not self.DynamicIsland then
			return
		end

		self.Expanded = true
		if IslandHit then
			IslandHit.Visible = false
		end

		Bleed.Visible = type(self.CoverUrl) == "string" and self.CoverUrl ~= ""

		self:AnimateTo(CardSize, CardRadius, 0.34)

		Tween(IslandGroup, 0.1, { GroupTransparency = 1 }):Play()
		Tween(IslandScale, 0.12, { Scale = 1.04 }):Play()
		task.delay(0.12, function()
			if not self.Expanded then
				return
			end
			IslandGroup.Visible = false
			IslandScale.Scale = 1
		end)

		CardGroup.Visible = true
		CardGroup.GroupTransparency = 0.35
		CardScale.Scale = 0.955
		Tween(CardGroup, 0.28, { GroupTransparency = 0 }):Play()
		Tween(CardScale, 0.42, { Scale = 1 }, Enum.EasingStyle.Quint, Enum.EasingDirection.Out):Play()

		self:Sweep()

		self:SetIcon(self.Playing and "pause" or "play")
		self:Fire("Expanded", true)
	end

	function Widget:Collapse()
		if not self.Expanded or self.Destroyed or not self.DynamicIsland then
			return
		end

		self.Expanded = false
		self.SettingsOpen = false
		self.View = "providers"
		Bleed.Visible = false

		Tween(CardGroup, 0.12, { GroupTransparency = 1 }):Play()
		Tween(CardScale, 0.16, { Scale = 0.965 }):Play()
		Tween(SettingsGroup, 0.1, { GroupTransparency = 1 }):Play()
		Tween(SettingsGroup, 0.16, { Position = UDim2.fromOffset(8, 0) }):Play()

		task.delay(0.14, function()
			if Widget.Expanded then
				return
			end
			CardGroup.Visible = false
			SettingsGroup.Visible = false
			RowColumn.Visible = true
			Page.Visible = false
			Widget.SettingsOpen = false
		end)

		IslandGroup.Visible = true
		IslandGroup.GroupTransparency = 1
		IslandScale.Scale = 0.94
		Tween(IslandGroup, 0.2, { GroupTransparency = 0 }):Play()
		Tween(IslandScale, 0.34, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out):Play()

		if IslandHit then
			IslandHit.Visible = true
		end

		self:AnimateTo(IslandSize, IslandRadius, 0.3)
		self:Sweep("soft")
		self:Fire("Expanded", false)
	end

	function Widget:ToggleSettings(Force)
		local Show = Force
		if Show == nil then
			Show = not self.SettingsOpen
		end

		if not self.Expanded then
			if not Show then
				return
			end
			self:Expand()
		end

		self.SettingsOpen = Show

		if Show then
			self:ShowCase("providers")
			SettingsGroup.Visible = true
			SettingsGroup.GroupTransparency = 1
			SettingsGroup.Position = UDim2.fromOffset(10, 0)

			Tween(CardGroup, 0.12, { GroupTransparency = 1 }):Play()
			Tween(SettingsGroup, 0.22, { GroupTransparency = 0 }):Play()
			Tween(SettingsGroup, 0.3, { Position = UDim2.fromOffset(0, 0) }, Enum.EasingStyle.Quint, Enum.EasingDirection.Out):Play()

			task.delay(0.1, function()
				if Widget.SettingsOpen then
					CardGroup.Visible = false
				end
			end)

			self:AnimateTo(SettingsSize, CardRadius, 0.3)
			self:Sweep("soft")
			self:Fire("Settings", true)
			return
		end

		Tween(SettingsGroup, 0.12, { GroupTransparency = 1 }):Play()
		Tween(SettingsGroup, 0.16, { Position = UDim2.fromOffset(10, 0) }):Play()
		CardGroup.Visible = true
		CardGroup.GroupTransparency = 1
		Tween(CardGroup, 0.18, { GroupTransparency = 0 }):Play()

		task.delay(0.12, function()
			if not Widget.SettingsOpen then
				SettingsGroup.Visible = false
			end
		end)

		self:AnimateTo(CardSize, CardRadius, 0.26)
		self:Fire("Settings", false)
	end

	---------------------------------------------------------------- pointers

	local function BarDrag(Hit, Track_, OnChange)
		local Dragging = false

		local function Apply(Input)
			local Width = Track_.AbsoluteSize.X
			if Width <= 0 then
				return
			end
			local Alpha = math.clamp((Input.Position.X - Track_.AbsolutePosition.X) / Width, 0, 1)
			OnChange(Alpha)
		end

		Widget:Connect(Hit.InputBegan, function(Input)
			if
				Input.UserInputType ~= Enum.UserInputType.MouseButton1
				and Input.UserInputType ~= Enum.UserInputType.Touch
			then
				return
			end
			Dragging = true
			Apply(Input)
		end)

		Widget:Connect(UserInputService.InputChanged, function(Input)
			if not Dragging then
				return
			end
			if
				Input.UserInputType == Enum.UserInputType.MouseMovement
				or Input.UserInputType == Enum.UserInputType.Touch
			then
				Apply(Input)
			end
		end)

		Widget:Connect(UserInputService.InputEnded, function(Input)
			if not Dragging then
				return
			end
			if
				Input.UserInputType == Enum.UserInputType.MouseButton1
				or Input.UserInputType == Enum.UserInputType.Touch
			then
				Dragging = false
				Widget.Scubbing = false
				Widget:Seek(Widget.DisplayPosition)
			end
		end)

		return function()
			return Dragging
		end
	end

	BarDrag(SeekHit, Track, function(Alpha)
		local Duration = tonumber(Widget.State.Duration) or 0
		Widget.Scubbing = true
		Widget.DisplayPosition = Alpha * Duration
		Widget.StateAt = tick()
		Widget:UpdateClock()
		Widget:Fire("Scrub", Widget.DisplayPosition)
	end)

	BarDrag(VolumeHit, VolumeTrack, function(Alpha)
		Widget:SetVolume(Alpha * 100)
	end)

	-- Outside tap collapses, exactly like the phone. A fixed mini player has no
	-- collapsed state to fall back to, so it stays put.
	Widget:Connect(UserInputService.InputBegan, function(Input)
		if not Widget.Expanded or not Widget.DynamicIsland then
			return
		end
		if
			Input.UserInputType ~= Enum.UserInputType.MouseButton1
			and Input.UserInputType ~= Enum.UserInputType.Touch
		then
			return
		end

		local Point = Input.Position
		local TopLeft = Container.AbsolutePosition
		local Size_ = Container.AbsoluteSize

		local Inside = Point.X >= TopLeft.X
			and Point.X <= TopLeft.X + Size_.X
			and Point.Y >= TopLeft.Y
			and Point.Y <= TopLeft.Y + Size_.Y

		if not Inside then
			if Widget.SettingsOpen then
				Widget:ToggleSettings(false)
			end
			Widget:Collapse()
		end
	end)

	--------------------------------------------------------------- lifecycle

	IslandHit = New("TextButton", {
		Parent = Fill,
		Name = "IslandHit",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 30,
	})

	Widget:Connect(IslandHit.MouseButton1Click, function()
		Widget:Expand()
	end)

	Widget:Connect(IslandHit.MouseEnter, function()
		Tween(Outline.UIStroke, 0.18, { Transparency = 0.68 }):Play()
		Tween(IslandScale, 0.28, { Scale = 1.035 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out):Play()
		Widget:Sweep("soft")
	end)
	Widget:Connect(IslandHit.MouseLeave, function()
		Tween(Outline.UIStroke, 0.18, { Transparency = 0.86 }):Play()
		Tween(IslandScale, 0.22, { Scale = 1 }):Play()
	end)

	-- Six bars breathing while a track runs. Height is damped toward a target
	-- so pause settles into the stolen resting shape instead of snapping.
	local BarCurrent = { 14, 11, 13, 16, 14, 13 }

	Widget:Connect(RunService.Heartbeat, function(Delta)
		if Widget.Destroyed then
			return
		end

		local Now = tick()
		local Energy = 0.55 + math.clamp(tonumber(Widget.Volume) or 60, 0, 100) / 160

		for Index, Bar in ipairs(Bars) do
			local Target
			if Widget.Playing then
				Target = 3.5 + (0.3 + math.abs(math.sin(Now * 4.4 + Index * 1.35)) * 0.7) * (9 * Energy)
			else
				Target = BarHeights[Index]
			end

			BarCurrent[Index] = BarCurrent[Index] + (Target - BarCurrent[Index]) * math.min(Delta * 12, 1)
			Bar.Size = UDim2.fromOffset(2, BarCurrent[Index])
		end

		Widget:UpdateClock()
	end)

	function Widget:SetScale(Value)
		self.Scale = Value
		ScaleObject.Scale = Value
	end

	function Widget:Show()
		Container.Visible = true
	end

	function Widget:Hide()
		Container.Visible = false
	end

	-- Switch between the phone-style pill and the always-open card at runtime.
	function Widget:SetDynamicIsland(Value)
		local Enabled = Value ~= false
		if self.DynamicIsland == Enabled then
			return
		end

		self.DynamicIsland = Enabled
		CollapseButton.Visible = Enabled

		if Enabled then
			self.Expanded = true
			self:Collapse()
			return
		end

		self.Expanded = true
		if IslandHit then
			IslandHit.Visible = false
		end
		IslandGroup.Visible = false
		SettingsGroup.Visible = false
		CardGroup.Visible = true
		CardGroup.GroupTransparency = 0
		CardScale.Scale = 1

		self.CurrentSize = CardSize
		self.CurrentRadius = CardRadius
		ApplyShell(CardSize.X, CardSize.Y, CardRadius)
	end

	function Widget:Destroy()
		self.Destroyed = true
		if self.Animating then
			self.Animating:Disconnect()
			self.Animating = nil
		end
		for _, Connection in ipairs(self.Connections) do
			Connection:Disconnect()
		end
		self.Connections = {}
		for _, Provider_ in ipairs(self.Providers) do
			if Provider_.Disconnect then
				Provider_:Disconnect()
			end
		end
		Container:Destroy()
	end

	--------------------------------------------------------------- start-up

	if Config.Position then
		Container.Position = Config.Position
	end

	for _, Provider_ in ipairs(Widget.Providers) do
		if type(Provider_.Load) == "function" then
			Provider_:Load(Widget:LoadPersisted("provider-" .. Provider_.Id))
		end
	end

	local Files = Widget.ByProviderId.files
	if Files and type(Files.Scan) == "function" then
		Files:Scan()

		-- Cover lookups finish long after the poll that asked for them; push the
		-- art straight into the shell when the track is still the one playing.
		Files.OnCover = function(Track, Url)
			if Widget.ActiveProvider == Files and Files:Current() == Track and Url ~= "" then
				Widget.State.Cover = Url
				Widget:SetCover(Url)
			end
		end

		Widget.Shuffle = Files.Shuffle == true
		ShuffleButton.Label.TextColor3 = Widget.Shuffle and Text or Sub
	end

	-- Default source: a signed-in account, then local files if the folder has
	-- audio, then whatever came first in the list.
	if not Config.Provider then
		local Spotify = Widget.ByProviderId.spotify

		if Spotify and Spotify:HasTokens() then
			Widget.ActiveProvider = Spotify
		elseif Files and #Files.Tracks > 0 then
			Widget.ActiveProvider = Files
		end
	end

	if Widget.ActiveProvider then
		StatusLabel.Text = string.upper(Widget.ActiveProvider.Name)
		SideValue.Text = Widget.ActiveProvider.Name
		SideDetail.Text = Widget.ActiveProvider.Status or ""
		Widget:SetVolumeIcon("volume-2")
		VolumeFill.Size = UDim2.new(Widget.Volume / 100, 0, 1, 0)
	end

	Widget:RefreshRows()
	Widget:SetIcon("play")

	-- Fixed mode: no pill, no expanding, just the card from the first frame.
	if not Widget.DynamicIsland then
		Widget.Expanded = true
		CollapseButton.Visible = false
		if IslandHit then
			IslandHit.Visible = false
		end
		IslandGroup.Visible = false
		CardGroup.Visible = true
		CardGroup.GroupTransparency = 0
		CardScale.Scale = 1
		Widget.CurrentSize = CardSize
		Widget.CurrentRadius = CardRadius
		ApplyShell(CardSize.X, CardSize.Y, CardRadius)
	end

	task.spawn(function()
		task.wait(0.3)
		while not Widget.Destroyed do
			Widget:Poll()
			task.wait(Widget.PollInterval)
		end
	end)

	return Widget
end

return MusicMiniPlayer
