-- Miniplayer - the compact now-playing card, floating and draggable.
--
--   local Player = WindUI:Miniplayer({
--       Providers = { "files", "spotify", "demo" },
--       Folder = "Ender Hub/songs",
--   })
--
--   -- docked inside a window instead of floating over the game:
--   local Player = WindUI:Miniplayer({ Parent = Tab.Frame })
--
-- Ported from the Novoline "Now playing" card: 440 x 177, 86 px artwork at
-- (18, 16), the title and artist beside it, the level glyph top right, the
-- scrubber with both times, then bare previous / play / next glyphs with the
-- volume control on the right. Same provider set as the dynamic island, so a
-- track started here shows and stops on both.

local cloneref = (cloneref or clonereference or function(instance)
	return instance
end)

local UserInputService = cloneref(game:GetService("UserInputService"))

local Creator = require("../../modules/Creator")
local Surface = require("../../modules/MusicSurface")

local New = Creator.New
local Tween = Creator.Tween

local Miniplayer = {}
Miniplayer.__index = Miniplayer

---------------------------------------------------------------------------
-- metrics, in card pixels
---------------------------------------------------------------------------

local W, H = 440, 177
local Radius = 24

local CoverSize = 86
local CoverAt = Vector2.new(18, 16)
local CoverRadius = 16

-- The scrubber sits clear of the 86 px artwork (which ends at y = 102).
local ScrubY = 118
local TrackX, TrackW, TrackH = 62, W - 124, 4
local ControlsY = 148

local Palette = {
	Shell = Color3.fromRGB(0, 0, 0),
	Text = Color3.fromRGB(255, 255, 255),
	Muted = Color3.fromRGB(150, 152, 160),
	Tile = Color3.fromRGB(40, 40, 44),
	Accent = Color3.fromRGB(30, 215, 96),
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

	New("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.4, 0.05),
			NumberSequenceKeypoint.new(0.66, 0.16),
			NumberSequenceKeypoint.new(0.86, 0.48),
			NumberSequenceKeypoint.new(1, 0.52),
		}),
		Parent = Shell,
	})

	pcall(function()
		New("UIShadow", {
			Color = Color3.new(0, 0, 0),
			BlurRadius = UDim.new(0, 18),
			Offset = UDim2.fromOffset(0, 7),
			Transparency = 0.58,
			Parent = Shell,
		})
	end)

	local ShellScale = New("UIScale", { Scale = 1, Parent = Shell })
	self.Shell = Shell
	self.ShellScale = ShellScale

	--------------------------------------------------------------- backdrop

	-- The card picks up the artwork: the cover is stretched behind a dark veil
	-- so the widget carries the album's colour instead of flat black.
	local Backdrop = New("ImageLabel", {
		Name = "Backdrop",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Image = "",
		ImageTransparency = 1,
		ScaleType = Enum.ScaleType.Crop,
		ZIndex = 1,
		Parent = Shell,
	})
	Corner(Backdrop, Radius)

	local Veil = New("Frame", {
		Name = "Veil",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.52,
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = Shell,
	})
	Corner(Veil, Radius)
	New("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.05),
			NumberSequenceKeypoint.new(0.55, 0.22),
			NumberSequenceKeypoint.new(1, 0.5),
		}),
		Parent = Veil,
	})

	self.Backdrop = Backdrop

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

	local CoverGlyph = Glyph("lucide:music", 28, Palette.Muted)
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
		Size = UDim2.fromOffset(228, 20),
		Position = UDim2.fromOffset(116, 22),
		Text = "Nothing playing",
		TextSize = 17,
		FontFace = Font.new(Creator.Font, Enum.FontWeight.Bold),
		ZIndex = 8,
		Parent = Shell,
	})
	self.TitleLabel = Title

	local Artist = Text({
		Name = "Artist",
		Size = UDim2.fromOffset(228, 16),
		Position = UDim2.fromOffset(116, 46),
		Text = "Pick a song from your library",
		TextSize = 14,
		TextColor3 = Palette.Muted,
		ZIndex = 8,
		Parent = Shell,
	})
	self.ArtistLabel = Artist

	local Level = Glyph("lucide:audio-lines", 20, Palette.Muted)
	Level.Name = "Level"
	Level.AnchorPoint = Vector2.new(1, 0.5)
	Level.Position = UDim2.new(1, -20, 0, 46)
	Level.ZIndex = 8
	Level.Parent = Shell

	--------------------------------------------------------------- scrubber

	local Elapsed = Text({
		Name = "Elapsed",
		Size = UDim2.fromOffset(44, 14),
		Position = UDim2.fromOffset(18, ScrubY - 7),
		Text = "0:00",
		TextSize = 12,
		TextColor3 = Palette.Muted,
		ZIndex = 8,
		Parent = Shell,
	})
	self.Elapsed = Elapsed

	local Remaining = Text({
		Name = "Remaining",
		Size = UDim2.fromOffset(52, 14),
		Position = UDim2.fromOffset(W - 70, ScrubY - 7),
		Text = "-0:00",
		TextSize = 12,
		TextColor3 = Palette.Muted,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 8,
		Parent = Shell,
	})
	self.Remaining = Remaining

	local Track = New("Frame", {
		Name = "Track",
		Size = UDim2.fromOffset(TrackW, TrackH),
		Position = UDim2.fromOffset(TrackX, ScrubY - TrackH / 2),
		BackgroundColor3 = Palette.Text,
		BackgroundTransparency = 0.82,
		BorderSizePixel = 0,
		ZIndex = 8,
		Parent = Shell,
	})
	Corner(Track, TrackH / 2)
	self.Track = Track

	local Fill = New("Frame", {
		Name = "Fill",
		Size = UDim2.new(0, 0, 1, 0),
		BackgroundColor3 = Palette.Text,
		BackgroundTransparency = 0.05,
		BorderSizePixel = 0,
		ZIndex = 9,
		Parent = Track,
	})
	Corner(Fill, TrackH / 2)
	self.Fill = Fill

	local Scrub = Button({
		Name = "Scrub",
		Size = UDim2.new(1, 16, 0, 24),
		Position = UDim2.fromOffset(-8, -10),
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

	--------------------------------------------------------------- transport

	local function Control(Name, CenterX, Icon, GlyphSize, OnPress, Color)
		local Hit = Button({
			Name = Name,
			Size = UDim2.fromOffset(GlyphSize + 24, GlyphSize + 20),
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

	local Previous, PreviousIcon = Control("Previous", 145, "sfsymbols:backwardFill", 22, function()
		self:Previous()
	end)
	local Play, PlayIcon = Control("Play", 220, "sfsymbols:playFill", 30, function()
		self:TogglePlay()
	end)
	local NextButton, NextIcon = Control("Next", 295, "sfsymbols:forwardFill", 22, function()
		self:Next()
	end)
	local Volume, VolumeIcon = Control("Volume", 396, "sfsymbols:speakerWave2Fill", 22, function()
		self:ToggleMute()
	end, Palette.Muted)

	self.PreviousButton, self.PreviousIcon = Previous, PreviousIcon
	self.PlayButton, self.PlayIcon = Play, PlayIcon
	self.NextButton, self.NextIcon = NextButton, NextIcon
	self.VolumeButton, self.VolumeIcon = Volume, VolumeIcon

	--------------------------------------------------------------- wiring

	Surface.Bind(self, Config)
	self:_WireDrag()

	self:Fit()
	self:SetSource(Config.Source or 1)

	return self
end

---------------------------------------------------------------------------
-- sources
---------------------------------------------------------------------------

-- Kept so callers written against the older card keep working; the Novoline
-- mini player has no source list, the island owns that.
function Miniplayer:RenderSources() end

function Miniplayer:ToggleSources()
	return false
end

---------------------------------------------------------------------------
-- drag
---------------------------------------------------------------------------

function Miniplayer:_WireDrag()
	local Shell = self.Shell
	local Pressed, Dragging = false, false
	local DragStart, StartPosition = nil, nil

	local Hit = Button({
		Name = "Drag",
		Size = UDim2.fromScale(1, 1),
		ZIndex = 3,
		Parent = Shell,
	})
	self.Hit = Hit

	Hit.MouseButton1Down:Connect(function(Input)
		Pressed = true
		DragStart = Input.Position
		StartPosition = Shell.Position
	end)

	local MoveSignal = UserInputService.InputChanged:Connect(function(Input)
		if not Pressed or not self.Floating then
			return
		end
		if Input.UserInputType ~= Enum.UserInputType.MouseMovement and Input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end

		local Delta = Input.Position - DragStart
		if math.abs(Delta.X) > 3 or math.abs(Delta.Y) > 3 then
			Dragging = true
			Shell.Position = UDim2.new(
				StartPosition.X.Scale,
				StartPosition.X.Offset + Delta.X,
				StartPosition.Y.Scale,
				StartPosition.Y.Offset + Delta.Y
			)
		end
	end)

	local EndSignal = UserInputService.InputEnded:Connect(function(Input)
		if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
			Pressed = false
			Dragging = false
		end
	end)

	table.insert(self.Signals, MoveSignal)
	table.insert(self.Signals, EndSignal)
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
		self.ArtistLabel.Text = "Pick a song from your library"
	end

	local Cover = State.Cover or ""
	if Cover ~= self.CoverId then
		self.CoverId = Cover
		if Cover ~= "" then
			self.Cover.Image = Cover
			self.Cover.BackgroundTransparency = 1
			self.CoverGlyph.Visible = false
			self.Backdrop.Image = Cover
			self.Backdrop.ImageTransparency = 0.25
		else
			self.Cover.Image = ""
			self.Cover.BackgroundTransparency = 0
			self.CoverGlyph.Visible = true
			self.Backdrop.Image = ""
			self.Backdrop.ImageTransparency = 1
		end
	end

	if State.Duration and State.Duration > 0 then
		if not self.Seeking then
			local Ratio = math.clamp((State.Position or 0) / State.Duration, 0, 1)
			self.Fill.Size = UDim2.new(Ratio, 0, 1, 0)
			self.Elapsed.Text = Surface.FormatTime(State.Position or 0)
			self.Remaining.Text = "-" .. Surface.FormatTime(math.max(State.Duration - (State.Position or 0), 0))
		end
	else
		self.Fill.Size = UDim2.new(0, 0, 1, 0)
		self.Elapsed.Text = "0:00"
		self.Remaining.Text = "-0:00"
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

function Miniplayer:ToggleMute()
	self.Muted = not self.Muted
	if self.Provider and self.Provider.SetVolume then
		self.Provider:SetVolume(self.Muted and 0 or self.Volume, function() end)
	end
	local Icon, Rect = Creator.Icon(self.Muted and "sfsymbols:speakerSlashFill" or "sfsymbols:speakerWave2Fill")
	self.VolumeIcon.Image = Icon
	self.VolumeIcon.ImageRectOffset, self.VolumeIcon.ImageRectSize = Rect.ImageRectPosition, Rect.ImageRectSize
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
