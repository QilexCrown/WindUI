-- Miniplayer - the music card, a floating widget you can drag anywhere.
--
--   local Player = WindUI:Miniplayer({
--       Providers = { "files", "spotify", "demo" },
--       Folder = "Ender Hub/songs",
--   })
--
--   -- docked inside a window instead of floating over the game:
--   local Player = WindUI:Miniplayer({ Parent = Tab.Frame })
--
-- Measured off the card the client runs: 300 x 162, radius 28, black at the
-- top that lets the world through down the card. 56 px artwork at (16, 16),
-- the title and artist beside it, a four-bar wave top right, the scrubber with
-- both times, then previous / play / next and the source disc. It has nothing
-- to do with the dynamic island - that is a separate element.

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

local W, H = 300, 162
local Radius = 28

local CoverSize = 56
local CoverAt = Vector2.new(16, 16)
local CoverRadius = 12

local BarW, BarH, BarGap = 3, 12, 3
local WaveRight = 18
local WaveTop = 29

local Palette = {
	Shell = Color3.fromRGB(0, 0, 0),
	Text = Color3.fromRGB(255, 255, 255),
	Muted = Color3.fromRGB(154, 156, 164),
	Hairline = Color3.fromRGB(255, 255, 255),
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
		HoverScale = 1,
		FitScale = 1,
		CoverId = nil,
		Volume = 60,
		Muted = false,
		SheetOpen = false,
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
			NumberSequenceKeypoint.new(0.32, 0.06),
			NumberSequenceKeypoint.new(0.55, 0.2),
			NumberSequenceKeypoint.new(0.78, 0.54),
			NumberSequenceKeypoint.new(1, 0.56),
		}),
		Parent = Shell,
	})

	pcall(function()
		New("UIShadow", {
			Color = Color3.new(0, 0, 0),
			BlurRadius = UDim.new(0, 16),
			Offset = UDim2.fromOffset(0, 6),
			Transparency = 0.6,
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
		BackgroundColor3 = Color3.fromRGB(22, 22, 26),
		BackgroundTransparency = 0,
		Image = "",
		ScaleType = Enum.ScaleType.Crop,
		ZIndex = 5,
		Parent = Shell,
	})
	Corner(Cover, CoverRadius)

	local CoverGlyph = Glyph("sfsymbols:musicNote", 22, Palette.Muted)
	CoverGlyph.Name = "Placeholder"
	CoverGlyph.Size = UDim2.fromScale(0.4, 0.4)
	CoverGlyph.Position = UDim2.fromScale(0.5, 0.5)
	CoverGlyph.AnchorPoint = Vector2.new(0.5, 0.5)
	CoverGlyph.ZIndex = 6
	CoverGlyph.Parent = Cover

	self.Cover = Cover
	self.CoverGlyph = CoverGlyph

	--------------------------------------------------------------- header

	local Title = Text({
		Name = "Title",
		Size = UDim2.fromOffset(180, 24),
		Position = UDim2.fromOffset(85, 22),
		Text = "Nothing playing",
		TextSize = 19,
		FontFace = Font.new(Creator.Font, Enum.FontWeight.Bold),
		ZIndex = 8,
		Parent = Shell,
	})
	self.TitleLabel = Title

	local Artist = Text({
		Name = "Artist",
		Size = UDim2.fromOffset(180, 18),
		Position = UDim2.fromOffset(85, 46),
		Text = "",
		TextSize = 13,
		TextColor3 = Palette.Muted,
		ZIndex = 8,
		Parent = Shell,
	})
	self.ArtistLabel = Artist

	local Wave = New("Frame", {
		Name = "Wave",
		Size = UDim2.fromOffset(BarW * 4 + BarGap * 3, BarH),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -WaveRight, 0, WaveTop),
		BackgroundTransparency = 1,
		ZIndex = 8,
		Parent = Shell,
	})
	self.Wave = Wave

	for Index = 1, 4 do
		local Bar = New("Frame", {
			Name = "Bar" .. Index,
			Size = UDim2.fromOffset(BarW, BarH),
			Position = UDim2.fromOffset((Index - 1) * (BarW + BarGap), 0),
			BackgroundColor3 = Palette.Text,
			BorderSizePixel = 0,
			ZIndex = 8,
			Parent = Wave,
		})
		Corner(Bar, 1.5)
	end

	--------------------------------------------------------------- scrubber

	local Elapsed = Text({
		Name = "Elapsed",
		Size = UDim2.fromOffset(44, 14),
		Position = UDim2.fromOffset(15, 86),
		Text = "0:00",
		TextSize = 12,
		TextColor3 = Palette.Muted,
		ZIndex = 8,
		Parent = Shell,
	})
	self.Elapsed = Elapsed

	local Remaining = Text({
		Name = "Remaining",
		Size = UDim2.fromOffset(44, 14),
		Position = UDim2.fromOffset(241, 86),
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
		Size = UDim2.fromOffset(186, 3),
		Position = UDim2.fromOffset(56, 92),
		BackgroundColor3 = Palette.Text,
		BackgroundTransparency = 0.82,
		BorderSizePixel = 0,
		ZIndex = 8,
		Parent = Shell,
	})
	Corner(Track, 2)
	self.Track = Track

	local Fill = New("Frame", {
		Name = "Fill",
		Size = UDim2.new(0, 0, 1, 0),
		BackgroundColor3 = Palette.Text,
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
		ZIndex = 9,
		Parent = Track,
	})
	Corner(Fill, 2)
	self.Fill = Fill

	local Scrub = Button({
		Name = "Scrub",
		Size = UDim2.new(1, 0, 0, 22),
		Position = UDim2.fromOffset(0, -10),
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

	--------------------------------------------------------------- transport

	local function Control(Name, CenterX, Icon, GlyphSize, OnPress)
		local Hit = Button({
			Name = Name,
			Size = UDim2.fromOffset(GlyphSize * 1.9, 26),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(CenterX, 130),
			ZIndex = 10,
			Parent = Shell,
		})

		local Image = Glyph(Icon, GlyphSize, Palette.Text)
		Image.AnchorPoint = Vector2.new(0.5, 0.5)
		Image.Position = UDim2.fromScale(0.5, 0.5)
		Image.ZIndex = 9
		Image.Parent = Hit

		Hit.MouseButton1Click:Connect(OnPress)
		Hit.MouseEnter:Connect(function()
			Tween(Image, 0.14, { ImageTransparency = 0.35 }, Enum.EasingStyle.Quad, EaseOut):Play()
		end)
		Hit.MouseLeave:Connect(function()
			Tween(Image, 0.16, { ImageTransparency = 0 }, Enum.EasingStyle.Quad, EaseOut):Play()
		end)

		return Image
	end

	Control("Previous", 93, "sfsymbols:backwardFill", 20, function()
		self:Previous()
	end)
	self.PlayIcon = Control("Play", 149, "sfsymbols:playFill", 20, function()
		self:TogglePlay()
	end)
	Control("Next", 205, "sfsymbols:forwardFill", 20, function()
		self:Next()
	end)

	local Disc = Button({
		Name = "Sources",
		Size = UDim2.fromOffset(18, 18),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(274, 130),
		BackgroundColor3 = Palette.Text,
		BackgroundTransparency = 0.35,
		ZIndex = 10,
		Parent = Shell,
	})
	Corner(Disc, 9)

	local DiscGlyph = Glyph("sfsymbols:ellipsis", 11, Color3.fromRGB(0, 0, 0))
	DiscGlyph.AnchorPoint = Vector2.new(0.5, 0.5)
	DiscGlyph.Position = UDim2.fromScale(0.5, 0.5)
	DiscGlyph.ZIndex = 11
	DiscGlyph.Parent = Disc

	--------------------------------------------------------------- sources

	local Sheet = New("Frame", {
		Name = "SourceSheet",
		Size = UDim2.fromOffset(276, 34),
		Position = UDim2.fromOffset(12, 74),
		BackgroundColor3 = Palette.Shell,
		BackgroundTransparency = 0.06,
		Visible = false,
		ClipsDescendants = true,
		ZIndex = 14,
		Parent = Shell,
	})
	Corner(Sheet, 18)
	New("UIStroke", {
		Color = Palette.Hairline,
		Transparency = 0.88,
		Thickness = 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = Sheet,
	})
	self.SourceSheet = Sheet

	local Rows = New("Frame", {
		Name = "Rows",
		Size = UDim2.new(1, -8, 1, -8),
		Position = UDim2.fromOffset(4, 4),
		BackgroundTransparency = 1,
		ZIndex = 15,
		Parent = Sheet,
	}, {
		New("UIListLayout", {
			Padding = UDim.new(0, 2),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	self.SourceRows = Rows

	Disc.MouseButton1Click:Connect(function()
		self:ToggleSources()
	end)

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

function Miniplayer:RenderSources()
	self.RowDetails = self.RowDetails or {}

	for Index, Provider in ipairs(self.Sources) do
		local Detail_ = self.RowDetails[Index]

		if not Detail_ then
			local Row = Button({
				Name = "Source" .. Index,
				Size = UDim2.fromOffset(268, 26),
				BackgroundColor3 = Palette.Text,
				BackgroundTransparency = 0.94,
				LayoutOrder = Index,
				ZIndex = 15,
				Parent = self.SourceRows,
			})
			Corner(Row, 13)

			Text({
				Name = "Label",
				Size = UDim2.fromOffset(150, 14),
				Position = UDim2.fromOffset(12, 6),
				Text = Provider.Name,
				TextSize = 12,
				ZIndex = 16,
				Parent = Row,
			})

			Detail_ = Text({
				Name = "Detail",
				Size = UDim2.fromOffset(80, 14),
				Position = UDim2.fromOffset(176, 6),
				Text = Provider.Status or "Ready",
				TextSize = 11,
				TextColor3 = Palette.Muted,
				TextXAlignment = Enum.TextXAlignment.Right,
				ZIndex = 16,
				Parent = Row,
			})

			self.RowDetails[Index] = Detail_
			self.Rows = self.Rows or {}
			self.Rows[Index] = Row

			Row.MouseButton1Click:Connect(function()
				self:SelectSource(Index)
				self:ToggleSources(false)
			end)
		end

		Detail_.Text = Index == self.SourceIndex and "Active" or (Provider.Status or "Ready")
		Detail_.TextColor3 = Index == self.SourceIndex and Palette.Text or Palette.Muted
		Tween(self.Rows[Index], 0.18, { BackgroundTransparency = Index == self.SourceIndex and 0.86 or 0.94 }):Play()
	end

	self.SourceSheet.Size = UDim2.fromOffset(276, #self.Sources * 28 + 8)
end

function Miniplayer:ToggleSources(Force)
	local Show = Force
	if Show == nil then
		Show = not self.SourceSheet.Visible
	end

	if Show then
		self.SourceSheet.Visible = true
		self.SourceSheet.BackgroundTransparency = 1
		Tween(self.SourceSheet, 0.18, { BackgroundTransparency = 0.06 }, Enum.EasingStyle.Quad, EaseOut):Play()
	else
		self.SourceSheet.Visible = false
	end
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

	table.insert(self.Signals or {}, MoveSignal)
	table.insert(self.Signals or {}, EndSignal)
end

---------------------------------------------------------------------------
-- state
---------------------------------------------------------------------------

function Miniplayer:RenderState(State)
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

	self.PlayIcon.Image = Creator.Icon(State.Playing == true and "sfsymbols:pauseFill" or "sfsymbols:playFill")
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
	if self.Provider and self.Provider.SetVolume then
		self.Provider:SetVolume(self.Muted and 0 or self.Volume)
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
