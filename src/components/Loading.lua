local Creator = require("../modules/Creator")
local New = Creator.New
local Tween = Creator.Tween

--[[
	The boot element.

	It is the notification, copied line for line and then given a home at the
	top of the screen:

	  * the same two-squircle surface - Main on Notification at 0.05
	    transparency, Inner on Notification2 / Notification2Transparency, both
	    at the notification's 18 px corner. No glass texture, no outline: the
	    toast does not draw one and neither does this;
	  * the same 14 px padding, the same 26 px icon slot, the same title at 18
	    SemiBold on NotificationTitle and the same content at 15 Medium on
	    NotificationContent / NotificationContentTransparency;
	  * the bar is the ProgressBar element's own bar - 6 px tall, radius 99,
	    fill on ProgressBar, track on ProgressBarTrack at 0.9, and the value
	    label at 14 Medium, 0.25 transparency, right aligned on ProgressBarText.

	Because every one of those is a theme tag, the element repaints with the
	active theme the moment it is set: the boot element in a hub is the same
	surface as the toasts the hub fires next to it, in the hub's own palette.

	The arrival: the element is born above the top edge of the viewport as a
	thin line, full width, and comes down while it thickens. The fall is
	Back/Out so it passes its resting spot and springs back up into it; the
	height run is Quint/Out at 94% of the fall, so the shape finishes forming
	a hair before the body lands. Then four short squash steps carry the
	surface past its own edges and back before the text cross-fades in.

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

	-- The line the element is born as, before it thickens.
	BeadWidthRatio = 0.92,
	BeadHeight = 10,
	BeadGap = 8, -- clear space above the viewport edge at birth

	-- Arrival timing, in seconds.
	FallTime = 0.60,
	SettleTime = 0.28,
	FadeTime = 0.20,
	BarTime = 0.20,

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
		Icon = Config.Icon,
		IconThemed = Config.IconThemed,
		Progress = nil,
		Closed = false,
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
			TextColor3 = "NotificationTitle",
			TextTransparency = "NotificationTitleTransparency",
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
			TextColor3 = "NotificationContent",
			TextTransparency = "NotificationContentTransparency",
		},
	})

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
		TextTransparency = 0.25,
		FontFace = Font.new(Creator.Font, Enum.FontWeight.Medium),
		ZIndex = 52,
		ThemeTag = {
			TextColor3 = "ProgressBarText",
		},
	})

	-- Bar, exactly as src/elements/ProgressBar.lua builds it.
	local Fill = Creator.NewRoundFrame(99, "Squircle", {
		Name = "Fill",
		Size = UDim2.new(0, 0, 1, 0),
		ZIndex = 52,
		ThemeTag = {
			ImageColor3 = "ProgressBar",
		},
	})

	local Track = Creator.NewRoundFrame(99, "Squircle", {
		Name = "Track",
		Size = UDim2.new(1, 0, 1, 0),
		ClipsDescendants = true,
		ImageTransparency = 0.9,
		ZIndex = 51,
		ThemeTag = {
			ImageColor3 = "ProgressBarTrack",
			ImageTransparency = "ProgressBarTrackTransparency",
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

	-- The notification surface: outer squircle on Notification, inner squircle
	-- on Notification2. Two layers, corner 18, nothing else.
	local Inner = Creator.NewRoundFrame(Corner, "Squircle", {
		Name = "Inner",
		Size = UDim2.new(1, 0, 1, 0),
		ZIndex = 50,
		ThemeTag = {
			ImageColor3 = "Notification2",
			ImageTransparency = "Notification2Transparency",
		},
	})

	local Main = Creator.NewRoundFrame(Corner, "Squircle", {
		Name = "Main",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 0),
		Size = UDim2.new(0, Width, 0, Height),
		ImageTransparency = 0.05,
		ZIndex = 50,
		ThemeTag = {
			ImageColor3 = "Notification",
		},
	}, {
		Inner,
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

	-- The bead is born above the viewport, not merely above its resting spot.
	-- The holder already sits below the topbar, so a fixed negative offset
	-- still lands on screen; measure the holder and clear it, so the element
	-- always enters from off the top of the player's screen at any inset.
	local function BirthOffset()
		local HolderY = TopOffset()
		pcall(function()
			HolderY = MainContainer.AbsolutePosition.Y
		end)
		return -(HolderY + LoadingModule.BeadHeight + LoadingModule.BeadGap)
	end

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

		-- Leave the way it came: thin out and run back up past the top edge,
		-- so the exit is the arrival played backwards rather than a frame
		-- disappearing off the screen.
		pcall(function()
			Tween(Face, 0.14, { GroupTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In):Play()
		end)
		Face.Visible = false
		Tween(Main, 0.26, {
			Size = UDim2.new(0, Width * LoadingModule.BeadWidthRatio, 0, LoadingModule.BeadHeight),
		}, Enum.EasingStyle.Quint, Enum.EasingDirection.In):Play()
		Tween(Main, 0.30, {
			Position = UDim2.new(0.5, 0, 0, BirthOffset()),
		}, Enum.EasingStyle.Back, Enum.EasingDirection.In):Play()
		task.delay(0.32, function()
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

	-- Arrival. The line is born above the top edge at full width and two runs
	-- leave it at once:
	--
	--   Position - travels down, Back/Out, so it passes its resting spot and
	--              comes back up into it instead of stopping dead;
	--   Size     - thickens to the resting element, Quint/Out, so the wide
	--              part of the travel happens early and the last stretch is
	--              slow.
	--
	-- The two runs are deliberately not the same duration: the shape finishes
	-- forming slightly before the body finishes falling, which is what makes
	-- it read as liquid being pulled into place by the fall.
	task.spawn(function()
		task.wait()
		if Loading.Closed then
			return
		end

		local BeadW = Width * LoadingModule.BeadWidthRatio
		Main.Size = UDim2.new(0, BeadW, 0, LoadingModule.BeadHeight)
		Main.Position = UDim2.new(0.5, 0, 0, BirthOffset())

		Tween(Main, LoadingModule.FallTime, { Position = UDim2.new(0.5, 0, 0, 0) }, Enum.EasingStyle.Back, Enum.EasingDirection.Out):Play()
		Tween(Main, LoadingModule.FallTime * 0.94, { Size = UDim2.new(0, Width, 0, Height) }, Enum.EasingStyle.Quint, Enum.EasingDirection.Out):Play()

		task.wait(LoadingModule.FallTime)
		if Loading.Closed then
			return
		end

		-- Squash and settle. The surface overshoots wide and flat, springs
		-- back through its own size, and relaxes. The amplitude shrinks each
		-- step so the last two frames are the surface finding rest, not
		-- wobbling.
		local Step = LoadingModule.SettleTime / 4
		for _, Frame in ipairs({
			{ UDim2.new(0, Width + 8, 0, Height - 4), Step },
			{ UDim2.new(0, Width - 3, 0, Height + 2), Step },
			{ UDim2.new(0, Width + 1, 0, Height - 1), Step * 0.8 },
			{ UDim2.new(0, Width, 0, Height), Step * 0.7 },
		}) do
			if Loading.Closed then
				return
			end
			Tween(Main, Frame[2], { Size = Frame[1] }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut):Play()
			task.wait(Frame[2])
		end

		if Loading.Closed then
			return
		end

		Face.Visible = true
		pcall(function()
			Tween(Face, LoadingModule.FadeTime, { GroupTransparency = 0 }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out):Play()
		end)
	end)

	return Loading
end

return LoadingModule
