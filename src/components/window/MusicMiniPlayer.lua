-- Music Mini Player — a floating widget, not a window element.
--
--   local Player = WindUI:MusicMiniPlayer({
--       Title = "Red Flags",
--       Providers = { "spotify", "apple", "youtube", "local", "demo" },
--   })
--
-- The card is a glass surface in the window's own language: squircle shell,
-- cover bleed behind the text, out-of-focus scrim, hairline highlight. It is
-- dragged from anywhere that is not a control, snaps to the screen edges, and
-- keeps its spot between sessions when the executor can write files.
--
-- Everything service-specific lives in modules/MusicProviders — this file only
-- knows how to draw a state table and how to shout at a provider.

local cloneref = (cloneref or clonereference or function(instance)
	return instance
end)

local RunService = cloneref(game:GetService("RunService"))
local UserInputService = cloneref(game:GetService("UserInputService"))

local Creator = require("../modules/Creator")
local Providers = require("../modules/MusicProviders")

local New = Creator.New
local Tween = Creator.Tween

local MusicMiniPlayer = {}
MusicMiniPlayer.__index = MusicMiniPlayer

local DefaultSize = Vector2.new(348, 178)
local SettingsHeight = 306
local ShadowMargin = 12

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

-- Gradient themes return a table for Text/Background; anything that must be a
-- flat colour falls back instead of erroring on the property set.
local function Solid(Key, Fallback)
	local Value = Creator.GetThemeProperty(Key, Creator.Theme)
	if typeof(Value) == "Color3" then
		return Value
	end
	return Fallback
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
			ThemeTag = { ImageColor3 = "Text" },
		}, Clean)
	)
end

local function TimeText(Seconds, Prefix)
	return (Prefix or "") .. Providers.FormatTime(Seconds)
end

--------------------------------------------------------------------- widget

function MusicMiniPlayer.New(Config)
	Config = Config or {}

	local WindUI = Config.WindUI
	if not WindUI then
		error("MusicMiniPlayer needs WindUI: use WindUI:MusicMiniPlayer()")
	end

	local Size = Vector2.new(Config.Width or DefaultSize.X, Config.Height or DefaultSize.Y)
	local Radius = Config.Radius or 22
	local Folder = Config.Folder or (WindUI.Window and WindUI.Window.Folder) or "Widgets"

	local Widget = setmetatable({
		WindUI = WindUI,
		Config = Config,
		Folder = Folder,
		Radius = Radius,
		BaseSize = Size,
		Scale = Config.Scale or 1,
		Draggable = Config.Draggable ~= false,
		SavePosition = Config.SavePosition ~= false,
		PollInterval = math.max(tonumber(Config.PollInterval) or 1.5, 0.5),
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
		SettingsOpen = false,
		Destroyed = false,
		Polling = false,
		Manual = false,
		UIElements = {},
	}, MusicMiniPlayer)

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
				elseif Entry == "local" then
					Add(Providers.NewLocal({
						Sound = Config.Sound,
						Playlist = Config.Playlist,
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
			Add(Providers.NewLocal({
				Sound = Config.Sound,
				Playlist = Config.Playlist,
				Title = Config.Title,
				Artist = Config.Artist,
				Cover = Config.Cover,
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
	if Config.ZIndex then
		-- nothing: a widget owns its own stack inside its container
	end

	local Container = New("Frame", {
		Name = "MusicMiniPlayer",
		Parent = Parent,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(Size.X, Size.Y),
		AnchorPoint = Vector2.new(0, 0),
		Position = Config.Position or UDim2.new(1, -(Size.X + 28), 0, 96),
		ZIndex = 5,
	})

	local ScaleObject = New("UIScale", {
		Scale = Widget.Scale,
		Parent = Container,
	})

	Creator.NewRoundFrame(Radius + 4, "Squircle", {
		Parent = Container,
		Name = "Shadow",
		Size = UDim2.new(1, ShadowMargin, 1, ShadowMargin + 6),
		Position = UDim2.new(0.5, 0, 0.5, 4),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ImageColor3 = Color3.new(0, 0, 0),
		ImageTransparency = 0.62,
		ZIndex = 1,
	})

	local Main = Creator.NewRoundFrame(Radius, "Squircle", {
		Parent = Container,
		Name = "Main",
		Size = UDim2.new(1, 0, 1, 0),
		ImageTransparency = 0.02,
		ThemeTag = { ImageColor3 = "ElementBackground" },
		ZIndex = 2,
	})

	-- The cover bleeds behind everything, cropped to the shell. A Frame with
	-- UICorner does the rounding because an ImageLabel clip is rectangular.
	local Bleed = New("Frame", {
		Parent = Main,
		Name = "Bleed",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		ZIndex = 1,
	}, {
		New("UICorner", { CornerRadius = UDim.new(0, Radius) }),
	})

	Creator.NewRoundFrame(Radius, "Squircle", {
		Parent = Bleed,
		Name = "Fallback",
		Size = UDim2.new(1, 0, 1, 0),
		ThemeTag = { ImageColor3 = "Accent" },
		ImageTransparency = 0.15,
		ZIndex = 1,
	})

	do
	local Scrim = New("Frame", {
		Parent = Bleed,
		Name = "Scrim",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.34,
		ZIndex = 3,
	}, {
		New("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.1),
				NumberSequenceKeypoint.new(0.55, 0.45),
				NumberSequenceKeypoint.new(1, 0.86),
			}),
		}),
	})
	Scrim.Name = "Scrim"

	local Sheen = Creator.NewRoundFrame(Radius, "SquircleGlass", {
		Parent = Bleed,
		Name = "Sheen",
		Size = UDim2.new(1, 0, 1, 0),
		ImageColor3 = Color3.new(1, 1, 1),
		ImageTransparency = 0.9,
		ZIndex = 4,
	}, {
		New("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.2),
				NumberSequenceKeypoint.new(0.7, 1),
				NumberSequenceKeypoint.new(1, 0.75),
			}),
		}),
	})
	Sheen.Name = "Sheen"
	end

	-- Drag surface: a button so the input always lands here and never on a
	-- control sitting above it.
	local Surface = New("TextButton", {
		Parent = Main,
		Name = "Surface",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 5,
	})

	local CoverHolder = New("Frame", {
		Parent = Main,
		Name = "Cover",
		Size = UDim2.fromOffset(58, 58),
		Position = UDim2.fromOffset(15, 15),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		ZIndex = 8,
	}, {
		New("UICorner", { CornerRadius = UDim.new(0, 15) }),
		New("UIStroke", {
			Thickness = 1,
			Color = Color3.new(1, 1, 1),
			Transparency = 0.72,
		}),
		Creator.NewRoundFrame(15, "Squircle", {
			Name = "Placeholder",
			Size = UDim2.new(1, 0, 1, 0),
			ThemeTag = { ImageColor3 = "Accent" },
			ImageTransparency = 0.05,
			ZIndex = 7,
		}),
	})

	local TitleText = New("TextLabel", {
		Parent = Main,
		Name = "Title",
		Position = UDim2.fromOffset(84, 18),
		Size = UDim2.new(1, -84 - 46, 0, 19),
		BackgroundTransparency = 1,
		Text = "Nothing playing",
		TextXAlignment = "Left",
		TextYAlignment = "Bottom",
		TextTruncate = "AtEnd",
		TextSize = 16,
		FontFace = Font.new(Creator.Font, Enum.FontWeight.SemiBold),
		ThemeTag = { TextColor3 = "Text" },
		ZIndex = 9,
	})

	local ArtistText = New("TextLabel", {
		Parent = Main,
		Name = "Artist",
		Position = UDim2.fromOffset(84, 38),
		Size = UDim2.new(1, -84 - 46, 0, 17),
		BackgroundTransparency = 1,
		Text = "",
		TextXAlignment = "Left",
		TextYAlignment = "Top",
		TextTruncate = "AtEnd",
		TextSize = 13,
		FontFace = Font.new(Creator.Font, Enum.FontWeight.Regular),
		ThemeTag = { TextColor3 = "Text", TextTransparency = 0.32 },
		ZIndex = 9,
	})

	local SourcePill = New("TextLabel", {
		Parent = Main,
		Name = "Source",
		Position = UDim2.fromOffset(84, 57),
		Size = UDim2.fromOffset(90, 14),
		BackgroundTransparency = 1,
		Text = "offline",
		TextXAlignment = "Left",
		TextSize = 10,
		FontFace = Font.new(Creator.Font, Enum.FontWeight.Medium),
		TextTransparency = 0.55,
		ThemeTag = { TextColor3 = "Text" },
		ZIndex = 9,
	})

	------------------------------------------------------------- gear button

	local Gear = New("TextButton", {
		Parent = Main,
		Name = "Settings",
		Size = UDim2.fromOffset(26, 26),
		Position = UDim2.new(1, -15, 0, 15),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundTransparency = 1,
		Text = "",
		ZIndex = 12,
	}, {
		Creator.NewRoundFrame(99, "Circle", {
			Name = "Hover",
			Size = UDim2.new(1, 0, 1, 0),
			ImageColor3 = Color3.new(1, 1, 1),
			ImageTransparency = 1,
		}),
		Icon("settings", 15, {
			Name = "Glyph",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, 0),
			ThemeTag = { ImageColor3 = "Text" },
			ImageTransparency = 0.15,
		}),
	})

	Widget:Connect(Gear.MouseEnter, function()
		Tween(Gear.Hover, 0.12, { ImageTransparency = 0.88 }):Play()
		Tween(Gear.Glyph, 0.12, { ImageTransparency = 0 }):Play()
	end)
	Widget:Connect(Gear.MouseLeave, function()
		Tween(Gear.Hover, 0.12, { ImageTransparency = 1 }):Play()
		Tween(Gear.Glyph, 0.12, { ImageTransparency = 0.15 }):Play()
	end)

	------------------------------------------------------------ progress bar

	local Progress = New("Frame", {
		Parent = Main,
		Name = "Progress",
		Position = UDim2.fromOffset(15, 84),
		Size = UDim2.new(1, -30, 0, 30),
		BackgroundTransparency = 1,
		ZIndex = 9,
	})

	local Track = Creator.NewRoundFrame(99, "Squircle", {
		Parent = Progress,
		Name = "Track",
		Position = UDim2.new(0, 0, 0, 3),
		Size = UDim2.new(1, 0, 0, 5),
		ImageTransparency = 0.82,
		ThemeTag = { ImageColor3 = "Text" },
		ZIndex = 9,
	})

	local Fill = Creator.NewRoundFrame(99, "Squircle", {
		Parent = Track,
		Name = "Fill",
		Size = UDim2.new(0, 0, 1, 0),
		ImageTransparency = 0.08,
		ThemeTag = { ImageColor3 = "Text" },
		ZIndex = 9,
	})

	local Knob = Creator.NewRoundFrame(99, "Circle", {
		Parent = Fill,
		Name = "Knob",
		Size = UDim2.fromOffset(9, 9),
		Position = UDim2.new(1, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ThemeTag = { ImageColor3 = "Text" },
		ZIndex = 10,
	})

	local ElapsedText = New("TextLabel", {
		Parent = Progress,
		Name = "Elapsed",
		Position = UDim2.fromOffset(0, 12),
		Size = UDim2.fromOffset(56, 14),
		BackgroundTransparency = 1,
		Text = "0:00",
		TextXAlignment = "Left",
		TextSize = 11,
		FontFace = Font.new(Creator.Font, Enum.FontWeight.Regular),
		ThemeTag = { TextColor3 = "Text", TextTransparency = 0.3 },
		ZIndex = 9,
	})

	local RemainingText = New("TextLabel", {
		Parent = Progress,
		Name = "Remaining",
		Position = UDim2.new(1, -56, 0, 12),
		Size = UDim2.fromOffset(56, 14),
		BackgroundTransparency = 1,
		Text = "0:00",
		TextXAlignment = "Right",
		TextSize = 11,
		FontFace = Font.new(Creator.Font, Enum.FontWeight.Regular),
		ThemeTag = { TextColor3 = "Text", TextTransparency = 0.3 },
		ZIndex = 9,
	})

	---------------------------------------------------------------- controls

	local Controls = New("Frame", {
		Parent = Main,
		Name = "Controls",
		Position = UDim2.new(0.5, 0, 1, -44),
		Size = UDim2.new(1, -30, 0, 30),
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		ZIndex = 9,
	}, {
		New("UIListLayout", {
			FillDirection = "Horizontal",
			HorizontalAlignment = "Center",
			VerticalAlignment = "Center",
			Padding = UDim.new(0, 10),
			SortOrder = "LayoutOrder",
		}),
	})

	local function Control(Name, IconName, IconSize, Order, Callback, Extra)
		local Button = New("TextButton", {
			Parent = Controls,
			Name = Name,
			Size = UDim2.fromOffset(IconSize + 14, IconSize + 14),
			BackgroundTransparency = 1,
			Text = "",
			LayoutOrder = Order,
			ZIndex = 12,
		}, {
			Creator.NewRoundFrame(99, "Circle", {
				Name = "Hover",
				Size = UDim2.new(1, 0, 1, 0),
				ImageColor3 = Color3.new(1, 1, 1),
				ImageTransparency = 1,
				ZIndex = 12,
			}),
			Icon(IconName, IconSize, {
				Name = "Glyph",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, 0, 0.5, 0),
				ImageTransparency = (Extra and Extra.Transparency) or 0,
				ZIndex = 13,
			}),
		})

		Widget:Connect(Button.MouseEnter, function()
			Tween(Button.Hover, 0.12, { ImageTransparency = 0.88 }):Play()
		end)
		Widget:Connect(Button.MouseLeave, function()
			Tween(Button.Hover, 0.12, { ImageTransparency = 1 }):Play()
		end)
		Widget:Connect(Button.MouseButton1Click, function()
			Callback(Button)
		end)

		return Button
	end

	local VolumeButton = Control("Volume", "volume-2", 16, 1, function()
		Widget:ToggleVolume()
	end)
	VolumeButton.Glyph.ThemeTag = { ImageColor3 = "Text" }

	local PrevButton = Control("Previous", "skip-back", 17, 2, function()
		if Widget.ActiveProvider then
			Widget.ActiveProvider:Previous(function() end)
			Widget:Fire("Previous")
			Widget:Kick()
		end
	end)

	local PlayButton = Control("PlayPause", "play", 18, 3, function()
		Widget:Toggle()
	end)

	local NextButton = Control("Next", "skip-forward", 17, 4, function()
		if Widget.ActiveProvider then
			Widget.ActiveProvider:Next(function() end)
			Widget:Fire("Next")
			Widget:Kick()
		end
	end)

	local QueueButton = Control("Queue", "list-music", 16, 5, function()
		Widget:ToggleSettings()
	end)

	--------------------------------------------------------------- volume pop

	local VolumePop = New("Frame", {
		Parent = Main,
		Name = "VolumePop",
		Position = UDim2.new(0, 15, 1, -70),
		Size = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Visible = false,
		ZIndex = 20,
	}, {
		Creator.NewRoundFrame(13, "Squircle", {
			Name = "Body",
			Size = UDim2.new(1, 0, 1, 0),
			ImageColor3 = Color3.new(0, 0, 0),
			ImageTransparency = 0.42,
			ThemeTag = nil,
			ZIndex = 20,
		}),
		Creator.NewRoundFrame(13, "SquircleGlass", {
			Name = "Glass",
			Size = UDim2.new(1, 0, 1, 0),
			ImageColor3 = Color3.new(1, 1, 1),
			ImageTransparency = 0.92,
			ZIndex = 21,
		}),
	})

	local VolumeTrack = Creator.NewRoundFrame(99, "Squircle", {
		Parent = VolumePop,
		Name = "Track",
		Position = UDim2.new(0, 12, 0.5, 0),
		Size = UDim2.new(1, -80, 0, 4),
		AnchorPoint = Vector2.new(0, 0.5),
		ImageColor3 = Color3.new(1, 1, 1),
		ImageTransparency = 0.65,
		ZIndex = 21,
	})

	local VolumeFill = Creator.NewRoundFrame(99, "Squircle", {
		Parent = VolumeTrack,
		Name = "Fill",
		Size = UDim2.new(0.6, 0, 1, 0),
		ImageColor3 = Color3.new(1, 1, 1),
		ImageTransparency = 0.05,
		ZIndex = 22,
	})

	local VolumeLabel = New("TextLabel", {
		Parent = VolumePop,
		Name = "Value",
		Position = UDim2.new(1, -56, 0.5, 0),
		Size = UDim2.fromOffset(44, 16),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
		Text = "60",
		TextXAlignment = "Right",
		TextSize = 11,
		FontFace = Font.new(Creator.Font, Enum.FontWeight.Medium),
		TextColor3 = Color3.new(1, 1, 1),
		TextTransparency = 0.1,
		ZIndex = 22,
	})

	--------------------------------------------------------------- settings

	local Settings = New("Frame", {
		Parent = Main,
		Name = "SettingsPanel",
		Size = UDim2.new(1, 0, 1, 0),
		Position = UDim2.new(0, 0, 1, 0),
		BackgroundColor3 = Solid("Background", Color3.fromHex("#101010")),
		BackgroundTransparency = 0.04,
		Visible = false,
		ClipsDescendants = true,
		ZIndex = 40,
	}, {
		New("UICorner", { CornerRadius = UDim.new(0, Radius) }),
	})

	New("TextLabel", {
		Parent = Settings,
		Position = UDim2.fromOffset(15, 12),
		Size = UDim2.new(1, -46, 0, 18),
		BackgroundTransparency = 1,
		Text = "Music source",
		TextXAlignment = "Left",
		TextSize = 14,
		FontFace = Font.new(Creator.Font, Enum.FontWeight.SemiBold),
		ThemeTag = { TextColor3 = "Text" },
		ZIndex = 41,
	})

	local SettingsClose = New("TextButton", {
		Parent = Settings,
		Name = "Close",
		Size = UDim2.fromOffset(24, 24),
		Position = UDim2.new(1, -11, 0, 9),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundTransparency = 1,
		Text = "",
		ZIndex = 43,
	}, {
		Icon("x", 13, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, 0),
			ThemeTag = { ImageColor3 = "Text" },
			ImageTransparency = 0.25,
			ZIndex = 43,
		}),
	})

	Widget:Connect(SettingsClose.MouseButton1Click, function()
		Widget:ToggleSettings(false)
	end)

	local RowScroller = New("ScrollingFrame", {
		Parent = Settings,
		Name = "Rows",
		Position = UDim2.fromOffset(10, 38),
		Size = UDim2.new(1, -20, 1, -48),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Color3.new(1, 1, 1),
		ScrollBarImageTransparency = 0.6,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = "Y",
		ScrollingDirection = "Y",
		ZIndex = 41,
	}, {
		New("UIListLayout", {
			Padding = UDim.new(0, 6),
			SortOrder = "LayoutOrder",
		}),
	})

	local SettingsHint = New("TextLabel", {
		Parent = Settings,
		Position = UDim2.new(0, 15, 1, -22),
		Size = UDim2.new(1, -30, 0, 14),
		BackgroundTransparency = 1,
		Text = "",
		TextXAlignment = "Left",
		TextTruncate = "AtEnd",
		TextSize = 10,
		TextTransparency = 0.45,
		ThemeTag = { TextColor3 = "Text" },
		ZIndex = 41,
	})

	------------------------------------------------------------------ state

	function Widget:SetCover(Url)
		if self.CoverFrame then
			self.CoverFrame:Destroy()
			self.CoverFrame = nil
		end
		if self.BleedFrame then
			self.BleedFrame:Destroy()
			self.BleedFrame = nil
		end

		-- No cover is not a blank card: the accent squircle and the cover
		-- placeholder stay visible underneath, so a failed download degrades
		-- to a tinted glass card instead of a hole.
		if type(Url) ~= "string" or Url == "" then
			return
		end

		local Thumb = Creator.Image(Url, Url, 0, self.Folder, "MusicThumb", false)
		if Thumb then
			Thumb.Name = "Art"
			Thumb.Parent = CoverHolder
			Thumb.Size = UDim2.new(1, 0, 1, 0)
			Thumb.BackgroundTransparency = 1
			Thumb.ZIndex = 9
			if Thumb.ImageLabel then
				Thumb.ImageLabel.ZIndex = 9
			end
			self.CoverFrame = Thumb
		end

		local BleedImage = Creator.Image(Url, Url, 0, self.Folder, "MusicBleed", false)
		if BleedImage then
			BleedImage.Name = "Art"
			BleedImage.Parent = Bleed
			BleedImage.Size = UDim2.new(1, 0, 1, 0)
			BleedImage.BackgroundTransparency = 1
			BleedImage.ZIndex = 2
			if BleedImage.ImageLabel then
				BleedImage.ImageLabel.ZIndex = 2
				BleedImage.ImageLabel.ImageTransparency = 0.25
				BleedImage.ImageLabel.ScaleType = Enum.ScaleType.Crop
			end
			self.BleedFrame = BleedImage
		end
	end

	function Widget:RenderState(State)
		self.State = State
		self.StateAt = tick()
		self.DisplayPosition = State.Position
		self.Playing = State.Playing

		TitleText.Text = State.Title or ""
		ArtistText.Text = State.Artist or ""

		local Active = self.ActiveProvider
		local Label = Active and Active.Name or "offline"
		if Active and Active.Kind == "demo" then
			Label = "preview"
		end
		SourcePill.Text = string.upper(Label)

		if State.Cover ~= self.LastCover then
			self.LastCover = State.Cover
			self:SetCover(State.Cover)
		end

		if type(State.Volume) == "number" then
			self.Volume = math.clamp(tonumber(State.Volume) or 0, 0, 100)
			self.LastVolume = math.max(self.Volume, 1)
			VolumeFill.Size = UDim2.new(self.Volume / 100, 0, 1, 0)
			VolumeLabel.Text = tostring(math.floor(self.Volume + 0.5))
		end

		self:SetIcon(self.Playing and "pause" or "play")
		self:UpdateClock(true)

		Widget:Fire("State", State)
	end

	-- Manual state: a screenshot, a demo, a host that drives the card itself.
	-- Polling parks until another source is selected.
	function Widget:SetTrack(Track)
		Track = Track or {}

		self.Manual = true
		self:RenderState({
			Title = Track.Title or "Nothing playing",
			Artist = Track.Artist or "",
			Album = Track.Album or "",
			Cover = Track.Cover or "",
			Position = tonumber(Track.Position) or 0,
			Duration = tonumber(Track.Duration) or 0,
			Playing = Track.Playing == true,
			Volume = self.Volume,
			CanSeek = true,
			CanSkip = true,
		})
	end

	function Widget:SetProgress(Elapsed, Duration)
		self.State.Duration = tonumber(Duration) or self.State.Duration
		self.DisplayPosition = math.max(tonumber(Elapsed) or 0, 0)
		self.StateAt = tick()
		self:UpdateClock(true)
	end

	function Widget:SetPlaying(Playing)
		self.Playing = Playing == true
		self.StateAt = tick()
		self:SetIcon(self.Playing and "pause" or "play")
	end

	function Widget:SetIcon(Name)
		if self.IconName == Name then
			return
		end
		self.IconName = Name

		local Data = Creator.Icon(Name) or {}
		local Rect_ = Data[2] or {}

		PlayButton.Glyph.Image = Data[1] or ""
		PlayButton.Glyph.ImageRectOffset = Rect_.ImageRectPosition or Vector2.new(0, 0)
		PlayButton.Glyph.ImageRectSize = Rect_.ImageRectSize or Vector2.new(0, 0)
	end

	function Widget:UpdateClock(Force)
		local State = self.State
		local Duration = tonumber(State.Duration) or 0

		local Position = self.DisplayPosition
		if self.Playing and Duration > 0 then
			Position = math.min(Position + (tick() - self.StateAt), Duration)
		end

		self.DisplayPosition = Position

		local Fraction = Duration > 0 and math.clamp(Position / Duration, 0, 1) or 0
		Fill.Size = UDim2.new(Fraction, 0, 1, 0)
		Knob.Visible = Duration > 0

		ElapsedText.Text = TimeText(Position)
		RemainingText.Text = Duration > 0 and TimeText(math.max(Duration - Position, 0), "-") or "-0:00"

		if Force then
			self.LastSecond = math.floor(Position)
		end

		self.StateAt = tick()
	end

	------------------------------------------------------------------ poll

	function Widget:Poll()
		local Provider_ = self.ActiveProvider
		if not Provider_ or self.Destroyed or self.Polling or self.Manual then
			return
		end

		self.Polling = true

		Provider_:Poll(function(Ok, State)
			self.Polling = false
			if self.Destroyed or Provider_ ~= self.ActiveProvider then
				return
			end

			if not Ok then
				Provider_.Connected = false
				SourcePill.Text = "OFFLINE"
				return
			end

			if type(State) == "table" then
				self:RenderState(State)
			end
		end)
	end

	function Widget:Kick()
		task.defer(function()
			Widget:Poll()
		end)
	end

	function Widget:SelectProvider(Provider_)
		if not Provider_ then
			return
		end

		self.ActiveProvider = Provider_
		self.LastCover = nil
		self.Polling = false
		self.Manual = false

		SourcePill.Text = string.upper(Provider_.Name)
		self:Fire("Source", Provider_)

		if Provider_.Connected then
			self:Kick()
		end
	end

	-------------------------------------------------------------- transport

	function Widget:Toggle()
		local Provider_ = self.ActiveProvider
		if not Provider_ then
			return
		end

		local WasPlaying = self.Playing
		self.Playing = not WasPlaying
		self:SetIcon(self.Playing and "pause" or "play")
		self.StateAt = tick()

		if WasPlaying then
			Provider_:Pause(function() end)
			self:Fire("Pause")
		else
			Provider_:Play(function() end)
			self:Fire("Play")
		end

		task.delay(0.6, function()
			if not self.Destroyed then
				self:Kick()
			end
		end)
	end

	function Widget:Seek(Seconds)
		local Provider_ = self.ActiveProvider
		if not Provider_ then
			return
		end

		Seconds = math.max(tonumber(Seconds) or 0, 0)
		self.DisplayPosition = Seconds
		self.StateAt = tick()
		self:UpdateClock(true)

		Provider_:Seek(Seconds, function() end)
		self:Fire("Seek", Seconds)
	end

	function Widget:SetVolume(Percent, Silent)
		local Value = math.clamp(math.floor(tonumber(Percent) or 0), 0, 100)
		self.Volume = Value
		if Value > 0 then
			self.LastVolume = Value
		end

		VolumeFill.Size = UDim2.new(Value / 100, 0, 1, 0)
		VolumeLabel.Text = tostring(Value)

		local Name = Value == 0 and "volume-x" or (Value < 40 and "volume-1" or "volume-2")
		local Data = Creator.Icon(Name) or {}
		local Rect_ = Data[2] or {}
		VolumeButton.Glyph.Image = Data[1] or ""
		VolumeButton.Glyph.ImageRectOffset = Rect_.ImageRectPosition or Vector2.new(0, 0)
		VolumeButton.Glyph.ImageRectSize = Rect_.ImageRectSize or Vector2.new(0, 0)

		if not Silent then
			if self.ActiveProvider then
				self.ActiveProvider:SetVolume(Value, function() end)
			end
			if self.OnVolume then
				Creator.SafeCallback(self.OnVolume, Value)
			end
			self:Fire("Volume", Value)
		end
	end

	function Widget:ToggleMute()
		if self.Volume > 0 then
			self:SetVolume(0)
		else
			self:SetVolume(self.LastVolume > 0 and self.LastVolume or 50)
		end
	end

	function Widget:ToggleVolume(Force)
		local Show = Force
		if Show == nil then
			Show = not VolumePop.Visible
		end

		if Show then
			VolumePop.Visible = true
			Tween(VolumePop, 0.16, { Size = UDim2.fromOffset(132, 30) }, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
				:Play()
		else
			local Tween_ = Tween(VolumePop, 0.12, { Size = UDim2.fromOffset(0, 30) })
			Tween_:Play()
			Tween_.Completed:Once(function()
				if not VolumePop.Visible then
					return
				end
				VolumePop.Visible = false
			end)
		end
	end

	--------------------------------------------------------------- settings

	local SettingsRowHeight = 44
	local Rows = {}
	local TokenForm = nil

	local function ClearForm()
		if TokenForm then
			TokenForm:Destroy()
			TokenForm = nil
		end
	end

	local function BuildForm(Fields, Submit)
		ClearForm()

		local Form = New("Frame", {
			Parent = RowScroller,
			Name = "Form",
			Size = UDim2.new(1, -4, 0, 0),
			AutomaticSize = "Y",
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.93,
			LayoutOrder = 900,
			ZIndex = 42,
		}, {
			New("UICorner", { CornerRadius = UDim.new(0, 10) }),
			New("UIListLayout", {
				Padding = UDim.new(0, 6),
				SortOrder = "LayoutOrder",
			}),
			New("UIPadding", {
				PaddingTop = UDim.new(0, 8),
				PaddingBottom = UDim.new(0, 8),
				PaddingLeft = UDim.new(0, 8),
				PaddingRight = UDim.new(0, 8),
			}),
		})

		local Boxes = {}

		for Index, Field in ipairs(Fields) do
			local Box = New("TextBox", {
				Parent = Form,
				Size = UDim2.new(1, 0, 0, 28),
				BackgroundColor3 = Color3.new(0, 0, 0),
				BackgroundTransparency = 0.55,
				Text = Field.Default or "",
				PlaceholderText = Field.Placeholder or "",
				PlaceholderColor3 = Color3.new(0.6, 0.6, 0.62),
				TextColor3 = Solid("Text", Color3.new(1, 1, 1)),
				TextSize = 11,
				TextXAlignment = "Left",
				ClearTextOnFocus = false,
				LayoutOrder = Index,
				ZIndex = 43,
			}, {
				New("UICorner", { CornerRadius = UDim.new(0, 7) }),
				New("UIPadding", {
					PaddingLeft = UDim.new(0, 8),
					PaddingRight = UDim.new(0, 8),
				}),
			})

			Boxes[#Boxes + 1] = Box
		end

		local SubmitButton = New("TextButton", {
			Parent = Form,
			Size = UDim2.new(1, 0, 0, 28),
			BackgroundColor3 = Solid("Text", Color3.new(1, 1, 1)),
			BackgroundTransparency = 0.08,
			Text = "Connect",
			TextSize = 12,
			FontFace = Font.new(Creator.Font, Enum.FontWeight.SemiBold),
			TextColor3 = Solid("Background", Color3.new(0, 0, 0)),
			LayoutOrder = #Fields + 1,
			ZIndex = 43,
		}, {
			New("UICorner", { CornerRadius = UDim.new(0, 7) }),
		})

		Widget:Connect(SubmitButton.MouseButton1Click, function()
			local Values = {}
			for Index, Box in ipairs(Boxes) do
				Values[Index] = Box.Text
			end
			Submit(Values)
		end)

		TokenForm = Form
		return Form
	end

	local function SetHint(Text)
		SettingsHint.Text = Text
	end

	function Widget:ConnectSpotify()
		local Provider_ = self.ByProviderId.spotify
		if not Provider_ then
			return
		end

		self:SelectProvider(Provider_)
		SetHint("Paste a token, or the three refresh fields.")

		BuildForm({
			{ Placeholder = "Access token" },
			{ Placeholder = "Refresh token (optional)" },
			{ Placeholder = "client_id:client_secret (optional)" },
		}, function(Values)
			local AccessToken, RefreshToken, Pair_ = Values[1], Values[2], Values[3]
			local ClientId, ClientSecret = nil, nil
			if type(Pair_) == "string" and Pair_ ~= "" then
				ClientId, ClientSecret = Pair_:match("^([^:]+):(.+)$")
			end

			SetHint("Checking token with Spotify…")
			Provider_:Connect({
				AccessToken = AccessToken,
				RefreshToken = RefreshToken ~= "" and RefreshToken or nil,
				ClientId = ClientId,
				ClientSecret = ClientSecret,
			}, function(Ok, Message)
				if not Ok then
					SetHint(string.upper(tostring(Message)))
					return
				end

				ClearForm()
				Widget:Persist("spotify", Provider_:Save())
				Widget:SelectProvider(Provider_)
				Widget:RefreshRows()
				SetHint("Connected — playback follows whatever device is playing.")
				Widget:Fire("Connect", Provider_)
			end)
		end)
	end

	function Widget:ConnectBridge(Provider_)
		if not Provider_ then
			return
		end

		self:SelectProvider(Provider_)
		SetHint("Point the widget at a bridge, or leave the default port.")

		BuildForm({
			{ Placeholder = "http://127.0.0.1:5764", Default = Provider_.Url or "" },
		}, function(Values)
			SetHint("Talking to the bridge…")
			Provider_:Connect({ Url = Values[1] }, function(Ok, Message)
				if not Ok then
					SetHint(string.upper(tostring(Message)))
					return
				end

				ClearForm()
				Widget:SelectProvider(Provider_)
				Widget:RefreshRows()
				SetHint("Connected to " .. tostring(Provider_.Account or Provider_.Name) .. ".")
				Widget:Fire("Connect", Provider_)
			end)
		end)
	end

	function Widget:RefreshRows()
		for _, Row in ipairs(Rows) do
			local Provider_ = Row.Provider
			local Status = Provider_.Status or ""

			Row.Status.Text = Status
			Row.Status.TextTransparency = Provider_.Connected and 0.35 or 0.6
			Row.Dot.ImageColor3 = Provider_.Connected and Color3.fromHex("#33c759")
				or Color3.fromHex("#8a8a92")
			Row.Dot.ImageTransparency = Provider_.Connected and 0 or 0.35
		end
	end

	local function BuildRows()
		for Index, Provider_ in ipairs(Widget.Providers) do
			local Row = New("TextButton", {
				Parent = RowScroller,
				Name = Provider_.Id,
				Size = UDim2.new(1, -4, 0, SettingsRowHeight),
				BackgroundColor3 = Color3.new(1, 1, 1),
				BackgroundTransparency = 0.94,
				Text = "",
				LayoutOrder = Index,
				ZIndex = 42,
			}, {
				New("UICorner", { CornerRadius = UDim.new(0, 10) }),
				New("Frame", {
					Name = "Dot",
					Size = UDim2.fromOffset(6, 6),
					Position = UDim2.new(0, 12, 0.5, 0),
					AnchorPoint = Vector2.new(0, 0.5),
					BackgroundColor3 = Color3.fromHex("#8a8a92"),
					BorderSizePixel = 0,
					ZIndex = 43,
				}, {
					New("UICorner", { CornerRadius = UDim.new(1, 0) }),
				}),
				New("TextLabel", {
					Name = "Name",
					Position = UDim2.fromOffset(26, 0),
					Size = UDim2.new(1, -90, 1, 0),
					BackgroundTransparency = 1,
					Text = Provider_.Name,
					TextXAlignment = "Left",
					TextSize = 13,
					FontFace = Font.new(Creator.Font, Enum.FontWeight.Medium),
					ThemeTag = { TextColor3 = "Text" },
					ZIndex = 43,
				}),
				New("TextLabel", {
					Name = "Status",
					Position = UDim2.new(1, -10, 0, 0),
					Size = UDim2.new(0, 96, 1, 0),
					AnchorPoint = Vector2.new(1, 0),
					BackgroundTransparency = 1,
					Text = Provider_.Status or "",
					TextXAlignment = "Right",
					TextTruncate = "AtEnd",
					TextSize = 10,
					FontFace = Font.new(Creator.Font, Enum.FontWeight.Regular),
					TextTransparency = 0.6,
					ThemeTag = { TextColor3 = "Text" },
					ZIndex = 43,
				}),
			})

			Row.Provider = Provider_

			Widget:Connect(Row.MouseEnter, function()
				Tween(Row, 0.1, { BackgroundTransparency = 0.86 }):Play()
			end)
			Widget:Connect(Row.MouseLeave, function()
				Tween(Row, 0.1, { BackgroundTransparency = 0.94 }):Play()
			end)
			Widget:Connect(Row.MouseButton1Click, function()
				Widget:ChooseProvider(Provider_)
			end)

			Rows[#Rows + 1] = Row
		end
	end

	function Widget:ChooseProvider(Provider_)
		if Provider_.Id == "spotify" then
			self:ConnectSpotify()
			return
		end

		if Provider_.Kind == "bridge" then
			self:ConnectBridge(Provider_)
			return
		end

		if Provider_.Kind == "local" then
			if not Provider_.Sound then
				SetHint("Bind a Sound: MusicMiniPlayer({ Sound = sound }).")
				self:SelectProvider(Provider_)
				return
			end

			Provider_:Connect({}, function()
				self:SelectProvider(Provider_)
				self:RefreshRows()
				SetHint("Playing the game's own sound.")
			end)
			return
		end

		Provider_:Connect({}, function()
			self:SelectProvider(Provider_)
			self:RefreshRows()
			SetHint("Previewing demo tracks.")
		end)
	end

	function Widget:ToggleSettings(Force)
		local Show = Force
		if Show == nil then
			Show = not self.SettingsOpen
		end

		self.SettingsOpen = Show

		if Show then
			self:RefreshRows()
			Settings.Visible = true

			Tween(Container, 0.22, {
				Size = UDim2.fromOffset(Size.X, math.max(SettingsHeight, Size.Y)),
			}, Enum.EasingStyle.Quint, Enum.EasingDirection.Out):Play()

			Tween(Settings, 0.22, { Position = UDim2.new(0, 0, 0, 0) }, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
				:Play()

			self:Fire("Settings", true)
			return
		end

		ClearForm()

		local Slide = Tween(Settings, 0.18, { Position = UDim2.new(0, 0, 1, 0) }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)

		Slide.Completed:Once(function()
			if not Widget.SettingsOpen then
				Settings.Visible = false
			end
		end)

		Slide:Play()

		Tween(Container, 0.2, { Size = UDim2.fromOffset(Size.X, Size.Y) }, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
			:Play()

		self:Fire("Settings", false)
	end

	------------------------------------------------------------------ files

	function Widget:Folder_()
		local Base = "WindUI/" .. tostring(self.Folder) .. "/music"

		if type(makefolder) == "function" and type(isfolder) == "function" then
			if not isfolder("WindUI") then
				makefolder("WindUI")
			end
			if not isfolder("WindUI/" .. tostring(self.Folder)) then
				makefolder("WindUI/" .. tostring(self.Folder))
			end
			if not isfolder(Base) then
				makefolder(Base)
			end
			if not isfolder("WindUI/" .. tostring(self.Folder) .. "/assets") then
				makefolder("WindUI/" .. tostring(self.Folder) .. "/assets")
			end
		end

		return Base
	end

	function Widget:Persist(Name, Data)
		if type(writefile) ~= "function" then
			return
		end

		local Ok, Body = pcall(function()
			return game:GetService("HttpService"):JSONEncode(Data)
		end)
		if not Ok then
			return
		end

		local Base = self:Folder_()
		pcall(writefile, Base .. "/" .. tostring(Name) .. ".json", Body)
	end

	function Widget:LoadPersisted(Name)
		if type(readfile) ~= "function" or type(isfile) ~= "function" then
			return nil
		end

		local Base = self:Folder_()
		local Path_ = Base .. "/" .. tostring(Name) .. ".json"
		if not isfile(Path_) then
			return nil
		end

		local Ok, Data = pcall(function()
			return game:GetService("HttpService"):JSONDecode(readfile(Path_))
		end)

		if Ok and type(Data) == "table" then
			return Data
		end

		return nil
	end

	local function SavePositionFile()
		if not Widget.SavePosition then
			return
		end
		Widget:Persist("position", {
			X = Container.Position.X.Offset,
			Y = Container.Position.Y.Offset,
			ScaleX = Container.Position.X.Scale,
			ScaleY = Container.Position.Y.Scale,
		})
	end

	--------------------------------------------------------------- dragging

	if Widget.Draggable then
		Widget.Drag = Creator.Drag(Container, { Surface }, function(Dragging)
			if Dragging then
				Widget:ToggleVolume(false)
				if not Widget.SettingsOpen then
					Tween(Container, 0.12, { Size = UDim2.fromOffset(Size.X + 2, Size.Y + 2) }):Play()
				end
				return
			end

			Tween(Container, 0.12, { Size = UDim2.fromOffset(Size.X, Size.Y) }):Play()
			Widget:Snap()
			SavePositionFile()
		end)
	end

	function Widget:Snap()
		local Screen = self.WindUI.ScreenGui
		if not Screen then
			return
		end

		local Scale_ = ScaleObject.Scale ~= 0 and ScaleObject.Scale or 1
		local Viewport = Screen.AbsoluteSize
		local Absolute = Container.AbsolutePosition
		local AbsoluteSize = Container.AbsoluteSize

		local Margin = 6
		local MaxX = math.max(Viewport.X - AbsoluteSize.X - Margin, Margin)
		local MaxY = math.max(Viewport.Y - AbsoluteSize.Y - Margin, Margin)

		local TargetX = math.clamp(Absolute.X, Margin, MaxX)
		local TargetY = math.clamp(Absolute.Y, Margin, MaxY)

		if math.abs(TargetX - Absolute.X) < 0.5 and math.abs(TargetY - Absolute.Y) < 0.5 then
			return
		end

		Container.Position = UDim2.fromOffset(TargetX / Scale_, TargetY / Scale_)
	end

	function Widget:SetPosition(Position)
		Container.Position = Position
	end

	function Widget:GetPosition()
		return Container.Position
	end

	function Widget:SetScale(Scale_)
		self.Scale = Scale_
		ScaleObject.Scale = Scale_
	end

	--------------------------------------------------------------- input

	local function TrackFraction(Track_, Input)
		local X = Input.Position.X
		if Input.UserInputType == Enum.UserInputType.MouseButton1 then
			X = UserInputService:GetMouseLocation().X
		end

		return math.clamp((X - Track_.AbsolutePosition.X) / math.max(Track_.AbsoluteSize.X, 1), 0, 1)
	end

	local function BindSeek(Track_, OnFraction)
		local Guid = nil
		local Moving = nil
		local Releasing = nil

		Widget:Connect(Track_.InputBegan, function(Input)
			if Input.UserInputType ~= Enum.UserInputType.MouseButton1
				and Input.UserInputType ~= Enum.UserInputType.Touch
			then
				return
			end

			if Widget.WindUI.CurrentInput and Widget.WindUI.CurrentInput ~= Guid then
				return
			end

			Guid = Widget.WindUI.GenerateGUID()
			Widget.WindUI.CurrentInput = Guid

			OnFraction(TrackFraction(Track_, Input))

			local IsTouch = Input.UserInputType == Enum.UserInputType.Touch

			Moving = RunService.RenderStepped:Connect(function()
				if not Guid then
					return
				end
				OnFraction(TrackFraction(Track_, Input))
			end)

			Releasing = UserInputService.InputEnded:Connect(function(Ended)
				local Matches = Ended == Input
					or (not IsTouch and Ended.UserInputType == Enum.UserInputType.MouseButton1)

				if not Matches then
					return
				end

				if Moving then
					Moving:Disconnect()
					Moving = nil
				end
				if Releasing then
					Releasing:Disconnect()
					Releasing = nil
				end

				Guid = nil
				Widget.WindUI.CurrentInput = nil
			end)
		end)
	end

	BindSeek(Track, function(Fraction)
		local Duration = tonumber(Widget.State.Duration) or 0
		if Duration <= 0 then
			return
		end
		Widget:Seek(Fraction * Duration)
	end)

	BindSeek(VolumeTrack, function(Fraction)
		Widget:SetVolume(math.floor(Fraction * 100 + 0.5))
	end)

	Widget:Connect(VolumeButton.MouseButton2Click, function()
		Widget:ToggleMute()
	end)

	--------------------------------------------------------------- lifecycle

	local Heartbeat = RunService.RenderStepped:Connect(function()
		if Widget.Destroyed or Widget.SettingsOpen then
			return
		end

		local NowAll = tick()
		if NowAll - (Widget.LastTick or 0) < 0.05 then
			return
		end
		Widget.LastTick = NowAll

		Widget:UpdateClock(false)
	end)
	Widget.Connections[#Widget.Connections + 1] = Heartbeat

	task.spawn(function()
		while not Widget.Destroyed do
			Widget:Poll()
			task.wait(Widget.PollInterval)
		end
	end)

	function Widget:Destroy()
		if self.Destroyed then
			return
		end

		self.Destroyed = true

		for _, Connection in ipairs(self.Connections) do
			pcall(function()
				Connection:Disconnect()
			end)
		end
		self.Connections = {}

		if self.WindUI.CurrentInput == nil then
			-- nothing to release
		end

		Container:Destroy()
	end

	function Widget:Show()
		Container.Visible = true
	end

	function Widget:Hide()
		Container.Visible = false
	end

	------------------------------------------------------------------ boot

	BuildRows()
	Widget:RefreshRows()

	local SavedSpotify = Widget:LoadPersisted("spotify")
	if SavedSpotify then
		local Spotify_ = Widget.ByProviderId.spotify
		if Spotify_ and Spotify_:Load(SavedSpotify) then
			Spotify_:Connect({}, function()
				Widget:RefreshRows()
				if Widget.ActiveProvider == Spotify_ then
					Widget:Kick()
				end
			end)
		end
	end

	local SavedPosition = Widget:LoadPersisted("position")
	if SavedPosition and type(SavedPosition.X) == "number" and type(SavedPosition.Y) == "number" then
		Container.Position = UDim2.new(
			SavedPosition.ScaleX or 0,
			SavedPosition.X,
			SavedPosition.ScaleY or 0,
			SavedPosition.Y
		)
	end

	Widget.UIElements = {
		Container = Container,
		Main = Main,
		Surface = Surface,
		Cover = CoverHolder,
		Title = TitleText,
		Artist = ArtistText,
		Source = SourcePill,
		Progress = Progress,
		Track = Track,
		Fill = Fill,
		Controls = Controls,
		Play = PlayButton,
		Previous = PrevButton,
		Next = NextButton,
		Volume = VolumeButton,
		VolumePop = VolumePop,
		VolumeTrack = VolumeTrack,
		Settings = Settings,
		Queue = QueueButton,
		Rows = RowScroller,
		SettingsClose = SettingsClose,
		Gear = Gear,
	}

	Widget.VolumeGlyph = nil

	if Config.Demo then
		local Demo_ = Widget.ByProviderId.demo
		if Demo_ then
			Widget.ActiveProvider = Demo_
		end
	elseif Config.Provider and Widget.ByProviderId[Config.Provider] then
		Widget.ActiveProvider = Widget.ByProviderId[Config.Provider]
	end

	Widget:SetVolume(Widget.Volume, true)
	Widget:SelectProvider(Widget.ActiveProvider)
	Widget:RefreshRows()
	Widget:Kick()

	return Widget
end

return MusicMiniPlayer
