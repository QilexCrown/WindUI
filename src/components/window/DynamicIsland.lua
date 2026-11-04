-- DynamicIsland - the pill at the top of the screen and the card it opens into.
--
--   local Island = WindUI:DynamicIsland({
--       Providers = { "files", "spotify", "demo" },
--       Folder = "Ender Hub/songs",
--   })
--
--   -- docked inside a window instead of floating over the game:
--   local Island = WindUI:DynamicIsland({ Parent = Tab.Frame })
--
-- Collapsed it is a 212 x 40 capsule: 28 px artwork at (6, 6) and six 2 x 14
-- bars on the right edge. Tapped it springs into a 540 x 204 card: a header
-- with the source name and the ping, the now-playing card with 84 px artwork,
-- two chips, then the scrubber with both times and the transport. Measured off
-- the island the client runs. Everything service-specific lives in
-- modules/MusicProviders.

local cloneref = (cloneref or clonereference or function(instance)
	return instance
end)

local UserInputService = cloneref(game:GetService("UserInputService"))
local Stats = cloneref(game:GetService("Stats"))

local Creator = require("../../modules/Creator")
local Surface = require("../../modules/MusicSurface")

local New = Creator.New
local Tween = Creator.Tween

local DynamicIsland = {}
DynamicIsland.__index = DynamicIsland

---------------------------------------------------------------------------
-- metrics, in island pixels
---------------------------------------------------------------------------

local PillW, PillH = 212, 40
local OpenW, OpenH = 540, 204

local PillRadius, OpenRadius = 20, 30

local PillCover, PillCoverAt, PillCoverRadius = 28, Vector2.new(6, 6), 12
local OpenCover, OpenCoverAt, OpenCoverRadius = 84, Vector2.new(38, 66), 16

local PillBarW, PillBarH, PillBarGap = 2, 14, 2
local PillBarRight = 14

local P = 24
local NowW, NowH = 320, 114
local SideW, SideH = 160, 54

local Palette = {
	Shell = Color3.fromRGB(0, 0, 0),
	Text = Color3.fromRGB(255, 255, 255),
	Muted = Color3.fromRGB(154, 156, 164),
	Card = Color3.fromRGB(255, 255, 255),
	Blue = Color3.fromRGB(20, 49, 63),
	BlueIcon = Color3.fromRGB(64, 166, 255),
	Purple = Color3.fromRGB(36, 26, 63),
	PurpleIcon = Color3.fromRGB(168, 112, 255),
	Hairline = Color3.fromRGB(255, 255, 255),
}

local Ease = Enum.EasingStyle.Quint
local EaseOut = Enum.EasingDirection.Out
local EaseIn = Enum.EasingDirection.In

---------------------------------------------------------------------------
-- primitives
---------------------------------------------------------------------------

local function Corner(Object, Radius_)
	return New("UICorner", { CornerRadius = UDim.new(0, Radius_), Parent = Object })
end

local function Stroke(Object, Color, Transparency, Thickness)
	return New("UIStroke", {
		Color = Color,
		Transparency = Transparency or 0,
		Thickness = Thickness or 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = Object,
	})
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

---------------------------------------------------------------------------
-- construction
---------------------------------------------------------------------------

function DynamicIsland.New(Config)
	Config = Config or {}

	local self = setmetatable({
		Config = Config,
		WindUI = Config.WindUI,
		Parent = Config.Parent,
		Alive = true,
		Expanded = Config.Expanded == true,
		HoverScale = 1,
		FitScale = 1,
		CoverId = nil,
		Volume = 60,
		Muted = false,
		Shuffled = false,
		Born = os.time(),
		Signals = {},
	}, DynamicIsland)

	self.Floating = self.Parent == nil

	local Folder = self.Parent or (self.WindUI and self.WindUI.ScreenGui)
	if not Folder then
		error("DynamicIsland: floating mode needs WindUI.ScreenGui, pass Config.Parent instead")
	end

	local StartW = self.Expanded and OpenW or PillW
	local StartH = self.Expanded and OpenH or PillH

	--------------------------------------------------------------- shell

	local Shell = New("Frame", {
		Name = "DynamicIsland",
		Size = UDim2.fromOffset(StartW, StartH),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, self.Floating and (Config.Top or 12) or 0),
		BackgroundColor3 = Palette.Shell,
		BackgroundTransparency = 0,
		ClipsDescendants = true,
		Parent = Folder,
	})
	local ShellCorner = Corner(Shell, self.Expanded and OpenRadius or PillRadius)

	New("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.55, 0.02),
			NumberSequenceKeypoint.new(1, 0.1),
		}),
		Parent = Shell,
	})

	-- UIShadow caches the parent's size when it is created, so a shadow on a
	-- frame that is about to resize leaves a stale silhouette behind. It is
	-- torn down before each size tween and rebuilt after it lands.
	self.Shadow = nil

	local ShellScale = New("UIScale", { Scale = 1, Parent = Shell })
	self.Shell = Shell
	self.ShellCorner = ShellCorner
	self.ShellScale = ShellScale

	--------------------------------------------------------------- artwork

	local Cover = New("ImageLabel", {
		Name = "Cover",
		Size = UDim2.fromOffset(self.Expanded and OpenCover or PillCover, self.Expanded and OpenCover or PillCover),
		Position = UDim2.fromOffset(self.Expanded and OpenCoverAt.X or PillCoverAt.X, self.Expanded and OpenCoverAt.Y or PillCoverAt.Y),
		BackgroundColor3 = Color3.fromRGB(22, 22, 26),
		BackgroundTransparency = 0,
		Image = "",
		ScaleType = Enum.ScaleType.Crop,
		ZIndex = 20,
		Parent = Shell,
	})
	local CoverCorner = Corner(Cover, PillCoverRadius)

	local CoverGlyph = Glyph("sfsymbols:musicNote", 14, Palette.Muted)
	CoverGlyph.Name = "Placeholder"
	CoverGlyph.Size = UDim2.fromScale(0.42, 0.42)
	CoverGlyph.Position = UDim2.fromScale(0.5, 0.5)
	CoverGlyph.AnchorPoint = Vector2.new(0.5, 0.5)
	CoverGlyph.ZIndex = 21
	CoverGlyph.Parent = Cover

	self.Cover = Cover
	self.CoverCorner = CoverCorner
	self.CoverGlyph = CoverGlyph

	--------------------------------------------------------------- pill bars

	local PillWave = New("Frame", {
		Name = "PillWave",
		Size = UDim2.fromOffset(PillBarW * 6 + PillBarGap * 5, PillBarH),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -PillBarRight, 0.5, 0),
		BackgroundTransparency = 1,
		Visible = not self.Expanded,
		ZIndex = 5,
		Parent = Shell,
	})
	self.PillWave = PillWave

	for Index = 1, 6 do
		local Bar = New("Frame", {
			Name = "Bar" .. Index,
			Size = UDim2.fromOffset(PillBarW, PillBarH),
			Position = UDim2.fromOffset((Index - 1) * (PillBarW + PillBarGap), 0),
			BackgroundColor3 = Palette.Text,
			BorderSizePixel = 0,
			ZIndex = 5,
			Parent = PillWave,
		})
		Corner(Bar, 1)
	end

	--------------------------------------------------------------- open card

	local Card = New("CanvasGroup", {
		Name = "Card",
		Size = UDim2.fromOffset(OpenW, OpenH),
		Position = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 1,
		GroupTransparency = self.Expanded and 0 or 1,
		Visible = self.Expanded,
		ZIndex = 6,
		Parent = Shell,
	})
	self.Card = Card

	-- header: the source disc, the source name, ping and uptime
	local Disc = New("Frame", {
		Name = "SourceDisc",
		Size = UDim2.fromOffset(26, 26),
		Position = UDim2.fromOffset(P, 12),
		BackgroundColor3 = Palette.Text,
		BackgroundTransparency = 0.94,
		ZIndex = 7,
		Parent = Card,
	})
	Corner(Disc, 13)

	local DiscGlyph = Glyph("sfsymbols:musicNote", 13, Palette.Text)
	DiscGlyph.AnchorPoint = Vector2.new(0.5, 0.5)
	DiscGlyph.Position = UDim2.fromScale(0.5, 0.5)
	DiscGlyph.ZIndex = 8
	DiscGlyph.Parent = Disc

	local SourceLabel = Text({
		Name = "SourceLabel",
		Size = UDim2.fromOffset(200, 26),
		Position = UDim2.fromOffset(P + 34, 12),
		Text = "Library",
		TextSize = 13,
		TextColor3 = Color3.fromRGB(216, 216, 222),
		ZIndex = 8,
		Parent = Card,
	})
	self.SourceLabel = SourceLabel

	local PingIcon = Glyph("sfsymbols:wifi", 11, Palette.Muted)
	PingIcon.AnchorPoint = Vector2.new(1, 0.5)
	PingIcon.Position = UDim2.fromOffset(OpenW - P - 86, 25)
	PingIcon.ZIndex = 8
	PingIcon.Parent = Card

	local PingText = Text({
		Name = "Ping",
		Size = UDim2.fromOffset(60, 26),
		Position = UDim2.fromOffset(OpenW - P - 80, 12),
		Text = "0 ms",
		TextSize = 12,
		TextColor3 = Palette.Muted,
		ZIndex = 8,
		Parent = Card,
	})
	self.PingText = PingText

	local ClockIcon = Glyph("sfsymbols:clock", 11, Palette.Muted)
	ClockIcon.AnchorPoint = Vector2.new(1, 0.5)
	ClockIcon.Position = UDim2.fromOffset(OpenW - P - 28, 25)
	ClockIcon.ZIndex = 8
	ClockIcon.Parent = Card

	local UptimeText = Text({
	Name = "Uptime",
		Size = UDim2.fromOffset(40, 26),
		Position = UDim2.fromOffset(OpenW - P - 22, 12),
		Text = "0m",
		TextSize = 12,
		TextColor3 = Palette.Muted,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 8,
		Parent = Card,
	})
	self.UptimeText = UptimeText

	-- now playing
	local Now = New("Frame", {
		Name = "NowPlaying",
		Size = UDim2.fromOffset(NowW, NowH),
		Position = UDim2.fromOffset(P, 50),
		BackgroundColor3 = Palette.Card,
		BackgroundTransparency = 0.945,
		ZIndex = 7,
		Parent = Card,
	})
	Corner(Now, 22)
	Stroke(Now, Palette.Hairline, 0.93, 1)

	local Artist = Text({
		Name = "Artist",
		Size = UDim2.fromOffset(190, 14),
		Position = UDim2.fromOffset(112, 14),
		Text = "",
		TextSize = 12,
		TextColor3 = Palette.Muted,
		ZIndex = 8,
		Parent = Now,
	})
	self.ArtistLabel = Artist

	local Title = Text({
		Name = "Title",
		Size = UDim2.fromOffset(190, 20),
		Position = UDim2.fromOffset(112, 32),
		Text = "Nothing playing",
		TextSize = 15,
		FontFace = Font.new(Creator.Font, Enum.FontWeight.Bold),
		ZIndex = 8,
		Parent = Now,
	})
	self.TitleLabel = Title

	local StateIcon = Glyph("sfsymbols:playFill", 10, Palette.Muted)
	StateIcon.Position = UDim2.fromOffset(112, 66)
	StateIcon.ZIndex = 8
	StateIcon.Parent = Now
	self.StateIcon = StateIcon

	local StateText = Text({
		Name = "State",
		Size = UDim2.fromOffset(170, 14),
		Position = UDim2.fromOffset(128, 64),
		Text = "Paused",
		TextSize = 11,
		TextColor3 = Palette.Muted,
		ZIndex = 8,
		Parent = Now,
	})
	self.StateText = StateText

	-- chips
	local function Chip(Name, Y, Label, Icon, Background, IconColor, OnPress)
		local Frame = Button({
			Name = Name,
			Size = UDim2.fromOffset(SideW, SideH),
			Position = UDim2.fromOffset(OpenW - P - SideW, Y),
			BackgroundColor3 = Background,
			BackgroundTransparency = 0.35,
			ZIndex = 7,
			Parent = Card,
		})
		Corner(Frame, 18)
		Stroke(Frame, Palette.Hairline, 0.94, 1)

		local GlyphIcon = Glyph(Icon, 16, IconColor)
		GlyphIcon.Position = UDim2.fromOffset(14, 10)
		GlyphIcon.ZIndex = 8
		GlyphIcon.Parent = Frame

		Text({
			Name = "Label",
			Size = UDim2.fromOffset(132, 18),
			Position = UDim2.fromOffset(14, 28),
			Text = Label,
			TextSize = 13,
			FontFace = Font.new(Creator.Font, Enum.FontWeight.Bold),
			ZIndex = 8,
			Parent = Frame,
		})

		Frame.MouseButton1Click:Connect(OnPress)
		Frame.MouseEnter:Connect(function()
			Tween(Frame, 0.16, { BackgroundTransparency = 0.2 }, Enum.EasingStyle.Quad, EaseOut):Play()
		end)
		Frame.MouseLeave:Connect(function()
			Tween(Frame, 0.18, { BackgroundTransparency = 0.35 }, Enum.EasingStyle.Quad, EaseOut):Play()
		end)

		return Frame, GlyphIcon
	end

	local ShuffleChip = Chip("Shuffle", 50, "Shuffle", "sfsymbols:shuffle", Palette.Blue, Palette.BlueIcon, function()
		self:ToggleShuffle()
	end)
	self.ShuffleChip = ShuffleChip

	Chip("Library", 110, "Library", "sfsymbols:squareStack", Palette.Purple, Palette.PurpleIcon, function()
		self:CycleSource()
	end)

	-- scrubber
	local Track = New("Frame", {
		Name = "Track",
		Size = UDim2.fromOffset(320, 4),
		Position = UDim2.fromOffset(P, 176),
		BackgroundColor3 = Palette.Text,
		BackgroundTransparency = 0.8,
		BorderSizePixel = 0,
		ZIndex = 8,
		Parent = Card,
	})
	Corner(Track, 2)
	self.Track = Track

	local Fill = New("Frame", {
		Name = "Fill",
		Size = UDim2.new(0, 0, 1, 0),
		BackgroundColor3 = Palette.Text,
		BorderSizePixel = 0,
		ZIndex = 9,
		Parent = Track,
	})
	Corner(Fill, 2)
	self.Fill = Fill

	local Scrub = Button({
		Name = "Scrub",
		Size = UDim2.new(1, 0, 0, 22),
		Position = UDim2.fromOffset(0, -9),
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
		if Duration > 0 then
			self:Seek(Ratio * Duration)
		end
	end

	Scrub.MouseButton1Down:Connect(SeekAt)
	Scrub.InputChanged:Connect(function(Input)
		if Input.UserInputType == Enum.UserInputType.MouseMovement and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
			SeekAt(Input)
		end
	end)

	local Elapsed = Text({
		Name = "Elapsed",
		Size = UDim2.fromOffset(60, 14),
		Position = UDim2.fromOffset(P, 186),
		Text = "0:00",
		TextSize = 12,
		TextColor3 = Palette.Muted,
		ZIndex = 8,
		Parent = Card,
	})
	self.Elapsed = Elapsed

	local Remaining = Text({
		Name = "Remaining",
		Size = UDim2.fromOffset(60, 14),
		Position = UDim2.fromOffset(P + 320 - 60, 186),
		Text = "-0:00",
		TextSize = 12,
		TextColor3 = Palette.Muted,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 8,
		Parent = Card,
	})
	self.Remaining = Remaining

	-- transport
	local function Disc_(Name, CenterX, Icon, GlyphSize, Bright, OnPress)
		local Frame = Button({
			Name = Name,
			Size = UDim2.fromOffset(30, 30),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(CenterX, 184),
			BackgroundColor3 = Palette.Text,
			BackgroundTransparency = Bright and 0.88 or 0.94,
			ZIndex = 10,
			Parent = Card,
		})
		Corner(Frame, 15)
		Stroke(Frame, Palette.Hairline, 0.9, 1)

		local Image = Glyph(Icon, GlyphSize, Palette.Text)
		Image.AnchorPoint = Vector2.new(0.5, 0.5)
		Image.Position = UDim2.fromScale(0.5, 0.5)
		Image.ZIndex = 11
		Image.Parent = Frame

		Frame.MouseButton1Click:Connect(OnPress)
		Frame.MouseEnter:Connect(function()
			Tween(Frame, 0.14, { BackgroundTransparency = 0.84 }, Enum.EasingStyle.Quad, EaseOut):Play()
		end)
		Frame.MouseLeave:Connect(function()
			Tween(Frame, 0.16, { BackgroundTransparency = Bright and 0.88 or 0.94 }, Enum.EasingStyle.Quad, EaseOut):Play()
		end)

		return Image
	end

	Disc_("Previous", 391, "sfsymbols:backwardFill", 13, false, function()
		self:Previous()
	end)

	self.PlayIcon = Disc_("Play", 436, "sfsymbols:playFill", 13, true, function()
		self:TogglePlay()
	end)

	Disc_("Next", 481, "sfsymbols:forwardFill", 13, false, function()
		self:Next()
	end)

	--------------------------------------------------------------- input

	local PillHit = Button({
		Name = "PillHit",
		Size = UDim2.fromScale(1, 1),
		Visible = not self.Expanded,
		ZIndex = 25,
		Parent = Shell,
	})
	self.PillHit = PillHit

	local HeaderHit = Button({
		Name = "HeaderHit",
		Size = UDim2.fromOffset(OpenW, 46),
		Position = UDim2.fromOffset(0, 0),
		Visible = self.Expanded,
		ZIndex = 25,
		Parent = Shell,
	})
	self.HeaderHit = HeaderHit

	--------------------------------------------------------------- wiring

	Surface.Bind(self, Config)
	self:_WireDrag()
	self:_WireStatus()
	self:_RefreshShadow()

	self:Fit()

	return self
end

---------------------------------------------------------------------------
-- status: ping and uptime in the header
---------------------------------------------------------------------------

function DynamicIsland:_WireStatus()
	task.spawn(function()
		while self.Alive do
			local Ping = 0
			pcall(function()
				Ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue() + 0.5)
			end)
			self.PingText.Text = Ping .. " ms"
			self.UptimeText.Text = math.floor((os.time() - self.Born) / 60) .. "m"
			task.wait(1)
		end
	end)
end

---------------------------------------------------------------------------
-- drag and click
---------------------------------------------------------------------------

function DynamicIsland:_WireDrag()
	local Shell = self.Shell
	local Pressed, Dragging, Moved = false, false, 0
	local DragStart, StartPosition = nil, nil

	local function Begin(Input)
		Pressed = true
		Moved = 0
		DragStart = Input.Position
		StartPosition = Shell.Position
	end

	local function Release()
		if not Pressed then
			return
		end
		Pressed = false
		if Dragging then
			Dragging = false
			return
		end
		if Moved < 6 and not self.Expanded then
			self:Expand()
		end
	end

	self.PillHit.MouseButton1Down:Connect(Begin)
	self.HeaderHit.MouseButton1Down:Connect(Begin)

	local function Move(Input)
		if not Pressed or not self.Floating then
			return
		end
		if Input.UserInputType ~= Enum.UserInputType.MouseMovement and Input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		local Delta = Input.Position - DragStart
		if math.abs(Delta.X) > 4 or math.abs(Delta.Y) > 4 then
			Dragging = true
			Moved = math.max(Moved, math.abs(Delta.X) + math.abs(Delta.Y))
			Shell.Position = UDim2.new(
				StartPosition.X.Scale,
				StartPosition.X.Offset + Delta.X,
				StartPosition.Y.Scale,
				StartPosition.Y.Offset + Delta.Y
			)
		end
	end

	table.insert(
		self.Signals,
		UserInputService.InputChanged:Connect(Move)
	)

	table.insert(
		self.Signals,
		UserInputService.InputEnded:Connect(function(Input)
			if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
				Release()
			end
		end)
	)

	self.PillHit.MouseButton1Up:Connect(Release)
	self.HeaderHit.MouseButton1Up:Connect(Release)

	-- right click anywhere on the island closes the card
	table.insert(
		self.Signals,
		UserInputService.InputBegan:Connect(function(Input)
			if Input.UserInputType ~= Enum.UserInputType.MouseButton2 then
				return
			end
			local Mouse = UserInputService:GetMouseLocation()
			local Size, Position = Shell.AbsoluteSize, Shell.AbsolutePosition
			if Mouse.X >= Position.X and Mouse.X <= Position.X + Size.X and Mouse.Y >= Position.Y and Mouse.Y <= Position.Y + Size.Y then
				self:Collapse()
			end
		end)
	)
end

---------------------------------------------------------------------------
-- state
---------------------------------------------------------------------------

function DynamicIsland:RenderState(State)
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
		Tween(self.Fill, 0.2, { Size = UDim2.new(Ratio, 0, 1, 0) }, Enum.EasingStyle.Linear):Play()
		self.Elapsed.Text = Surface.FormatTime(State.Position or 0)
		self.Remaining.Text = "-" .. Surface.FormatTime(math.max(State.Duration - (State.Position or 0), 0))
	else
		self.Elapsed.Text = "0:00"
		self.Remaining.Text = "-0:00"
	end

	local Playing = State.Playing == true
	self.PlayIcon.Image = Creator.Icon(Playing and "sfsymbols:pauseFill" or "sfsymbols:playFill")
	self.StateIcon.Image = Creator.Icon(Playing and "sfsymbols:playFill" or "sfsymbols:pauseFill")
	self.StateText.Text = Playing and "Playing" or "Paused"
end

function DynamicIsland:RenderError(Message)
	if self.ArtistLabel then
		self.ArtistLabel.Text = Message
	end
end

function DynamicIsland:RenderSources()
	local Provider = self.Provider
	if Provider then
		self.SourceLabel.Text = Provider.Name or "Library"
	end
end

---------------------------------------------------------------------------
-- expand / collapse
---------------------------------------------------------------------------

function DynamicIsland:_RefreshShadow()
	if not self.Alive then
		return
	end

	if self.Shadow then
		pcall(function()
			self.Shadow:Destroy()
		end)
		self.Shadow = nil
	end

	local Ok, Shadow = pcall(function()
		return New("UIShadow", {
			Color = Color3.new(0, 0, 0),
			BlurRadius = UDim.new(0, 22),
			Offset = UDim2.fromOffset(0, 8),
			Transparency = 0.55,
			Parent = self.Shell,
		})
	end)

	if Ok then
		self.Shadow = Shadow
	end
end

function DynamicIsland:Fit()
	if not self.Alive then
		return
	end

	local Available = self.Parent and math.max(self.Parent.AbsoluteSize.X - 8, 120) or math.huge
	local Design = self.Expanded and OpenW or PillW
	local Scale = math.clamp(Available / Design, 0.3, 1)
	if self.Config.Scale then
		Scale = Scale * self.Config.Scale
	end

	self.FitScale = Scale
	self.ShellScale.Scale = Scale
end

function DynamicIsland:_ApplyExpand(Instant)
	local Duration = Instant and 0 or 0.44

	if self.Shadow then
		pcall(function()
			self.Shadow:Destroy()
		end)
		self.Shadow = nil
	end

	self.Card.Visible = true
	self.PillWave.Visible = false
	self.PillHit.Visible = false
	self.HeaderHit.Visible = true
	self:Fit()

	Tween(self.Shell, Duration, { Size = UDim2.fromOffset(OpenW, OpenH) }, Ease, EaseOut):Play()
	Tween(self.ShellCorner, Duration, { CornerRadius = UDim.new(0, OpenRadius) }, Ease, EaseOut):Play()
	Tween(self.Cover, Duration, {
		Size = UDim2.fromOffset(OpenCover, OpenCover),
		Position = UDim2.fromOffset(OpenCoverAt.X, OpenCoverAt.Y),
	}, Ease, EaseOut):Play()
	Tween(self.CoverCorner, Duration, { CornerRadius = UDim.new(0, OpenCoverRadius) }, Ease, EaseOut):Play()
	Tween(self.Card, Instant and 0 or 0.26, { GroupTransparency = 0 }, Enum.EasingStyle.Quad, EaseOut):Play()

	task.delay(Duration + 0.02, function()
		self:_RefreshShadow()
	end)
end

function DynamicIsland:_ApplyCollapse(Instant)
	local Duration = Instant and 0 or 0.38

	if self.Shadow then
		pcall(function()
			self.Shadow:Destroy()
		end)
		self.Shadow = nil
	end

	self:Fit()

	Tween(self.Shell, Duration, { Size = UDim2.fromOffset(PillW, PillH) }, Ease, EaseOut):Play()
	Tween(self.ShellCorner, Duration, { CornerRadius = UDim.new(0, PillRadius) }, Ease, EaseOut):Play()
	Tween(self.Cover, Duration, {
		Size = UDim2.fromOffset(PillCover, PillCover),
		Position = UDim2.fromOffset(PillCoverAt.X, PillCoverAt.Y),
	}, Ease, EaseOut):Play()
	Tween(self.CoverCorner, Duration, { CornerRadius = UDim.new(0, PillCoverRadius) }, Ease, EaseOut):Play()
	Tween(self.Card, Instant and 0 or 0.14, { GroupTransparency = 1 }, Enum.EasingStyle.Quad, EaseIn):Play()

	task.delay(Instant and 0 or 0.18, function()
		if not self.Alive or self.Expanded then
			return
		end
		self.Card.Visible = false
		self.PillWave.Visible = true
		self.PillHit.Visible = true
		self.HeaderHit.Visible = false
	end)

	task.delay(Duration + 0.02, function()
		self:_RefreshShadow()
	end)
end

function DynamicIsland:Expand()
	if self.Expanded or not self.Alive then
		return
	end
	self.Expanded = true
	self:_ApplyExpand(false)
	if self.Config.OnExpand then
		pcall(self.Config.OnExpand, self)
	end
end

function DynamicIsland:Collapse()
	if not self.Expanded or not self.Alive then
		return
	end
	self.Expanded = false
	self:_ApplyCollapse(false)
	if self.Config.OnCollapse then
		pcall(self.Config.OnCollapse, self)
	end
end

function DynamicIsland:Toggle()
	if self.Expanded then
		self:Collapse()
	else
		self:Expand()
	end
end

---------------------------------------------------------------------------
-- public actions
---------------------------------------------------------------------------

function DynamicIsland:SelectSource(Index, Silent)
	Surface.SelectSource(self, Index, Silent)
end

function DynamicIsland:SetSource(Source)
	Surface.SetSource(self, Source)
end

function DynamicIsland:CycleSource()
	local Next_ = (self.SourceIndex % math.max(#self.Sources, 1)) + 1
	self:SelectSource(Next_)
end

function DynamicIsland:ToggleShuffle()
	self.Shuffled = not self.Shuffled
	local Provider = self.Provider
	if Provider then
		Provider.Shuffle = self.Shuffled
	end
	Tween(self.ShuffleChip, 0.18, { BackgroundTransparency = self.Shuffled and 0.1 or 0.35 }):Play()
end

function DynamicIsland:TogglePlay()
	local Provider = self.Provider
	if not Provider then
		return
	end
	if self.MusicState and self.MusicState.Playing then
		Provider:Pause()
	else
		Provider:Play()
	end
end

function DynamicIsland:Play()
	if self.Provider then
		self.Provider:Play()
	end
end

function DynamicIsland:Pause()
	if self.Provider then
		self.Provider:Pause()
	end
end

function DynamicIsland:Next()
	if self.Provider then
		self.Provider:Next()
	end
end

function DynamicIsland:Previous()
	if self.Provider then
		self.Provider:Previous()
	end
end

function DynamicIsland:Seek(Seconds)
	if self.Provider and self.Provider.Seek then
		self.Provider:Seek(Seconds)
	end
end

function DynamicIsland:SetVolume(Percent)
	self.Volume = math.clamp(Percent or 60, 0, 100)
	if self.Provider and self.Provider.SetVolume then
		self.Provider:SetVolume(self.Volume)
	end
end

function DynamicIsland:GetState()
	return self.MusicState
end

function DynamicIsland:Show()
	self.Shell.Visible = true
end

function DynamicIsland:Hide()
	self.Shell.Visible = false
end

function DynamicIsland:Destroy()
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

	Surface.Release(self)

	if self.Shell then
		self.Shell:Destroy()
		self.Shell = nil
	end
end

return DynamicIsland
