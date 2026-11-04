-- Miniplayer - the compact now-playing strip, floating and draggable.
--
--   local Player = WindUI:Miniplayer({
--       Providers = { "files", "spotify", "demo" },
--       Folder = "Ender Hub/songs",
--   })
--
--   -- docked inside a window instead of floating over the game:
--   local Player = WindUI:Miniplayer({ Parent = Tab.Frame })
--
-- A strip, not a card: 340 x 88, 56 px artwork at (14, 16), the title and the
-- artist beside it, five level bars that only move while a track is running,
-- bare previous / play / next glyphs on the right, and a hairline progress bar
-- along the bottom edge. Black and white only - the colour lives on the
-- dynamic island, not here. Dragging is the library's own Creator.Drag, so it
-- obeys the same input lock every other WindUI surface does.

local cloneref = (cloneref or clonereference or function(instance)
	return instance
end)

local RunService = cloneref(game:GetService("RunService"))

local Creator = require("../../modules/Creator")
local Surface = require("../../modules/MusicSurface")

local New = Creator.New
local Tween = Creator.Tween

local Miniplayer = {}
Miniplayer.__index = Miniplayer

---------------------------------------------------------------------------
-- metrics, in strip pixels
---------------------------------------------------------------------------

local W, H = 340, 88
local Radius = 18

local CoverSize = 56
local CoverAt = Vector2.new(14, 16)
local CoverRadius = 14

local TextX = 82
local TextW = 148

local BarsX, BarsY = 298, 28
local BarW, BarGap = 3, 2

local ControlsY = 48
local PrevX, PlayX, NextX = 246, 282, 316

local TrackX, TrackW, TrackH = 14, W - 28, 3
local TrackY = H - 8

local Palette = {
	Shell = Color3.fromRGB(0, 0, 0),
	Text = Color3.fromRGB(255, 255, 255),
	Muted = Color3.fromRGB(148, 150, 158),
	Tile = Color3.fromRGB(30, 30, 34),
}

local EaseOut = Enum.EasingDirection.Out

---------------------------------------------------------------------------
-- primitives
---------------------------------------------------------------------------

local function Corner(Object, Radius_)
	return New("UICorner", { CornerRadius = UDim.new(0, Radius_), Parent = Object })
end

local function Glyph(Icon, Size, Color)
	local Image, Rect = Creator.Icon(Icon)
	return New("ImageLabel", {
		Image = Image,
		ImageRectOffset = Rect.ImageRectPosition,
		ImageRectSize = Rect.ImageRectSize,
		ImageColor3 = Color or Palette.Text,
		ScaleType = Enum.ScaleType.Fit,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(Size, Size),
	})
end

local function Text(Properties)
	Properties.FontFace = Properties.FontFace or Font.new(Creator.Font, Enum.FontWeight.Medium)
	Properties.BackgroundTransparency = 1
	Properties.TextXAlignment = Properties.TextXAlignment or Enum.TextXAlignment.Left
	Properties.TextYAlignment = Properties.TextYAlignment or Enum.TextYAlignment.Center
	Properties.TextColor3 = Properties.TextColor3 or Palette.Text
	Properties.TextTruncate = Enum.TextTruncate.AtEnd
	return New("TextLabel", Properties)
end

local function Button(Properties)
	Properties.BackgroundTransparency = Properties.BackgroundTransparency or 1
	Properties.Text = ""
	Properties.AutoButtonColor = false
	return New("TextButton", Properties)
end

-- "Artist - Song" and "Artist – Song" both split the way the reference does.
local function SplitName(Name)
	Name = tostring(Name or ""):gsub("%.%w+$", "")
	local Artist, Song = Name:match("^(.-)%s+%-%s+(.+)$")
	if Artist and Artist ~= "" then
		return Song, Artist
	end
	return Name, ""
end

---------------------------------------------------------------------------
-- construction
---------------------------------------------------------------------------

function Miniplayer.New(Config)
	Config = Config or {}

	local self = setmetatable({
		Config = Config,
		WindUI = Config.WindUI,
		Parent = Config.Parent,
		Alive = true,
		FitScale = 1,
		CoverId = nil,
		Volume = 60,
		Muted = false,
		Seeking = false,
		Signals = {},
	}, Miniplayer)

	self.Floating = self.Parent == nil

	local Folder = self.Parent or (self.WindUI and self.WindUI.ScreenGui)
	if not Folder then
		error("Miniplayer: floating mode needs WindUI.ScreenGui, pass Config.Parent instead")
	end

	--------------------------------------------------------------- shell

	local Shell = New("Frame", {
		Name = "Miniplayer",
		Size = UDim2.fromOffset(W, H),
		AnchorPoint = Vector2.new(Config.AnchorX or 0, 0),
		Position = UDim2.new(Config.AnchorX or 0, Config.X or 18, 0, self.Floating and (Config.Top or 0) or 0),
		BackgroundColor3 = Palette.Shell,
		BackgroundTransparency = 0,
		ClipsDescendants = true,
		Parent = Folder,
	})
	Corner(Shell, Radius)

	local Rim = New("Frame", {
		Name = "Rim",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 12,
		Parent = Shell,
	})
	Corner(Rim, Radius)
	New("UIStroke", {
		Parent = Rim,
		Color = Color3.new(1, 1, 1),
		Thickness = 1,
		Transparency = 0.88,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})

	pcall(function()
		New("UIShadow", {
			Color = Color3.new(0, 0, 0),
			BlurRadius = UDim.new(0, 16),
			Offset = UDim2.fromOffset(0, 6),
			Transparency = 0.55,
			Parent = Shell,
		})
	end)

	local ShellScale = New("UIScale", { Scale = 1, Parent = Shell })
	self.Shell = Shell
	self.ShellScale = ShellScale

	--------------------------------------------------------------- artwork

	local Cover = New("ImageLabel", {
		Name = "Cover",
		Size = UDim2.fromOffset(CoverSize, CoverSize),
		Position = UDim2.fromOffset(CoverAt.X, CoverAt.Y),
		BackgroundColor3 = Palette.Tile,
		BackgroundTransparency = 0,
		Image = "",
		ScaleType = Enum.ScaleType.Crop,
		ZIndex = 5,
		Parent = Shell,
	})
	Corner(Cover, CoverRadius)

	local CoverGlyph = Glyph("lucide:music", 22, Palette.Muted)
	CoverGlyph.Name = "Placeholder"
	CoverGlyph.AnchorPoint = Vector2.new(0.5, 0.5)
	CoverGlyph.Position = UDim2.fromScale(0.5, 0.5)
	CoverGlyph.ZIndex = 6
	CoverGlyph.Parent = Cover

	self.Cover = Cover
	self.CoverGlyph = CoverGlyph

	--------------------------------------------------------------- titles

	local Title = Text({
		Name = "Title",
		Size = UDim2.fromOffset(TextW, 18),
		Position = UDim2.fromOffset(TextX, 22),
		Text = "Nothing playing",
		TextSize = 14,
		FontFace = Font.new(Creator.Font, Enum.FontWeight.Bold),
		ZIndex = 8,
		Parent = Shell,
	})
	self.TitleLabel = Title

	local Artist = Text({
		Name = "Artist",
		Size = UDim2.fromOffset(TextW, 14),
		Position = UDim2.fromOffset(TextX, 42),
		Text = "Pick a song",
		TextSize = 12,
		TextColor3 = Palette.Muted,
		ZIndex = 8,
		Parent = Shell,
	})
	self.ArtistLabel = Artist

	--------------------------------------------------------------- bars

	-- Five bars, right aligned, silent when the track is paused. This is the
	-- only thing on the strip that moves, so the widget reads as playing from
	-- across the screen without a single colour.
	local Bars = {}
	for Index = 1, 5 do
		local Bar = New("Frame", {
			Name = "Bar",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(BarsX - (5 - Index) * (BarW + BarGap), BarsY),
			Size = UDim2.fromOffset(BarW, 3),
			BackgroundColor3 = Palette.Text,
			BorderSizePixel = 0,
			ZIndex = 8,
			Parent = Shell,
		})
		Corner(Bar, 1.5)
		Bars[Index] = { Frame = Bar, Current = 0.05, Goal = 0.05 }
	end
	self.Bars = Bars

	--------------------------------------------------------------- transport

	local function Control(Name, CenterX, Icon, GlyphSize, OnPress, Color)
		local Hit = Button({
			Name = Name,
			Size = UDim2.fromOffset(GlyphSize + 12, GlyphSize + 16),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(CenterX, ControlsY),
			ZIndex = 10,
			Parent = Shell,
		})

		local Image = Glyph(Icon, GlyphSize, Color or Palette.Text)
		Image.AnchorPoint = Vector2.new(0.5, 0.5)
		Image.Position = UDim2.fromScale(0.5, 0.5)
		Image.ZIndex = 11
		Image.Parent = Hit

		Hit.MouseButton1Click:Connect(OnPress)
		Hit.MouseEnter:Connect(function()
			Tween(Image, 0.14, { ImageTransparency = 0.35 }, Enum.EasingStyle.Quad, EaseOut):Play()
		end)
		Hit.MouseLeave:Connect(function()
			Tween(Image, 0.16, { ImageTransparency = 0 }, Enum.EasingStyle.Quad, EaseOut):Play()
		end)

		return Hit, Image
	end

	local Previous, PreviousIcon = Control("Previous", PrevX, "sfsymbols:backwardFill", 18, function()
		self:Previous()
	end)
	local Play, PlayIcon = Control("Play", PlayX, "sfsymbols:playFill", 26, function()
		self:TogglePlay()
	end)
	local NextButton, NextIcon = Control("Next", NextX, "sfsymbols:forwardFill", 18, function()
		self:Next()
	end)

	self.PreviousButton, self.PreviousIcon = Previous, PreviousIcon
	self.PlayButton, self.PlayIcon = Play, PlayIcon
	self.NextButton, self.NextIcon = NextButton, NextIcon

	--------------------------------------------------------------- progress

	local Track = New("Frame", {
		Name = "Track",
		Size = UDim2.fromOffset(TrackW, TrackH),
		Position = UDim2.fromOffset(TrackX, TrackY),
		BackgroundColor3 = Palette.Text,
		BackgroundTransparency = 0.84,
		BorderSizePixel = 0,
		ZIndex = 8,
		Parent = Shell,
	})
	Corner(Track, TrackH / 2)

	local Fill = New("Frame", {
		Name = "Fill",
		Size = UDim2.new(0, 0, 1, 0),
		BackgroundColor3 = Palette.Text,
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
		ZIndex = 9,
		Parent = Track,
	})
	Corner(Fill, TrackH / 2)

	self.Track = Track
	self.Fill = Fill

	local Scrub = Button({
		Name = "Scrub",
		Size = UDim2.new(1, 20, 0, 22),
		Position = UDim2.fromOffset(-10, -10),
		ZIndex = 11,
		Parent = Track,
	})

	local function SeekAt(Input)
		local Width = Track.AbsoluteSize.X
		if Width <= 0 then
			return
		end
		local Ratio = math.clamp((Input.Position.X - Track.AbsolutePosition.X) / Width, 0, 1)
		local Duration = self.MusicState and self.MusicState.Duration or 0
		self.Fill.Size = UDim2.new(Ratio, 0, 1, 0)
		if Duration > 0 then
			self:Seek(Ratio * Duration)
		end
	end

	Scrub.InputBegan:Connect(function(Input)
		if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
			self.Seeking = true
			SeekAt(Input)
		end
	end)
	Scrub.InputChanged:Connect(function(Input)
		if self.Seeking and (Input.UserInputType == Enum.UserInputType.MouseMovement or Input.UserInputType == Enum.UserInputType.Touch) then
			SeekAt(Input)
		end
	end)
	Scrub.InputEnded:Connect(function(Input)
		if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
			self.Seeking = false
		end
	end)

	--------------------------------------------------------------- drag

	-- The library's own drag, on a hit layer under the content, so a press on
	-- the artwork or the type moves the strip and a press on a glyph does not.
	local DragArea = Button({
		Name = "Drag",
		Size = UDim2.fromScale(1, 1),
		ZIndex = 3,
		Parent = Shell,
	})
	self.DragArea = DragArea
	Creator.Drag(Shell, { DragArea })

	--------------------------------------------------------------- wiring

	Surface.Bind(self, Config)
	self:_WireBars()

	self:Fit()
	self:SetSource(Config.Source or 1)

	return self
end

---------------------------------------------------------------------------
-- bars
---------------------------------------------------------------------------

function Miniplayer:_WireBars()
	local Acc = 0
	local Signal = RunService.Heartbeat:Connect(function(Delta)
		if not self.Alive then
			return
		end

		Acc += Delta
		local Retarget = Acc >= 0.1
		if Retarget then
			Acc = 0
		end

		local Playing = self.MusicState and self.MusicState.Playing == true
		local Step = math.min(Delta * 16, 1)
		for _, Bar in ipairs(self.Bars) do
			if Retarget then
				Bar.Goal = Playing and (0.2 + 0.8 * math.random()) or 0.04
			end
			Bar.Current += (Bar.Goal - Bar.Current) * Step
			Bar.Frame.Size = UDim2.fromOffset(BarW, 3 + 13 * Bar.Current)
		end
	end)

	table.insert(self.Signals, Signal)
end

---------------------------------------------------------------------------
-- sources
---------------------------------------------------------------------------

-- Kept so callers written against the older card keep working; the strip has
-- no source list, the island owns that.
function Miniplayer:RenderSources() end

function Miniplayer:ToggleSources()
	return false
end

---------------------------------------------------------------------------
-- state
---------------------------------------------------------------------------

function Miniplayer:RenderState(State)
	local Raw = State.Title ~= "" and State.Title or State.Hint or ""
	local Song, Artist = SplitName(Raw)
	local Playing = State.Playing == true
	local HasTrack = Raw ~= ""

	if HasTrack then
		self.TitleLabel.Text = Song
		local Subtitle = State.Artist ~= "" and State.Artist or Artist
		self.ArtistLabel.Text = Subtitle ~= "" and Subtitle or (Playing and "Playing" or "Paused")
	else
		self.TitleLabel.Text = "Nothing playing"
		self.ArtistLabel.Text = "Pick a song"
	end

	local Cover = State.Cover or ""
	if Cover ~= self.CoverId then
		self.CoverId = Cover
		if Cover ~= "" then
			self.Cover.Image = Cover
			self.Cover.BackgroundTransparency = 1
			self.CoverGlyph.Visible = false
		else
			self.Cover.Image = ""
			self.Cover.BackgroundTransparency = 0
			self.CoverGlyph.Visible = true
		end
	end

	if State.Duration and State.Duration > 0 then
		if not self.Seeking then
			local Ratio = math.clamp((State.Position or 0) / State.Duration, 0, 1)
			self.Fill.Size = UDim2.new(Ratio, 0, 1, 0)
		end
	else
		self.Fill.Size = UDim2.new(0, 0, 1, 0)
	end

	local Icon, Rect = Creator.Icon(Playing and "sfsymbols:pauseFill" or "sfsymbols:playFill")
	self.PlayIcon.Image = Icon
	self.PlayIcon.ImageRectOffset, self.PlayIcon.ImageRectSize = Rect.ImageRectPosition, Rect.ImageRectSize

	self.PreviousButton.Visible = HasTrack
	self.NextButton.Visible = HasTrack
end

function Miniplayer:RenderError(Message)
	if self.ArtistLabel then
		self.ArtistLabel.Text = Message
	end
end

---------------------------------------------------------------------------
-- sizing
---------------------------------------------------------------------------

function Miniplayer:Fit()
	if not self.Alive then
		return
	end

	local Available = self.Parent and math.max(self.Parent.AbsoluteSize.X - 8, 120) or math.huge
	local Scale = math.clamp(Available / W, 0.3, 1)
	if self.Config.Scale then
		Scale = Scale * self.Config.Scale
	end

	self.FitScale = Scale
	self.ShellScale.Scale = Scale
end

---------------------------------------------------------------------------
-- public actions
---------------------------------------------------------------------------

function Miniplayer:SelectSource(Index, Silent)
	Surface.SelectSource(self, Index, Silent)
end

function Miniplayer:SetSource(Source)
	Surface.SetSource(self, Source)
end

function Miniplayer:TogglePlay()
	local Provider = self.Provider
	if not Provider then
		return
	end
	if self.MusicState and self.MusicState.Playing then
		Provider:Pause(function() end)
	else
		Provider:Play(function() end)
	end
end

function Miniplayer:Play()
	if self.Provider then
		self.Provider:Play(function() end)
	end
end

function Miniplayer:Pause()
	if self.Provider then
		self.Provider:Pause(function() end)
	end
end

function Miniplayer:Next()
	if self.Provider then
		self.Provider:Next(function() end)
	end
end

function Miniplayer:Previous()
	if self.Provider then
		self.Provider:Previous(function() end)
	end
end

function Miniplayer:Seek(Seconds)
	if self.Provider and self.Provider.Seek then
		self.Provider:Seek(Seconds, function() end)
	end
end

function Miniplayer:SetVolume(Percent)
	self.Volume = math.clamp(Percent or 60, 0, 100)
	if self.Provider and self.Provider.SetVolume then
		self.Provider:SetVolume(self.Volume, function() end)
	end
end

-- No volume control on a strip this size; the method stays for callers.
function Miniplayer:ToggleMute()
	self.Muted = not self.Muted
	if self.Provider and self.Provider.SetVolume then
		self.Provider:SetVolume(self.Muted and 0 or self.Volume, function() end)
	end
end

function Miniplayer:GetState()
	return self.MusicState
end

function Miniplayer:Show()
	self.Shell.Visible = true
end

function Miniplayer:Hide()
	self.Shell.Visible = false
end

function Miniplayer:Destroy()
	if not self.Alive then
		return
	end
	self.Alive = false

	for _, Signal in ipairs(self.Signals or {}) do
		pcall(function()
			Signal:Disconnect()
		end)
	end
	self.Signals = {}

	Surface.Release(self)

	if self.Shell then
		self.Shell:Destroy()
		self.Shell = nil
	end
end

return Miniplayer
