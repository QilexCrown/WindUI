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
-- Ported from the Novoline "Now playing" card: 260 x 173, the header line and
-- the note glyph on the right, 56 px artwork at (18, 46), the title and artist
-- beside it, then three round controls on the bottom edge - 34 px previous and
-- next, 40 px play with the light face. Nothing here is wired to the dynamic
-- island; the two are separate elements that share provider plumbing only.

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

local W, H = 260, 173
local Radius = 24

local CoverSize = 56
local CoverAt = Vector2.new(18, 46)
local CoverRadius = 12

local ControlsY = H - 18 - 20

local Palette = {
	Shell = Color3.fromRGB(0, 0, 0),
	Text = Color3.fromRGB(255, 255, 255),
	Muted = Color3.fromRGB(154, 156, 164),
	Tile = Color3.fromRGB(40, 40, 44),
	Face = Color3.fromRGB(242, 242, 244),
	Ink = Color3.fromRGB(18, 18, 20),
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

-- "Artist - Song" and "Artist â€“ Song" both split the way the reference does.
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
			NumberSequenceKeypoint.new(0.34, 0.05),
			NumberSequenceKeypoint.new(0.58, 0.18),
			NumberSequenceKeypoint.new(0.8, 0.52),
			NumberSequenceKeypoint.new(1, 0.55),
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

	--------------------------------------------------------------- header

	local Heading = Text({
		Name = "Heading",
		Size = UDim2.fromOffset(200, 18),
		Position = UDim2.fromOffset(18, 16),
		Text = "Now playing",
		TextSize = 14,
		FontFace = Font.new(Creator.Font, Enum.FontWeight.Bold),
		ZIndex = 8,
		Parent = Shell,
	})
	self.Heading = Heading

	local NoteGlyph = Glyph("lucide:music", 16, Palette.Muted)
	NoteGlyph.Name = "Note"
	NoteGlyph.AnchorPoint = Vector2.new(1, 0)
	NoteGlyph.Position = UDim2.fromOffset(W - 18, 17)
	NoteGlyph.ZIndex = 8
	NoteGlyph.Parent = Shell

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
	CoverGlyph.Position = UDim2.fromOffset(17, 17)
	CoverGlyph.ZIndex = 6
	CoverGlyph.Parent = Cover

	self.Cover = Cover
	self.CoverGlyph = CoverGlyph

	--------------------------------------------------------------- titles

	local Title = Text({
		Name = "Title",
		Size = UDim2.fromOffset(156, 18),
		Position = UDim2.fromOffset(86, 54),
		Text = "Nothing playing",
		TextSize = 14,
		FontFace = Font.new(Creator.Font, Enum.FontWeight.Bold),
		ZIndex = 8,
		Parent = Shell,
	})
	self.TitleLabel = Title

	local Artist = Text({
		Name = "Artist",
		Size = UDim2.fromOffset(156, 16),
		Position = UDim2.fromOffset(86, 73),
		Text = "Pick a song from your library",
		TextSize = 12,
		TextColor3 = Palette.Muted,
		ZIndex = 8,
		Parent = Shell,
	})
	self.ArtistLabel = Artist

	--------------------------------------------------------------- transport

	local function Control(Name, CenterX, Size, Icon, GlyphSize, OnPress, Light)
		local Hit = Button({
			Name = Name,
			Size = UDim2.fromOffset(Size, Size),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(CenterX, ControlsY),
			BackgroundColor3 = Light and Palette.Face or Palette.Text,
			BackgroundTransparency = Light and 0 or 0.9,
			ZIndex = 10,
			Parent = Shell,
		})
		Corner(Hit, Size / 2)

		local Image = Glyph(Icon, GlyphSize, Light and Palette.Ink or Palette.Text)
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

	local Previous, PreviousIcon = Control("Previous", 64, 34, "sfsymbols:backwardFill", 14, function()
		self:Previous()
	end)
	local Play, PlayIcon = Control("Play", 110, 40, "sfsymbols:playFill", 16, function()
		self:TogglePlay()
	end, true)
	local NextButton, NextIcon = Control("Next", 162, 34, "sfsymbols:forwardFill", 14, function()
		self:Next()
	end)

	self.Previous, self.PreviousIcon = Previous, PreviousIcon
	self.Play, self.PlayIcon = Play, PlayIcon
	self.NextButton, self.NextIcon = NextButton, NextIcon

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
		else
			self.Cover.Image = ""
			self.Cover.BackgroundTransparency = 0
			self.CoverGlyph.Visible = true
		end
	end

	self.Previous.Visible = HasTrack
	self.NextButton.Visible = HasTrack
	self.PlayIcon.Image = Creator.Icon(Playing and "sfsymbols:pauseFill" or "sfsymbols:playFill")
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
