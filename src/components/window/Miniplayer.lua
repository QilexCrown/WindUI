-- Miniplayer - the dynamic island and the music player it springs into.
--
--   local Player = WindUI:Miniplayer({
--       Providers = { "files", "spotify", "demo" },
--       Folder = "Ender Hub/songs",
--   })
--
--   -- docked inside a window instead of floating over the game:
--   local Player = WindUI:Miniplayer({ Parent = Tab.Frame })
--
-- Geometry, palette and type are lifted from the island running in the client:
-- 212 x 40 collapsed, 752 x 204 expanded, radius 20, #000000 shell, #F2F2F4
-- hairline, Gotham SSm. Collapsed it is artwork on the left and a six-bar wave
-- on the right. Tapped, the artwork grows into the card and the player fades in
-- behind it: title, transport, scrubber, chips and a source column. Everything
-- service-specific lives in modules/MusicProviders.

local cloneref = (cloneref or clonereference or function(instance)
	return instance
end)

local RunService = cloneref(game:GetService("RunService"))
local UserInputService = cloneref(game:GetService("UserInputService"))
local GuiService = cloneref(game:GetService("GuiService"))

local Creator = require("../../modules/Creator")
local Providers = require("../../modules/MusicProviders")

local New = Creator.New
local Tween = Creator.Tween

local Miniplayer = {}
Miniplayer.__index = Miniplayer

---------------------------------------------------------------------------
-- island metrics, straight off the running client
---------------------------------------------------------------------------

local Narrow = 212
local Short = 40
local Wide = 752
local Tall = 204
local Radius = 20

local Palette = {
	Shell = Color3.fromRGB(0, 0, 0),
	Hairline = Color3.fromRGB(242, 242, 244),
	Text = Color3.fromRGB(255, 255, 255),
	Muted = Color3.fromRGB(150, 150, 156),
	Bar = Color3.fromRGB(226, 226, 232),
	Track = Color3.fromRGB(242, 242, 244),
	Teal = Color3.fromRGB(13, 40, 51),
	TealIcon = Color3.fromRGB(64, 186, 255),
	Purple = Color3.fromRGB(38, 28, 62),
	PurpleIcon = Color3.fromRGB(168, 120, 255),
	Red = Color3.fromRGB(62, 20, 24),
	RedIcon = Color3.fromRGB(255, 96, 96),
	Green = Color3.fromRGB(14, 46, 40),
	GreenIcon = Color3.fromRGB(56, 224, 186),
}

local Ease = Enum.EasingStyle.Quint
local EaseOut = Enum.EasingDirection.Out
local EaseIn = Enum.EasingDirection.In

---------------------------------------------------------------------------
-- primitives
---------------------------------------------------------------------------

local function Corner(Object, Radius_)
	return New("UICorner", {
		CornerRadius = UDim.new(0, Radius_),
		Parent = Object,
	})
end

local function Stroke(Object, Color, Transparency, Thickness)
	return New("UIStroke", {
		Color = Color or Palette.Hairline,
		Transparency = Transparency == nil and 0.85 or Transparency,
		Thickness = Thickness or 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = Object,
	})
end

local function Glyph(Icon, Size, Color, Transparency)
	local Data = Creator.Icon(Icon)
	local Rect = Data[2] or {}

	return New("ImageLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(Size, Size),
		Image = Data[1],
		ImageRectSize = Rect.ImageRectSize,
		ImageRectOffset = Rect.ImageRectPosition,
		ImageColor3 = Color or Palette.Text,
		ImageTransparency = Transparency or 0,
		ScaleType = Enum.ScaleType.Fit,
	})
end

local function Text(Properties)
	Properties.FontFace = Properties.FontFace or Font.new(Creator.Font, Enum.FontWeight.Medium)
	Properties.BackgroundTransparency = 1
	Properties.TextXAlignment = Properties.TextXAlignment or Enum.TextXAlignment.Left
	Properties.TextYAlignment = Properties.TextYAlignment or Enum.TextYAlignment.Center
	Properties.TextColor3 = Properties.TextColor3 or Palette.Text
	return New("TextLabel", Properties)
end

local function Button(Properties, Children)
	Properties.BackgroundTransparency = Properties.BackgroundTransparency or 1
	Properties.Text = ""
	Properties.AutoButtonColor = false
	return New("TextButton", Properties, Children)
end

-- One press target with the three states the island uses: hover, held, done.
local function Pressable(Object, OnPress, OnHover)
	local Held = false
	local Hovered = false

	Object.MouseEnter:Connect(function()
		Hovered = true
		if OnHover then
			OnHover(true)
		end
	end)

	Object.MouseLeave:Connect(function()
		Hovered = false
		if OnHover then
			OnHover(false)
		end
	end)

	Object.MouseButton1Down:Connect(function()
		Held = true
	end)

	local function Release()
		if not Held then
			return
		end
		Held = false
		if Hovered and OnPress then
			OnPress()
		end
	end

	Object.MouseButton1Up:Connect(Release)
	Object.MouseLeave:Connect(function()
		Held = false
	end)

	return Object
end

local function FitText(Object)
	Object.TextTruncate = Enum.TextTruncate.AtEnd
	return Object
end

-- Idle heights of the six wave bars, measured off the collapsed island.
local BarHeights = { 14, 11, 13, 16, 14, 13 }

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
		Expanded = Config.Expanded == true,
		HoverScale = 1,
		FitScale = 1,
		State = nil,
		Provider = nil,
		Sources = {},
		SourceIndex = 0,
		Bars = {},
		Signals = {},
		CoverId = nil,
		Liked = false,
		Muted = false,
		Volume = 60,
		Tab = "player",
	}, Miniplayer)

	self.Floating = self.Parent == nil

	local Folder = self.Floating and self.WindUI and self.WindUI.ScreenGui or nil
	if self.Floating and not Folder then
		error("Miniplayer: floating mode needs WindUI.ScreenGui, pass Config.Parent instead")
	end

	------------------------------------------------------------- shell

	local Shell = New("Frame", {
		Name = "Miniplayer",
		Size = UDim2.fromOffset(Narrow, Short),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, self.Floating and (Config.Top or 12) or 0),
		BackgroundColor3 = Palette.Shell,
		BackgroundTransparency = 0,
		ClipsDescendants = true,
		Parent = Folder,
	})

	Corner(Shell, Radius)

	self.Shell = Shell
	self.Stroke = Stroke(Shell, Palette.Hairline, 0.86, 1)

	local ShellScale = New("UIScale", { Scale = 1, Parent = Shell })
	self.ShellScale = ShellScale

	if self.Parent then
		Shell.Parent = self.Parent
	end

	--------------------------------------------------------- collapsed

	local Face = New("Frame", {
		Name = "Face",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 4,
		Parent = Shell,
	})

	local Cover = New("ImageLabel", {
		Name = "Cover",
		Size = UDim2.fromOffset(28, 28),
		Position = UDim2.fromOffset(6, 6),
		BackgroundColor3 = Color3.fromRGB(24, 24, 28),
		BackgroundTransparency = 0,
		Image = "",
		ScaleType = Enum.ScaleType.Crop,
		ZIndex = 5,
		Parent = Shell,
	})

	Corner(Cover, 9)
	Stroke(Cover, Palette.Hairline, 0.9, 1)

	local CoverGlyph = Glyph("sfsymbols:musicNote", 13, Palette.Muted, 0)
	CoverGlyph.Name = "Placeholder"
	CoverGlyph.Size = UDim2.fromScale(0.46, 0.46)
	CoverGlyph.Position = UDim2.fromScale(0.5, 0.5)
	CoverGlyph.AnchorPoint = Vector2.new(0.5, 0.5)
	CoverGlyph.ZIndex = 6
	CoverGlyph.Parent = Cover
	self.CoverGlyph = CoverGlyph
	self.Cover = Cover

	local Wave = New("Frame", {
		Name = "Wave",
		Size = UDim2.fromOffset(24, 18),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0, 20),
		BackgroundTransparency = 1,
		ZIndex = 5,
		Parent = Shell,
	})
	self.Wave = Wave

	for Index, Height in ipairs(BarHeights) do
		local Bar = New("Frame", {
			Name = "Bar" .. Index,
			Size = UDim2.fromOffset(2, Height),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(2 + (Index - 1) * 4, 9),
			BackgroundColor3 = Palette.Bar,
			BackgroundTransparency = 0,
			BorderSizePixel = 0,
			ZIndex = 5,
			Parent = Wave,
		})
		Corner(Bar, 1)
		self.Bars[Index] = Bar
	end

	local Hit = Button({
		Name = "Hit",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = Shell,
	})
	self.Hit = Hit

	------------------------------------------------------------ cards

	local Cards = New("CanvasGroup", {
		Name = "Cards",
		Size = UDim2.fromOffset(Wide, Tall),
		Position = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 1,
		GroupTransparency = self.Expanded and 0 or 1,
		Visible = self.Expanded,
		ZIndex = 6,
		Parent = Shell,
	})
	self.Cards = Cards

	self:_BuildTop(Cards)
	self:_BuildNow(Cards)
	self:_BuildChips(Cards)
	self:_BuildSeek(Cards)
	self:_BuildSide(Cards)

	------------------------------------------------------------- glass

	-- The wash is the looking glass: a soft white gradient over the black shell
	-- plus a second hairline just inside the edge. Both fade with the card.
	local Sheen = New("Frame", {
		Name = "Sheen",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 0,
		ZIndex = 20,
		Parent = Shell,
	}, {
		New("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.94),
				NumberSequenceKeypoint.new(0.55, 0.965),
				NumberSequenceKeypoint.new(1, 0.99),
			}),
		}),
	})
	Corner(Sheen, Radius)
	self.Sheen = Sheen

	local Gloss = New("Frame", {
		Name = "Gloss",
		Size = UDim2.new(1, 0, 0, 96),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 1,
		ZIndex = 21,
		Parent = Shell,
	})
	Corner(Gloss, Radius)
	self.Gloss = Gloss

	------------------------------------------------------------- wiring

	self:_WireShell()
	self:_WireLoop()
	self:_BuildSources()

	if self.Expanded then
		self:_ApplyExpand(true)
	else
		self:_ApplyCollapse(true)
	end

	self:Fit()
	self:SetSource(Config.Source or 1)

	return self
end

---------------------------------------------------------------------------
-- card: top bar
---------------------------------------------------------------------------

function Miniplayer:_BuildTop(Cards)
	local Top = New("Frame", {
		Name = "Top",
		Size = UDim2.fromOffset(Wide, 36),
		Position = UDim2.fromOffset(0, 12),
		BackgroundTransparency = 1,
		ZIndex = 7,
		Parent = Cards,
	})

	local Tabs = New("Frame", {
		Name = "Tabs",
		Size = UDim2.fromOffset(64, 22),
		Position = UDim2.fromOffset(20, 9),
		BackgroundColor3 = Palette.Hairline,
		BackgroundTransparency = 0.93,
		ClipsDescendants = true,
		ZIndex = 8,
		Parent = Top,
	})
	Corner(Tabs, 11)
	Stroke(Tabs, Palette.Hairline, 0.9, 1)

	local Active = New("Frame", {
		Name = "Active",
		Size = UDim2.fromOffset(30, 16),
		Position = UDim2.fromOffset(3, 3),
		BackgroundColor3 = Palette.Hairline,
		BackgroundTransparency = 0.9,
		ZIndex = 9,
		Parent = Tabs,
	})
	Corner(Active, 8)
	self.TabPill = Active

	local PlayerTab = Button({
		Name = "player",
		Size = UDim2.fromOffset(30, 16),
		Position = UDim2.fromOffset(3, 3),
		ZIndex = 10,
		Parent = Tabs,
	})

	local PlayerGlyph = Glyph("sfsymbols:musicNote", 11, Palette.Text, 0.05)
	PlayerGlyph.AnchorPoint = Vector2.new(0.5, 0.5)
	PlayerGlyph.Position = UDim2.fromScale(0.5, 0.5)
	PlayerGlyph.ZIndex = 11
	PlayerGlyph.Parent = PlayerTab

	local LibraryTab = Button({
		Name = "library",
		Size = UDim2.fromOffset(30, 16),
		Position = UDim2.fromOffset(33, 3),
		ZIndex = 10,
		Parent = Tabs,
	})

	local LibraryGlyph = Glyph("sfsymbols:listBullet", 11, Palette.Text, 0.5)
	LibraryGlyph.AnchorPoint = Vector2.new(0.5, 0.5)
	LibraryGlyph.Position = UDim2.fromScale(0.5, 0.5)
	LibraryGlyph.ZIndex = 11
	LibraryGlyph.Parent = LibraryTab

	Pressable(PlayerTab, function()
		self:SetTab("player")
	end)
	Pressable(LibraryTab, function()
		self:SetTab("library")
	end)

	self.TabGlyphs = { player = PlayerGlyph, library = LibraryGlyph }

	local Caption = Text({
		Name = "Caption",
		Size = UDim2.fromOffset(160, 22),
		Position = UDim2.fromOffset(96, 9),
		Text = "Library",
		TextSize = 11,
		TextColor3 = Palette.Muted,
		ZIndex = 8,
		Parent = Top,
	})
	self.Caption = Caption

	local Status = New("Frame", {
		Name = "Status",
		Size = UDim2.fromOffset(220, 22),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -20, 0, 9),
		BackgroundTransparency = 1,
		ZIndex = 8,
		Parent = Top,
	}, {
		New("UIListLayout", {
			Padding = UDim.new(0, 5),
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	local Pulse = Glyph("sfsymbols:dotRadiowavesLeftAndRight", 11, Palette.Muted, 0)
	Pulse.LayoutOrder = 1
	Pulse.Parent = Status

	local Latency = Text({
		Name = "Latency",
		Size = UDim2.fromOffset(0, 22),
		AutomaticSize = Enum.AutomaticSize.X,
		Text = "-- ms",
		TextSize = 11,
		TextColor3 = Palette.Muted,
		TextXAlignment = Enum.TextXAlignment.Center,
		LayoutOrder = 2,
		Parent = Status,
	})

	local Spacer = New("Frame", {
		Size = UDim2.fromOffset(4, 1),
		BackgroundTransparency = 1,
		LayoutOrder = 3,
		Parent = Status,
	})

	local Clock = Glyph("sfsymbols:clock", 11, Palette.Muted, 0)
	Clock.LayoutOrder = 4
	Clock.Parent = Status

	local Count = Text({
		Name = "Count",
		Size = UDim2.fromOffset(0, 22),
		AutomaticSize = Enum.AutomaticSize.X,
		Text = "0 tracks",
		TextSize = 11,
		TextColor3 = Palette.Muted,
		TextXAlignment = Enum.TextXAlignment.Center,
		LayoutOrder = 5,
		Parent = Status,
	})

	self.Latency = Latency
	self.Count = Count
end

---------------------------------------------------------------------------
-- card: now playing block
---------------------------------------------------------------------------

function Miniplayer:_BuildNow(Cards)
	local Now = New("Frame", {
		Name = "Now",
		Size = UDim2.fromOffset(288, 96),
		Position = UDim2.fromOffset(14, 48),
		BackgroundTransparency = 1,
		ZIndex = 7,
		Parent = Cards,
	})

	local Artist = Text({
		Name = "Artist",
		Size = UDim2.fromOffset(190, 14),
		Position = UDim2.fromOffset(84, 12),
		Text = "",
		TextSize = 11,
		TextColor3 = Palette.Muted,
		ZIndex = 8,
		Parent = Now,
	})
	FitText(Artist)

	local Title = Text({
		Name = "Title",
		Size = UDim2.fromOffset(190, 20),
		Position = UDim2.fromOffset(84, 30),
		Text = "Nothing playing",
		TextSize = 15,
		TextColor3 = Palette.Text,
		FontFace = Font.new(Creator.Font, Enum.FontWeight.Bold),
		ZIndex = 8,
		Parent = Now,
	})
	FitText(Title)

	local StateIcon = Glyph("sfsymbols:playFill", 11, Palette.Muted, 0)
	StateIcon.Name = "StateIcon"
	StateIcon.AnchorPoint = Vector2.new(0.5, 0.5)
	StateIcon.Position = UDim2.fromOffset(90, 68)
	StateIcon.ZIndex = 9
	StateIcon.Parent = Now

	local StateText = Text({
		Name = "State",
		Size = UDim2.fromOffset(170, 14),
		Position = UDim2.fromOffset(100, 61),
		Text = "Idle",
		TextSize = 11,
		TextColor3 = Palette.Muted,
		ZIndex = 8,
		Parent = Now,
	})
	FitText(StateText)

	self.ArtistLabel = Artist
	self.TitleLabel = Title
	self.StateIcon = StateIcon
	self.StateLabel = StateText
end

---------------------------------------------------------------------------
-- card: chips
---------------------------------------------------------------------------

function Miniplayer:_Chip(Parent, Position, Icon, Label, Tint, TintIcon, OnPress)
	local Holder = New("Frame", {
		Name = "Chip",
		Size = UDim2.fromOffset(80, 48),
		Position = UDim2.fromOffset(Position.X, Position.Y),
		BackgroundColor3 = Tint,
		BackgroundTransparency = 0.08,
		ZIndex = 8,
		Parent = Parent,
	})
	Corner(Holder, 14)
	Stroke(Holder, Palette.Text, 0.92, 1)

	local Lift = New("Frame", {
		Name = "Lift",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 1,
		ZIndex = 9,
		Parent = Holder,
	})
	Corner(Lift, 14)

	local IconGlyph = Glyph(Icon, 15, TintIcon, 0)
	IconGlyph.Position = UDim2.fromOffset(11, 9)
	IconGlyph.ZIndex = 10
	IconGlyph.Parent = Holder

	local Caption = Text({
		Name = "Label",
		Size = UDim2.fromOffset(58, 14),
		Position = UDim2.fromOffset(11, 27),
		Text = Label,
		TextSize = 11,
		TextColor3 = Palette.Text,
		FontFace = Font.new(Creator.Font, Enum.FontWeight.Bold),
		ZIndex = 10,
		Parent = Holder,
	})
	FitText(Caption)

	local HitArea = Button({
		Name = "Hit",
		Size = UDim2.fromScale(1, 1),
		ZIndex = 12,
		Parent = Holder,
	})

	local Scale = New("UIScale", { Scale = 1, Parent = Holder })

	local Pressed = false
	HitArea.MouseButton1Down:Connect(function()
		Pressed = true
		Tween(Scale, 0.12, { Scale = 0.95 }, Enum.EasingStyle.Quad, EaseOut):Play()
	end)
	HitArea.MouseButton1Up:Connect(function()
		Pressed = false
		Tween(Scale, 0.2, { Scale = 1 }, Enum.EasingStyle.Back, EaseOut):Play()
	end)
	HitArea.MouseLeave:Connect(function()
		if Pressed then
			Pressed = false
			Tween(Scale, 0.2, { Scale = 1 }, Enum.EasingStyle.Back, EaseOut):Play()
		end
	end)

	HitArea.MouseEnter:Connect(function()
		Tween(Lift, 0.18, { BackgroundTransparency = 0.9 }, Enum.EasingStyle.Quad, EaseOut):Play()
		Tween(Scale, 0.18, { Scale = 1.04 }, Enum.EasingStyle.Quad, EaseOut):Play()
	end)

	HitArea.MouseLeave:Connect(function()
		Tween(Lift, 0.22, { BackgroundTransparency = 1 }, Enum.EasingStyle.Quad, EaseOut):Play()
		Tween(Scale, 0.22, { Scale = 1 }, Enum.EasingStyle.Quad, EaseOut):Play()
	end)

	HitArea.MouseButton1Click:Connect(function()
		if OnPress then
			OnPress()
		end
	end)

	return Holder, Caption, IconGlyph
end

function Miniplayer:_BuildChips(Cards)
	local Grid = New("Frame", {
		Name = "Grid",
		Size = UDim2.fromOffset(176, 120),
		Position = UDim2.fromOffset(298, 36),
		BackgroundTransparency = 1,
		ZIndex = 7,
		Parent = Cards,
	})

	local _, ShuffleCaption, ShuffleIcon = self:_Chip(
		Grid,
		Vector2.new(0, 0),
		"sfsymbols:shuffle",
		"Shuffle",
		Palette.Teal,
		Palette.TealIcon,
		function()
			self:ToggleShuffle()
		end
	)

	local _, LibraryCaption, LibraryIcon = self:_Chip(
		Grid,
		Vector2.new(92, 0),
		"sfsymbols:musicNoteList",
		"Library",
		Palette.Purple,
		Palette.PurpleIcon,
		function()
			self:SetTab("library")
		end
	)

	local _, LikeCaption, LikeIcon = self:_Chip(
		Grid,
		Vector2.new(0, 60),
		"sfsymbols:heart",
		"Like",
		Palette.Red,
		Palette.RedIcon,
		function()
			self:ToggleLike()
		end
	)

	local _, VolumeCaption, VolumeIcon = self:_Chip(
		Grid,
		Vector2.new(92, 60),
		"sfsymbols:speakerWave3Fill",
		"Volume",
		Palette.Green,
		Palette.GreenIcon,
		function()
			self:ToggleMute()
		end
	)

	self.ShuffleIcon = ShuffleIcon
	self.ShuffleCaption = ShuffleCaption
	self.LikeIcon = LikeIcon
	self.LikeCaption = LikeCaption
	self.VolumeIcon = VolumeIcon
	self.VolumeCaption = VolumeCaption
	self.LibraryIcon = LibraryIcon
	self.LibraryCaption = LibraryCaption
	self.Grid = Grid
end

---------------------------------------------------------------------------
-- card: scrubber and transport
---------------------------------------------------------------------------

function Miniplayer:_BuildSeek(Cards)
	local Seek = New("Frame", {
		Name = "Seek",
		Size = UDim2.fromOffset(464, 66),
		Position = UDim2.fromOffset(6, 144),
		BackgroundTransparency = 1,
		ZIndex = 7,
		Parent = Cards,
	})

	local Track = New("Frame", {
		Name = "Track",
		Size = UDim2.fromOffset(298, 5),
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromOffset(22, 26),
		BackgroundColor3 = Palette.Track,
		BackgroundTransparency = 0.86,
		ClipsDescendants = true,
		ZIndex = 8,
		Parent = Seek,
	})
	Corner(Track, 2.5)

	local Fill = New("Frame", {
		Name = "Fill",
		Size = UDim2.new(0, 0, 1, 0),
		BackgroundColor3 = Palette.Track,
		BackgroundTransparency = 0.15,
		ZIndex = 9,
		Parent = Track,
	})
	Corner(Fill, 2.5)

	local Thumb = New("Frame", {
		Name = "Thumb",
		Size = UDim2.fromOffset(10, 10),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		BackgroundColor3 = Palette.Text,
		BackgroundTransparency = 1,
		ZIndex = 10,
		Parent = Seek,
	})
	Corner(Thumb, 5)
	local ThumbStroke = Stroke(Thumb, Palette.Hairline, 1, 1)
	self.ThumbStroke = ThumbStroke

	local Elapsed = Text({
		Name = "Elapsed",
		Size = UDim2.fromOffset(60, 16),
		Position = UDim2.fromOffset(22, 34),
		Text = "0:00",
		TextSize = 12,
		TextColor3 = Palette.Muted,
		ZIndex = 8,
		Parent = Seek,
	})

	local Remaining = Text({
		Name = "Remaining",
		Size = UDim2.fromOffset(60, 16),
		Position = UDim2.fromOffset(260, 34),
		Text = "-0:00",
		TextSize = 12,
		TextColor3 = Palette.Muted,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 8,
		Parent = Seek,
	})

	local Scrub = Button({
		Name = "Scrub",
		Size = UDim2.fromOffset(306, 28),
		Position = UDim2.fromOffset(18, 12),
		ZIndex = 11,
		Parent = Seek,
	})

	local Scrubbing = false

	local function Apply(Input)
		local State = self.State
		if not State or not State.CanSeek or (State.Duration or 0) <= 0 then
			return
		end

		local Left = Track.AbsolutePosition.X
		local Width = math.max(Track.AbsoluteSize.X, 1)
		local Ratio = math.clamp((Input.Position.X - Left) / Width, 0, 1)
		Fill.Size = UDim2.new(Ratio, 0, 1, 0)
		Thumb.Position = UDim2.new(Ratio, 0, 0.5, 0)
		Elapsed.Text = Providers.FormatTime(State.Duration * Ratio)
		Remaining.Text = "-" .. Providers.FormatTime(State.Duration * (1 - Ratio))
	end

	local function Commit(Input)
		local State = self.State
		if not State or not State.CanSeek or (State.Duration or 0) <= 0 then
			return
		end

		local Left = Track.AbsolutePosition.X
		local Width = math.max(Track.AbsoluteSize.X, 1)
		local Ratio = math.clamp((Input.Position.X - Left) / Width, 0, 1)
		self:Seek((State.Duration or 0) * Ratio)
	end

	Scrub.InputBegan:Connect(function(Input)
		if Input.UserInputType ~= Enum.UserInputType.MouseButton1 and Input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		Scrubbing = true
		Apply(Input)
	end)

	Scrub.InputChanged:Connect(function(Input)
		if not Scrubbing then
			return
		end
		if Input.UserInputType == Enum.UserInputType.MouseMovement or Input.UserInputType == Enum.UserInputType.Touch then
			Apply(Input)
		end
	end)

	Scrub.InputEnded:Connect(function(Input)
		if not Scrubbing then
			return
		end
		Scrubbing = false
		if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
			Commit(Input)
		end
	end)

	Scrub.MouseEnter:Connect(function()
		Tween(Track, 0.16, { Size = UDim2.fromOffset(298, 7) }, Enum.EasingStyle.Quad, EaseOut):Play()
		Tween(Thumb, 0.16, { BackgroundTransparency = 0 }, Enum.EasingStyle.Quad, EaseOut):Play()
		Tween(ThumbStroke, 0.16, { Transparency = 0.6 }, Enum.EasingStyle.Quad, EaseOut):Play()
	end)

	Scrub.MouseLeave:Connect(function()
		if Scrubbing then
			return
		end
		Tween(Track, 0.2, { Size = UDim2.fromOffset(298, 5) }, Enum.EasingStyle.Quad, EaseOut):Play()
		Tween(Thumb, 0.2, { BackgroundTransparency = 1 }, Enum.EasingStyle.Quad, EaseOut):Play()
		Tween(ThumbStroke, 0.2, { Transparency = 1 }, Enum.EasingStyle.Quad, EaseOut):Play()
	end)

	local function Disc(Position, Size, Icon, OnPress)
		local Holder = New("Frame", {
			Name = "Glass",
			Size = UDim2.fromOffset(Size, Size),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(Position, 33),
			BackgroundColor3 = Palette.Hairline,
			BackgroundTransparency = 1,
			ZIndex = 8,
			Parent = Seek,
		})
		Corner(Holder, Size / 2)
		Stroke(Holder, Palette.Hairline, 0.88, 1)

		local Face = Button({
			Name = "Face",
			Size = UDim2.fromScale(1, 1),
			ZIndex = 9,
			Parent = Holder,
		})
		Corner(Face, Size / 2)

		local IconGlyph = Glyph(Icon, math.floor(Size * 0.44), Palette.Text, 0)
		IconGlyph.AnchorPoint = Vector2.new(0.5, 0.5)
		IconGlyph.Position = UDim2.fromScale(0.5, 0.5)
		IconGlyph.ZIndex = 11
		IconGlyph.Parent = Holder

		local Scale = New("UIScale", { Scale = 1, Parent = Holder })

		Face.MouseEnter:Connect(function()
			Tween(Holder, 0.16, { BackgroundTransparency = 0.9 }, Enum.EasingStyle.Quad, EaseOut):Play()
			Tween(Scale, 0.16, { Scale = 1.08 }, Enum.EasingStyle.Quad, EaseOut):Play()
		end)

		Face.MouseLeave:Connect(function()
			Tween(Holder, 0.2, { BackgroundTransparency = 1 }, Enum.EasingStyle.Quad, EaseOut):Play()
			Tween(Scale, 0.2, { Scale = 1 }, Enum.EasingStyle.Quad, EaseOut):Play()
		end)

		Face.MouseButton1Down:Connect(function()
			Tween(Scale, 0.1, { Scale = 0.92 }, Enum.EasingStyle.Quad, EaseOut):Play()
		end)

		Face.MouseButton1Up:Connect(function()
			Tween(Scale, 0.24, { Scale = 1 }, Enum.EasingStyle.Back, EaseOut):Play()
		end)

		Face.MouseButton1Click:Connect(function()
			if OnPress then
				OnPress()
			end
		end)

		return IconGlyph
	end

	self.PreviousIcon = Disc(351, 30, "sfsymbols:backwardFill", function()
		self:Previous()
	end)
	self.PlayIcon = Disc(389, 38, "sfsymbols:playFill", function()
		self:TogglePlay()
	end)
	self.NextIcon = Disc(427, 30, "sfsymbols:forwardFill", function()
		self:Next()
	end)

	self.Track = Track
	self.Fill = Fill
	self.Thumb = Thumb
	self.Elapsed = Elapsed
	self.Remaining = Remaining
end

---------------------------------------------------------------------------
-- card: source column
---------------------------------------------------------------------------

function Miniplayer:_BuildSide(Cards)
	local Side = New("Frame", {
		Name = "Side",
		Size = UDim2.fromOffset(360, 154),
		Position = UDim2.fromOffset(378, 36),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		ZIndex = 7,
		Parent = Cards,
	})
	self.Side = Side

	local LibraryPage = New("Frame", {
		Name = "LibraryPage",
		Size = UDim2.fromOffset(348, 154),
		BackgroundTransparency = 1,
		ZIndex = 7,
		Parent = Side,
	})
	self.SideLibrary = LibraryPage

	local Heading = Text({
		Name = "Heading",
		Size = UDim2.fromOffset(336, 16),
		Position = UDim2.fromOffset(0, 0),
		Text = "Sources",
		TextSize = 11,
		TextColor3 = Palette.Muted,
		ZIndex = 8,
		Parent = LibraryPage,
	})
	self.SideHeading = Heading

	local Rows = New("Frame", {
		Name = "Rows",
		Size = UDim2.fromOffset(348, 132),
		Position = UDim2.fromOffset(0, 22),
		BackgroundTransparency = 1,
		ZIndex = 8,
		Parent = LibraryPage,
	}, {
		New("UIListLayout", {
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	self.SourceRows = Rows

	Side.Visible = false
	LibraryPage.Visible = false
end

function Miniplayer:_SourceRow(Index, Name, Detail, Tint)
	local Row = New("Frame", {
		Name = "Source" .. Index,
		Size = UDim2.fromOffset(348, 40),
		BackgroundColor3 = Palette.Hairline,
		BackgroundTransparency = 0.94,
		ZIndex = 8,
		Parent = self.SourceRows,
		LayoutOrder = Index,
	})
	Corner(Row, 12)
	Stroke(Row, Palette.Hairline, 0.94, 1)

	local Dot = New("Frame", {
		Name = "Dot",
		Size = UDim2.fromOffset(8, 8),
		Position = UDim2.fromOffset(12, 16),
		BackgroundColor3 = Tint or Palette.Muted,
		BackgroundTransparency = 0.4,
		ZIndex = 9,
		Parent = Row,
	})
	Corner(Dot, 4)

	local Label_ = Text({
		Name = "Name",
		Size = UDim2.fromOffset(220, 16),
		Position = UDim2.fromOffset(28, 6),
		Text = Name,
		TextSize = 12,
		TextColor3 = Palette.Text,
		FontFace = Font.new(Creator.Font, Enum.FontWeight.Bold),
		ZIndex = 9,
		Parent = Row,
	})
	FitText(Label_)

	local Detail_ = Text({
		Name = "Detail",
		Size = UDim2.fromOffset(220, 14),
		Position = UDim2.fromOffset(28, 21),
		Text = Detail,
		TextSize = 10,
		TextColor3 = Palette.Muted,
		ZIndex = 9,
		Parent = Row,
	})
	FitText(Detail_)

	local HitArea = Button({
		Name = "Hit",
		Size = UDim2.fromScale(1, 1),
		ZIndex = 10,
		Parent = Row,
	})

	HitArea.MouseEnter:Connect(function()
		Tween(Row, 0.16, { BackgroundTransparency = 0.9 }, Enum.EasingStyle.Quad, EaseOut):Play()
	end)

	HitArea.MouseLeave:Connect(function()
		Tween(Row, 0.2, { BackgroundTransparency = 0.94 }, Enum.EasingStyle.Quad, EaseOut):Play()
	end)

	HitArea.MouseButton1Click:Connect(function()
		self:_SelectSource(Index)
	end)

	return Row, Label_, Detail_, Dot
end

function Miniplayer:_BuildSources()
	local Entries = self.Config.Providers or { "files", "spotify", "demo" }
	if type(Entries) ~= "table" then
		Entries = { Entries }
	end

	for Index, Entry in ipairs(Entries) do
		local Provider = self:_CreateProvider(Entry)
		if Provider then
			local Tint = Palette.Muted
			if Provider.Id == "spotify" then
				Tint = Palette.GreenIcon
			elseif Provider.Id == "files" then
				Tint = Palette.TealIcon
			elseif Provider.Id == "demo" then
				Tint = Palette.PurpleIcon
			end

			self.Sources[Index] = Provider
			local Row, Label_, Detail_, Dot = self:_SourceRow(Index, Provider.Name, Provider.Status, Tint)
			Provider._Row = Row
			Provider._Detail = Detail_
			Provider._Dot = Dot
			Provider._Name = Label_
		end
	end

	if #self.Sources == 0 then
		local Demo = Providers.NewDemo()
		self.Sources[1] = Demo
		local Row, Label_, Detail_, Dot = self:_SourceRow(1, Demo.Name, Demo.Status, Palette.PurpleIcon)
		Demo._Row = Row
		Demo._Detail = Detail_
		Demo._Dot = Dot
		Demo._Name = Label_
	end
end

function Miniplayer:_CreateProvider(Entry)
	if type(Entry) == "table" then
		return Providers.NewBridge(Entry)
	end

	if Entry == "files" then
		return Providers.NewFolder({ Path = self.Config.Folder or "Ender Hub/songs" })
	end

	if Entry == "spotify" then
		return Providers.NewSpotify(self.Config.Spotify or {})
	end

	if Entry == "demo" then
		return Providers.NewDemo()
	end

	if Entry == "sound" then
		return Providers.NewSound({ Sound = self.Config.Sound })
	end

	return nil
end

---------------------------------------------------------------------------
-- provider switching
---------------------------------------------------------------------------

function Miniplayer:_SelectSource(Index, Silent)
	if not self.Alive then
		return
	end

	local Provider = self.Sources[Index]
	if not Provider then
		return
	end

	if self.Provider and self.Provider ~= Provider then
		pcall(function()
			self.Provider:Disconnect()
		end)
	end

	self.SourceIndex = Index
	self.Provider = Provider

	for RowIndex, Row in ipairs(self.Sources) do
		local Dot = Row._Dot
		local Detail = Row._Detail
		if Dot then
			Tween(Dot, 0.2, { BackgroundTransparency = RowIndex == Index and 0 or 0.7 }):Play()
		end
		if Detail then
			Detail.Text = RowIndex == Index and "Active" or Row.Status
			Detail.TextColor3 = RowIndex == Index and Palette.Text or Palette.Muted
		end
	end

	if not Silent and Provider.Connect then
		local Self_ = self
		Provider:Connect({}, function(Ok, Message)
			if not Self_.Alive then
				return
			end
			if not Ok and Self_.StateLabel then
				Self_.StateLabel.Text = tostring(Message or "Unavailable")
			end
			Self_:_SyncStatus()
		end)
	end

	self:_SyncStatus()
end

function Miniplayer:_SyncStatus()
	local Provider = self.Provider
	if not Provider then
		return
	end

	if Provider._Detail then
		Provider._Detail.Text = Provider.Status or "Ready"
	end

	if self.Count then
		local Tracks = Provider.Tracks
		if type(Tracks) == "table" then
			self.Count.Text = #Tracks .. (#Tracks == 1 and " track" or " tracks")
		else
			self.Count.Text = Provider.Name or "Ready"
		end
	end
end

---------------------------------------------------------------------------
-- shell wiring: press, hover, drag, loop
---------------------------------------------------------------------------

function Miniplayer:_WireShell()
	local Shell = self.Shell

	local Pressed = false
	local Dragging = false
	local DragStart = nil
	local StartPosition = nil
	local Moved = 0

	self.Hit.MouseEnter:Connect(function()
		if self.Expanded then
			return
		end
		self.HoverScale = 1.03
		self:Fit()
		Tween(self.Stroke, 0.2, { Transparency = 0.7 }, Enum.EasingStyle.Quad, EaseOut):Play()
		Tween(self.Gloss, 0.2, { BackgroundTransparency = 0.9 }, Enum.EasingStyle.Quad, EaseOut):Play()
	end)

	self.Hit.MouseLeave:Connect(function()
		if self.Expanded then
			return
		end
		self.HoverScale = 1
		self:Fit()
		Tween(self.Stroke, 0.24, { Transparency = 0.86 }, Enum.EasingStyle.Quad, EaseOut):Play()
		Tween(self.Gloss, 0.24, { BackgroundTransparency = 1 }, Enum.EasingStyle.Quad, EaseOut):Play()
	end)

	self.Hit.MouseButton1Down:Connect(function(Input)
		Pressed = true
		Moved = 0
		DragStart = Input.Position
		StartPosition = Shell.Position
		self.HoverScale = 0.98
		self:Fit()
	end)

	local MoveSignal = UserInputService.InputChanged:Connect(function(Input)
		if not Pressed or not self.Floating then
			return
		end

		if Input.UserInputType ~= Enum.UserInputType.MouseMovement and Input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end

		local Delta = Input.Position - DragStart
		if math.abs(Delta.X) > 4 or math.abs(Delta.Y) > 4 then
			if not Dragging then
				Dragging = true
				self.HoverScale = 1
				self:Fit()
			end

			Moved = math.max(Moved, math.abs(Delta.X) + math.abs(Delta.Y))
			Shell.Position = UDim2.new(
				StartPosition.X.Scale,
				StartPosition.X.Offset + Delta.X,
				StartPosition.Y.Scale,
				StartPosition.Y.Offset + Delta.Y
			)
		end
	end)

	local function Release()
		if not Pressed then
			return
		end

		Pressed = false
		local WasDragging = Dragging
		Dragging = false
		self.HoverScale = 1
		self:Fit()

		if WasDragging then
			return
		end

		if self.Expanded then
			return
		end

		self:Expand()
	end

	self.Hit.MouseButton1Up:Connect(Release)

	local EndSignal = UserInputService.InputEnded:Connect(function(Input)
		if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
			Release()
		end
	end)

	table.insert(self.Signals, MoveSignal)
	table.insert(self.Signals, EndSignal)

	-- The artwork is its own target: it opens the card and closes it again.
	local CoverHit = Button({
		Name = "CoverHit",
		Size = UDim2.fromScale(1, 1),
		ZIndex = 12,
		Parent = self.Cover,
	})

	CoverHit.MouseButton1Click:Connect(function()
		if self.Expanded then
			self:Collapse()
		else
			self:Expand()
		end
	end)

	CoverHit.MouseEnter:Connect(function()
		if self.Expanded then
			return
		end
		Tween(self.Cover, 0.18, { Size = UDim2.fromOffset(30, 30) }, Enum.EasingStyle.Quad, EaseOut):Play()
	end)

	CoverHit.MouseLeave:Connect(function()
		if self.Expanded then
			return
		end
		Tween(self.Cover, 0.22, { Size = UDim2.fromOffset(28, 28) }, Enum.EasingStyle.Quad, EaseOut):Play()
	end)
end

function Miniplayer:_WireLoop()
	local Clock_ = 0

	table.insert(
		self.Signals,
		RunService.Heartbeat:Connect(function(Delta)
			if not self.Alive then
				return
			end

			Clock_ = Clock_ + Delta
			local Playing = self.State and self.State.Playing
			local Amplitude = Playing and 1 or 0.28

			for Index, Bar in ipairs(self.Bars) do
				local Base = BarHeights[Index]
				local Speed = 2.1 + Index * 0.43
				local Height = Base * (0.45 + 0.55 * math.abs(math.sin(Clock_ * Speed + Index * 0.9)))
				Bar.Size = UDim2.fromOffset(2, math.max(3, 3 + (Height - 3) * Amplitude))
			end
		end)
	)

	task.spawn(function()
		while self.Alive do
			local Provider = self.Provider
			if Provider and Provider.Poll then
				local Started = os.clock()
				local Ok = pcall(function()
					Provider:Poll(function(Success, State)
						if not self.Alive or self.Provider ~= Provider then
							return
						end
						if Success and type(State) == "table" then
							self:_Apply(State)
						elseif self.StateLabel then
							self.StateLabel.Text = tostring(State or "Unavailable")
						end
					end)
				end)

				if self.Latency then
					local Ms = (os.clock() - Started) * 1000
					self.Latency.Text = string.format("%d ms", math.floor(Ms + 0.5))
				end

				if not Ok then
					self.StateLabel.Text = "Poll error"
				end
			end

			task.wait(self.Config.PollRate or 0.25)
		end
	end)
end

---------------------------------------------------------------------------
-- state
---------------------------------------------------------------------------

function Miniplayer:_Apply(State)
	self.State = State

	local Title = State.Title ~= "" and State.Title or State.Hint or "Nothing playing"
	self.TitleLabel.Text = Title
	self.ArtistLabel.Text = State.Artist ~= "" and State.Artist or (State.Album or "")

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
		local Ratio = math.clamp((State.Position or 0) / State.Duration, 0, 1)
		if self.Fill then
			Tween(self.Fill, 0.2, { Size = UDim2.new(Ratio, 0, 1, 0) }, Enum.EasingStyle.Linear):Play()
			self.Thumb.Position = UDim2.new(Ratio, 0, 0.5, 0)
		end
		self.Elapsed.Text = Providers.FormatTime(State.Position or 0)
		self.Remaining.Text = "-" .. Providers.FormatTime(math.max(State.Duration - (State.Position or 0), 0))
	else
		self.Elapsed.Text = "0:00"
		self.Remaining.Text = "-0:00"
	end

	local Playing = State.Playing == true
	self.StateIcon.Image = Creator.Icon(Playing and "sfsymbols:waveform" or "sfsymbols:playFill")[1]
	self.StateLabel.Text = Playing and "Playing" or ((State.Hint and State.Hint ~= "") and State.Hint or "Paused")
	self.PlayIcon.Image = Creator.Icon(Playing and "sfsymbols:pauseFill" or "sfsymbols:playFill")[1]

	if self.Caption then
		self.Caption.Text = self.Tab == "library" and "Library" or "Player"
	end
end

function Miniplayer:_SyncLibrary()
	if not self.Side then
		return
	end

	local Library = self.Tab == "library"
	self.Side.Visible = Library
	self.SideLibrary.Visible = Library
	self.Grid.Visible = not Library

	if Library then
		self.SideHeading.Text = "Sources"
	end
end

---------------------------------------------------------------------------
-- expand / collapse
---------------------------------------------------------------------------

function Miniplayer:Fit()
	if not self.Alive then
		return
	end

	local Available = self:AvailableWidth()
	local Design = self.Expanded and Wide or Narrow
	local Scale = math.clamp(Available / Design, 0.3, 1)
	if self.Config.Scale then
		Scale = Scale * self.Config.Scale
	end

	self.FitScale = Scale
	self.ShellScale.Scale = Scale * self.HoverScale
end

function Miniplayer:AvailableWidth()
	if self.Parent then
		return math.max(self.Parent.AbsoluteSize.X - 8, 120)
	end

	local Camera = workspace.CurrentCamera
	local Viewport = Camera and Camera.ViewportSize or Vector2.new(1280, 720)
	return math.max(Viewport.X - 24, 120)
end

function Miniplayer:_ApplyExpand(Instant)
	local Duration = Instant and 0 or 0.42

	self.Cards.Visible = true
	self:Fit()

	Tween(self.Shell, Duration, { Size = UDim2.fromOffset(Wide, Tall) }, Ease, EaseOut):Play()
	Tween(self.Cards, Instant and 0 or 0.3, { GroupTransparency = 0 }, Enum.EasingStyle.Quad, EaseOut):Play()
	Tween(self.Cover, Duration, {
		Size = UDim2.fromOffset(72, 72),
		Position = UDim2.fromOffset(14, 48),
	}, Ease, EaseOut):Play()
	Tween(self.Cover:FindFirstChildOfClass("UICorner"), Duration, { CornerRadius = UDim.new(0, 16) }, Ease, EaseOut):Play()
	Tween(self.Wave, Instant and 0 or 0.18, { BackgroundTransparency = 1 }, Enum.EasingStyle.Quad, EaseIn):Play()

	for _, Bar in ipairs(self.Bars) do
		Tween(Bar, Instant and 0 or 0.16, { BackgroundTransparency = 1 }, Enum.EasingStyle.Quad, EaseIn):Play()
	end

	Tween(self.Gloss, Instant and 0 or 0.24, { BackgroundTransparency = 1 }, Enum.EasingStyle.Quad, EaseOut):Play()
	Tween(self.Stroke, Instant and 0 or 0.3, { Transparency = 0.86 }, Enum.EasingStyle.Quad, EaseOut):Play()
end

function Miniplayer:_ApplyCollapse(Instant)
	local Duration = Instant and 0 or 0.38

	self:Fit()

	Tween(self.Shell, Duration, { Size = UDim2.fromOffset(Narrow, Short) }, Ease, EaseOut):Play()
	Tween(self.Cards, Instant and 0 or 0.16, { GroupTransparency = 1 }, Enum.EasingStyle.Quad, EaseIn):Play()
	Tween(self.Cover, Duration, {
		Size = UDim2.fromOffset(28, 28),
		Position = UDim2.fromOffset(6, 6),
	}, Ease, EaseOut):Play()
	Tween(self.Cover:FindFirstChildOfClass("UICorner"), Duration, { CornerRadius = UDim.new(0, 9) }, Ease, EaseOut):Play()

	task.delay(Instant and 0 or 0.18, function()
		if not self.Alive or self.Expanded then
			return
		end
		self.Cards.Visible = false
		self.Wave.BackgroundTransparency = 1
		for _, Bar in ipairs(self.Bars) do
			Bar.BackgroundTransparency = 0
		end
	end)
end

function Miniplayer:Expand()
	if self.Expanded or not self.Alive then
		return
	end

	self.Expanded = true
	self.HoverScale = 1
	self:_ApplyExpand(false)
	self:_SyncLibrary()

	if self.Config.OnExpand then
		pcall(self.Config.OnExpand, self)
	end
end

function Miniplayer:Collapse()
	if not self.Expanded or not self.Alive then
		return
	end

	self.Expanded = false
	self.HoverScale = 1
	self:_ApplyCollapse(false)

	if self.Config.OnCollapse then
		pcall(self.Config.OnCollapse, self)
	end
end

function Miniplayer:Toggle()
	if self.Expanded then
		self:Collapse()
	else
		self:Expand()
	end
end

---------------------------------------------------------------------------
-- public actions
---------------------------------------------------------------------------

function Miniplayer:SetTab(Tab)
	self.Tab = Tab == "library" and "library" or "player"

	local Target = self.Tab == "library" and UDim2.fromOffset(33, 3) or UDim2.fromOffset(3, 3)
	Tween(self.TabPill, 0.26, { Position = Target }, Ease, EaseOut):Play()

	Tween(self.TabGlyphs.player, 0.2, { ImageTransparency = self.Tab == "player" and 0.05 or 0.5 }):Play()
	Tween(self.TabGlyphs.library, 0.2, { ImageTransparency = self.Tab == "library" and 0.05 or 0.5 }):Play()

	self:_SyncLibrary()
end

function Miniplayer:TogglePlay()
	local Provider = self.Provider
	if not Provider then
		return
	end

	if self.State and self.State.Playing then
		Provider:Pause()
	else
		Provider:Play()
	end
end

function Miniplayer:Play()
	if self.Provider then
		self.Provider:Play()
	end
end

function Miniplayer:Pause()
	if self.Provider then
		self.Provider:Pause()
	end
end

function Miniplayer:Next()
	if self.Provider then
		self.Provider:Next()
	end
end

function Miniplayer:Previous()
	if self.Provider then
		self.Provider:Previous()
	end
end

function Miniplayer:Seek(Seconds)
	if self.Provider and self.Provider.Seek then
		self.Provider:Seek(Seconds)
	end
end

function Miniplayer:SetVolume(Percent)
	self.Volume = math.clamp(Percent or 60, 0, 100)
	if self.Provider and self.Provider.SetVolume then
		self.Provider:SetVolume(self.Volume)
	end
end

function Miniplayer:ToggleMute()
	self.Muted = not self.Muted
	self.VolumeIcon.Image = Creator.Icon(self.Muted and "sfsymbols:speakerSlashFill" or "sfsymbols:speakerWave3Fill")[1]
	self.VolumeCaption.Text = self.Muted and "Muted" or "Volume"

	if self.Provider and self.Provider.SetVolume then
		self.Provider:SetVolume(self.Muted and 0 or self.Volume)
	end
end

function Miniplayer:ToggleShuffle()
	local Provider = self.Provider
	if not Provider then
		return
	end

	Provider.Shuffle = not Provider.Shuffle
	self.ShuffleIcon.Image = Creator.Icon("sfsymbols:shuffle")[1]
	self.ShuffleIcon.ImageColor3 = Provider.Shuffle and Palette.TealIcon or Palette.Muted
	self.ShuffleCaption.Text = Provider.Shuffle and "Shuffled" or "Shuffle"
end

function Miniplayer:ToggleLike()
	self.Liked = not self.Liked
	self.LikeIcon.Image = Creator.Icon(self.Liked and "sfsymbols:heartFill" or "sfsymbols:heart")[1]
	self.LikeCaption.Text = self.Liked and "Liked" or "Like"

	if self.Config.OnLike then
		pcall(self.Config.OnLike, self.Liked, self.State)
	end
end

function Miniplayer:SetSource(Source)
	if type(Source) == "number" then
		self:_SelectSource(Source)
		return
	end

	for Index, Provider in ipairs(self.Sources) do
		if Provider.Id == Source or Provider.Name == Source then
			self:_SelectSource(Index)
			return
		end
	end
end

function Miniplayer:GetState()
	return self.State
end

function Miniplayer:Show()
	if self.Shell then
		self.Shell.Visible = true
	end
end

function Miniplayer:Hide()
	if self.Shell then
		self.Shell.Visible = false
	end
end

function Miniplayer:Destroy()
	if not self.Alive then
		return
	end

	self.Alive = false

	for _, Signal in ipairs(self.Signals) do
		pcall(function()
			Signal:Disconnect()
		end)
	end
	self.Signals = {}

	for _, Provider in ipairs(self.Sources) do
		pcall(function()
			Provider:Disconnect()
		end)
	end

	if self.Shell then
		self.Shell:Destroy()
		self.Shell = nil
	end
end

return Miniplayer
