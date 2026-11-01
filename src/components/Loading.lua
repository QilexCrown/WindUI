local Creator = require("../modules/Creator")
local New = Creator.New
local Tween = Creator.Tween

--[[
	The boot element.

	It is the notification, copied line for line and then given a home at the
	top of the screen - but every colour on it is read from the theme that is
	selected, not from a palette of its own:

	  * the outer squircle is the theme's Accent, at the notification's own
	    0.05 transparency; the face over it is the theme's Dialog. A theme that
	    sets only Accent / Dialog / Outline / Text / Icon - the five keys every
	    theme pack in this library defines - lands on the element without a
	    single extra entry;
	  * a one-pixel UIStroke would be the obvious rim, but the surface is a
	    sliced squircle art, so a rectangle stroke would trace the bounding
	    box instead of the pill. The rim is the glass layer at the top edge
	    instead - the same highlight the rest of the library uses;
	  * the title is the theme's Text at 18 SemiBold, the content is the same
	    colour at 15 Medium and 0.42, the value is 14 Medium at 0.28;
	  * the bar is white by default - the ProgressBar element's geometry, 6 px
	    tall at radius 99, a track on Text at 0.9 - because a fill that inherits
	    Accent disappears the moment a theme puts Accent near the surface;
	  * the icon is the hub's own mark, tinted with the theme's Icon only when
	    the caller passes a lucide name instead of an asset id.

	Because every one of those is a theme tag, the element repaints with the
	active theme the moment it is set: switch to Warden Soul Light and the pill
	turns with it, no rebuild.

	The arrival: the element is not slid into place, it is formed.

	It is born as a dot - a real circle, because the corner radius is set to
	half the dot and DynamicShape then picks its Circle art - pinned to the
	top edge, where the pill is going to live. The dot lengthens into a short
	droplet, and then a single damped spring carries it out into the full
	width. Width, height and corner radius are all read off that one spring
	value, so at no point is the element a rectangle being resized: it is a
	blob whose corners are still rounding off while it spreads, and it passes
	through the library's Circle, SquircleV and SquircleH art on the way. The
	spring is underdamped on purpose - it overshoots by about two percent and
	then settles in shrinking swings, which is the wide-narrow-wide read of
	the reference.

	The hover is the same motion language, at a smaller scale. The pointer does
	not resize the element and it is not eased into a new shape and parked
	there - it is released, and damped springs carry it out and ring it back.
	The reach is split between the two edges from where the pointer came in,
	so the pill stretches out of the side that was touched and the far edge
	follows late; wherever the width is away from its target the height gives
	up a few pixels and the corners take them on, which is why it reads as a
	surface holding its own volume rather than a box being scaled. Zeta 0.56
	leaves two or three visible swings, the wide-narrow-wide settle the
	reference has. All of it is pixels and two transparencies: there is no
	colour in the response, so it reads the same in every theme the element is
	mounted under.

	Nothing here reads or writes the notification module. A live toast and the
	boot element can share the screen and no state is shared between them.
]]

local LoadingModule = {
	-- Every child is positioned from these at build time.
	Width = 360,
	Height = 86,
	UICorner = 18, -- the notification's corner, not a capsule
	UIPadding = 14, -- the notification's padding
	IconSize = 26, -- the notification's icon slot
	BarHeight = 6, -- the ProgressBar element's bar
	MarginTop = 14,

	-- The icon an element gets when the caller passes none. The hub's own mark.
	DefaultIcon = "rbxassetid://84919257334887",

	-- The dot the element is born as, and the droplet it lengthens into
	-- before it spreads. Both in pixels.
	DotSize = 18,
	DotDrop = 32,
	DotTime = 0.14, -- seconds to lengthen, before the spread spring takes over

	-- The spread. The width spring sits at zeta 0.78 - an overshoot of about
	-- two percent - and the height spring is softer, at zeta 0.65, because
	-- the reference's vertical swing is proportionally larger than its
	-- horizontal one. Both settle in roughly 0.4 s.
	SpreadStiffness = 170,
	SpreadDamping = 20.4,
	HeightStiffness = 150,
	HeightDamping = 16,

	-- The glass sheen settles to this transparency once the shape has formed.
	-- 1 is invisible, 0 is opaque white.
	GlassTransparency = 0.86,

	-- The face: the theme's Dialog over the theme's Accent. At 0 the face is
	-- solid Dialog and the accent never shows; at 1 the face is gone.
	FaceTransparency = 0.35,

	-- Fade and bar timing, in seconds.
	FadeTime = 0.20,
	BarTime = 0.20,

	-- Hover. The pointer does not resize the element - it releases it, and a
	-- damped spring carries the surface out and rings it back. The reach is
	-- split between the two edges by where the pointer entered, so the pill
	-- stretches out of the side that was touched and the far edge barely
	-- moves, which is how a body of liquid moves: the near wall travels and
	-- the rest follows late.
	HoverReach = 36, -- total pixels added to the width at full throw
	HoverLift = 3, -- pixels the whole surface rises
	HoverSheen = 0.14, -- how much brighter the glass highlight goes
	SquashAmount = 3, -- pixels the height loses at peak stretch
	RadiusBulge = 5, -- extra corner radius while the surface is deformed
	ReachDeviation = 30, -- width error, in pixels, that counts as a full squash
	ReachStiffness = 240,
	ReachDamping = 17.4, -- zeta 0.56: two or three visible swings, then rest
	HoverDeadband = 0.06, -- how far off centre the pointer must be to pick a side
	SpringStiffness = 190,
	SpringDamping = 22, -- under 2*sqrt(stiffness): one soft overshoot, no wobble

	Holder = nil,
	LoadingIndex = 0,
	Loadings = {},
}

local function GuiInset()
	local Inset = 0
	pcall(function()
		Inset = game:GetService("GuiService"):GetGuiInset().Y
	end)
	if type(Inset) ~= "number" or Inset ~= Inset then
		Inset = 0
	end
	return Inset
end

local function TopOffset()
	return GuiInset() + LoadingModule.MarginTop
end

function LoadingModule.Init(Parent)
	local Module = {}

	-- The notification screen ignores the gui inset, so the holder has to
	-- clear the topbar itself or the element lands under it.
	Module.Frame = New("Frame", {
		Name = "LoadingHolder",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, TopOffset()),
		Size = UDim2.new(0, LoadingModule.Width, 0, LoadingModule.Height),
		BackgroundTransparency = 1,
		ZIndex = 50,
		Parent = Parent,
	})

	LoadingModule.Holder = Module
	return Module
end

function LoadingModule.New(Config)
	Config = Config or {}

	local Loading = {
		__type = "Loading",
		Title = Config.Title or "Loading",
		Content = Config.Content or "",
		Icon = Config.Icon or LoadingModule.DefaultIcon,
		IconThemed = Config.IconThemed,
		Progress = nil,
		Closed = false,
		Ready = false, -- arrival finished; the hover spring may steer the surface
		Hovered = false, -- the pointer, tracked even before Ready so a hover that
		-- starts mid-arrival is picked up rather than dropped
		Connections = {},
		UIElements = {},
	}

	LoadingModule.LoadingIndex = LoadingModule.LoadingIndex + 1
	LoadingModule.Loadings[LoadingModule.LoadingIndex] = Loading

	local Holder = Config.Holder or (LoadingModule.Holder and LoadingModule.Holder.Frame)
	if not Holder then
		error("WindUI.Loading: no holder parent", 0)
	end

	-- Resolved on every build, not only at load: an executor can answer a zero
	-- inset while the module is initialising and the holder would then park
	-- under the Roblox topbar for the rest of the session.
	if LoadingModule.Holder and Holder == LoadingModule.Holder.Frame then
		Holder.Position = UDim2.new(0.5, 0, 0, TopOffset())
	end

	local Width = LoadingModule.Width
	local Height = LoadingModule.Height
	local Pad = LoadingModule.UIPadding
	local Corner = LoadingModule.UICorner

	-- The text column clears the icon only when there is one, so an iconless
	-- element gets the full width instead of a dead gutter.
	local TextX = Pad + (Loading.Icon and (LoadingModule.IconSize + 16) or 0)
	local TextW = Width - TextX - Pad

	local TitleH = 22
	local ContentY = Pad + TitleH + 5
	local PercentW = 54
	local BarY = Height - Pad - LoadingModule.BarHeight

	local Icon
	if Loading.Icon then
		Icon = Creator.Image(Loading.Icon, Loading.Title .. ":" .. Loading.Icon, 0, Config.Window, "Loading", Loading.IconThemed)
		Icon.Name = "Icon"
		Icon.Size = UDim2.new(0, LoadingModule.IconSize, 0, LoadingModule.IconSize)
		-- Centred on the two text lines, not pinned to the top edge: the
		-- notification's icon sits level with its single title, this one has
		-- a second line under it.
		Icon.Position = UDim2.new(0, Pad, 0, Pad + (ContentY + 20 - Pad - LoadingModule.IconSize) / 2)
		Icon.ZIndex = 52
	end

	-- Title: the notification's own type ramp.
	local Title = New("TextLabel", {
		Name = "Title",
		Position = UDim2.new(0, TextX, 0, Pad),
		Size = UDim2.new(0, TextW - PercentW - 6, 0, TitleH),
		TextXAlignment = "Left",
		TextYAlignment = "Top",
		TextTruncate = "AtEnd",
		RichText = true,
		BackgroundTransparency = 1,
		TextSize = 18,
		Text = Loading.Title,
		FontFace = Font.new(Creator.Font, Enum.FontWeight.SemiBold),
		ZIndex = 52,
		ThemeTag = {
			TextColor3 = "Text",
		},
	})

	-- Content: the notification's second line, same tag, same 0.4 wash.
	local Content = New("TextLabel", {
		Name = "Content",
		Position = UDim2.new(0, TextX, 0, ContentY),
		Size = UDim2.new(0, TextW, 0, 20),
		TextXAlignment = "Left",
		TextYAlignment = "Top",
		TextTruncate = "AtEnd",
		RichText = true,
		BackgroundTransparency = 1,
		TextSize = 15,
		Text = Loading.Content,
		FontFace = Font.new(Creator.Font, Enum.FontWeight.Medium),
		ZIndex = 52,
		ThemeTag = {
			TextColor3 = "Text",
		},
	})
	Content.TextTransparency = 0.42

	-- Value: the ProgressBar element's own label.
	local Percent = New("TextLabel", {
		Name = "Percent",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -Pad, 0, Pad + 1),
		Size = UDim2.new(0, PercentW, 0, 20),
		TextXAlignment = "Right",
		TextYAlignment = "Top",
		TextTruncate = "AtEnd",
		BackgroundTransparency = 1,
		Text = "0%",
		TextSize = 14,
		TextTransparency = 0.28,
		FontFace = Font.new(Creator.Font, Enum.FontWeight.Medium),
		ZIndex = 52,
		ThemeTag = {
			TextColor3 = "Text",
		},
	})

	-- Bar, exactly as src/elements/ProgressBar.lua builds it, but the fill is
	-- white rather than the theme's accent: an accent-coloured fill vanishes
	-- the moment a theme's accent sits near the surface it is drawn on.
	local Fill = Creator.NewRoundFrame(99, "Squircle", {
		Name = "Fill",
		Size = UDim2.new(0, 0, 1, 0),
		ZIndex = 52,
		ThemeTag = {
			ImageColor3 = "White",
		},
	})

	local Track = Creator.NewRoundFrame(99, "Squircle", {
		Name = "Track",
		Size = UDim2.new(1, 0, 1, 0),
		ClipsDescendants = true,
		ImageTransparency = 0.9,
		ZIndex = 51,
		ThemeTag = {
			ImageColor3 = "Text",
		},
	}, {
		Fill,
	})

	local Bar = New("Frame", {
		Name = "Bar",
		Position = UDim2.new(0, Pad, 0, BarY),
		Size = UDim2.new(1, -Pad * 2, 0, LoadingModule.BarHeight),
		BackgroundTransparency = 1,
		ZIndex = 51,
	}, {
		Track,
	})

	-- The face rides in a CanvasGroup so it can be cross-faded as one piece.
	-- A plain frame is the fallback if the Roblox build predates CanvasGroup;
	-- the element still works, the text just appears instead of dissolving in.
	local FaceChildren = { Icon, Title, Content, Percent, Bar }
	local Face
	local Faced = pcall(function()
		Face = New("CanvasGroup", {
			Name = "Face",
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			GroupTransparency = 1,
			ZIndex = 51,
		}, FaceChildren)
	end)
	if not Faced or not Face then
		Face = New("Frame", {
			Name = "Face",
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			ZIndex = 51,
		}, FaceChildren)
	end

	-- The surface: the theme's Accent underneath, the theme's Dialog over it,
	-- the theme's Outline as a one-pixel rim, then the glass sheen. Every one
	-- of those five keys exists in every theme pack, so the element lands on
	-- the selected theme without the pack having to learn a new tag.
	local Inner, InnerShape = Creator.NewRoundFrame(Corner, "Squircle", {
		Name = "Inner",
		Size = UDim2.new(1, 0, 1, 0),
		ImageTransparency = LoadingModule.FaceTransparency,
		ZIndex = 50,
		ThemeTag = {
			ImageColor3 = "Dialog",
		},
	})

	local Glass, GlassShape = Creator.NewRoundFrame(Corner, "SquircleGlass", {
		Name = "Glass",
		Size = UDim2.new(1, 0, 1, 0),
		ImageColor3 = Color3.new(1, 1, 1),
		ImageTransparency = 1,
		ZIndex = 51,
	})

	local Main, MainShape = Creator.NewRoundFrame(LoadingModule.DotSize / 2, "Circle", {
		Name = "Main",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 0),
		-- Born as the dot, not built at full size and then shrunk: a single
		-- frame of the finished pill before the morph starts is a flash.
		Size = UDim2.new(0, LoadingModule.DotSize, 0, LoadingModule.DotSize),
		ImageTransparency = 0.05,
		ZIndex = 50,
		ThemeTag = {
			ImageColor3 = "Accent",
		},
	}, {
		Inner,
		Glass,
		Face,
	})

	local MainContainer = New("Frame", {
		Name = "LoadingPill",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),
		ZIndex = 50,
		Parent = Holder,
	}, {
		Main,
	})

	Loading.UIElements = {
		Main = Main,
		Container = MainContainer,
		Inner = Inner,
		Glass = Glass,
		Face = Face,
		Title = Title,
		Content = Content,
		Percent = Percent,
		Bar = Bar,
		Track = Track,
		Fill = Fill,
		Icon = Icon,
	}

	Loading.Container = MainContainer

	-- Hover.
	--
	-- TweenService cannot express this, so the springs are integrated by hand.
	-- There are three of them:
	--
	--   reach - one value per edge, in pixels, springing from 0 to the share
	--           of HoverReach that edge was given. The share comes from the
	--           pointer's position across the element, so the edge it came in
	--           over travels most of the distance and the far edge travels a
	--           little. Zeta 0.56 leaves two or three visible swings, which
	--           is the wide-narrow-wide settle the reference has;
	--   value - the lift and the sheen, on the tighter spring the element
	--           already used, so the surface comes toward the pointer while
	--           it is still spreading;
	--   squash- not a spring: it is read straight off the reach. Wherever the
	--           width is away from its target - overshooting outward or
	--           ringing back through it - the height gives up a few pixels
	--           and the corners take them on. Volume in, volume out. It is
	--           the difference between a box being resized and a surface
	--           holding its own amount of material.
	local Reach = {
		L = 0,
		LV = 0,
		R = 0,
		RV = 0,
		Side = 1, -- +1 pointer on the right half, -1 on the left
	}

	local Spring = {
		Value = 0,
		Velocity = 0,
		Target = 0,
		Active = false,
	}

	-- The hit area is the resting pill exactly. It is a button only because a
	-- Frame does not report mouse entry; it draws nothing and swallows a click
	-- that was already landing on the element anyway.
	local HoverArea = New("TextButton", {
		Name = "Hover",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		ZIndex = 53,
		Parent = MainContainer,
	})

	local function Share()
		local T = Reach.Side
		return (0.5 + 0.5 * T), (0.5 - 0.5 * T)
	end

	local function ApplyHover()
		local W = Width + Reach.L + Reach.R
		local TargetW = Width + (Loading.Hovered and LoadingModule.HoverReach or 0)

		-- Away from target, in either direction, is deformation. Clamped so a
		-- hard swing squashes fully but never inverts the element.
		local Squash = math.clamp(math.abs(W - TargetW) / LoadingModule.ReachDeviation, 0, 1)
		local H = Spring.Value
		local BoxH = Height - LoadingModule.SquashAmount * Squash
		local Radius = Corner + LoadingModule.RadiusBulge * Squash

		-- AnchorPoint is (0.5, 0), so the x offset is measured from the
		-- centre: the right edge reaching R and the left edge reaching L
		-- moves the centre by half their difference.
		local OffsetX = (Reach.R - Reach.L) * 0.5
		local OffsetY = (Height - BoxH) * 0.5 + LoadingModule.HoverLift * H

		Main.Size = UDim2.new(0, W, 0, BoxH)
		Main.Position = UDim2.new(0.5, OffsetX, 0, -OffsetY)
		MainShape:SetRadius(Radius)
		InnerShape:SetRadius(Radius)
		GlassShape:SetRadius(Radius)
		Glass.ImageTransparency = LoadingModule.GlassTransparency - LoadingModule.HoverSheen * H
	end

	local function SetSide(X)
		local Centre = Width * 0.5
		pcall(function()
			Centre = MainContainer.AbsoluteSize.X * 0.5
		end)
		local T = (X - Centre) / math.max(Centre, 1)
		if math.abs(T) < LoadingModule.HoverDeadband then
			return
		end
		Reach.Side = T > 0 and 1 or -1
	end

	local function SetHovered(On, X)
		Loading.Hovered = On
		if On and X then
			SetSide(X)
		end
		Spring.Target = On and 1 or 0
		Spring.Active = true
	end

	table.insert(
		Loading.Connections,
		HoverArea.MouseEnter:Connect(function(X)
			SetHovered(true, X)
		end)
	)
	table.insert(
		Loading.Connections,
		HoverArea.MouseLeave:Connect(function()
			SetHovered(false)
		end)
	)
	table.insert(
		Loading.Connections,
		HoverArea.MouseMoved:Connect(function(X)
			if Loading.Hovered then
				SetSide(X)
			end
		end)
	)

	local RunService = game:GetService("RunService")
	table.insert(
		Loading.Connections,
		RunService.Heartbeat:Connect(function(Dt)
			if not Spring.Active or not Loading.Ready or Loading.Closed then
				return
			end

			-- A hitch hands Heartbeat a long frame, and an unclamped step would
			-- throw a spring past its target and ring it. One frame is capped
			-- at a thirtieth: the response slows under load instead of breaking.
			local Step = math.min(Dt, 1 / 30)

			local Delta = Spring.Target - Spring.Value
			Spring.Velocity = Spring.Velocity
				+ (Delta * LoadingModule.SpringStiffness - Spring.Velocity * LoadingModule.SpringDamping) * Step
			Spring.Value = Spring.Value + Spring.Velocity * Step

			local ShareR, ShareL = Share()
			local ReachTotal = LoadingModule.HoverReach
			local TargetR = Loading.Hovered and ReachTotal * ShareR or 0
			local TargetL = Loading.Hovered and ReachTotal * ShareL or 0

			local K, D = LoadingModule.ReachStiffness, LoadingModule.ReachDamping

			Delta = TargetR - Reach.R
			Reach.RV = Reach.RV + (Delta * K - Reach.RV * D) * Step
			Reach.R = Reach.R + Reach.RV * Step

			Delta = TargetL - Reach.L
			Reach.LV = Reach.LV + (Delta * K - Reach.LV * D) * Step
			Reach.L = Reach.L + Reach.LV * Step

			-- Land exactly on the resting geometry, so an unhovered element is
			-- the notification's box and not a spring stranded at 0.0004.
			local Settled = math.abs(Spring.Target - Spring.Value) < 0.0015
				and math.abs(Spring.Velocity) < 0.02
				and math.abs(TargetR - Reach.R) < 0.01
				and math.abs(Reach.RV) < 0.05
				and math.abs(TargetL - Reach.L) < 0.01
				and math.abs(Reach.LV) < 0.05

			if Settled then
				Spring.Value = Spring.Target
				Spring.Velocity = 0
				Reach.R, Reach.RV = TargetR, 0
				Reach.L, Reach.LV = TargetL, 0
				Spring.Active = false
			end

			ApplyHover()
		end)
	)

	function Loading:SetContent(Text)
		if Loading.Closed then
			return Loading.Content
		end
		Loading.Content = tostring(Text)
		Content.Text = Loading.Content
		return Loading.Content
	end

	function Loading:SetTitle(Text)
		if Loading.Closed then
			return Loading.Title
		end
		Loading.Title = tostring(Text)
		Title.Text = Loading.Title
		return Loading.Title
	end

	function Loading:SetProgress(Value)
		if Loading.Closed then
			return Loading.Progress
		end
		local Ratio = tonumber(Value)
		if Ratio == nil or Ratio ~= Ratio then
			return Loading.Progress
		end
		Ratio = math.clamp(Ratio, 0, 1)
		Loading.Progress = Ratio
		Percent.Text = string.format("%d%%", math.floor(Ratio * 100 + 0.5))
		-- Quint out on the fill only: the number jumps with the data, the bar
		-- chases it, so a fast loader still reads as motion rather than a snap.
		Tween(Fill, LoadingModule.BarTime, { Size = UDim2.new(Ratio, 0, 1, 0) }, Enum.EasingStyle.Quint, Enum.EasingDirection.Out):Play()
		return Ratio
	end

	function Loading:Close()
		if Loading.Closed then
			return
		end
		Loading.Closed = true
		for _, Connection in next, Loading.Connections do
			pcall(function()
				Connection:Disconnect()
			end)
		end
		table.clear(Loading.Connections)

		-- Leave the way it came: the surface pulls back down into the dot it
		-- was born as, then the dot dims out, rather than the frame blinking
		-- off the screen.
		pcall(function()
			Tween(Face, 0.10, { GroupTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In):Play()
		end)
		Face.Visible = false

		local Dot = LoadingModule.DotSize
		-- The collapse is measured from the resting box, so a surface that was
		-- still leaning toward the pointer has to come back to centre first or
		-- the dot would form off to one side.
		Tween(Main, 0.24, { Position = UDim2.new(0.5, 0, 0, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out):Play()
		Tween(Main, 0.24, { Size = UDim2.new(0, Dot, 0, Dot) }, Enum.EasingStyle.Back, Enum.EasingDirection.In):Play()
		MainShape:SetType("Circle")
		InnerShape:SetType("Circle")
		GlassShape:SetType("CircleGlass")
		MainShape:SetRadius(Dot / 2)
		InnerShape:SetRadius(Dot / 2)
		GlassShape:SetRadius(Dot / 2)
		task.delay(0.16, function()
			Tween(Main, 0.14, { ImageTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In):Play()
			Tween(Inner, 0.14, { ImageTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In):Play()
			Tween(Glass, 0.14, { ImageTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In):Play()
		end)
		task.delay(0.34, function()
			MainContainer:Destroy()
		end)
	end

	function Loading:Destroy()
		for _, Connection in next, Loading.Connections do
			pcall(function()
				Connection:Disconnect()
			end)
		end
		table.clear(Loading.Connections)
		Loading.Closed = true
		MainContainer:Destroy()
	end

	-- Arrival: the element is formed, not moved.
	--
	--   dot     - born as a circle of DotSize at the very top edge. It is a
	--             real circle: the Circle art, with the corner slice set to
	--             half the dot, not a rounded square pretending;
	--   droplet - the dot lengthens downward to DotDrop, because a bead of
	--             liquid stretches before it spreads;
	--   spread  - two damped springs carry the width and the height out to
	--             the notification's geometry, and the corner radius is read
	--             off the width spring, walking from half the short side to
	--             the surface's 18 px as it goes. At no frame is this a
	--             rectangle being resized: it is a blob whose corners are
	--             still rounding off while it spreads;
	--   swing   - the width spring overshoots about two percent and the
	--             height about seven, so the surface goes wide and a little
	--             taller, then a hair narrow and shorter, then rest - the
	--             wide-narrow-wide settle the reference has;
	--   sheen   - the SquircleGlass layer rises with the spread, so the
	--             highlight arrives with the shape rather than after it.
	--
	-- The shape art is chosen here rather than left to DynamicShape's own
	-- AbsoluteSize handler: that handler only runs while the current art is a
	-- Squircle, so the moment the element is a Circle it can never leave it.
	-- The rule below is the same one the module uses, evaluated fresh.
	local SquircleRatio = 310 / 1024 -- DynamicShape's Squircle radius over 1024

	local function ShapeFor(W, H, R)
		local Ratio = R / math.min(W, H)
		if Ratio >= SquircleRatio then
			if W > H then
				return "SquircleH"
			elseif W < H then
				return "SquircleV"
			end
			return "Circle"
		end
		return "Squircle"
	end

	local function Spread()
		local Dot = LoadingModule.DotSize
		local Drop = LoadingModule.DotDrop
		local WP, WV = 0, 0
		local HP, HV = 0, 0

		while not Loading.Closed do
			local Step = math.min(RunService.Heartbeat:Wait(), 1 / 30)

			local Delta = 1 - WP
			WV = WV + (Delta * LoadingModule.SpreadStiffness - WV * LoadingModule.SpreadDamping) * Step
			WP = WP + WV * Step

			Delta = 1 - HP
			HV = HV + (Delta * LoadingModule.HeightStiffness - HV * LoadingModule.HeightDamping) * Step
			HP = HP + HV * Step

			local Morph = math.clamp(WP, 0, 1)
			local W = Dot + (Width - Dot) * WP
			local H = Drop + (Height - Drop) * HP
			local R = (1 - Morph) * math.min(W, H) / 2 + Morph * Corner

			Main.Size = UDim2.new(0, W, 0, H)
			MainShape:SetRadius(R)

			-- All three layers are the same box, so they take the same radius
			-- and the same art: Inner is what the eye actually sees, and a
			-- surface that rounds off underneath while its face stays square
			-- is not one material.
			local Type = ShapeFor(W, H, R)
			if Type ~= MainShape:GetType() then
				MainShape:SetType(Type)
			end
			if Type ~= InnerShape:GetType() then
				InnerShape:SetType(Type)
			end
			InnerShape:SetRadius(R)

			local GlassType = Type .. "Glass"
			if GlassType ~= GlassShape:GetType() then
				GlassShape:SetType(GlassType)
			end
			GlassShape:SetRadius(R)

			Glass.ImageTransparency = 1 - (1 - LoadingModule.GlassTransparency) * math.clamp(WP * 1.2, 0, 1)

			if math.abs(1 - WP) < 0.002 and math.abs(WV) < 0.05 and math.abs(1 - HP) < 0.002 and math.abs(HV) < 0.05 then
				break
			end
		end

		if Loading.Closed then
			return
		end

		-- Land exactly on the notification's geometry instead of on a spring
		-- value stranded a thousandth short of it - and back on the art the
		-- size handler can maintain again, so the hover still morphs it.
		Main.Size = UDim2.new(0, Width, 0, Height)
		MainShape:SetType("Squircle")
		MainShape:SetRadius(Corner)
		InnerShape:SetType("Squircle")
		InnerShape:SetRadius(Corner)
		GlassShape:SetType("SquircleGlass")
		GlassShape:SetRadius(Corner)
		Glass.ImageTransparency = LoadingModule.GlassTransparency
	end

	task.spawn(function()
		task.wait()
		if Loading.Closed then
			return
		end

		Tween(Main, LoadingModule.DotTime, {
			Size = UDim2.new(0, LoadingModule.DotSize, 0, LoadingModule.DotDrop),
		}, Enum.EasingStyle.Quad, Enum.EasingDirection.Out):Play()
		task.wait(LoadingModule.DotTime)
		if Loading.Closed then
			return
		end

		Spread()
		if Loading.Closed then
			return
		end

		Face.Visible = true
		pcall(function()
			Tween(Face, LoadingModule.FadeTime, { GroupTransparency = 0 }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out):Play()
		end)

		-- Hand the surface to the hover spring only now. The arrival owns
		-- Main's size until the shape has finished forming, and a pointer
		-- that was already sitting on the element is carried straight into
		-- the hover instead of needing a re-entry.
		Loading.Ready = true
		if Loading.Hovered then
			Spring.Target = 1
			Spring.Active = true
		end
	end)

	return Loading
end

return LoadingModule
