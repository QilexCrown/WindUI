local Creator = require("../modules/Creator")
local New = Creator.New
local Tween = Creator.Tween

--[[
	The boot card.

	It is the notification element, copied: the same squircle Main, the same
	Notification/Notification2 theme tags, the same 18 px corner, the same 14 px
	padding, the same 26 px icon slot, the same Inter title and content. Two
	things are different because a loading card needs them and a toast does not:

	  * it hangs from the top centre of the screen instead of the toast stack,
	  * the bar is determinate and the title row carries a percentage.

	It arrives as a liquid bead. The card itself starts as a small capsule above
	the top of the screen, stretches down and out with a spring overshoot, then
	squashes and settles into its own shape. The bead *is* the card - no second
	shape is ever drawn - so when the text appears there is nothing to swap and
	nothing to see but the element that just finished forming.

	Nothing here reads or writes the notification module: a live toast and the
	boot card can share the screen and no state is shared.
]]

local LoadingModule = {
	Width = 300,
	UICorner = 18,
	UIPadding = 14,
	BarHeight = 4,
	MarginTop = 18,
	-- How far above the resting spot the bead is born, in card heights.
	DropFrom = 1,
	Holder = nil,
	LoadingIndex = 0,
	Loadings = {},
}

function LoadingModule.Init(Parent)
	local Module = {}

	-- The notification screen ignores the gui inset, so the holder has to clear
	-- the topbar itself or it lands above the visible screen.
	local Inset = 0
	pcall(function()
		Inset = game:GetService("GuiService"):GetGuiInset().Y
	end)

	Module.Frame = New("Frame", {
		Name = "LoadingHolder",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, Inset + LoadingModule.MarginTop),
		Size = UDim2.new(0, LoadingModule.Width, 0, 0),
		Parent = Parent,
		BackgroundTransparency = 1,
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

	local Icon
	if Loading.Icon then
		Icon = Creator.Image(Loading.Icon, Loading.Title .. ":" .. Loading.Icon, 0, Config.Window, "Loading", Loading.IconThemed)
		Icon.Size = UDim2.new(0, 26, 0, 26)
		Icon.Position = UDim2.new(0, LoadingModule.UIPadding, 0, LoadingModule.UIPadding)
	end

	local Percent = New("TextLabel", {
		Name = "Percent",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -LoadingModule.UIPadding, 0, LoadingModule.UIPadding),
		Size = UDim2.new(0, 60, 0, 18),
		BackgroundTransparency = 1,
		Text = "0%",
		TextSize = 13,
		TextXAlignment = "Right",
		TextYAlignment = "Top",
		FontFace = Font.new(Creator.Font, Enum.FontWeight.Medium),
		ThemeTag = {
			TextColor3 = "NotificationContent",
		},
	})

	local Title = New("TextLabel", {
		Name = "Title",
		AutomaticSize = "Y",
		Size = UDim2.new(1, -30 - LoadingModule.UIPadding, 0, 0),
		TextWrapped = true,
		TextXAlignment = "Left",
		RichText = true,
		BackgroundTransparency = 1,
		TextSize = 18,
		Text = Loading.Title,
		FontFace = Font.new(Creator.Font, Enum.FontWeight.SemiBold),
		ThemeTag = {
			TextColor3 = "NotificationTitle",
			TextTransparency = "NotificationTitleTransparency",
		},
	})

	local Content = New("TextLabel", {
		Name = "Content",
		AutomaticSize = "Y",
		Size = UDim2.new(1, 0, 0, 0),
		TextWrapped = true,
		TextXAlignment = "Left",
		RichText = true,
		BackgroundTransparency = 1,
		TextSize = 15,
		Text = Loading.Content,
		FontFace = Font.new(Creator.Font, Enum.FontWeight.Medium),
		ThemeTag = {
			TextColor3 = "NotificationContent",
			TextTransparency = "NotificationContentTransparency",
		},
	})

	local Fill = Creator.NewRoundFrame(99, "Squircle", {
		Name = "Fill",
		Size = UDim2.new(0, 0, 1, 0),
		ThemeTag = {
			ImageColor3 = "NotificationTitle",
			ImageTransparency = "NotificationTitleTransparency",
		},
	})

	local Track = Creator.NewRoundFrame(99, "Squircle", {
		Name = "Track",
		Size = UDim2.new(1, 0, 1, 0),
		ThemeTag = {
			ImageColor3 = "NotificationContent",
			ImageTransparency = "NotificationContentTransparency",
		},
	}, {
		Fill,
	})

	local Bar = New("Frame", {
		Name = "Bar",
		Size = UDim2.new(1, 0, 0, LoadingModule.BarHeight),
		BackgroundTransparency = 1,
	}, {
		Track,
	})

	local TextContainer = New("Frame", {
		Name = "TextContainer",
		Size = UDim2.new(1, Loading.Icon and -28 - LoadingModule.UIPadding or 0, 1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundTransparency = 1,
		AutomaticSize = "Y",
	}, {
		New("UIPadding", {
			PaddingTop = UDim.new(0, LoadingModule.UIPadding),
			PaddingLeft = UDim.new(0, LoadingModule.UIPadding),
			PaddingRight = UDim.new(0, LoadingModule.UIPadding),
			PaddingBottom = UDim.new(0, LoadingModule.UIPadding),
		}),
		New("UIListLayout", {
			Padding = UDim.new(0, LoadingModule.UIPadding / 3),
			SortOrder = "LayoutOrder",
		}),
		Title,
		Content,
		Bar,
	})

	local Main = Creator.NewRoundFrame(LoadingModule.UICorner, "Squircle", {
		Name = "Main",
		Size = UDim2.new(1, 0, 0, 0),
		Position = UDim2.new(0, 0, 1, 0),
		AnchorPoint = Vector2.new(0, 1),
		AutomaticSize = "Y",
		ImageTransparency = 0.05,
		ThemeTag = {
			ImageColor3 = "Notification",
		},
	}, {
		Creator.NewRoundFrame(LoadingModule.UICorner, "Squircle", {
			Name = "Inner",
			Size = UDim2.new(1, 0, 1, 0),
			ThemeTag = {
				ImageColor3 = "Notification2",
				ImageTransparency = "Notification2Transparency",
			},
		}),
		New("Frame", {
			Name = "DurationFrame",
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
		}),
		TextContainer,
		Icon,
		Percent,
	})

	local MainContainer = New("Frame", {
		Name = "LoadingCard",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		Parent = Holder,
	}, {
		Main,
	})

	Loading.UIElements = {
		Main = Main,
		Container = MainContainer,
		TextContainer = TextContainer,
		Title = Title,
		Content = Content,
		Percent = Percent,
		Bar = Bar,
		Track = Track,
		Fill = Fill,
		Icon = Icon,
	}

	Loading.Container = MainContainer

	-- Text only exists once the shape has finished forming, so the eye follows
	-- the bead instead of reading a half-built card.
	local FaceParts = { TextContainer, Icon, Percent }
	for _, Part in ipairs(FaceParts) do
		if Part then
			Part.Visible = false
		end
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

		local Height = Main.AbsoluteSize.Y
		Tween(Main, 0.32, { Size = UDim2.new(1, 0, 0, 0) }, Enum.EasingStyle.Quint, Enum.EasingDirection.Out):Play()
		Tween(MainContainer, 0.32, { Size = UDim2.new(1, 0, 0, 0) }, Enum.EasingStyle.Quint, Enum.EasingDirection.Out):Play()
		task.delay(0.34, function()
			MainContainer:Destroy()
		end)
		return Height
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

	-- Formation. Measure the card once at full size, then reset it to a bead and
	-- let it grow into the shape it was measured at. The shape module swaps the
	-- squircle asset as the aspect changes, so the capsule and the card are the
	-- same image at different slices - that is the morph.
	task.spawn(function()
		-- The automatic height resolves a frame or two after the font face is
		-- ready; measuring at frame one reads zero and the card would form flat.
		local RestHeight = 0
		for _ = 1, 60 do
			RestHeight = math.floor(Main.AbsoluteSize.Y)
			if RestHeight > 0 then
				break
			end
			task.wait()
		end
		if RestHeight <= 0 then
			RestHeight = 73
		end
		if Loading.Closed then
			return
		end

		Main.AutomaticSize = "None"
		Main.AnchorPoint = Vector2.new(0.5, 0)
		Main.Position = UDim2.new(0.5, 0, 0, -RestHeight * LoadingModule.DropFrom)
		Main.Size = UDim2.new(0, 44, 0, 10)
		MainContainer.Size = UDim2.new(1, 0, 0, RestHeight)
		Holder.Size = UDim2.new(0, LoadingModule.Width, 0, RestHeight)

		Tween(Main, 0.55, { Size = UDim2.new(1, 0, 0, RestHeight) }, Enum.EasingStyle.Quint, Enum.EasingDirection.Out):Play()
		Tween(Main, 0.6, { Position = UDim2.new(0.5, 0, 0, 0) }, Enum.EasingStyle.Back, Enum.EasingDirection.Out):Play()

		task.wait(0.6)
		if Loading.Closed then
			return
		end

		-- Squash and settle. The shape overshoots wide and flat, then relaxes
		-- into its own size instead of stopping dead - the liquid part.
		for _, Step in ipairs({
			{ UDim2.new(1, 6, 0, RestHeight - 3), 0.1 },
			{ UDim2.new(1, 0, 0, RestHeight), 0.12 },
			{ UDim2.new(1, -2, 0, RestHeight + 1), 0.09 },
			{ UDim2.new(1, 0, 0, RestHeight), 0.08 },
		}) do
			if Loading.Closed then
				return
			end
			Tween(Main, Step[2], { Size = Step[1] }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut):Play()
			task.wait(Step[2])
		end

		if Loading.Closed then
			return
		end

		for _, Part in ipairs(FaceParts) do
			if Part then
				Part.Visible = true
			end
		end
	end)

	return Loading
end

return LoadingModule
