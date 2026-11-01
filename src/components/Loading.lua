local Creator = require("../modules/Creator")
local New = Creator.New
local Tween = Creator.Tween

--[[
	The boot pill.

	It is the notification element copied, then laid on its side: the same
	squircle glass the toast uses, the same Notification / Notification2 /
	NotificationTitle / NotificationContent theme tags, the same icon slot.
	What is different is the geometry and the arrival, because a boot bar is
	not a toast:

	  * it is wide and short - a bar across the top centre, not a card in the
	    stack, sized so it reads as a pill in the same family as a phone's
	    island cutout;
	  * the bar is determinate - ProgressBar fill, ProgressBarTrack track, and
	    a live percentage on the right;
	  * it arrives as a bead from above the screen and stretches into the pill.

	The arrival is the whole point. The element is born as a small capsule
	above the top edge and travels down while its size runs in the opposite
	direction, so the shape is *falling* and *unfolding* at the same time.
	DynamicShape swaps the slice asset as the aspect crosses, so the capsule
	and the pill are one image being stretched rather than two images being
	swapped. It lands with a spring overshoot, then goes through three short
	squash steps that carry the lip of the glass past its own edge and back -
	that overshoot is the liquid part, and it is what stops the shape reading
	as a slide-in.

	Nothing here reads or writes the notification module. A live toast and the
	boot pill can share the screen and no state is shared between them.
]]

local LoadingModule = {
	-- Geometry. These are the only numbers to touch if the pill needs to be
	-- wider or taller; every child is positioned from them at build time.
	Width = 300,
	Height = 52,
	UICorner = 26, -- half the height: fully rounded ends, no flat lip
	UIPadding = 12,
	IconSize = 22,
	BarHeight = 3,
	MarginTop = 14,

	-- The bead the pill is born as, before it unfolds.
	BeadWidth = 96,
	BeadHeight = 8,
	BeadGap = 10, -- clear space above the viewport edge at birth

	-- Arrival timing, in seconds. Detach and settle are read by both the
	-- position run and the size run so the two land on the same frame.
	FallTime = 0.62,
	SettleTime = 0.30,
	FadeTime = 0.22,

	Holder = nil,
	LoadingIndex = 0,
	Loadings = {},
}

function LoadingModule.Init(Parent)
	local Module = {}

	-- The notification screen ignores the gui inset, so the holder has to
	-- clear the topbar itself or the pill lands above the visible screen.
	local Inset = 0
	pcall(function()
		Inset = game:GetService("GuiService"):GetGuiInset().Y
	end)

	Module.Frame = New("Frame", {
		Name = "LoadingHolder",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, Inset + LoadingModule.MarginTop),
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

	local Width = LoadingModule.Width
	local Height = LoadingModule.Height
	local Pad = LoadingModule.UIPadding

	-- Where the text column starts: it clears the icon only when there is one,
	-- so an iconless pill gets the full width instead of a dead gutter.
	local TextX = Pad + (Loading.Icon and (LoadingModule.IconSize + 10) or 0)
	local PercentWidth = 42
	local TextWidth = Width - TextX - Pad - PercentWidth

	local Icon
	if Loading.Icon then
		Icon = Creator.Image(Loading.Icon, Loading.Title .. ":" .. Loading.Icon, 0, Config.Window, "Loading", Loading.IconThemed)
		Icon.Size = UDim2.new(0, LoadingModule.IconSize, 0, LoadingModule.IconSize)
		Icon.Position = UDim2.new(0, Pad, 0, (Height - LoadingModule.IconSize) / 2)
		Icon.ZIndex = 52
	end

	local Title = New("TextLabel", {
		Name = "Title",
		Position = UDim2.new(0, TextX, 0, 9),
		Size = UDim2.new(0, TextWidth, 0, 16),
		TextXAlignment = "Left",
		TextYAlignment = "Top",
		TextTruncate = "AtEnd",
		RichText = true,
		BackgroundTransparency = 1,
		TextSize = 13,
		Text = Loading.Title,
		FontFace = Font.new(Creator.Font, Enum.FontWeight.SemiBold),
		ZIndex = 52,
		ThemeTag = {
			TextColor3 = "NotificationTitle",
			TextTransparency = "NotificationTitleTransparency",
		},
	})

	local Content = New("TextLabel", {
		Name = "Content",
		Position = UDim2.new(0, TextX, 0, 26),
		Size = UDim2.new(0, TextWidth, 0, 14),
		TextXAlignment = "Left",
		TextYAlignment = "Top",
		TextTruncate = "AtEnd",
		RichText = true,
		BackgroundTransparency = 1,
		TextSize = 11,
		Text = Loading.Content,
		FontFace = Font.new(Creator.Font, Enum.FontWeight.Medium),
		ZIndex = 52,
		ThemeTag = {
			TextColor3 = "NotificationContent",
			TextTransparency = "NotificationContentTransparency",
		},
	})

	local Percent = New("TextLabel", {
		Name = "Percent",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -Pad, 0, 10),
		Size = UDim2.new(0, PercentWidth, 0, 15),
		TextXAlignment = "Right",
		TextYAlignment = "Top",
		BackgroundTransparency = 1,
		Text = "0%",
		TextSize = 12,
		FontFace = Font.new(Creator.Font, Enum.FontWeight.SemiBold),
		ZIndex = 52,
		ThemeTag = {
			TextColor3 = "NotificationTitle",
			TextTransparency = "NotificationTitleTransparency",
		},
	})

	-- Determinate bar. ProgressBar / ProgressBarTrack are the theme's own
	-- bar pair, so the fill matches every progress bar inside the window
	-- instead of inventing a colour for the boot screen only.
	local Fill = Creator.NewRoundFrame(99, "Squircle", {
		Name = "Fill",
		Size = UDim2.new(0, 0, 1, 0),
		ZIndex = 52,
		ThemeTag = {
			ImageColor3 = "ProgressBar",
			ImageTransparency = "NotificationTitleTransparency",
		},
	})

	local Track = Creator.NewRoundFrame(99, "Squircle", {
		Name = "Track",
		Size = UDim2.new(1, 0, 1, 0),
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
		Position = UDim2.new(0, Pad, 1, -Pad + 3),
		Size = UDim2.new(1, -Pad * 2, 0, LoadingModule.BarHeight),
		BackgroundTransparency = 1,
		ZIndex = 51,
	}, {
		Track,
	})

	-- The face rides in a CanvasGroup so it can be cross-faded as one piece
	-- the moment the glass finishes settling. A plain frame is the fallback
	-- if the executor's Roblox build is too old to have CanvasGroup; the pill
	-- still works, the text just appears instead of dissolving in.
	local Face
	local Faced = pcall(function()
		Face = New("CanvasGroup", {
			Name = "Face",
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			GroupTransparency = 1,
			ZIndex = 51,
		}, {
			Icon,
			Percent,
			Title,
			Content,
			Bar,
		})
	end)
	if not Faced then
		Face = New("Frame", {
			Name = "Face",
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			ZIndex = 51,
		}, {
			Icon,
			Percent,
			Title,
			Content,
			Bar,
		})
	end

	-- Backdrop first, glass over it, border last: the same stack the toast
	-- uses, so the theme reads it as the same surface at a different size.
	local Backdrop = Creator.NewRoundFrame(LoadingModule.UICorner, "Squircle", {
		Name = "Backdrop",
		Size = UDim2.new(1, 0, 1, 0),
		ImageTransparency = 0.05,
		ZIndex = 50,
		ThemeTag = {
			ImageColor3 = "Notification",
		},
	})

	local Glass = Creator.NewRoundFrame(LoadingModule.UICorner, "SquircleGlass", {
		Name = "Glass",
		Size = UDim2.new(1, 0, 1, 0),
		ZIndex = 51,
		ThemeTag = {
			ImageColor3 = "Notification2",
			ImageTransparency = "Notification2Transparency",
		},
	})

	local Border = Creator.NewRoundFrame(LoadingModule.UICorner, "SquircleOutline", {
		Name = "Border",
		Size = UDim2.new(1, 0, 1, 0),
		ZIndex = 53,
		ThemeTag = {
			ImageColor3 = "NotificationBorder",
			ImageTransparency = "NotificationBorderTransparency",
		},
	})

	local Main = New("Frame", {
		Name = "Main",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 0),
		Size = UDim2.new(0, Width, 0, Height),
		BackgroundTransparency = 1,
		ZIndex = 50,
	}, {
		Backdrop,
		Glass,
		Border,
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
		Face = Face,
		Backdrop = Backdrop,
		Glass = Glass,
		Border = Border,
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
		local HolderY = 0
		pcall(function()
			HolderY = MainContainer.AbsolutePosition.Y
		end)
		return -(HolderY + LoadingModule.BeadHeight + LoadingModule.BeadGap)
	end

	-- The face is invisible until the glass has settled: the eye follows the
	-- shape down, not a half-built label riding a growing frame.
	Face.Visible = false

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
		Tween(Fill, 0.25, { Size = UDim2.new(Ratio, 0, 1, 0) }, Enum.EasingStyle.Quint, Enum.EasingDirection.Out):Play()
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

		-- Leave the way it came: collapse to the bead and run back up past the
		-- top edge, so the exit is the arrival played backwards rather than a
		-- frame disappearing off the screen.
		pcall(function()
			Tween(Face, 0.14, { GroupTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In):Play()
		end)
		Face.Visible = false
		Tween(Main, 0.24, { Size = UDim2.new(0, LoadingModule.BeadWidth, 0, LoadingModule.BeadHeight) }, Enum.EasingStyle.Quint, Enum.EasingDirection.In):Play()
		Tween(Main, 0.28, {
			Position = UDim2.new(0.5, 0, 0, BirthOffset()),
		}, Enum.EasingStyle.Back, Enum.EasingDirection.In):Play()
		task.delay(0.30, function()
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

	-- Arrival. The bead is born above the top edge at a small capsule size and
	-- two runs leave it at once:
	--
	--   Position - travels down, Back/Out, so it passes its resting spot and
	--              comes back up into it instead of stopping dead;
	--   Size     - unfolds to the resting pill, Quint/Out, so the wide part of
	--              the travel happens early and the last stretch is slow.
	--
	-- The two runs are deliberately not the same duration: the shape finishes
	-- unfolding slightly before the body finishes falling, which is what makes
	-- it read as liquid being pulled into place by the fall.
	task.spawn(function()
		task.wait()
		if Loading.Closed then
			return
		end

		Main.Size = UDim2.new(0, LoadingModule.BeadWidth, 0, LoadingModule.BeadHeight)
		Main.Position = UDim2.new(0.5, 0, 0, BirthOffset())

		Tween(Main, LoadingModule.FallTime, { Position = UDim2.new(0.5, 0, 0, 0) }, Enum.EasingStyle.Back, Enum.EasingDirection.Out):Play()
		Tween(Main, LoadingModule.FallTime * 0.94, { Size = UDim2.new(0, Width, 0, Height) }, Enum.EasingStyle.Quint, Enum.EasingDirection.Out):Play()

		task.wait(LoadingModule.FallTime)
		if Loading.Closed then
			return
		end

		-- Squash and settle. The pill overshoots wide and flat, springs back
		-- through its own size, and relaxes. The amplitude shrinks each step
		-- so the last two frames are the glass finding rest, not wobbling.
		local Step = LoadingModule.SettleTime / 4
		for _, Frame in ipairs({
			{ UDim2.new(0, Width + 10, 0, Height - 5), Step },
			{ UDim2.new(0, Width - 4, 0, Height + 2), Step },
			{ UDim2.new(0, Width + 2, 0, Height - 1), Step * 0.8 },
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
