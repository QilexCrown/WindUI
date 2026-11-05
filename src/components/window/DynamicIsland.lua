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
-- Ported from the Novoline island: the shell is a 212 x 40 capsule with 28 px
-- artwork at (6, 6) and six 2 px bars on the right edge. Tapped it springs to
-- 476 x 204 (752 wide with the sources pane open): header strip with the source
-- and the ping, a 288 x 96 now-playing card with 72 px artwork, a 176 x 120 chip
-- grid, a 448 x 50 scrubber card with the transport, and the 360 x 154 sources
-- pane. Every size is a spring, every section fades in on a stagger, and the
-- cover morphs between the pill size and the card size on the same curve the
-- reference uses. Service plumbing lives in modules/MusicProviders.

local cloneref = (cloneref or clonereference or function(instance)
	return instance
end)

local UserInputService = cloneref(game:GetService("UserInputService"))
local RunService = cloneref(game:GetService("RunService"))
local Stats = cloneref(game:GetService("Stats"))

local Creator = require("../../modules/Creator")
local Surface = require("../../modules/MusicSurface")

local New = Creator.New
local Tween = Creator.Tween

local Medium = Font.new(Creator.Font, Enum.FontWeight.Medium)
local Bold = Font.new(Creator.Font, Enum.FontWeight.Bold)

local DynamicIsland = {}
DynamicIsland.__index = DynamicIsland

--------------------------------------------------------------------------
-- metrics, straight off the reference
--------------------------------------------------------------------------

local W, SW, AW, P = 476, 276, 288, 14
local SX, SWW = 378, 360
local HE, HC = 204, 40

local PILL_W, PILL_H = 212, 40
local BW = W - P * 2

-- Loading is a card, not a capsule: the same footprint as the mini strip, so
-- the label, the line under it and the bar all have room to breathe.
local LOAD_W, LOAD_H = 340, 88

-- Toasts ride the same surface as every other element: a card a touch
-- smaller than the mini strip, with an icon tile, a title and a line.
local TOAST_W, TOAST_H = 300, 76

-- The key prompt fills the card the player does: same width and height, so
-- switching between the two never resizes the capsule and the card never
-- carries a dead band where the music header used to be.
local KEY_W, KEY_H = W, HE
local KEY_Y = 0

local WHITE = Color3.new(1, 1, 1)
local SUBTLE = Color3.fromRGB(154, 156, 164)
local ACCENT = Color3.fromRGB(110, 220, 170)
local GREEN = Color3.fromRGB(52, 199, 89)
local RED = Color3.fromRGB(255, 92, 92)

-- The bench is monochrome: the only colour on screen comes from the artwork.
local TINT = {
	like = { Color3.fromRGB(20, 20, 22), WHITE },
	shuffle = { Color3.fromRGB(20, 20, 22), WHITE },
	sources = { Color3.fromRGB(20, 20, 22), WHITE },
	library = { Color3.fromRGB(20, 20, 22), WHITE },
}

local ICONS = {
	note = "lucide:music",
	pause = "sfsymbols:pauseFill",
	play = "sfsymbols:playFill",
	previous = "sfsymbols:backwardFill",
	next = "sfsymbols:forwardFill",
	shuffle = "lucide:shuffle",
	library = "lucide:library",
	pulse = "lucide:activity",
	clock = "lucide:clock",
	back = "sfsymbols:chevronLeft",
	check = "lucide:circle-check",
	key = "lucide:key",
	alert = "lucide:circle-alert",
	copy = "lucide:copy",
	link = "lucide:external-link",
	exit = "lucide:log-out",
}

local function Icon(IconName)
	local Data = Creator.Icon(ICONS[IconName] or IconName)
	return Data[1], Data[2]
end

local function Corner(Object, Radius)
	return New("UICorner", { Parent = Object, CornerRadius = UDim.new(0, Radius) })
end

local function Stroke(Object, Transparency)
	local Rim = New("UIStroke", {
		Parent = Object,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = WHITE,
		Thickness = 1,
		Transparency = Transparency or 0,
	})
	pcall(function()
		Rim.BorderStrokePosition = Enum.BorderStrokePosition.Inner
	end)
	return Rim
end

local function Gradient(Object, Rotation, Sequence)
	return New("UIGradient", { Parent = Object, Rotation = Rotation, Transparency = Sequence })
end

local function Sequence(...)
	local Keypoints = {}
	for _, Pair in ipairs({ ... }) do
		table.insert(Keypoints, NumberSequenceKeypoint.new(Pair[1], Pair[2]))
	end
	return NumberSequence.new(Keypoints)
end

local function Fade(From, To, Speed, Delta)
	return From + (To - From) * (1 - math.exp(-Speed * Delta))
end

local function Lerp(From, To, K)
	return From + (To - From) * K
end

local function Pop(Icon_)
	local Scale = Icon_:FindFirstChild("Pop") or New("UIScale", { Parent = Icon_, Name = "Pop" })
	Scale.Scale = 0.72
	Tween(Scale, 0.42, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out):Play()
end

--------------------------------------------------------------------------
-- fade groups: every descendant of a group is scaled toward full
-- transparency by the group's alpha, so a whole subtree can fade as one
--------------------------------------------------------------------------

local FX = { Groups = {}, ByFrame = setmetatable({}, { __mode = "k" }) }

FX.Props = {
	TextLabel = { "TextTransparency", "BackgroundTransparency" },
	TextButton = { "TextTransparency", "BackgroundTransparency" },
	TextBox = { "TextTransparency", "BackgroundTransparency" },
	ImageLabel = { "ImageTransparency", "BackgroundTransparency" },
	ImageButton = { "ImageTransparency", "BackgroundTransparency" },
	Frame = { "BackgroundTransparency" },
	UIStroke = { "Transparency" },
	UIShadow = { "Transparency" },
}

function FX.Group(Frame, Parent, Alpha)
	local Group = {
		Frame = Frame,
		Parent = Parent,
		Alpha = Alpha or 1,
		Live = false,
		Items = setmetatable({}, { __mode = "k" }),
		Base = setmetatable({}, { __mode = "k" }),
		Wrote = setmetatable({}, { __mode = "k" }),
	}
	table.insert(FX.Groups, Group)
	FX.ByFrame[Frame] = Group
	return Group
end

function FX.Set(Group, Alpha)
	if Group then
		Group.Alpha = Alpha
	end
end

function FX.Claim(Instance_)
	if not FX.Props[Instance_.ClassName] then
		return
	end
	local Node = Instance_
	while Node do
		local Group = FX.ByFrame[Node]
		if Group then
			Group.Items[Instance_] = true
			return
		end
		Node = Node.Parent
	end
end

function FX.Step()
	for _, Group in ipairs(FX.Groups) do
		local Effective, Node = Group.Alpha, Group.Parent
		while Node do
			Effective = Effective * Node.Alpha
			Node = Node.Parent
		end

		if Effective >= 0.999 then
			if Group.Live then
				Group.Live = false
				for Instance_, Wrote in pairs(Group.Wrote) do
					local Base = Group.Base[Instance_]
					if Base and Instance_.Parent then
						for Property, Value in pairs(Wrote) do
							if Base[Property] ~= nil and math.abs(Instance_[Property] - Value) < 1e-4 then
								Instance_[Property] = Base[Property]
							end
						end
					end
				end
				table.clear(Group.Wrote)
				table.clear(Group.Base)
			end
		elseif Group.Frame.Visible then
			Group.Live = true
			for Instance_ in pairs(Group.Items) do
				if Instance_.Parent then
					local Wrote, Base = Group.Wrote[Instance_], Group.Base[Instance_]
					if not Wrote then
						Wrote, Base = {}, {}
						Group.Wrote[Instance_], Group.Base[Instance_] = Wrote, Base
					end
					for _, Property in ipairs(FX.Props[Instance_.ClassName]) do
						local Current = Instance_[Property]
						local Last = Wrote[Property]
						if Last == nil or math.abs(Current - Last) > 1e-4 then
							Base[Property] = Current
						end
						local Value = 1 - (1 - Base[Property]) * Effective
						if math.abs(Value - Current) > 1e-4 then
							Instance_[Property] = Value
						end
						Wrote[Property] = Value
					end
				end
			end
		end
	end
end

--------------------------------------------------------------------------
-- construction
--------------------------------------------------------------------------

function DynamicIsland.New(Config)
	Config = Config or {}

	local self = setmetatable({
		Config = Config,
		WindUI = Config.WindUI,
		Parent = Config.Parent,
		Alive = true,
		Floating = Config.Parent == nil,
		Expanded = false,
		SideOpen = false,
		Liked = false,
		Shuffled = false,
		Born = os.clock(),
		Signals = {},
		Glass = {},
		Chips = {},
		ChipBy = {},
		Sections = {},
		Bars = {},
	}, DynamicIsland)

	local Folder = self.Parent or (self.WindUI and self.WindUI.ScreenGui)
	if not Folder then
		error("DynamicIsland: floating mode needs WindUI.ScreenGui, pass Config.Parent instead")
	end

	local State = self
	local KeepUntil = 0
	local Geo = ""
	local Peeking, Pressing = false, false
	local LeftAt, TouchAt = nil, nil
	local Touched = false
	local Width = { x = 120, v = 0, g = 120 }
	local Height = { x = 36, v = 0, g = 36 }
	local Expand = { a = 0, goal = 0, at = 0 }
	local Accent = Config.Accent or ACCENT
	local AccentLive = Accent
	local Beat, BeatTarget, BeatAcc = 0, 0, 0
	local Position, PositionAt, Duration = 0, 0, 0
	local Playing = false
	local Title, Artist, Cover, Hint = "", "", "", ""
	local ArtW, ArtH = 0, 0
	local Mode = "idle"
	local ToastUntil = 0
	local ValidUntil = 0
	local LoadedUntil = 0
	local LoadUntil, LoadDuration = 0, 0
	local HasTrack = false
	local PillMode
	local HeaderName = "Library"
	local KeyCfg = Config.KeySystem
	local Hidden, KeyGiven = false, false

	-- Roblox has no pixel reader for a texture, so colour is taken by
	-- rendering: a 1 x 1 crop of the sleeve stretched flat is that pixel's
	-- colour, whatever it happens to be. The header gives the size; without
	-- one, the top-left pixel is still a colour from the cover.
	local function Sample(FX, FY)
		if ArtW <= 0 or ArtH <= 0 then
			return Vector2.zero
		end
		local X = math.clamp(math.floor(ArtW * FX), 0, ArtW - 1)
		local Y = math.clamp(math.floor(ArtH * FY), 0, ArtH - 1)
		return Vector2.new(X, Y)
	end
	local ScrubDrag, ScrubRel = false, 0
	local GlassHeld = nil

	--------------------------------------------------------------- host

	local Host = New("Frame", {
		Name = "DynamicIslandHost",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ClipsDescendants = false,
		Parent = Folder,
	})
	self.Host = Host

	local Root = New("Frame", {
		Name = "DynamicIsland",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, Config.Top or (self.Floating and 10 or 0)),
		Size = UDim2.fromOffset(PILL_W, PILL_H),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Visible = false,
		ZIndex = 1,
		Parent = Host,
	})
	self.Root = Root

	-- Declared after Root: a closure made before the local existed would read
	-- the global of the same name and index nil on the first call.
	local function SetHidden(Value)
		Hidden = Value == true
		Root.Visible = not Hidden
	end

	local Corner_ = Corner(Root, 20)
	self.Corner = Corner_

	local GlassGrad = Gradient(Root, 90, NumberSequence.new(0))
	self.GlassGrad = GlassGrad

	-- One pixel of the sleeve, stretched over the whole shell: the island
	-- itself carries the cover's colour, not just the cards inside it.
	local RootWash = New("ImageLabel", {
		Parent = Root,
		Name = "RootWash",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Image = "",
		ImageRectSize = Vector2.new(1, 1),
		ImageTransparency = 1,
		ScaleType = Enum.ScaleType.Stretch,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2,
	})
	Corner(RootWash, 30)
	Gradient(RootWash, 90, Sequence({ 0, 1 }, { 0.5, 0.94 }, { 1, 0.82 }))

	local FxRoot = FX.Group(Root, nil, 1)
	self.FxRoot = FxRoot

	local Shadow, Contact
	pcall(function()
		Shadow = New("UIShadow", {
			Name = "DarkGlow",
			Color = Color3.new(0, 0, 0),
			BlurRadius = UDim.new(0, 38),
			Offset = UDim2.fromOffset(0, 16),
			Transparency = 1,
			ZIndex = -2,
			Parent = Root,
		})
		Contact = New("UIShadow", {
			Name = "Contact",
			Color = Color3.new(0, 0, 0),
			BlurRadius = UDim.new(0, 9),
			Offset = UDim2.fromOffset(0, 3),
			Transparency = 1,
			ZIndex = -1,
			Parent = Root,
		})
	end)
	self.Shadow, self.Contact = Shadow, Contact

	local Outline = New("Frame", {
		Parent = Root,
		Name = "Outline",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 30,
	})
	local OutlineCorner = Corner(Outline, 20)
	self.OutlineCorner = OutlineCorner
	local Edge = Stroke(Outline)
	Gradient(Edge, 90, Sequence({ 0, 0.8 }, { 0.5, 0.93 }, { 1, 0.89 }))

	local Hit = New("TextButton", {
		Parent = Root,
		Name = "Hit",
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 3,
	})
	self.Hit = Hit

	--------------------------------------------------------------- cover

	local CoverFrame = New("ImageLabel", {
		Parent = Root,
		Name = "Cover",
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		ScaleType = Enum.ScaleType.Crop,
		Image = "",
		Size = UDim2.fromOffset(28, 28),
		Position = UDim2.fromOffset(6, 6),
		ZIndex = 4,
	})
	local CoverGrad = Gradient(CoverFrame, 90, nil)
	CoverGrad.Color = ColorSequence.new(Color3.fromRGB(46, 46, 49), Color3.fromRGB(32, 32, 35))
	local CoverCorner = Corner(CoverFrame, 9)
	self.Cover = CoverFrame
	self.CoverGrad = CoverGrad
	self.CoverCorner = CoverCorner

	local Mark = New("ImageLabel", {
		Parent = CoverFrame,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.46, 0.46),
		ImageColor3 = SUBTLE,
		ZIndex = 5,
		ScaleType = Enum.ScaleType.Fit,
	})
	local MarkImage, MarkRect = Icon("note")
	Mark.Image, Mark.ImageRectOffset, Mark.ImageRectSize = MarkImage, MarkRect.ImageRectPosition, MarkRect.ImageRectSize
	self.Mark = Mark

	--------------------------------------------------------------- wave

	local Wave = New("Frame", {
		Parent = Root,
		Name = "Wave",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0.5),
		Size = UDim2.fromOffset(28, 22),
		Position = UDim2.new(1, -14, 0, 20),
		ZIndex = 4,
	})
	-- Plain solid bars. Colour comes from the cover tint in WaveStep, never from
	-- a slice of the artwork. No artwork, neutral bars.
	for Index = 1, 6 do
		local Bar = New("Frame", {
			Parent = Wave,
			Name = "Bar",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset((Index - 1) * 5 + 1.5, 11),
			Size = UDim2.fromOffset(3, 4),
			BackgroundColor3 = WHITE,
			BackgroundTransparency = 0,
			BorderSizePixel = 0,
			ClipsDescendants = true,
			ZIndex = 5,
		})
		Corner(Bar, 1.5)
		self.Bars[Index] = {
			Frame = Bar,
			Current = 0,
			Goal = 0,
			Height = 4,
			Weight = 0.55 + 0.45 * ((Index * 37) % 10) / 10,
		}
	end
	self.Wave = Wave

	--------------------------------------------------------------- generic pill

	-- The island is a surface; each mode brings its own element. Toast mode
	-- is a small card: icon tile, title, description. No artwork, no bars.
	local T = {}
	T.Tile = New("Frame", {
		Parent = Root,
		Name = "ToastTile",
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.93,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(16, 20),
		Size = UDim2.fromOffset(36, 36),
		Visible = false,
		ZIndex = 5,
	})
	Corner(T.Tile, 12)
	Stroke(T.Tile, 0.88).Color = WHITE
	T.Icon = New("ImageLabel", {
		Parent = T.Tile,
		Name = "Icon",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(18, 18),
		ScaleType = Enum.ScaleType.Fit,
		ImageColor3 = WHITE,
		ZIndex = 6,
	})
	T.Title = New("TextLabel", {
		Parent = Root,
		Name = "ToastTitle",
		BackgroundTransparency = 1,
		FontFace = Bold,
		TextSize = 14,
		TextColor3 = WHITE,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
		Position = UDim2.fromOffset(64, 16),
		Size = UDim2.fromOffset(TOAST_W - 80, 18),
		Visible = false,
		ZIndex = 5,
	})
	T.Desc = New("TextLabel", {
		Parent = Root,
		Name = "ToastDesc",
		BackgroundTransparency = 1,
		FontFace = Medium,
		TextSize = 11,
		TextColor3 = SUBTLE,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
		Position = UDim2.fromOffset(64, 36),
		Size = UDim2.fromOffset(TOAST_W - 80, 14),
		Visible = false,
		ZIndex = 5,
	})
	self.ToastTile, self.ToastIcon = T.Tile, T.Icon
	self.ToastTitle, self.ToastDesc = T.Title, T.Desc

	-- Loading is its own card: hub name, what is loading, percentage, and a
	-- bar along the bottom. No artwork, no icon.
	local LoadTitle = New("TextLabel", {
		Parent = Root,
		Name = "LoadTitle",
		BackgroundTransparency = 1,
		FontFace = Bold,
		TextSize = 15,
		TextColor3 = WHITE,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "Ender Hub",
		Position = UDim2.fromOffset(18, 13),
		Size = UDim2.fromOffset(LOAD_W - 36 - 74, 20),
		Visible = false,
		ZIndex = 5,
	})
	local LoadText = New("TextLabel", {
		Parent = Root,
		Name = "LoadText",
		BackgroundTransparency = 1,
		FontFace = Medium,
		TextSize = 11,
		TextColor3 = SUBTLE,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "Loading modules, ui...",
		Position = UDim2.fromOffset(18, 35),
		Size = UDim2.fromOffset(LOAD_W - 36, 16),
		Visible = false,
		ZIndex = 5,
	})
	local LoadPercent = New("TextLabel", {
		Parent = Root,
		Name = "LoadPercent",
		BackgroundTransparency = 1,
		FontFace = Medium,
		TextSize = 11,
		TextColor3 = SUBTLE,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "0%",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromOffset(LOAD_W - 18, 14),
		Size = UDim2.fromOffset(60, 18),
		Visible = false,
		ZIndex = 5,
	})
	local LoadTrack = New("Frame", {
		Parent = Root,
		Name = "LoadTrack",
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.84,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(18, LOAD_H - 22),
		Size = UDim2.fromOffset(LOAD_W - 36, 4),
		Visible = false,
		ZIndex = 5,
	})
	Corner(LoadTrack, 2)
	local LoadFill = New("Frame", {
		Parent = LoadTrack,
		Name = "Fill",
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.06,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(0, 4),
		ZIndex = 6,
	})
	Corner(LoadFill, 2)
	self.LoadTitle, self.LoadText, self.LoadPercent, self.LoadFill =
		LoadTitle, LoadText, LoadPercent, LoadFill

	-- Collapsed key mode: the pill says what is missing instead of showing
	-- artwork. Hidden again the moment the card opens.
	local KeyReqIcon = New("ImageLabel", {
		Parent = Root,
		Name = "KeyReqIcon",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(14, 11),
		Size = UDim2.fromOffset(18, 18),
		ScaleType = Enum.ScaleType.Fit,
		ImageColor3 = WHITE,
		Visible = false,
		ZIndex = 5,
	})
	local KeyReqSource, KeyReqRect = Icon("key")
	KeyReqIcon.Image, KeyReqIcon.ImageRectOffset, KeyReqIcon.ImageRectSize =
		KeyReqSource, KeyReqRect.ImageRectPosition, KeyReqRect.ImageRectSize
	local KeyReqText = New("TextLabel", {
		Parent = Root,
		Name = "KeyReqText",
		BackgroundTransparency = 1,
		FontFace = Bold,
		TextSize = 13,
		TextColor3 = WHITE,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "Key Required",
		Position = UDim2.fromOffset(38, 9),
		Size = UDim2.fromOffset(PILL_W - 52, 22),
		Visible = false,
		ZIndex = 5,
	})
	self.KeyReqIcon, self.KeyReqText = KeyReqIcon, KeyReqText

	local ValidIcon = New("ImageLabel", {
		Parent = Root,
		Name = "ValidIcon",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(14, 11),
		Size = UDim2.fromOffset(18, 18),
		ScaleType = Enum.ScaleType.Fit,
		ImageColor3 = GREEN,
		Visible = false,
		ZIndex = 5,
	})
	local ValidSource, ValidRect = Icon("check")
	ValidIcon.Image, ValidIcon.ImageRectOffset, ValidIcon.ImageRectSize =
		ValidSource, ValidRect.ImageRectPosition, ValidRect.ImageRectSize
	local ValidText = New("TextLabel", {
		Parent = Root,
		Name = "ValidText",
		BackgroundTransparency = 1,
		FontFace = Bold,
		TextSize = 13,
		TextColor3 = GREEN,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "Key Valid",
		Position = UDim2.fromOffset(38, 9),
		Size = UDim2.fromOffset(PILL_W - 52, 22),
		Visible = false,
		ZIndex = 5,
	})
	self.ValidIcon, self.ValidText = ValidIcon, ValidText

	-- Idle: the island never leaves the screen, so the resting capsule needs
	-- a face of its own. Same slot as the key and valid pills: mark, wordmark.
	local IdleIcon = New("ImageLabel", {
		Parent = Root,
		Name = "IdleIcon",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(14, 11),
		Size = UDim2.fromOffset(18, 18),
		ScaleType = Enum.ScaleType.Fit,
		ImageColor3 = ACCENT,
		Visible = false,
		ZIndex = 5,
	})
	local IdleSource, IdleRect = Icon("lucide:sparkles")
	IdleIcon.Image, IdleIcon.ImageRectOffset, IdleIcon.ImageRectSize =
		IdleSource, IdleRect.ImageRectPosition, IdleRect.ImageRectSize
	local IdleText = New("TextLabel", {
		Parent = Root,
		Name = "IdleText",
		BackgroundTransparency = 1,
		FontFace = Bold,
		TextSize = 13,
		TextColor3 = WHITE,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "Ender Hub",
		Position = UDim2.fromOffset(38, 9),
		Size = UDim2.fromOffset(PILL_W - 52, 22),
		Visible = false,
		ZIndex = 5,
	})
	self.IdleIcon, self.IdleText = IdleIcon, IdleText

	--------------------------------------------------------------- cards

	local Back = New("Frame", {
		Parent = Root,
		Name = "Cards",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(W + SW, HE),
		Visible = false,
		ZIndex = 2,
	})
	self.Back = Back
	local FxBack = FX.Group(Back, FxRoot, 0)
	self.FxBack = FxBack

	local function Card(Parent_, Name, X, Y, CardW, CardH)
		local Frame = New("Frame", {
			Parent = Parent_,
			Name = Name,
			BackgroundColor3 = WHITE,
			BackgroundTransparency = 0.955,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(X, Y),
			Size = UDim2.fromOffset(CardW, CardH),
			ZIndex = 2,
		})
		Corner(Frame, 16)
		local Rim = Stroke(Frame)
		Gradient(Rim, 90, Sequence({ 0, 0.84 }, { 0.5, 0.95 }, { 1, 0.9 }))
		return Frame, Rim
	end

	-- The glow under the cards is one pixel of the sleeve stretched flat: a
	-- solid colour, not the photograph, faded out by the gradient. Whatever
	-- the cover's own colour is, that is what the card glows with.
	local function Wash(Card_, Rotation, FadeSeq)
		local Frame = New("ImageLabel", {
			Parent = Card_,
			Name = "Wash",
			BackgroundColor3 = WHITE,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Image = "",
			ImageRectSize = Vector2.new(1, 1),
			ImageTransparency = 1,
			ScaleType = Enum.ScaleType.Stretch,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 3,
		})
		Corner(Frame, 16)
		Gradient(Frame, Rotation, FadeSeq)
		return Frame
	end

	local CardA = Card(Back, "NowPlaying", P, 36, AW, 96)
	local CardB = Card(Back, "Progress", P, 140, BW, 50)
	local CardS, CardSRim = Card(Back, "Side", SX, 36, SWW, 154)
	self.CardA, self.CardB, self.CardS, self.CardSRim = CardA, CardB, CardS, CardSRim

	local WashA = Wash(CardA, 90, Sequence({ 0, 1 }, { 0.55, 0.88 }, { 1, 0.28 }))
	local WashB = Wash(CardB, 90, Sequence({ 0, 1 }, { 0.5, 0.82 }, { 1, 0.1 }))
	self.WashA, self.WashB = WashA, WashB

	local ArtShade
	pcall(function()
		ArtShade = New("UIShadow", {
			Parent = CoverFrame,
			Name = "ArtShade",
			Color = Color3.new(0, 0, 0),
			BlurRadius = UDim.new(0, 14),
			Offset = UDim2.fromOffset(0, 5),
			Transparency = 1,
			ZIndex = -1,
		})
	end)
	self.ArtShade = ArtShade

	--------------------------------------------------------------- player

	local Player = New("Frame", {
		Parent = Root,
		Name = "Player",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, -6),
		Size = UDim2.fromOffset(W + SW, HE),
		ZIndex = 6,
		Visible = false,
	})
	self.Player = Player
	local FxPlayer = FX.Group(Player, FxRoot, 0)
	self.FxPlayer = FxPlayer

	local function Section(Name, X, Y, SectionW, SectionH, Delay)
		local Frame = New("Frame", {
			Parent = Player,
			Name = Name,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(X, Y),
			Size = UDim2.fromOffset(SectionW, SectionH),
			ZIndex = 7,
		})
		local Record = { Frame = Frame, X = X, Y = Y, Delay = Delay, K = 0, K0 = 0, Rise = -1 }
		table.insert(self.Sections, Record)
		return Frame, Record
	end

	local function Label(Parent_, FontFace, Size, Color, X, Y, LabelW, LabelH, Align)
		return New("TextLabel", {
			Parent = Parent_,
			BackgroundTransparency = 1,
			FontFace = FontFace,
			TextSize = Size,
			TextColor3 = Color,
			Text = "",
			Position = UDim2.fromOffset(X, Y),
			Size = UDim2.fromOffset(LabelW, LabelH),
			ZIndex = 8,
			TextXAlignment = Align or Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
	end

	local function Glyph(Parent_, Name, Size, Color, Z)
		local Image = New("ImageLabel", {
			Parent = Parent_,
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(Size, Size),
			ScaleType = Enum.ScaleType.Fit,
			ImageColor3 = Color or WHITE,
			ZIndex = Z or 9,
		})
		local Source, Rect = Icon(Name)
		Image.Image, Image.ImageRectOffset, Image.ImageRectSize = Source, Rect.ImageRectPosition, Rect.ImageRectSize
		return Image
	end

	--------------------------------------------------------------- header

	local Top = Section("Top", 0, 0, W + SW, 36, 0.03)

	local Tabs = New("Frame", {
		Parent = Top,
		Name = "Tabs",
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.95,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Position = UDim2.fromOffset(P + 6, 9),
		Size = UDim2.fromOffset(32, 22),
		ZIndex = 8,
	})
	Corner(Tabs, 11)
	local TabPill = New("Frame", {
		Parent = Tabs,
		Name = "Active",
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.86,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(3, 3),
		Size = UDim2.fromOffset(26, 16),
		ZIndex = 9,
	})
	Corner(TabPill, 8)
	local TabHit = New("TextButton", {
		Parent = Tabs,
		Name = "music",
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(3, 3),
		Size = UDim2.fromOffset(26, 16),
		ZIndex = 10,
	})
	Glyph(TabHit, "note", 15, WHITE, 11)

	local SourceLabel = Label(Top, Medium, 11, SUBTLE, P + 46, 9, 140, 22)
	self.SourceLabel = SourceLabel

	local Status = New("Frame", {
		Parent = Top,
		Name = "Status",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromOffset(W - P - 6, 9),
		Size = UDim2.fromOffset(220, 22),
		ZIndex = 8,
	})
	New("UIListLayout", {
		Parent = Status,
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 5),
	})

	local function StatusItem(Order, IconName)
		local Image = New("ImageLabel", {
			Parent = Status,
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(15, 15),
			ScaleType = Enum.ScaleType.Fit,
			ImageColor3 = SUBTLE,
			LayoutOrder = Order,
			ZIndex = 9,
		})
		local Source, Rect = Icon(IconName)
		Image.Image, Image.ImageRectOffset, Image.ImageRectSize = Source, Rect.ImageRectPosition, Rect.ImageRectSize
		return New("TextLabel", {
			Parent = Status,
			BackgroundTransparency = 1,
			FontFace = Medium,
			TextSize = 11,
			TextColor3 = SUBTLE,
			Text = "",
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 22),
			LayoutOrder = Order + 1,
			ZIndex = 9,
		})
	end

	local PingText = StatusItem(1, "pulse")
	New("Frame", { Parent = Status, BackgroundTransparency = 1, Size = UDim2.fromOffset(4, 1), LayoutOrder = 3 })
	local UptimeText = StatusItem(4, "clock")
	self.PingText, self.UptimeText = PingText, UptimeText

	--------------------------------------------------------------- now playing

	local Now, NowRecord = Section("Now", P, 36, AW, 96, 0.07)
	self.NowSection = NowRecord

	local ArtistLabel = Label(Now, Medium, 11, SUBTLE, 98, 16, AW - 110, 14)
	local TitleLabel = Label(Now, Bold, 15, WHITE, 98, 33, AW - 132, 20)
	self.ArtistLabel, self.TitleLabel = ArtistLabel, TitleLabel
	self.TitleWidth = AW - 132

	local StateIcon = Glyph(Now, "pause", 15, SUBTLE, 9)
	StateIcon.Position = UDim2.fromOffset(104, 70)
	local StateText = Label(Now, Medium, 11, SUBTLE, 114, 63, AW - 126, 14)
	self.StateIcon, self.StateText = StateIcon, StateText

	--------------------------------------------------------------- chips

	local Grid = Section("Grid", P + AW - 4, 24, 176, 120, 0.1)
	self.Grid = Grid

	local function ChipLayout(List, Strip)
		local Count, Out = #List, {}
		if Strip then
			local Y0 = math.floor((154 - (Count * 30 + (Count - 1) * 8)) / 2 + 0.5)
			for Index = 1, Count do
				Out[Index] = { 28, Y0 + (Index - 1) * 38, 30, 30 }
			end
		elseif Count == 1 then
			Out[1] = { 0, 0, 152, 96 }
		elseif Count == 2 then
			Out[1], Out[2] = { 0, 0, 152, 44 }, { 0, 52, 152, 44 }
		elseif Count == 3 then
			Out[1], Out[2], Out[3] = { 0, 0, 72, 44 }, { 80, 0, 72, 44 }, { 0, 52, 152, 44 }
		else
			for Index = 1, Count do
				Out[Index] = { ((Index - 1) % 2) * 80, ((Index - 1) // 2) * 52, 72, 44 }
			end
		end
		return Out
	end

	local function Chip(Key, Text_, IconName, OnClick)
		local Tint = TINT[Key]
		local Holder = New("Frame", {
			Parent = Grid,
			Name = "Chip",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(96, 68),
			Visible = false,
			ZIndex = 8,
		})

		local function Fire()
			KeepUntil = math.max(KeepUntil, os.clock() + 4)
			pcall(OnClick)
		end

		local Button_ = New("TextButton", {
			Parent = Holder,
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = Tint[1],
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(12, 12),
			Size = UDim2.fromOffset(72, 44),
			ZIndex = 20,
		})
		Corner(Button_, 14)
		Button_.Activated:Connect(Fire)

		local ChipIcon = Glyph(Button_, IconName, 15, Tint[2], 22)
		ChipIcon.Position = UDim2.fromOffset(16, 8)

		local ChipText = New("TextLabel", {
			Parent = Button_,
			BackgroundTransparency = 1,
			FontFace = Bold,
			TextSize = 11,
			TextColor3 = WHITE,
			Text = Text_,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 12, 1, -6),
			Size = UDim2.new(1, -20, 0, 12),
			ZIndex = 22,
		})

		local Record = {
			Key = Key,
			Holder = Holder,
			Button = Button_,
			Icon = ChipIcon,
			Text = ChipText,
			Tint = Tint,
			Base = Text_,
			IconName = IconName,
			Scale = New("UIScale", { Parent = Holder, Scale = 0.7 }),
			On = false,
			X = { x = 0, v = 0, g = 0 },
			Y = { x = 0, v = 0, g = 0 },
			W = { x = 72, v = 0, g = 72 },
			H = { x = 44, v = 0, g = 44 },
			A = { x = 0, v = 0, g = 0 },
			Pr = { x = 0, v = 0, g = 0 },
		}

		local function Pressed(Input)
			return Input.UserInputType == Enum.UserInputType.MouseButton1
				or Input.UserInputType == Enum.UserInputType.Touch
		end

		Button_.InputBegan:Connect(function(Input)
			if Pressed(Input) then
				Record.Pr.g = 100
			end
		end)
		Button_.InputEnded:Connect(function(Input)
			if Pressed(Input) then
				Record.Pr.g = 0
			end
		end)
		Button_.MouseLeave:Connect(function()
			Record.Pr.g = 0
		end)

		table.insert(self.Chips, Record)
		self.ChipBy[Key] = Record
		return Record
	end

	Chip("shuffle", "Shuffle", "shuffle", function()
		State:ToggleShuffle()
	end)
	Chip("library", "Library", "library", function()
		State:ToggleSide()
	end)

	--------------------------------------------------------------- scrubber

	local M = 8
	local Seek, SeekRecord = Section("Seek", P - M, 140 - M, BW + M * 2, 50 + M * 2, 0.13)
	self.SeekSection = SeekRecord
	self.TrackWidth = BW - 150

	local Track = New("Frame", {
		Parent = Seek,
		Name = "Track",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromOffset(M + 14, M + 18),
		Size = UDim2.fromOffset(self.TrackWidth, 5),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.82,
		BorderSizePixel = 0,
		ZIndex = 8,
	})
	Corner(Track, 3)

	local Fill = New("Frame", {
		Parent = Track,
		Name = "Fill",
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		ZIndex = 9,
	})
	New("UICorner", { Parent = Fill, CornerRadius = UDim.new(1, 0) })
	self.Track, self.Fill = Track, Fill

	local Elapsed = Label(Seek, Medium, 12, SUBTLE, M + 14, M + 26, 60, 16)
	local Remaining = Label(Seek, Medium, 12, SUBTLE, M + 14 + self.TrackWidth - 60, M + 26, 60, 16, Enum.TextXAlignment.Right)
	self.Elapsed, self.Remaining = Elapsed, Remaining

	local SeekHit = New("TextButton", {
		Parent = Seek,
		Name = "Seek",
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(M + 10, M + 4),
		Size = UDim2.fromOffset(self.TrackWidth + 8, 28),
		ZIndex = 11,
	})
	self.SeekHit = SeekHit

	local function GlassButton(Parent_, X, Y, Size, IconName, IconSize, OnClick)
		local Holder = New("Frame", {
			Parent = Parent_,
			Name = "Glass",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(X, Y),
			Size = UDim2.fromOffset(Size, Size),
			ZIndex = 8,
		})
		local Face = New("TextButton", {
			Parent = Holder,
			Name = "Face",
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = WHITE,
			BackgroundTransparency = 0.9,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
			ZIndex = 9,
		})
		New("UICorner", { Parent = Face, CornerRadius = UDim.new(1, 0) })
		Gradient(Face, 90, Sequence({ 0, 0 }, { 1, 0.3 }))
		local Rim = Stroke(Face)
		Gradient(Rim, 90, Sequence({ 0, 0.5 }, { 0.5, 0.86 }, { 1, 0.72 }))
		pcall(function()
			New("UIShadow", {
				Parent = Face,
				Name = "Drop",
				Color = Color3.new(0, 0, 0),
				BlurRadius = UDim.new(0, 8),
				Offset = UDim2.fromOffset(0, 2),
				Transparency = 0.62,
				ZIndex = -1,
			})
		end)

		local Record = {
			Holder = Holder,
			Face = Face,
			Icon = Glyph(Face, IconName, IconSize, WHITE, 11),
			Size = Size,
			Callback = OnClick,
			Scale = New("UIScale", { Parent = Holder }),
			OX = { x = 0, v = 0, g = 0 },
			OY = { x = 0, v = 0, g = 0 },
			S = { x = 100, v = 0, g = 100 },
			Lit = 0,
			Raw = Vector2.zero,
		}

		Face.MouseEnter:Connect(function()
			Record.Over = true
		end)
		Face.MouseLeave:Connect(function()
			Record.Over = false
		end)
		Face.InputBegan:Connect(function(Input)
			local Type_ = Input.UserInputType
			if Type_ ~= Enum.UserInputType.MouseButton1 and Type_ ~= Enum.UserInputType.Touch then
				return
			end
			Record.Hold, Record.Raw, Record.Touch = true, Vector2.zero, Type_ == Enum.UserInputType.Touch
			Record.Start = Vector2.new(Input.Position.X, Input.Position.Y)
			GlassHeld = Record
			KeepUntil = math.max(KeepUntil, os.clock() + 4)
		end)

		table.insert(self.Glass, Record)
		return Record
	end

	local CenterX = M + BW - 14
	local Previous = GlassButton(Seek, CenterX - 91, M + 25, 30, "previous", 20, function()
		State:Previous()
	end)
	local Play = GlassButton(Seek, CenterX - 53, M + 25, 38, "play", 22, function()
		State:TogglePlay()
	end)
	local NextButton = GlassButton(Seek, CenterX - 15, M + 25, 30, "next", 20, function()
		State:Next()
	end)
	self.PlayIcon = Play.Icon
	self.Transport = { { Record = Previous, DX = -91 }, { Record = Play, DX = -53 }, { Record = NextButton, DX = -15 } }

	--------------------------------------------------------------- sources pane

	local Side = New("Frame", {
		Parent = Player,
		Name = "Side",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Position = UDim2.fromOffset(SX, 36),
		Size = UDim2.fromOffset(SWW, 154),
		ZIndex = 7,
	})
	self.Side = Side
	local SideSection = { Frame = Side, X = SX, Y = 36, Delay = 0.17, K = 0, K0 = 0, Rise = -1, Move = false }
	table.insert(self.Sections, SideSection)
	self.SideSection = SideSection

	local SourcesPage = New("Frame", {
		Parent = Side,
		Name = "SourcesPage",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.fromOffset(SWW - 24, 154),
		Visible = false,
		ZIndex = 8,
	})
	self.SourcesPage = SourcesPage
	local FxSources = FX.Group(SourcesPage, FxPlayer, 0)
	self.FxSources = FxSources

	GlassButton(SourcesPage, 26, 22, 26, "back", 15, function()
		State:ToggleSide(false)
	end)

	local SourcesHead = Label(SourcesPage, Bold, 14, WHITE, 44, 12, SWW - 70, 20)
	SourcesHead.Text = "Library"

	local SourcesList = New("Frame", {
		Parent = SourcesPage,
		Name = "List",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 40),
		Size = UDim2.fromOffset(SWW - 24, 114),
		ZIndex = 9,
	})
	self.SourcesList = SourcesList
	local SideSpring = { x = 0, v = 0, g = 0 }

	--------------------------------------------------------------- key panel

	-- Same card, same origin as the player. While it is up the music sections
	-- fade out and this fades in on the same expansion curve, so the capsule
	-- never changes size between the two.
	local KeyPanel = New("Frame", {
		Parent = Root,
		Name = "KeyPanel",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, KEY_Y),
		Size = UDim2.fromOffset(KEY_W, KEY_H),
		Visible = false,
		ZIndex = 6,
	})
	self.KeyPanel = KeyPanel
	local FxKey = FX.Group(KeyPanel, FxRoot, 0)
	self.FxKey = FxKey

	-- The key card wears the same sleeve wash as the player cards, so the
	-- island keeps the cover's colour when it changes element.
	local WashK = Wash(KeyPanel, 90, Sequence({ 0, 1 }, { 0.32, 0.9 }, { 0.84, 0.62 }, { 1, 0.96 }))
	WashK.ZIndex = 2
	local WashKCorner = WashK:FindFirstChildWhichIsA("UICorner")
	if WashKCorner then
		WashKCorner.CornerRadius = UDim.new(0, 30)
	end

	-- Every key-card piece lives in one table: the island's New() is already
	-- near the Luau local-register ceiling and each extra local costs a slot.
	local K = {}
	local KeyPad = P
	local KeyInnerW = KEY_W - KeyPad * 2
	K.Pad, K.InnerW = KeyPad, KeyInnerW

	local function PaintGlyph(Image, Name)
		local Source, Rect = Icon(Name)
		Image.Image = Source
		Image.ImageRectOffset, Image.ImageRectSize = Rect.ImageRectPosition, Rect.ImageRectSize
	end

	-- Header: key tile on the left, name and note beside it, ping and load
	-- time parked in the top-right corner.
	local KeyTile = New("Frame", {
		Parent = KeyPanel,
		Name = "Tile",
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.93,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(KeyPad, 14),
		Size = UDim2.fromOffset(32, 32),
		ZIndex = 8,
	})
	Corner(KeyTile, 10)
	Stroke(KeyTile, 0.88).Color = WHITE
	local KeyTileIcon = New("ImageLabel", {
		Parent = KeyTile,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(16, 16),
		ScaleType = Enum.ScaleType.Fit,
		ImageColor3 = WHITE,
		ZIndex = 9,
	})
	PaintGlyph(KeyTileIcon, "key")

	K.Title = Label(KeyPanel, Bold, 15, WHITE, 56, 16, 216, 20)
	K.Title.Text = "Key System"

	K.Note = New("TextLabel", {
		Parent = KeyPanel,
		Name = "Note",
		BackgroundTransparency = 1,
		FontFace = Medium,
		TextSize = 10,
		TextColor3 = SUBTLE,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
		Position = UDim2.fromOffset(56, 37),
		Size = UDim2.fromOffset(230, 14),
		ZIndex = 8,
	})

	-- Ping and mount time, mirroring the header: an icon for each, laid out
	-- right to left in one auto-sized row.
	K.Stat = New("Frame", {
		Parent = KeyPanel,
		Name = "Stat",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromOffset(KEY_W - KeyPad, 16),
		Size = UDim2.fromOffset(0, 16),
		AutomaticSize = Enum.AutomaticSize.X,
		ZIndex = 8,
	})
	New("UIListLayout", {
		Parent = K.Stat,
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 6),
	})
	K.PingIcon = New("ImageLabel", {
		Parent = K.Stat,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(12, 12),
		ScaleType = Enum.ScaleType.Fit,
		ImageColor3 = SUBTLE,
		LayoutOrder = 1,
		ZIndex = 9,
	})
	PaintGlyph(K.PingIcon, "pulse")
	K.Ping = New("TextLabel", {
		Parent = K.Stat,
		BackgroundTransparency = 1,
		FontFace = Medium,
		TextSize = 10,
		TextColor3 = SUBTLE,
		Text = "",
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 14),
		LayoutOrder = 2,
		ZIndex = 9,
	})
	New("Frame", {
		Parent = K.Stat,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(8, 1),
		LayoutOrder = 3,
	})
	K.ClockIcon = New("ImageLabel", {
		Parent = K.Stat,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(12, 12),
		ScaleType = Enum.ScaleType.Fit,
		ImageColor3 = SUBTLE,
		LayoutOrder = 4,
		ZIndex = 9,
	})
	PaintGlyph(K.ClockIcon, "clock")
	K.Time = New("TextLabel", {
		Parent = K.Stat,
		BackgroundTransparency = 1,
		FontFace = Medium,
		TextSize = 10,
		TextColor3 = SUBTLE,
		Text = "",
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 14),
		LayoutOrder = 5,
		ZIndex = 9,
	})
	self.KeyStat = K.Stat
	self.KeyPing, self.KeyTime = K.Ping, K.Time

	-- Input row. The row itself is the thing that shakes; the field and the
	-- submit button ride inside it so an error moves both together.
	K.Row = New("Frame", {
		Parent = KeyPanel,
		Name = "Row",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(KeyPad, 58),
		Size = UDim2.fromOffset(KeyInnerW, 42),
		ZIndex = 7,
	})
	self.KeyRow = K.Row

	local KeyBox = New("Frame", {
		Parent = K.Row,
		Name = "KeyBox",
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.94,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(KeyInnerW, 42),
		ZIndex = 8,
	})
	Corner(KeyBox, 13)
	Stroke(KeyBox, 0.86).Color = WHITE

	K.Input = New("TextBox", {
		Parent = KeyBox,
		Name = "Input",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(14, 0),
		Size = UDim2.new(1, -14 - 104, 1, 0),
		FontFace = Medium,
		TextSize = 13,
		TextColor3 = WHITE,
		Text = "",
		PlaceholderText = "Enter Your Key",
		PlaceholderColor3 = SUBTLE,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		ClearTextOnFocus = false,
		ZIndex = 9,
	})
	self.KeyInput = K.Input

	-- The submit is inside the field, not beside it.
	K.Submit = New("TextButton", {
		Parent = KeyBox,
		Name = "Submit",
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -5, 0, 6),
		Size = UDim2.fromOffset(96, 30),
		ZIndex = 9,
	})
	Corner(K.Submit, 10)
	New("TextLabel", {
		Parent = K.Submit,
		BackgroundTransparency = 1,
		FontFace = Bold,
		TextSize = 12,
		TextColor3 = Color3.fromRGB(10, 10, 12),
		Text = "Submit",
		Size = UDim2.fromScale(1, 1),
		ZIndex = 10,
	})
	self.KeySubmit = K.Submit

	-- Error line: red, with the alert glyph before it. Both are hidden until
	-- there is something to say.
	K.ErrIcon = New("ImageLabel", {
		Parent = KeyPanel,
		Name = "ErrIcon",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(KeyPad + 2, 108),
		Size = UDim2.fromOffset(14, 14),
		ScaleType = Enum.ScaleType.Fit,
		ImageColor3 = RED,
		Visible = false,
		ZIndex = 8,
	})
	PaintGlyph(K.ErrIcon, "alert")

	K.Error = New("TextLabel", {
		Parent = KeyPanel,
		Name = "Error",
		BackgroundTransparency = 1,
		FontFace = Medium,
		TextSize = 11,
		TextColor3 = RED,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
		Position = UDim2.fromOffset(KeyPad + 22, 106),
		Size = UDim2.fromOffset(KeyInnerW - 22, 16),
		Visible = false,
		ZIndex = 8,
	})
	self.KeyError = K.Error

	local function SetKeyError(Message)
		local Text_ = Message and tostring(Message) or ""
		K.Error.Text = Text_
		K.Error.Visible = Text_ ~= ""
		K.ErrIcon.Visible = Text_ ~= ""
	end
	self.SetKeyError = SetKeyError

	-- The row shakes on a failed submit: a short damped sine on its X, run
	-- from FrameStep while the card is open.
	local KeyShakeUntil = 0
	local function HintFlash(Text_)
		K.Hint.Text = Text_
		task.delay(2, function()
			if State.Alive and Mode == "key" then
				K.Hint.Text = "Click the island to hide the key system"
			end
		end)
	end

	-- Three glass buttons under the field. Copy is dead-simple: link for Get
	-- Key, the key itself for Copy Key, a callback for Exit.
	local function KeyButton(Name, X, Width_, Text_, IconName)
		local Button = New("TextButton", {
			Parent = KeyPanel,
			Name = Name,
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = WHITE,
			BackgroundTransparency = 0.93,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(X, 128),
			Size = UDim2.fromOffset(Width_, 34),
			ZIndex = 8,
		})
		Corner(Button, 12)
		Stroke(Button, 0.88).Color = WHITE
		local Icon_ = New("ImageLabel", {
			Parent = Button,
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(14, 10),
			Size = UDim2.fromOffset(14, 14),
			ScaleType = Enum.ScaleType.Fit,
			ImageColor3 = WHITE,
			ZIndex = 9,
		})
		PaintGlyph(Icon_, IconName)
		New("TextLabel", {
			Parent = Button,
			BackgroundTransparency = 1,
			FontFace = Bold,
			TextSize = 11,
			TextColor3 = WHITE,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = Text_,
			Position = UDim2.fromOffset(36, 0),
			Size = UDim2.new(1, -44, 1, 0),
			ZIndex = 9,
		})
		Button.MouseEnter:Connect(function()
			Tween(Button, 0.16, { BackgroundTransparency = 0.84 }, Enum.EasingStyle.Quint, Enum.EasingDirection.Out):Play()
		end)
		Button.MouseLeave:Connect(function()
			Tween(Button, 0.16, { BackgroundTransparency = 0.93 }, Enum.EasingStyle.Quint, Enum.EasingDirection.Out):Play()
		end)
		return Button
	end

	local ButtonW = math.floor((KeyInnerW - 16) / 3)
	K.Get = KeyButton("GetKey", KeyPad, ButtonW, "Get Key", "link")
	K.Copy = KeyButton("CopyKey", KeyPad + ButtonW + 8, ButtonW, "Copy Key", "copy")
	K.Exit = KeyButton("Exit", KeyPad + (ButtonW + 8) * 2, ButtonW, "Exit", "exit")

	K.Hint = Label(KeyPanel, Medium, 10, SUBTLE, KeyPad, 174, KeyInnerW, 14)
	K.Hint.Text = "Click the island to hide the key system"

	K.Submit.MouseEnter:Connect(function()
		Tween(K.Submit, 0.18, { BackgroundTransparency = 0.12 }, Enum.EasingStyle.Quint, Enum.EasingDirection.Out):Play()
	end)
	K.Submit.MouseLeave:Connect(function()
		Tween(K.Submit, 0.18, { BackgroundTransparency = 0 }, Enum.EasingStyle.Quint, Enum.EasingDirection.Out):Play()
	end)
	-- One validator, three shapes: a function, a literal (or list), or the
	-- same service table the standalone key system takes. Anything else is a
	-- no, never an accidental yes.
	local function ValidKey(Key)
		if type(KeyCfg) ~= "table" then
			return false
		end
		if type(KeyCfg.KeyValidator) == "function" then
			local Ok, Result = pcall(KeyCfg.KeyValidator, Key)
			return Ok and Result == true
		end
		if KeyCfg.Key ~= nil then
			if type(KeyCfg.Key) == "table" then
				return table.find(KeyCfg.Key, Key) ~= nil
			end
			return tostring(KeyCfg.Key) == Key
		end
		if type(KeyCfg.API) == "table" then
			local Services = Config.WindUI and Config.WindUI.Services
			if not Services then
				return false
			end
			for _, Entry in next, KeyCfg.API do
				local Def = type(Entry) == "table" and Services[Entry.Type]
				if Def then
					local Ok, Result = pcall(function()
						local Args = {}
						for _, Name in next, Def.Args do
							table.insert(Args, Entry[Name])
						end
						local Service = Def.New(table.unpack(Args))
						return Service:Verify(Key) and true or false
					end)
					if Ok and Result then
						return true
					end
				end
			end
		end
		return false
	end

	local function SaveKey(Key)
		if not (KeyCfg.SaveKey and type(writefile) == "function") then
			return
		end
		local Path = KeyCfg.File
			or ((KeyCfg.Folder or Config.Folder or "Temp") .. "/" .. tostring(KeyCfg.Name or Config.Title or "WindUI") .. ".key")
		pcall(writefile, Path, Key)
	end

	local function SubmitKey()
		if Mode ~= "key" then
			return
		end
		local Key = tostring(K.Input.Text or "")
		if Key == "" then
			SetKeyError(KeyCfg.Empty or "Enter a key first.")
			KeyShakeUntil = os.clock() + 0.45
			return
		end
		local Ok, Valid = pcall(ValidKey, Key)
		if Ok and Valid then
			SetKeyError("")
			KeyShakeUntil = 0
			K.Row.Position = UDim2.fromOffset(KeyPad, 58)
			SaveKey(Key)
			State:KeyValid()
		else
			SetKeyError(KeyCfg.Invalid or "Invalid key.")
			KeyShakeUntil = os.clock() + 0.45
		end
	end

	local function Clip(Value)
		if type(setclipboard) ~= "function" then
			return false
		end
		return (pcall(setclipboard, tostring(Value)))
	end

	K.Get.Activated:Connect(function()
		if type(KeyCfg.GetKey) == "function" then
			local Ok, Err = pcall(KeyCfg.GetKey, State)
			if not Ok then
				SetKeyError(tostring(Err))
			end
			return
		end
		if type(KeyCfg.GetKey) == "string" and KeyCfg.GetKey ~= "" then
			if Clip(KeyCfg.GetKey) then
				HintFlash("Key link copied to clipboard.")
			else
				HintFlash(KeyCfg.GetKey)
			end
			return
		end
		HintFlash("No key link configured.")
	end)

	K.Copy.Activated:Connect(function()
		local Value = type(KeyCfg.Copy) == "string" and KeyCfg.Copy
			or (type(KeyCfg.Key) == "string" and KeyCfg.Key)
			or (type(KeyCfg.Key) == "table" and type(KeyCfg.Key[1]) == "string" and KeyCfg.Key[1])
			or nil
		if not Value then
			HintFlash("Nothing to copy.")
			return
		end
		if Clip(Value) then
			HintFlash("Key copied to clipboard.")
		else
			HintFlash("Clipboard unavailable.")
		end
	end)

	K.Exit.Activated:Connect(function()
		if type(KeyCfg.OnExit) == "function" then
			local Ok, Err = pcall(KeyCfg.OnExit, State)
			if not Ok then
				SetKeyError(tostring(Err))
			end
			return
		end
		State:HideKey()
	end)

	K.Input:GetPropertyChangedSignal("Text"):Connect(function()
		if (K.Error.Text or "") ~= "" then
			SetKeyError("")
		end
	end)

	K.Submit.Activated:Connect(SubmitKey)
	K.Input.FocusLost:Connect(function(Enter)
		if Enter then
			SubmitKey()
		end
	end)

	--------------------------------------------------------------- springs

	local function Spring(Value, Delta, Omega, Zeta)
		Delta = math.min(Delta, 0.1)
		local Steps = math.clamp(math.ceil(Delta * 240), 1, 24)
		local Step = Delta / Steps
		for _ = 1, Steps do
			Value.v += (-Omega * Omega * (Value.x - Value.g) - 2 * Zeta * Omega * Value.v) * Step
			Value.x += Value.v * Step
		end
		if math.abs(Value.x - Value.g) < 0.05 and math.abs(Value.v) < 0.5 then
			Value.x, Value.v = Value.g, 0
		end
	end

	local function Swift(Value, Delta, Response, Damping)
		Spring(Value, Delta, 2 * math.pi / Response, Damping)
	end

	local function Band(Delta, Limit, K)
		local Absolute = math.abs(Delta)
		if Absolute < 0.01 then
			return 0
		end
		return math.sign(Delta) * Limit * (1 - 1 / (Absolute * K / Limit + 1))
	end

	local function Quart(T)
		T = math.clamp(T, 0, 1)
		return 1 - (1 - T) ^ 4
	end

	--------------------------------------------------------------- state

	local function GoalSize()
		if State.Expanded then
			return { W + (State.SideOpen and SW or 0), HE }
		end
		if Mode == "loading" then
			return { LOAD_W, LOAD_H }
		end
		if Mode == "toast" then
			return { TOAST_W, TOAST_H }
		end
		return { PILL_W, PILL_H }
	end

	local function PointerOver(Margin)
		Margin = Margin or 0
		local Mouse = UserInputService:GetMouseLocation()
		local Position_, Size = Root.AbsolutePosition, Root.AbsoluteSize
		local Goal = GoalSize()
		local GoalW, GoalH = math.max(Size.X, Goal[1]), math.max(Size.Y, Goal[2])
		local CenterX_ = Position_.X + Size.X / 2
		return Mouse.X >= CenterX_ - GoalW / 2 - 10 - Margin
			and Mouse.X <= CenterX_ + GoalW / 2 + 10 + Margin
			and Mouse.Y >= Position_.Y - 14 - Margin
			and Mouse.Y <= Position_.Y + GoalH + 12 + Margin
	end
	self.PointerOver = PointerOver

	--------------------------------------------------------------- shape

	local function Shape(Delta)
		local Now = os.clock()
		local Goal = GoalSize()
		local GoalW, GoalH = Goal[1], Goal[2]
		if not State.Expanded then
			if Pressing then
				GoalW, GoalH = GoalW - 8, GoalH - 2
			elseif Peeking then
				GoalW, GoalH = GoalW + 16, GoalH + 4
			end
		end
		Width.g, Height.g = GoalW, GoalH

		local Omega, Zeta, OmegaH, ZetaH = 16, 0.97, 16, 0.97
		if State.Expanded then
			Omega, Zeta, OmegaH, ZetaH = 15, 0.72, 15, 0.72
		elseif Peeking or Pressing then
			Omega, Zeta, OmegaH, ZetaH = 18, 0.62, 18, 0.62
		end
		Spring(Width, Delta, Omega, Zeta)
		Spring(Height, Delta, OmegaH, ZetaH)

		local CurrentW = math.max(40, 2 * math.floor(Width.x / 2 + 0.5))
		local CurrentH = math.max(20, math.floor(Height.x + 0.5))
		local Key = CurrentW .. "," .. CurrentH
		if Key == Geo then
			return
		end
		Geo = Key

		local P_ = math.clamp((CurrentH - HC) / (HE - HC), 0, 1)
		Root.Size = UDim2.fromOffset(CurrentW, CurrentH)

		local CoverSize = math.floor(Lerp(28, 72, P_) + 0.5)
		local Pad = math.floor(Lerp(6, P + 12, P_) + 0.5)
		local CoverY = math.floor(Lerp((CurrentH - CoverSize) / 2, 48, P_) + 0.5)
		CoverFrame.Size = UDim2.fromOffset(CoverSize, CoverSize)
		CoverFrame.Position = UDim2.fromOffset(Pad, CoverY)
		CoverCorner.CornerRadius = UDim.new(0, math.floor(Lerp(9, 12, P_) + 0.5))

		Wave.Position = UDim2.fromOffset(
			math.floor(Lerp(CurrentW - 14, P + AW - 14, P_) + 0.5),
			math.floor(Lerp(CurrentH / 2, 54, P_) + 0.5)
		)
		Wave.Visible = P_ < 0.6 and Mode == "music" and HasTrack

		local Radius = math.floor(math.min(CurrentH / 2, Lerp(20, 30, P_)) + 0.5)
		Corner_.CornerRadius = UDim.new(0, Radius)
		OutlineCorner.CornerRadius = Corner_.CornerRadius
		State.P = P_
	end

	--------------------------------------------------------------- fade

	local function Sheet(Frame, Group, Alpha, Y)
		local Visible = Alpha > 0.001
		if Frame.Visible ~= Visible then
			Frame.Visible = Visible
		end
		FX.Set(Group, Alpha)
		if not Visible then
			return
		end
		if Frame.Position.Y.Offset ~= Y then
			Frame.Position = UDim2.fromOffset(0, Y)
		end
	end

	local function PaintShadow()
		if Shadow then
			pcall(function()
				Shadow.Transparency = 0.5
			end)
		end
		if Contact then
			pcall(function()
				Contact.Transparency = 0.62
			end)
		end
	end

	local GlassK = 0

	local function FadeStep(Delta, Now)
		local Ex = Expand
		if Ex.a ~= Ex.goal then
			Ex.a = Fade(Ex.a, Ex.goal, Ex.goal == 1 and 11 or 28, Delta)
			if math.abs(Ex.a - Ex.goal) < 0.01 then
				Ex.a = Ex.goal
			end
		end

		local Y = math.floor(-6 * (1 - Ex.a) + 0.5)
		local Alpha = Ex.a
		local Key = math.floor(Ex.a * 40 + 0.5) / 40
		-- Mode is part of the cache key: the key card needs its own flat fill.
		local GlassKey = Key + (Mode == "key" and 0.5 or 0)
		if GlassKey ~= GlassK then
			GlassK = GlassKey
			local M = 0.42 * Key
			-- The key card is a solid surface: the pill's bottom glass fade
			-- reads as a grey band over it once the card is this tall.
			GlassGrad.Transparency = Key <= 0 and NumberSequence.new(0)
				or (Mode == "key" and NumberSequence.new(0))
				or Sequence({ 0, 0 }, { 0.55, 0 }, { 0.62, 0.14 * M }, { 0.7, 0.5 * M }, { 0.78, 0.86 * M }, { 0.85, M }, { 1, M })
			PaintShadow()
		end

		Sheet(Player, FxPlayer, Mode == "key" and 0 or Alpha, Y)
		Sheet(Back, FxBack, Mode == "key" and 0 or Alpha, Y)

		-- The key card rides the same alpha as the player but keeps its own
		-- position: it is a sibling card, not a sliding sheet.
		local KeyAlpha = Mode == "key" and Alpha or 0
		FX.Set(FxKey, KeyAlpha)
		local KeyVisible = KeyAlpha > 0.001
		if KeyPanel.Visible ~= KeyVisible then
			KeyPanel.Visible = KeyVisible
		end
		if KeyVisible then
			local KeyTop = KEY_Y + Y
			if KeyPanel.Position.Y.Offset ~= KeyTop then
				KeyPanel.Position = UDim2.fromOffset(0, KeyTop)
			end
		end

		if Ex.at ~= State.SecAt then
			State.SecAt = Ex.at
			for _, Record in ipairs(State.Sections) do
				Record.K0 = Record.K
			end
		end

		local Open = Ex.goal == 1
		local Live = Player.Visible
		for _, Record in ipairs(State.Sections) do
			local K
			if Open then
				K = Record.K0 + (1 - Record.K0) * Quart((Now - Ex.at - Record.Delay) / 0.36)
			else
				K = math.min(Record.K, Ex.a)
			end
			Record.K = K
			local Frame = Record.Frame
			if Frame and Live and Record.Move ~= false then
				local Rise = math.floor(12 * (1 - K) * 2 + 0.5) / 2
				if Rise ~= Record.Rise then
					Record.Rise = Rise
					Frame.Position = UDim2.fromOffset(Record.X, Record.Y + Rise)
				end
			end
		end
	end

	--------------------------------------------------------------- header paint

	local function TopStep(Delta, Width_)
		local StatusX = math.floor(Width_ - P - 6 + 0.5)
		if Status.Position.X.Offset ~= StatusX then
			Status.Position = UDim2.fromOffset(StatusX, 9)
		end

		local Head = Mode == "key" and "Key System" or HeaderName
		if SourceLabel.Text ~= Head then
			SourceLabel.Text = Head
		end
	end

	local StatAt = 0
	local function StatusStep(Now)
		if Now - StatAt < 1 then
			return
		end
		StatAt = Now

		local Milliseconds
		local Ok, Value = pcall(function()
			return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
		end)
		if Ok and tonumber(Value) then
			Milliseconds = math.floor(tonumber(Value) + 0.5)
		end
		if not Milliseconds then
			Ok, Value = pcall(function()
				return game:GetService("Players").LocalPlayer:GetNetworkPing()
			end)
			if Ok and tonumber(Value) then
				Milliseconds = math.floor(tonumber(Value) * 1000 + 0.5)
			end
		end

		local Ping = Milliseconds and (Milliseconds .. " ms") or ""
		if PingText.Text ~= Ping then
			PingText.Text = Ping
		end

		local Up = math.max(0, math.floor(Now - State.Born))
		local UpText = Up < 60 and (Up .. "s")
			or (Up < 3600 and ((Up // 60) .. "m") or string.format("%dh %02dm", Up // 3600, (Up % 3600) // 60))
		if UptimeText.Text ~= UpText then
			UptimeText.Text = UpText
		end

		-- The key card's top-right corner: ping and how long the island has
		-- been up, on the same one-second tick as the header.
		if K.Ping.Text ~= Ping then
			K.Ping.Text = Ping
		end
		if K.Time.Text ~= UpText then
			K.Time.Text = UpText
		end
	end

	--------------------------------------------------------------- tint

	local TintC, TintP
	local function TintStep()
		local Art, P_ = Cover .. "@" .. ArtW .. "x" .. ArtH, State.P or 0
		if Art == TintC and P_ == TintP then
			return
		end
		TintC, TintP = Art, P_
		Art = Cover

		if Art ~= "" then
			local Centre = Sample(0.5, 0.5)
			WashA.Image, WashA.ImageTransparency = Art, 0.32 - 0.12 * P_
			WashB.Image, WashB.ImageTransparency = Art, 0.24 - 0.14 * P_
			WashA.ImageRectOffset, WashB.ImageRectOffset = Centre, Centre
			WashA.BackgroundTransparency, WashB.BackgroundTransparency = 1, 1
			WashK.Image, WashK.ImageTransparency = Art, 0.42 - 0.1 * P_
			WashK.ImageRectOffset = Centre
			WashK.BackgroundTransparency = 1
			RootWash.Image = Art
			RootWash.ImageRectOffset = Centre
			RootWash.ImageTransparency = 0.68 - 0.1 * P_
			RootWash.BackgroundTransparency = 1
		else
			WashA.Image, WashB.Image = "", ""
			WashA.BackgroundColor3, WashB.BackgroundColor3 = WHITE, WHITE
			WashA.BackgroundTransparency, WashB.BackgroundTransparency = 0.94, 0.9
			WashK.Image = ""
			WashK.BackgroundColor3 = WHITE
			WashK.BackgroundTransparency = 0.94
			RootWash.Image = ""
			RootWash.ImageTransparency = 1
		end

		if ArtShade then
			ArtShade.Transparency = 1 - 0.5 * P_
		end
	end

	--------------------------------------------------------------- wave

	local function WaveTint(Color)
		local H, S, V = Color:ToHSV()
		if S < 0.08 then
			return Color3.fromRGB(226, 226, 232)
		end
		return Color3.fromHSV(H, S * 0.58, math.max(V, 0.95))
	end

	local BarAcc = 0
	local function WaveStep(Delta)
		BarAcc += Delta
		if BarAcc >= 0.09 then
			BarAcc = 0
			for _, Bar in ipairs(State.Bars) do
				local Random = 0.45 + 0.55 * math.random()
				Bar.Goal = Playing and math.clamp(0.1 + 0.45 * Random + 0.6 * Beat * Bar.Weight * Random, 0, 1) or 0
			end
		end

		local Color = WaveTint(AccentLive)
		for _, Bar in ipairs(State.Bars) do
			Bar.Current = Fade(Bar.Current, Bar.Goal, Bar.Goal > Bar.Current and 28 or 10, Delta)
			local BarHeight = math.floor(4 + 15 * Bar.Current + 0.5)
			if Bar.Height ~= BarHeight then
				Bar.Height = BarHeight
				Bar.Frame.Size = UDim2.fromOffset(3, BarHeight)
			end
			if Bar.Tint ~= Color then
				Bar.Tint = Color
				Bar.Frame.BackgroundColor3 = Color
			end
		end
	end

	--------------------------------------------------------------- chips

	local function ChipStateStep()
		local Shuffle = State.ChipBy.shuffle
		local Library = State.ChipBy.library
		if Library then
			Library.Can, Library.On = true, State.SideOpen
		end
		if Shuffle then
			Shuffle.Can = State.Provider ~= nil and State.Provider.Shuffle ~= nil
			Shuffle.On = Shuffle.Can and State.Shuffled
		end
	end

	local ChipMask
	local function ChipStep(Delta)
		local Mask = State.SideOpen and 16 or 0
		for Index, Record in ipairs(State.Chips) do
			if Record.Can then
				Mask += 2 ^ (Index - 1)
			end
		end

		if Mask ~= ChipMask then
			ChipMask = Mask
			local List = {}
			for _, Record in ipairs(State.Chips) do
				if Record.Can then
					table.insert(List, Record)
				end
			end
			local Layout = ChipLayout(List, State.SideOpen)
			for Index, Record in ipairs(List) do
				local Target = Layout[Index]
				Record.X.g, Record.Y.g, Record.W.g, Record.H.g = Target[1], Target[2], Target[3], Target[4]
				if not Record.Placed then
					Record.X.x, Record.Y.x, Record.W.x, Record.H.x = Target[1], Target[2], Target[3], Target[4]
					Record.Placed = true
				end
			end
		end

		for _, Record in ipairs(State.Chips) do
			Record.A.g = Record.Can and 100 or 0
			Swift(Record.A, Delta, Record.Can and 0.34 or 0.22, 1)
			local Alpha = math.clamp(Record.A.x / 100, 0, 1)
			local Visible = Alpha > 0.02
			if Record.Holder.Visible ~= Visible then
				Record.Holder.Visible = Visible
			end
			if Visible then
				local Scale = math.floor((0.7 + 0.3 * Alpha) * 200 + 0.5) / 200
				if Scale ~= Record.LastScale then
					Record.LastScale = Scale
					Record.Scale.Scale = Scale
				end
				Swift(Record.X, Delta, 0.42, 0.82)
				Swift(Record.Y, Delta, 0.42, 0.82)
				Swift(Record.W, Delta, 0.42, 0.82)
				Swift(Record.H, Delta, 0.42, 0.82)
				local X, Y = math.floor(Record.X.x + 0.5), math.floor(Record.Y.x + 0.5)
				local ChipW, ChipH = math.floor(Record.W.x + 0.5), math.floor(Record.H.x + 0.5)
				if Record.Pr.g > 0 then
					Swift(Record.Pr, Delta, 0.1, 1)
				else
					Swift(Record.Pr, Delta, 0.32, 0.7)
				end
				local Depth = math.floor(math.max(0, Record.Pr.x) / 100 * 2.5 * 2 + 0.5) / 2
				local LK = math.floor((Record.LK or 0) * 50 + 0.5) / 50
				if X ~= Record.GX or Y ~= Record.GY or ChipW ~= Record.GW or ChipH ~= Record.GH or Depth ~= Record.GD or LK ~= Record.GLK then
					Record.GX, Record.GY, Record.GW, Record.GH, Record.GD, Record.GLK = X, Y, ChipW, ChipH, Depth, LK
					Record.Holder.Position = UDim2.fromOffset(X + 12 + ChipW / 2, Y + 12 + ChipH / 2)
					Record.Holder.Size = UDim2.fromOffset(ChipW + 24, ChipH + 24)
					Record.Button.Position = UDim2.fromOffset(12 + Depth, 12 + Depth)
					Record.Button.Size = UDim2.fromOffset(ChipW - Depth * 2, ChipH - Depth * 2)
					Record.Icon.Position = UDim2.fromOffset(math.floor(Lerp(18, ChipW / 2, LK) + 0.5), math.floor(Lerp(16, ChipH / 2, LK) + 0.5))
					Record.Text.TextTransparency = math.clamp(LK * 1.6, 0, 1)
				end
				if Record.On ~= Record.ShownOn then
					local First = Record.ShownOn == nil
					Record.ShownOn = Record.On
					local Tint = Record.Tint
					local Background = Record.On and Tint[1]:Lerp(Tint[2], 0.24) or Tint[1]
					Record.Text.Text = Record.Key == "like" and (Record.On and "Liked" or "Like") or Record.Base
					if First then
						Record.Button.BackgroundColor3 = Background
					else
						Tween(Record.Button, 0.26, { BackgroundColor3 = Background }, Enum.EasingStyle.Quint, Enum.EasingDirection.Out):Play()
					end
					Pop(Record.Icon)
				end
			end
		end
	end

	--------------------------------------------------------------- side pane

	local function SideStep(Delta)
		SideSpring.g = State.SideOpen and 100 or 0
		Swift(SideSpring, Delta, SideSpring.g > 0 and 0.5 or 0.3, 0.92)
		local S = math.clamp(SideSpring.x / 100, 0, 1)
		State.SideProgress = S
		local K = S * (SideSection.K or 0)
		local Slide = math.floor(18 * (1 - S) + 0.5)

		local Visible = K > 0.005
		if SourcesPage.Visible ~= Visible then
			SourcesPage.Visible = Visible
		end
		if Visible then
			FX.Set(FxSources, K)
			local X = 12 + Slide
			if SourcesPage.Position.X.Offset ~= X then
				SourcesPage.Position = UDim2.fromOffset(X, 0)
			end
		end

		local SideVisible = S > 0.005
		if CardS.Visible ~= SideVisible then
			CardS.Visible = SideVisible
		end
		if SideVisible then
			local Transparency = 1 - 0.045 * S
			if math.abs(CardS.BackgroundTransparency - Transparency) > 0.0005 then
				CardS.BackgroundTransparency = Transparency
				CardSRim.Transparency = 1 - S
			end
		end

		for _, Record in ipairs(State.Chips) do
			Record.LK = S
		end
	end

	--------------------------------------------------------------- glass

	local function GlassStep(Delta)
		for _, Record in ipairs(State.Glass) do
			local Held = Record.Hold == true
			Record.OX.g = Held and Band(Record.Raw.X, 7, 0.16) or 0
			Record.OY.g = Held and Band(Record.Raw.Y, 7, 0.16) or 0
			Record.S.g = Held and 90 or (Record.Over and 105 or 100)
			if Held then
				Swift(Record.OX, Delta, 0.12, 1)
				Swift(Record.OY, Delta, 0.12, 1)
				Swift(Record.S, Delta, 0.16, 0.86)
			else
				Swift(Record.OX, Delta, 0.45, 0.72)
				Swift(Record.OY, Delta, 0.45, 0.72)
				Swift(Record.S, Delta, 0.36, 0.66)
			end
			Record.Lit = Fade(Record.Lit, Held and 1 or (Record.Over and 0.5 or 0), Held and 30 or 12, Delta)

			local OX, OY = math.floor(Record.OX.x * 2 + 0.5) / 2, math.floor(Record.OY.x * 2 + 0.5) / 2
			if OX ~= Record.LX or OY ~= Record.LY then
				Record.LX, Record.LY = OX, OY
				Record.Face.Position = UDim2.new(0.5, OX, 0.5, OY)
			end
			local Scale = math.floor(Record.S.x * 5 + 0.5) / 500
			if Scale ~= Record.LS then
				Record.LS = Scale
				Record.Scale.Scale = Scale
			end
			local Transparency = math.floor((0.9 - 0.06 * Record.Lit) * 200 + 0.5) / 200
			if Transparency ~= Record.LB then
				Record.LB = Transparency
				Record.Face.BackgroundTransparency = Transparency
			end
		end
	end

	--------------------------------------------------------------- layout

	local LastLayout, LastArtist
	local function LayoutStep()
		local S = State.SideProgress or 0
		local Key = math.floor(S * 400 + 0.5)
		local ShowArtist = Artist ~= ""
		if Key == LastLayout and ShowArtist == LastArtist then
			return
		end
		LastLayout, LastArtist = Key, ShowArtist

		local CardAW = math.floor(Lerp(AW, 314, S) + 0.5)
		local CardBW = math.floor(Lerp(BW, 314, S) + 0.5)
		CardA.Size = UDim2.fromOffset(CardAW, 96)
		CardB.Size = UDim2.fromOffset(CardBW, 50)
		Now.Size = UDim2.fromOffset(CardAW, 96)
		State.TitleWidth = CardAW - 132

		if ArtistLabel.Visible ~= ShowArtist then
			ArtistLabel.Visible = ShowArtist
		end
		ArtistLabel.Size = UDim2.fromOffset(CardAW - 110, 14)
		TitleLabel.Size = UDim2.fromOffset(State.TitleWidth, 20)
		TitleLabel.Position = UDim2.fromOffset(98, ShowArtist and 33 or 25)
		StateText.Size = UDim2.fromOffset(CardAW - 126, 14)
		StateText.Position = UDim2.fromOffset(114, ShowArtist and 63 or 55)
		StateIcon.Position = UDim2.fromOffset(104, ShowArtist and 70 or 62)

		local TrackW = CardBW - 150
		State.TrackWidth = TrackW
		Seek.Size = UDim2.fromOffset(CardBW + M * 2, 50 + M * 2)
		Track.Size = UDim2.fromOffset(TrackW, 5)
		Remaining.Position = UDim2.fromOffset(M + 14 + TrackW - 60, M + 26)
		SeekHit.Size = UDim2.fromOffset(TrackW + 8, 28)
		local Center = M + CardBW - 14
		for _, Entry in ipairs(State.Transport) do
			Entry.Record.Holder.Position = UDim2.fromOffset(Center + Entry.DX, M + 25)
		end
	end

	--------------------------------------------------------------- progress

	local LastFill = 0
	local function ProgressStep(Delta)
		local Pos, Len = Position, Duration
		if ScrubDrag then
			Pos = ScrubRel * Len
		elseif Playing and Len > 0 then
			Pos = math.min(Len, Position + (os.clock() - PositionAt))
		end

		local Ratio = Len > 0 and math.clamp(Pos / Len, 0, 1) or 0
		if math.abs(Ratio - LastFill) > 0.0005 then
			LastFill = Ratio
			Fill.Size = UDim2.fromScale(Ratio, 1)
		end

		local ElapsedText = Surface.FormatTime(Pos)
		local RemainText = "-" .. Surface.FormatTime(math.max(Len - Pos, 0))
		if Elapsed.Text ~= ElapsedText then
			Elapsed.Text = ElapsedText
		end
		if Remaining.Text ~= RemainText then
			Remaining.Text = RemainText
		end
	end

	--------------------------------------------------------------- transport paint

	local PlayName
	local function PaintPlay()
		local Name = Playing and "pause" or "play"
		if PlayName == Name then
			return
		end
		local First = PlayName == nil
		PlayName = Name
		local Source, Rect = Icon(Name)
		State.PlayIcon.Image = Source
		State.PlayIcon.ImageRectOffset, State.PlayIcon.ImageRectSize = Rect.ImageRectPosition, Rect.ImageRectSize
		if not First then
			Pop(State.PlayIcon)
		end
	end

	local StateName
	local function PaintState()
		local Name = Playing and "play" or "pause"
		if StateName ~= Name then
			StateName = Name
			local Source, Rect = Icon(Name)
			StateIcon.Image = Source
			StateIcon.ImageRectOffset, StateIcon.ImageRectSize = Rect.ImageRectPosition, Rect.ImageRectSize
		end
		local Text_ = (Playing and "Playing" or "Paused") .. (State.Shuffled and "  \u{b7}  Shuffle" or "")
		if StateText.Text ~= Text_ then
			StateText.Text = Text_
		end
	end

	--------------------------------------------------------------- sources list

	local function RenderSources()
		local Provider = State.Provider
		if Provider then
			local Name = Provider.Name or "Library"
			if Name == "My files" then
				Name = "Library"
			end
			HeaderName = Name
			if Mode ~= "key" then
				SourceLabel.Text = Name
			end
		end

		for _, Child in ipairs(SourcesList:GetChildren()) do
			if Child:IsA("GuiObject") then
				Child:Destroy()
			end
		end

		for Index, Provider in ipairs(State.Sources) do
			local Active = Index == State.SourceIndex
			local Row = New("TextButton", {
				Parent = SourcesList,
				Text = "",
				AutoButtonColor = false,
				BackgroundColor3 = Active and Color3.fromRGB(30, 215, 96) or WHITE,
				BackgroundTransparency = Active and 0.88 or 0.95,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(0, (Index - 1) * 38),
				Size = UDim2.new(1, 0, 0, 34),
				ZIndex = 9,
			})
			Corner(Row, 12)

			local Tile = New("Frame", {
				Parent = Row,
				Name = "Tile",
				BackgroundColor3 = Active and Color3.fromRGB(30, 215, 96) or WHITE,
				BackgroundTransparency = Active and 0.82 or 0.92,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(8, 6),
				Size = UDim2.fromOffset(22, 22),
				ZIndex = 10,
			})
			Corner(Tile, 7)

			local Glyph_ = Glyph(Tile, Active and "play" or "library", 14, Active and Color3.fromRGB(30, 215, 96) or WHITE, 11)
			Glyph_.AnchorPoint = Vector2.new(0.5, 0.5)
			Glyph_.Position = UDim2.fromScale(0.5, 0.5)
			Glyph_.Size = UDim2.fromOffset(14, 14)

			New("TextLabel", {
				Parent = Row,
				BackgroundTransparency = 1,
				FontFace = Bold,
				TextSize = 12,
				TextColor3 = WHITE,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Text = Provider.Name == "My files" and "Library" or (Provider.Name or "Source"),
				Position = UDim2.fromOffset(40, 3),
				Size = UDim2.new(1, -108, 0, 15),
				ZIndex = 10,
			})

			New("TextLabel", {
				Parent = Row,
				BackgroundTransparency = 1,
				FontFace = Medium,
				TextSize = 10,
				TextColor3 = Active and Color3.fromRGB(30, 215, 96) or SUBTLE,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Text = Active and "Playing here" or (Provider.Status or "Ready"),
				Position = UDim2.fromOffset(40, 17),
				Size = UDim2.new(1, -58, 0, 13),
				ZIndex = 10,
			})

			if Active then
				local Dot = Glyph(Row, "pulse", 14, Color3.fromRGB(30, 215, 96), 10)
				Dot.AnchorPoint = Vector2.new(1, 0.5)
				Dot.Position = UDim2.new(1, -12, 0.5, 0)
				Dot.Size = UDim2.fromOffset(14, 14)
			end

			Row.Activated:Connect(function()
				KeepUntil = os.clock() + 4
				State:SelectSource(Index)
			end)
		end
	end
	self.RenderSources = RenderSources

	--------------------------------------------------------------- pill paint

	-- One owner for pill visibility. Shape only repaints when the capsule
	-- changes size, so every mode edge has to land here instead.
	local function PillStep()
		local Music = Mode == "music"
		local ShowArt = Music and HasTrack
		CoverFrame.Visible = ShowArt
		Wave.Visible = ShowArt and (State.P or 0) < 0.6

		local Toast = Mode == "toast"
		T.Tile.Visible = Toast
		T.Title.Visible = Toast
		T.Desc.Visible = Toast

		local Loading = Mode == "loading" and not State.Expanded
		LoadTitle.Visible = Loading
		LoadText.Visible = Loading
		LoadPercent.Visible = Loading
		LoadTrack.Visible = Loading

		-- Key mode, collapsed: the pill says what is missing. It steps aside
		-- the moment the card opens.
		local KeyReq = Mode == "key" and not State.Expanded
		KeyReqIcon.Visible = KeyReq
		KeyReqText.Visible = KeyReq

		local Valid = Mode == "valid" or Mode == "loaded"
		ValidIcon.Visible = Valid
		ValidText.Visible = Valid
		if Valid then
			ValidText.Text = Mode == "loaded" and "Script Loaded" or "Key Valid"
		end

		local Idle = Mode == "idle"
		IdleIcon.Visible = Idle
		IdleText.Visible = Idle
	end

	local function LoadStep()
		if Mode ~= "loading" then
			return
		end
		local Total = math.max(0.2, LoadDuration)
		local Left = math.max(0, LoadUntil - os.clock())
		local K = math.clamp(1 - Left / Total, 0, 1)
		local Percent = math.floor(K * 100 + 0.5) .. "%"
		if LoadPercent.Text ~= Percent then
			LoadPercent.Text = Percent
		end
		local BarW = math.floor((LOAD_W - 36) * K + 0.5)
		if LoadFill.Size.X.Offset ~= BarW then
			LoadFill.Size = UDim2.fromOffset(BarW, 4)
		end
	end

	--------------------------------------------------------------- public

	-- The island as a general surface: an icon, a title and a line, no music
	-- required. Duration in seconds; the island returns to now-playing on its
	-- own, or immediately through :Dismiss().
	function DynamicIsland:Toast(Options)
		if not self.Alive then
			return
		end
		Options = Options or {}
		local Duration = math.max(0.5, tonumber(Options.Duration) or 3)
		Mode, ToastUntil = "toast", os.clock() + Duration
		self.Mode = Mode
		SetHidden(false)

		if self.Expanded then
			self:Collapse()
		end

		local Source, Rect = Icon(Options.Icon or "note")
		T.Icon.Image = Source
		T.Icon.ImageRectOffset, T.Icon.ImageRectSize = Rect.ImageRectPosition, Rect.ImageRectSize
		T.Icon.ImageColor3 = Options.Color or WHITE
		T.Title.Text = tostring(Options.Title or Options.Text or "")
		T.Title.TextColor3 = Options.Color or WHITE
		local Description = tostring(Options.Description or Options.Desc or "")
		T.Desc.Text = Description
		T.Title.Position = UDim2.fromOffset(64, Description ~= "" and 16 or 27)
		PillStep()

		if self.Config.OnToast then
			pcall(self.Config.OnToast, self, Options)
		end
	end

	function DynamicIsland:Dismiss()
		if Mode ~= "toast" then
			return
		end
		Mode, ToastUntil = "idle", 0
		self.Mode = Mode
		if Config.HideWhenDone then
			SetHidden(true)
		end
		T.Icon.ImageColor3 = WHITE
		T.Title.TextColor3 = WHITE
		PillStep()
	end

	-- Loading: the card-sized state. Hub name, what is loading, the percent,
	-- and a bar along the bottom. The island flips itself to the key prompt
	-- when the timer runs out.
	function DynamicIsland:Loading(Duration, Label_)
		if not self.Alive then
			return
		end
		if self.Expanded then
			self:Collapse()
		end
		SetHidden(false)
		LoadDuration = math.max(0.2, tonumber(Duration) or 5)
		LoadUntil = os.clock() + LoadDuration
		LoadTitle.Text = tostring((type(KeyCfg) == "table" and KeyCfg.LoadingTitle) or "Ender Hub")
		LoadText.Text = tostring(Label_ or (type(KeyCfg) == "table" and KeyCfg.Loading) or "Loading modules, ui...")
		LoadPercent.Text = "0%"
		LoadFill.Size = UDim2.fromOffset(0, 4)
		Mode = "loading"
		self.Mode = Mode
		PillStep()
	end

	function DynamicIsland:SetProgress(Value)
		if Mode ~= "loading" then
			return
		end
		local K = math.clamp(tonumber(Value) or 0, 0, 1)
		LoadUntil = os.clock() + (1 - K) * math.max(0.2, LoadDuration)
		LoadPercent.Text = math.floor(K * 100 + 0.5) .. "%"
		LoadFill.Size = UDim2.fromOffset(math.floor((LOAD_W - 36) * K + 0.5), 4)
	end

	-- Stage line without restarting the bar. Loading() would zero the fill, so
	-- every later stage goes through here instead.
	function DynamicIsland:SetLoadingLabel(Text)
		if Mode ~= "loading" then
			return
		end
		LoadText.Text = tostring(Text or "")
	end

	-- Key prompt: the card at the content origin. Expanding is the show, so
	-- the ordinary island toggle hides and re-shows it with no extra state.
	function DynamicIsland:ShowKey()
		if not self.Alive or type(KeyCfg) ~= "table" then
			return
		end
		Mode = "key"
		self.Mode = Mode
		SetHidden(false)
		SetKeyError("")
		KeyShakeUntil = 0
		K.Row.Position = UDim2.fromOffset(KeyPad, 58)
		K.Note.Text = tostring(KeyCfg.Note or "Enter your key to unlock the interface.")
		K.Title.Text = tostring(KeyCfg.Title or "Key System")
		K.Input.PlaceholderText = tostring(KeyCfg.Placeholder or "Enter Your Key")
		K.Input.Text = ""
		PillStep()
		self:Expand()
	end

	function DynamicIsland:HideKey()
		if Mode ~= "key" then
			return
		end
		if self.Expanded then
			self:Collapse()
		end
	end

	function DynamicIsland:KeyValid()
		if not self.Alive then
			return
		end
		Mode = "valid"
		self.Mode = Mode
		KeyGiven = true
		local ValidFor = type(KeyCfg) == "table" and tonumber(KeyCfg.ValidFor) or nil
		ValidUntil = os.clock() + (ValidFor or 4)
		if self.Expanded then
			self:Collapse()
		end
		SetKeyError("")
		K.Input.Text = ""
		PillStep()
		if type(KeyCfg) == "table" and KeyCfg.Callback then
			pcall(KeyCfg.Callback, true)
		end
		if self.Config.OnKeyValid then
			pcall(self.Config.OnKeyValid, self)
		end
	end

	function DynamicIsland:DismissKey()
		if Mode ~= "valid" then
			return
		end
		Mode = "idle"
		self.Mode = Mode
		if Config.HideWhenDone then
			SetHidden(true)
		end
		PillStep()
	end

	function DynamicIsland:Expand()
		if self.Expanded or not self.Alive or Mode == "toast" then
			return
		end
		self.Expanded = true
		LeftAt = nil
		Expand.goal, Expand.at = 1, os.clock()
		PillStep()
		PaintState()
		PaintPlay()
		if self.Config.OnExpand then
			pcall(self.Config.OnExpand, self)
		end
	end

	function DynamicIsland:Collapse()
		if not self.Expanded or not self.Alive then
			return
		end
		self.Expanded = false
		self.SideOpen = false
		Expand.goal, Expand.at = 0, os.clock()
		PillStep()
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

	function DynamicIsland:ToggleSide(Force)
		if Force ~= nil then
			self.SideOpen = Force == true
		else
			self.SideOpen = not self.SideOpen
		end
		if self.SideOpen and not self.Expanded then
			self:Expand()
		end
	end

	function DynamicIsland:ToggleShuffle()
		self.Shuffled = not self.Shuffled
		local Provider = self.Provider
		if Provider then
			if type(Provider.Shuffle) == "function" then
				pcall(Provider.Shuffle, Provider, self.Shuffled)
			else
				Provider.Shuffle = self.Shuffled
			end
		end
		local Record = self.ChipBy.shuffle
		if Record then
			Record.On = self.Shuffled
		end
		PaintState()
	end

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

	function DynamicIsland:TogglePlay()
		local Provider = self.Provider
		if not Provider then
			return
		end
		if Playing then
			Provider:Pause(function() end)
		else
			Provider:Play(function() end)
		end
	end

	function DynamicIsland:Play()
		if self.Provider then
			self.Provider:Play(function() end)
		end
	end

	function DynamicIsland:Pause()
		if self.Provider then
			self.Provider:Pause(function() end)
		end
	end

	function DynamicIsland:Next()
		if self.Provider then
			self.Provider:Next(function() end)
		end
	end

	function DynamicIsland:Previous()
		if self.Provider then
			self.Provider:Previous(function() end)
		end
	end

	function DynamicIsland:Seek(Seconds)
		if self.Provider and self.Provider.Seek then
			self.Provider:Seek(Seconds, function() end)
		end
	end

	function DynamicIsland:SetVolume(Percent)
		if self.Provider and self.Provider.SetVolume then
			self.Provider:SetVolume(math.clamp(Percent or 60, 0, 100), function() end)
		end
	end

	function DynamicIsland:GetState()
		return self.MusicState
	end

	function DynamicIsland:Show()
		SetHidden(false)
	end

	-- Sticky: the frame loop re-shows the root every step, so a plain
	-- Root.Visible = false would come straight back.
	function DynamicIsland:Hide()
		SetHidden(true)
	end

	function DynamicIsland:RenderState(State_)
		self.MusicState = State_

		Title = State_.Title ~= "" and State_.Title or (State_.Hint or "Nothing playing")
		Artist = State_.Artist or ""
		Hint = State_.Hint or ""
		Playing = State_.Playing == true
		Duration = tonumber(State_.Duration) or 0
		Position = tonumber(State_.Position) or 0
		PositionAt = os.clock()

		if TitleLabel.Text ~= Title then
			TitleLabel.Text = Title
		end
		if ArtistLabel.Text ~= Artist then
			ArtistLabel.Text = Artist
		end

		ArtW = tonumber(State_.CoverW) or 0
		ArtH = tonumber(State_.CoverH) or 0

		local Track = State_.Title ~= nil and tostring(State_.Title) ~= ""
		if Track ~= HasTrack then
			HasTrack = Track
			PillStep()
		end

		local NewCover = State_.Cover or ""
		if Cover ~= NewCover then
			Cover = NewCover
			if Cover ~= "" then
				CoverFrame.Image = Cover
				Mark.Visible = false
				CoverGrad.Enabled = false
				CoverFrame.BackgroundTransparency = 1
			else
				CoverFrame.Image = ""
				Mark.Visible = true
				CoverGrad.Enabled = true
				CoverFrame.BackgroundTransparency = 0
			end
		end

		PaintPlay()
		PaintState()
	end

	function DynamicIsland:RenderError(Message)
		Hint = tostring(Message or "Unavailable")
		if ArtistLabel then
			ArtistLabel.Text = Hint
		end
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

		if self.Host then
			self.Host:Destroy()
			self.Host = nil
		end
		self.Root = nil
	end

	--------------------------------------------------------------- input

	Hit.Activated:Connect(function()
		Pressing, Peeking = false, false
		if Mode == "toast" then
			State:Dismiss()
		elseif Mode == "loading" or Mode == "idle" then
			return
		elseif Mode == "valid" then
			State:DismissKey()
		elseif State.Expanded then
			State:Collapse()
		else
			State:Expand()
		end
	end)

	Hit.InputBegan:Connect(function(Input)
		local Type_ = Input.UserInputType
		if Type_ == Enum.UserInputType.MouseButton2 or Type_ == Enum.UserInputType.MouseButton3 then
			if Mode ~= "idle" then
				State:Expand()
			end
		end
		if (Type_ == Enum.UserInputType.MouseButton1 or Type_ == Enum.UserInputType.Touch) and not State.Expanded then
			Pressing = true
		end
	end)

	Hit.MouseLeave:Connect(function()
		Pressing = false
	end)

	local function RelAt(X)
		return math.clamp((X - Track.AbsolutePosition.X) / math.max(1, Track.AbsoluteSize.X), 0, 1)
	end

	local function SeekTo(Rel)
		local Provider = State.Provider
		if Provider and Provider.Seek and Duration > 0 then
			pcall(Provider.Seek, Provider, Rel * Duration)
		end
		Position, PositionAt = Rel * Duration, os.clock()
	end

	SeekHit.InputBegan:Connect(function(Input)
		local Type_ = Input.UserInputType
		if Type_ == Enum.UserInputType.MouseButton1 or Type_ == Enum.UserInputType.Touch then
			ScrubDrag = true
			ScrubRel = RelAt(Input.Position.X)
		end
	end)

	table.insert(self.Signals, UserInputService.InputBegan:Connect(function(Input)
		local Type_ = Input.UserInputType
		if (Type_ == Enum.UserInputType.MouseButton1 or Type_ == Enum.UserInputType.Touch or Type_ == Enum.UserInputType.MouseWheel)
			and State.Expanded
			and PointerOver(28)
		then
			TouchAt = os.clock()
		end
	end))

	table.insert(self.Signals, UserInputService.InputChanged:Connect(function(Input)
		local Type_ = Input.UserInputType
		if Type_ == Enum.UserInputType.MouseWheel and State.Expanded and PointerOver(28) then
			TouchAt = os.clock()
		end
		local Moving = Type_ == Enum.UserInputType.MouseMovement or Type_ == Enum.UserInputType.Touch
		if ScrubDrag and Moving then
			ScrubRel = RelAt(Input.Position.X)
		end
		if GlassHeld and Moving then
			GlassHeld.Raw = Vector2.new(Input.Position.X, Input.Position.Y) - GlassHeld.Start
		end
	end))

	table.insert(self.Signals, UserInputService.InputEnded:Connect(function(Input)
		local Type_ = Input.UserInputType
		local Up = Type_ == Enum.UserInputType.MouseButton1 or Type_ == Enum.UserInputType.Touch
		if Up then
			Pressing = false
		end
		if ScrubDrag and Up then
			SeekTo(ScrubRel)
			ScrubDrag = false
		end
		local Record = GlassHeld
		if Record and Up then
			GlassHeld = nil
			Record.Hold = false
			local Distance = Record.Raw.Magnitude
			if Record.Callback and ((Record.Touch and Distance < 36) or (not Record.Touch and Record.Over and Distance < 60)) then
				pcall(Record.Callback)
			end
		end
	end))

	--------------------------------------------------------------- loop

	local function Hover(Now)
		local Open = State.Expanded
		if PointerOver(Open and 28 or 0) then
			LeftAt = nil
			Touched = true
			Peeking = not Open
		else
			Peeking = false
			if Open and Touched and not ScrubDrag and not GlassHeld and Mode ~= "key" and State.Config.AutoCollapse ~= false then
				local Busy = Now - (TouchAt or -9) < 1.2
					or Now - Expand.at < 0.6
					or math.abs(Width.v) > 40
					or math.abs(Height.v) > 40
				if Busy or not LeftAt then
					LeftAt = Now
				end
				if Now - LeftAt > 1 then
					State:Collapse()
				end
			end
		end
	end

	local function FrameStep(Delta)
		local Now = os.clock()

		if Mode == "toast" and Now >= ToastUntil then
			State:Dismiss()
		elseif Mode == "loading" and Now >= LoadUntil then
			-- Key first, when the hub is gated: the prompt replaces the pill the
			-- moment the bar fills, with no "loaded" claim before the key lands.
			if type(KeyCfg) == "table" and not KeyGiven then
				State:ShowKey()
			else
				Mode, LoadedUntil = "loaded", Now + (type(KeyCfg) == "table" and (tonumber(KeyCfg.LoadedFor) or 3) or 3)
				State.Mode = Mode
				PillStep()
			end
		elseif Mode == "loaded" and Now >= LoadedUntil then
			if Config.HideWhenDone then
				SetHidden(true)
			elseif type(KeyCfg) == "table" then
				State:ShowKey()
			else
				Mode = "idle"
				State.Mode = Mode
				PillStep()
			end
		elseif Mode == "valid" and Now >= ValidUntil then
			State:DismissKey()
		end

		if not Hidden and not Root.Visible then
			Root.Visible = true
		end

		BeatAcc += Delta
		if BeatAcc >= 0.12 then
			BeatAcc = 0
			BeatTarget = math.random()
		end
		Beat = Fade(Beat, BeatTarget, 6, Delta)

		Hover(Now)
		Shape(Delta)

		-- Shape only repaints when the capsule changes size, so the swap
		-- between artwork, toast, loading and valid happens on the mode edge.
		if PillMode ~= Mode then
			PillMode = Mode
			PillStep()
		end

		LoadStep()

		FadeStep(Delta, Now)

		if Expand.a > 0 then
			ProgressStep(Delta)
			PaintPlay()
			GlassStep(Delta)
			SideStep(Delta)
			LayoutStep()
			if KeyShakeUntil > 0 then
				local Left = KeyShakeUntil - Now
				if Left <= 0 then
					KeyShakeUntil = 0
					K.Row.Position = UDim2.fromOffset(KeyPad, 58)
				else
					local T = 1 - Left / 0.45
					local Offset = math.sin(T * math.pi * 9) * 7 * (1 - T)
					K.Row.Position = UDim2.fromOffset(math.floor(KeyPad + Offset + 0.5), 58)
				end
			end
			ChipStateStep()
			ChipStep(Delta)
			TopStep(Delta, Root.Size.X.Offset)
			StatusStep(Now)
			TintStep()
		end

		-- The pill's bars animate while collapsed too, so they run outside the
		-- expand gate the way the reference does.
		WaveStep(Delta)
	end

	local Connection = RunService.RenderStepped:Connect(function(Delta)
		if not State.Alive then
			return
		end
		local Ok, Err = pcall(FrameStep, Delta)
		if Ok then
			pcall(FX.Step)
		else
			warn("WindUI dynamic island: " .. tostring(Err))
		end
	end)
	self.Connection = Connection

	--------------------------------------------------------------- boot

	Root.Visible = true
	Expand.a, Expand.goal, Expand.at = 0, 0, os.clock()

	for _, Descendant in ipairs(Root:GetDescendants()) do
		FX.Claim(Descendant)
	end
	table.insert(self.Signals, Root.DescendantAdded:Connect(FX.Claim))

	-- Music is opt-in: an island created without a provider list is a pure
	-- surface (loading, key, toast, idle). No demo folder scan runs behind it.
	if type(Config.Providers) == "table" and #Config.Providers > 0 then
		Surface.Bind(self, Config)
	end
	PaintState()
	PaintPlay()

	if Config.Expanded then
		self.Expanded = false
		self:Expand()
	end

	-- Key system: the island owns the flow now. Loading pill for Delay
	-- seconds, then the key card; a saved key skips straight to the tick.
	if type(KeyCfg) == "table" then
		local Saved = KeyCfg.SavedKey
		if Saved ~= nil and ValidKey(tostring(Saved)) then
			self:KeyValid()
		else
			self:Loading(KeyCfg.Delay or 5, KeyCfg.Loading or "Loading")
		end
	end

	return self
end

return DynamicIsland
