-- Modern key screen — opt-in through Config.KeySystem.Layout.
-- The stock KeySystem.lua path is untouched when Layout is absent, so deleting
-- the table restores the default WindUI key system exactly.

local Modern = {}

local Creator = require("../modules/Creator")
local New = Creator.New
local Tween = Creator.Tween

local ICON = {
	Close = "x",
	Key = "key",
	Arrow = "arrow-right",
	Check = "circle-check",
	Alert = "triangle-alert",
}

local STYLE_ALIASES = {
	Primary = "Solid",
	Secondary = "Soft",
	Tertiary = "Ghost",
	Solid = "Solid",
	Soft = "Soft",
	Ghost = "Ghost",
	White = "White",
}

local ERROR_COLOR = Color3.fromHex("#f87171")
local SUCCESS_COLOR = Color3.fromHex("#4ade80")

local function first(...)
	for index = 1, select("#", ...) do
		local value = select(index, ...)
		if value ~= nil then
			return value
		end
	end
	return nil
end

local function resolveThemeColor(name, fallback)
	local ok, value = pcall(Creator.GetThemeProperty, name, Creator.Theme)
	if ok and typeof(value) == "Color3" then
		return value
	end
	if fallback then
		return fallback
	end
	return Color3.fromRGB(120, 120, 130)
end

local function resolveAccent(spec)
	if typeof(spec) == "Color3" then
		return spec, nil
	end
	local name = type(spec) == "string" and spec or "Button"
	return resolveThemeColor(name), name
end

local function readableOn(color)
	local ok, value = pcall(Creator.GetTextColorForHSB, color, 0.55)
	if ok and typeof(value) == "Color3" then
		return value
	end
	return Color3.new(1, 1, 1)
end

local function iconData(name)
	if not name or name == "" then
		return nil, nil, nil
	end
	local data = Creator.Icon(name)
	if not data or not data[1] or data[1] == "" then
		return nil, nil, nil
	end
	return data[1], data[2].ImageRectSize, data[2].ImageRectPosition
end

local function applyIcon(image, name)
	local imageId, rectSize, rectOffset = iconData(name)
	if not imageId then
		image.Visible = false
		return
	end
	image.Visible = true
	image.Image = imageId
	image.ImageRectSize = rectSize
	image.ImageRectOffset = rectOffset
end

-- Accent surfaces keep a theme tag when the accent is a theme key, so they
-- follow theme switches without a manual refresh.
local function accentPaint(properties, accentTag, accentColor)
	if accentTag then
		properties.ThemeTag = properties.ThemeTag or {}
		properties.ThemeTag.ImageColor3 = accentTag
	else
		properties.ImageColor3 = accentColor
	end
	return properties
end

local function asBadge(value)
	if value == true then
		return "Premium"
	end
	if type(value) == "string" and value ~= "" then
		return value
	end
	return nil
end

-- Reason codes a validator (or API) can hand back as the second return value.
-- Layout.Status.Errors overrides or extends this table.
local DEFAULT_ERRORS = {
	invalid = "That key is not valid.",
	already_used = "This key is already used.",
	expired = "This key has expired.",
	revoked = "This key has been revoked.",
	banned = "This key has been banned.",
	wrong_account = "This key belongs to a different account.",
	limit = "Key limit reached, try again later.",
}

-- Contrast colour for a fill that can be a Color3, a theme key, or a WindUI:Gradient.
local function fillTextColor(fill)
	local kind = typeof(fill)
	if kind == "table" then
		local ok, average = pcall(function()
			return Creator.GetAverageColor(fill)
		end)
		if ok and average then
			return Creator.GetTextColorForHSB(average)
		end
	elseif kind == "Color3" then
		return Creator.GetTextColorForHSB(fill)
	elseif type(fill) == "string" then
		local ok, value = pcall(function()
			return Creator.GetThemeProperty(fill, Creator.Theme)
		end)
		if ok and typeof(value) == "Color3" then
			return Creator.GetTextColorForHSB(value)
		end
	end
	return nil
end

-- Applies a custom fill to a round frame. Returns the created UIGradient, if any.
local function applyFill(fill, fillProps, children)
	local kind = typeof(fill)
	if kind == "table" then
		fillProps.ImageColor3 = Color3.new(1, 1, 1)
		fillProps.ImageTransparency = fillProps.ImageTransparency or 0
		local gradient = New("UIGradient")
		for key, value in next, fill do
			gradient[key] = value
		end
		table.insert(children, gradient)
	elseif kind == "Color3" then
		fillProps.ImageColor3 = fill
		fillProps.ImageTransparency = fillProps.ImageTransparency or 0
	elseif type(fill) == "string" then
		fillProps.ThemeTag = fillProps.ThemeTag or {}
		fillProps.ThemeTag.ImageColor3 = fill
		fillProps.ImageTransparency = fillProps.ImageTransparency or 0
	end
	return fill
end

-- Notes accept the markdown the stock dialog understood (**bold**, *italic*,
-- `code`). Raw rich text (anything containing "<") is passed through untouched.
local function richText(value)
	local text = tostring(value)
	if string.find(text, "<", 1, true) then
		return text
	end
	text = string.gsub(text, "&", "&amp;")
	text = string.gsub(text, "(%*%*)(.-)%1", "<b>%2</b>")
	text = string.gsub(text, "(__)(.-)%1", "<b>%2</b>")
	text = string.gsub(text, "(`)(.-)%1", "<font face=\"RobotoMono\">%2</font>")
	text = string.gsub(text, "(%*)([^%s%*][^*]-)(%*)", "<i>%2</i>")
	return text
end

function Modern.new(Config, Filename, func)
	local KeySystemConfig = Config.KeySystem
	local Layout = type(KeySystemConfig.Layout) == "table" and KeySystemConfig.Layout or {}
	local ThumbConfig = type(Layout.Thumbnail) == "table" and Layout.Thumbnail or {}
	local HeaderConfig = type(Layout.Header) == "table" and Layout.Header or {}
	local InputConfig = type(Layout.Input) == "table" and Layout.Input or {}
	local FooterConfig = type(Layout.Footer) == "table" and Layout.Footer or {}
	local StatusConfig = type(Layout.Status) == "table" and Layout.Status or {}
	local StockThumb = type(KeySystemConfig.Thumbnail) == "table" and KeySystemConfig.Thumbnail or {}

	-- Default footer cluster: Get key / Copy key / Exit. Passing Layout.Buttons
	-- replaces this list outright.
	local ButtonEntries = Layout.Buttons
	if type(ButtonEntries) ~= "table" then
		ButtonEntries = {
			{ ID = "CopyKey", Title = "Copy key", Icon = "copy", Slot = "Footer", Style = "Secondary", Order = 20, Action = "CopyKey" },
			{ ID = "Exit", Title = "Exit", Icon = "log-out", Slot = "Footer", Style = "Ghost", Order = 30, Action = "Exit" },
		}
	end

	local StatusErrors = setmetatable({}, { __index = DEFAULT_ERRORS })
	if type(StatusConfig.Errors) == "table" then
		for reason, message in next, StatusConfig.Errors do
			StatusErrors[reason] = message
		end
	end

	local accentColor, accentTag = resolveAccent(Layout.Accent or "Button")
	local onAccent = readableOn(accentColor)

	local Radius = Layout.Radius or 26
	local Padding = Layout.Padding or 22
	local Gap = Layout.Gap or 16
	local BodyWidth = Layout.BodyWidth or 420

	local ThumbPosition = ThumbConfig.Position or "None"
	local ThumbImage = first(ThumbConfig.Image, ThumbPosition ~= "None" and StockThumb.Image or nil)
	local ThumbEnabled = ThumbConfig.Enabled ~= false and ThumbImage ~= nil and ThumbPosition ~= "None"
	local ThumbSize = ThumbConfig.Size or StockThumb.Width or 236
	local ThumbHeight = ThumbConfig.Height or 176
	local ThumbTitle = first(ThumbConfig.Title, StockThumb.Title)
	local ThumbSubtitle = ThumbConfig.Subtitle
	local ThumbBadge = asBadge(ThumbConfig.Badge)

	local Width = Layout.Width
	if not Width then
		if ThumbEnabled and (ThumbPosition == "Left" or ThumbPosition == "Right") then
			Width = Padding + ThumbSize + Gap + BodyWidth + Padding
		else
			Width = Padding + BodyWidth + Padding
		end
	end

	local Services = {}
	if KeySystemConfig.API then
		for _, serviceConfig in next, KeySystemConfig.API do
			local serviceDef = Config.WindUI.Services[serviceConfig.Type]
			if serviceDef then
				local args = {}
				for _, argName in next, serviceDef.Args do
					table.insert(args, serviceConfig[argName])
				end
				local instance = serviceDef.New(table.unpack(args))
				instance.Type = serviceConfig.Type
				table.insert(Services, instance)
			end
		end
	end

	local controller = {
		Mount = nil,
		Frame = nil,
		Input = nil,
		Shell = nil,
		Buttons = {},
	}

	local enteredKey = ""
	local busy = false
	local closed = false
	local statusToken = 0

	local submit, close, shake, setStatus, setBusy, copyToClipboard, openURL
	local card, holder, holderScale
	local body, thumbnail, textBox, inputShell, statusIcon, statusLabel, statusBlock
	local headerTitle, headerTag
	local submitButton, submitTextLabel
	local footerCluster, footerRow, loadingPill
	local statusRowHeight, pillRowHeight, pillVisible
	local inputCursorBase = 0

	------------------------------------------------------------------
	-- Mount
	------------------------------------------------------------------

	local mount = New("Frame", {
		Name = "WindUI/KeySystemModern",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = Config.WindUI.ScreenGui.KeySystem,
		ZIndex = 9999,
	})
	controller.Mount = mount

	holder = New("Frame", {
		Name = "Holder",
		Size = UDim2.new(0, Width, 0, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		AutomaticSize = "Y",
		BackgroundTransparency = 1,
		Parent = mount,
	})

	holderScale = New("UIScale", {
		Scale = 0.96,
		Parent = holder,
	})

	if Layout.Shadow ~= false then
		New("ImageLabel", {
			Name = "Shadow",
			Image = "rbxassetid://8992230677",
			ScaleType = "Slice",
			SliceCenter = Rect.new(99, 99, 99, 99),
			Size = UDim2.new(1, 110, 1, 110),
			Position = UDim2.new(0.5, 0, 0.5, 0),
			AnchorPoint = Vector2.new(0.5, 0.5),
			ImageTransparency = Layout.ShadowTransparency or 0.5,
			ThemeTag = { ImageColor3 = "WindowShadow" },
			Parent = holder,
		})
	end

	if Layout.Glow == true then
		New("ImageLabel", {
			Name = "Glow",
			Image = "rbxassetid://8992230677",
			ScaleType = "Slice",
			SliceCenter = Rect.new(99, 99, 99, 99),
			Size = UDim2.new(1, 150, 1, 150),
			Position = UDim2.new(0.5, 0, 0.5, 0),
			AnchorPoint = Vector2.new(0.5, 0.5),
			ImageTransparency = Layout.GlowTransparency or 0.76,
			Parent = holder,
			ThemeTag = accentTag and { ImageColor3 = accentTag } or nil,
			ImageColor3 = accentTag and nil or accentColor,
		})
	end

	card = New("CanvasGroup", {
		Name = "Card",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = "Y",
		BackgroundTransparency = 1,
		GroupTransparency = 1,
		Parent = holder,
	})
	controller.Frame = card

	local surface = Creator.NewRoundFrame(Radius, "Squircle", {
		Name = "Surface",
		Size = UDim2.new(1, 0, 1, 0),
		ClipsDescendants = true,
		ThemeTag = {
			ImageColor3 = "PopupBackground",
			ImageTransparency = "PopupBackgroundTransparency",
		},
		Parent = card,
	})

	-- Soft accent spotlight behind the header chip; clipped to the card rect.
	if Layout.Glow == true then
		New("ImageLabel", {
			Name = "AccentGlow",
			Image = "rbxassetid://8992230677",
			ScaleType = "Slice",
			SliceCenter = Rect.new(99, 99, 99, 99),
			Size = UDim2.new(0, 420, 0, 420),
			Position = UDim2.new(0, Padding + 22 - 210, 0, Padding + 22 - 210),
			BackgroundTransparency = 1,
			ImageTransparency = 0.87,
			ThemeTag = accentTag and { ImageColor3 = accentTag } or nil,
			ImageColor3 = accentTag and nil or accentColor,
			Parent = surface,
		})
	end

	Creator.NewRoundFrame(Radius, "SquircleOutline", {
		Name = "Stroke",
		Size = UDim2.new(1, 2, 1, 2),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		ThemeTag = { ImageColor3 = "Outline" },
		ImageTransparency = 0.87,
		Parent = card,
	})

	New("Frame", {
		Name = "TopSheen",
		Size = UDim2.new(1, -Radius * 2, 0, 1),
		Position = UDim2.new(0, Radius, 0, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.9,
		Parent = card,
	}, {
		New("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.5, 0.45),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}),
	})

	local content = New("Frame", {
		Name = "Content",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = "Y",
		BackgroundTransparency = 1,
		Parent = card,
	}, {
		New("UIPadding", {
			PaddingTop = UDim.new(0, Padding),
			PaddingLeft = UDim.new(0, Padding),
			PaddingRight = UDim.new(0, Padding),
			PaddingBottom = UDim.new(0, Padding),
		}),
		New("UIListLayout", {
			FillDirection = "Vertical",
			Padding = UDim.new(0, Gap),
			SortOrder = "LayoutOrder",
		}),
	})

	------------------------------------------------------------------
	-- Button factory
	------------------------------------------------------------------

	local function createButton(options)
		local height = options.Height or 38
		local style = STYLE_ALIASES[options.Style or options.Variant or "Soft"] or "Soft"
		local iconOnly = options.IconOnly
		if iconOnly == nil then
			iconOnly = options.Icon ~= nil and options.Title == nil
		end
		local width = options.Width

		local root = New("TextButton", {
			Name = options.Name or "Button",
			Size = width and UDim2.new(0, width, 0, height)
				or iconOnly and UDim2.new(0, height, 0, height)
				or UDim2.new(0, 0, 0, height),
			AutomaticSize = (width or iconOnly) and "None" or "X",
			BackgroundTransparency = 1,
			AutoButtonColor = false,
			Text = "",
			Parent = options.Parent,
			LayoutOrder = options.Order or 0,
			Visible = options.Visible ~= false,
		}, {
			New("UIScale", { Scale = 1 }),
		})

		local fillProps = {
			Name = "Fill",
			Size = UDim2.new(1, 0, 1, 0),
			Parent = root,
		}

		-- FillColor accepts a Color3, a theme key, or a WindUI:Gradient table.
		local customFill = options.FillColor
		local fillChildren = {}
		local customText = customFill ~= nil and fillTextColor(customFill) or nil
		local filled = style == "Solid" or style == "White" or customFill ~= nil

		if style == "Solid" then
			fillProps.ImageTransparency = 0
			accentPaint(fillProps, accentTag, accentColor)
		elseif style == "White" then
			fillProps.ImageColor3 = Color3.new(1, 1, 1)
			fillProps.ImageTransparency = 0
		elseif style == "Ghost" then
			fillProps.ThemeTag = { ImageColor3 = "Text" }
			fillProps.ImageTransparency = 1
		else
			fillProps.ThemeTag = {
				ImageColor3 = "LabelBackground",
				ImageTransparency = "LabelBackgroundTransparency",
			}
		end

		if customFill ~= nil then
			applyFill(customFill, fillProps, fillChildren)
		end

		local fill = Creator.NewRoundFrame(options.Radius or math.floor(height / 2), "Squircle", fillProps, fillChildren)
		local fillBase = fill.ImageTransparency

		Creator.NewRoundFrame(math.max((options.Radius or math.floor(height / 2)) - 1, 0), "SquircleGlass", {
			Size = UDim2.new(1, 1, 1, 1),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, 0),
			ThemeTag = { ImageColor3 = "Outline" },
			ImageTransparency = style == "Solid" and 0.82 or 0.9,
			Parent = root,
		})

		local hover = Creator.NewRoundFrame(options.Radius or math.floor(height / 2), "Squircle", {
			Name = "Hover",
			Size = UDim2.new(1, 0, 1, 0),
			ImageColor3 = Color3.new(1, 1, 1),
			ImageTransparency = 1,
			Parent = root,
		})

		local iconImage
		local image, rectSize, rectOffset = iconData(options.Icon)
		if image then
			iconImage = New("ImageLabel", {
				Image = image,
				ImageRectSize = rectSize,
				ImageRectOffset = rectOffset,
				Size = UDim2.new(0, options.IconSize or 18, 0, options.IconSize or 18),
				BackgroundTransparency = 1,
				ImageColor3 = customText
					or (style == "Solid" and onAccent or style == "White" and Color3.new(0, 0, 0) or nil),
				ThemeTag = (not filled) and { ImageColor3 = "Icon" } or nil,
			})
		end

		local label
		if options.Title then
			label = New("TextLabel", {
				BackgroundTransparency = 1,
				Text = options.Title,
				FontFace = Font.new(Creator.Font, Enum.FontWeight.SemiBold),
				TextSize = options.TextSize or 15,
				AutomaticSize = "XY",
				TextColor3 = customText
					or (style == "Solid" and onAccent or style == "White" and Color3.new(0, 0, 0) or nil),
				ThemeTag = (not filled) and { TextColor3 = "Text" } or nil,
				TextTransparency = filled and 0 or 0.05,
			})
		end

		New("Frame", {
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			Parent = root,
		}, {
			New("UIPadding", {
				PaddingLeft = UDim.new(0, iconOnly and 0 or 15),
				PaddingRight = UDim.new(0, iconOnly and 0 or 15),
			}),
			New("UIListLayout", {
				FillDirection = "Horizontal",
				Padding = UDim.new(0, 7),
				VerticalAlignment = "Center",
				HorizontalAlignment = "Center",
			}),
			iconImage,
			label,
		})

		local scale = root.UIScale

		Creator.AddSignal(root.MouseEnter, function()
			if options.Disabled then
				return
			end
			Tween(hover, 0.12, { ImageTransparency = style == "Ghost" and 0.94 or 0.9 }):Play()
			Tween(scale, 0.12, { Scale = 1.02 }):Play()
		end)
		Creator.AddSignal(root.MouseLeave, function()
			Tween(hover, 0.12, { ImageTransparency = 1 }):Play()
			Tween(scale, 0.12, { Scale = 1 }):Play()
		end)
		Creator.AddSignal(root.MouseButton1Down, function()
			if options.Disabled then
				return
			end
			Tween(scale, 0.08, { Scale = 0.97 }):Play()
		end)
		Creator.AddSignal(root.MouseButton1Up, function()
			Tween(scale, 0.12, { Scale = 1 }):Play()
		end)
		Creator.AddSignal(root.MouseButton1Click, function()
			if options.Disabled then
				return
			end
			if options.Callback then
				Creator.SafeCallback(options.Callback, controller)
			end
		end)

		if options.Disabled then
			fill.ImageTransparency = math.min(fillBase + 0.35, 1)
			if label then
				label.TextTransparency = 0.55
			end
			if iconImage then
				iconImage.ImageTransparency = 0.55
			end
		end

		return root, label, iconImage
	end

	------------------------------------------------------------------
	-- Pills (measured after one frame so the badge always fits its text)
	------------------------------------------------------------------

	local pills = {}

	local function makePill(text, options)
		options = options or {}
		local height = options.Height or 20
		local padding = options.Padding or 9

		local pill = New("Frame", {
			Name = options.Name or "Pill",
			Size = UDim2.new(0, 0, 0, height),
			BackgroundTransparency = 1,
			Parent = options.Parent,
		})

		local fillProps = {
			Size = UDim2.new(1, 0, 1, 0),
			ImageTransparency = options.Transparency or 0,
			Parent = pill,
		}
		accentPaint(fillProps, accentTag, accentColor)
		Creator.NewRoundFrame(999, "Squircle", fillProps)

		local label = New("TextLabel", {
			Size = UDim2.new(0, 0, 0, height),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, 0),
			BackgroundTransparency = 1,
			AutomaticSize = "X",
			Text = string.upper(tostring(text)),
			FontFace = Font.new(Creator.Font, Enum.FontWeight.Bold),
			TextSize = options.TextSize or 10,
			TextColor3 = onAccent,
			TextXAlignment = "Center",
			Parent = pill,
		})

		table.insert(pills, {
			Pill = pill,
			Label = label,
			Padding = padding,
			Height = height,
		})

		return pill
	end

	-- Header tag, drawn like WindUI:Tag but sized for the card:
	-- Header.Tag = { Title = "v2.5", Color = WindUI:Gradient({...}) }
	local function makeTag(TagConfig, parent)
		local height = TagConfig.Height or 20
		local padding = TagConfig.Padding or 8
		local color = TagConfig.Color or Color3.fromHex("#315dff")

		local tag = New("Frame", {
			Name = "Tag",
			Size = UDim2.new(0, 0, 0, height),
			BackgroundTransparency = 1,
			Parent = parent,
		})

		local children = {}
		local fillProps = {
			Name = "Fill",
			Size = UDim2.new(1, 0, 1, 0),
			Parent = tag,
		}
		if typeof(color) == "table" then
			applyFill(color, fillProps, children)
		else
			applyFill(color, fillProps, children)
		end

		local glass = Creator.NewRoundFrame(math.max(height / 2, 6), "SquircleGlass", {
			Size = UDim2.new(1, 1, 1, 1),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, 0),
			ThemeTag = { ImageColor3 = "White" },
			ImageTransparency = 0.75,
		})
		table.insert(children, glass)

		local textColor = fillTextColor(color) or Color3.new(1, 1, 1)

		local content = New("Frame", {
			Name = "Content",
			Size = UDim2.new(0, 0, 1, 0),
			AutomaticSize = "X",
			BackgroundTransparency = 1,
		}, {
			New("UIPadding", {
				PaddingLeft = UDim.new(0, padding),
				PaddingRight = UDim.new(0, padding),
			}),
			New("UIListLayout", {
				FillDirection = "Horizontal",
				Padding = UDim.new(0, 5),
				SortOrder = "LayoutOrder",
				VerticalAlignment = "Center",
			}),
		})

		local iconImage
		if TagConfig.Icon then
			local image, rectSize, rectOffset = iconData(TagConfig.Icon)
			if image then
				iconImage = New("ImageLabel", {
					Image = image,
					ImageRectSize = rectSize,
					ImageRectOffset = rectOffset,
					Size = UDim2.new(0, TagConfig.IconSize or 12, 0, TagConfig.IconSize or 12),
					BackgroundTransparency = 1,
					ImageColor3 = textColor,
					LayoutOrder = 1,
					Parent = content,
				})
			end
		end

		New("TextLabel", {
			Name = "Title",
			Size = UDim2.new(0, 0, 0, height),
			AutomaticSize = "X",
			BackgroundTransparency = 1,
			Text = tostring(TagConfig.Title or "Tag"),
			FontFace = Font.new(Creator.Font, Enum.FontWeight.SemiBold),
			TextSize = TagConfig.TextSize or 10,
			TextColor3 = textColor,
			LayoutOrder = 2,
			Parent = content,
		})

		Creator.NewRoundFrame(math.max(height / 2, 6), "Squircle", fillProps, children)
		content.Parent = tag

		-- The pill hugs its content: measured on the next frame, then fixed so the
		-- scale-1 fill can never stretch the frame through AutomaticSize.
		task.defer(function()
			local width = math.ceil(content.AbsoluteSize.X)
			if width > 0 and tag.Parent then
				tag.Size = UDim2.new(0, width, 0, height)
			end
		end)

		return tag
	end

	------------------------------------------------------------------
	-- Thumbnail
	------------------------------------------------------------------

	local function buildThumbnail(parent, mode)
		local innerRadius = ThumbConfig.Radius or math.max(Radius - 8, 6)

		local panel = New("Frame", {
			Name = "Thumbnail",
			BackgroundTransparency = 1,
			Parent = parent,
			Size = mode == "Side" and UDim2.new(0, ThumbSize, 0, 0) or UDim2.new(1, 0, 0, ThumbHeight),
		})

		New("ImageLabel", {
			Name = "Image",
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			Image = ThumbImage,
			ScaleType = ThumbConfig.ScaleType or "Crop",
			ImageTransparency = ThumbConfig.Transparency or 0,
			Parent = panel,
		}, {
			New("UICorner", { CornerRadius = UDim.new(0, innerRadius) }),
		})

		New("Frame", {
			Name = "Scrim",
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0,
			Parent = panel,
		}, {
			New("UICorner", { CornerRadius = UDim.new(0, innerRadius) }),
			New("UIGradient", {
				Rotation = 90,
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(0.4, 0.94),
					NumberSequenceKeypoint.new(1, 1 - (ThumbConfig.Gradient or 0.82)),
				}),
			}),
		})

		Creator.NewRoundFrame(innerRadius, "SquircleOutline", {
			Name = "Edge",
			Size = UDim2.new(1, 2, 1, 2),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, 0),
			ThemeTag = { ImageColor3 = "White" },
			ImageTransparency = 0.86,
			Parent = panel,
		})

		if ThumbBadge then
			local badge = makePill(ThumbBadge, {
				Name = "Badge",
				Parent = panel,
				Height = 22,
				Padding = 10,
				TextSize = 10,
			})
			badge.Position = UDim2.new(0, 12, 0, 12)
		end

		local stack = New("Frame", {
			Name = "Stack",
			Size = UDim2.new(1, -24, 0, 0),
			AutomaticSize = "Y",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 12, 1, -12),
			BackgroundTransparency = 1,
			Parent = panel,
		}, {
			New("UIListLayout", {
				FillDirection = "Vertical",
				Padding = UDim.new(0, 4),
				SortOrder = "LayoutOrder",
			}),
		})

		if ThumbTitle then
			New("TextLabel", {
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = "Y",
				BackgroundTransparency = 1,
				Text = ThumbTitle,
				TextWrapped = true,
				TextXAlignment = "Left",
				FontFace = Font.new(Creator.Font, Enum.FontWeight.SemiBold),
				TextSize = ThumbConfig.TitleSize or 20,
				TextColor3 = Color3.new(1, 1, 1),
				LayoutOrder = 1,
				Parent = stack,
			})
		end

		if ThumbSubtitle then
			New("TextLabel", {
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = "Y",
				BackgroundTransparency = 1,
				Text = ThumbSubtitle,
				TextWrapped = true,
				TextXAlignment = "Left",
				FontFace = Font.new(Creator.Font, Enum.FontWeight.Medium),
				TextSize = ThumbConfig.SubtitleSize or 13,
				TextColor3 = Color3.new(1, 1, 1),
				TextTransparency = 0.3,
				LayoutOrder = 2,
				Parent = stack,
			})
		end

		local buttonRow = New("Frame", {
			Name = "ThumbnailButtons",
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = "Y",
			BackgroundTransparency = 1,
			LayoutOrder = 3,
			Parent = stack,
		}, {
			New("UIListLayout", {
				FillDirection = "Horizontal",
				Padding = UDim.new(0, 8),
				SortOrder = "LayoutOrder",
				VerticalAlignment = "Center",
			}),
		})

		return {
			Panel = panel,
			Stack = stack,
			Buttons = buttonRow,
			Mode = mode,
		}
	end

	------------------------------------------------------------------
	-- Structure
	------------------------------------------------------------------

	if ThumbEnabled and (ThumbPosition == "Left" or ThumbPosition == "Right") then
		local row = New("Frame", {
			Name = "Row",
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = "Y",
			BackgroundTransparency = 1,
			LayoutOrder = 1,
			Parent = content,
		})

		thumbnail = buildThumbnail(row, "Side")

		if ThumbPosition == "Right" then
			thumbnail.Panel.AnchorPoint = Vector2.new(1, 0)
			thumbnail.Panel.Position = UDim2.new(1, 0, 0, 0)
			body = New("Frame", {
				Name = "Body",
				Size = UDim2.new(1, -(ThumbSize + Gap), 0, 0),
				AutomaticSize = "Y",
				BackgroundTransparency = 1,
				Parent = row,
			})
		else
			body = New("Frame", {
				Name = "Body",
				Size = UDim2.new(1, -(ThumbSize + Gap), 0, 0),
				Position = UDim2.new(0, ThumbSize + Gap, 0, 0),
				AutomaticSize = "Y",
				BackgroundTransparency = 1,
				Parent = row,
			})
		end
	else
		if ThumbEnabled and ThumbPosition == "Top" then
			thumbnail = buildThumbnail(content, "Top")
			thumbnail.Panel.LayoutOrder = 1
		end

		body = New("Frame", {
			Name = "Body",
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = "Y",
			BackgroundTransparency = 1,
			LayoutOrder = 2,
			Parent = content,
		})
	end

	New("UIListLayout", {
		FillDirection = "Vertical",
		Padding = UDim.new(0, Gap),
		SortOrder = "LayoutOrder",
		Parent = body,
	})

	------------------------------------------------------------------
	-- Header
	------------------------------------------------------------------

	local headerSlotEntries = {}
	for _, entry in next, ButtonEntries do
		if entry.Slot == "Header" then
			table.insert(headerSlotEntries, entry)
		end
	end

	local header = New("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = "Y",
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		Parent = body,
	})

	local kickerText = HeaderConfig.Kicker
	local badgeText = asBadge(HeaderConfig.Badge)

	local headerIcon = first(HeaderConfig.Icon, ICON.Key)
	local chipSize = HeaderConfig.IconSize or 44
	local chipWidth = 0
	local iconBackground = HeaderConfig.IconBackground == true

	if headerIcon and HeaderConfig.ShowIcon ~= false then
		if iconBackground then
			chipWidth = chipSize + 13
			local chip = Creator.NewRoundFrame(HeaderConfig.IconRadius or 13, "Squircle", accentPaint({
				Size = UDim2.new(0, chipSize, 0, chipSize),
				Parent = header,
			}, accentTag, accentColor))

			local chipImage, chipRectSize, chipRectOffset = iconData(headerIcon)
			if chipImage then
				New("ImageLabel", {
					Image = chipImage,
					ImageRectSize = chipRectSize,
					ImageRectOffset = chipRectOffset,
					Size = UDim2.new(0, HeaderConfig.ChipIconSize or 22, 0, HeaderConfig.ChipIconSize or 22),
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.new(0.5, 0, 0.5, 0),
					BackgroundTransparency = 1,
					ImageColor3 = onAccent,
					Parent = chip,
				})
			end
		else
			-- Bare icon: no chip, coloured from the theme's Icon key.
			local bareSize = HeaderConfig.ChipIconSize or 26
			local bareImage, bareRectSize, bareRectOffset = iconData(headerIcon)
			if bareImage then
				chipWidth = bareSize + 13
				New("ImageLabel", {
					Image = bareImage,
					ImageRectSize = bareRectSize,
					ImageRectOffset = bareRectOffset,
					Size = UDim2.new(0, bareSize, 0, bareSize),
					Position = UDim2.new(0, 0, 0, kickerText and 18 or 2),
					BackgroundTransparency = 1,
					ThemeTag = { ImageColor3 = "Icon" },
					Parent = header,
				})
			end
		end
	end

	local linkEnabled = HeaderConfig.Link ~= false and KeySystemConfig.URL ~= nil and Layout.ShowURL ~= false
	local linkWidth = linkEnabled and 38 or 0
	local closeWidth = HeaderConfig.Close ~= false and 32 or 0
	local headerReserve = linkWidth + closeWidth + #headerSlotEntries * 38 + 10

	local headerRight = New("Frame", {
		Name = "HeaderRight",
		Size = UDim2.new(0, 0, 0, 32),
		AutomaticSize = "X",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		BackgroundTransparency = 1,
		Parent = header,
	}, {
		New("UIListLayout", {
			FillDirection = "Horizontal",
			Padding = UDim.new(0, 6),
			SortOrder = "LayoutOrder",
			VerticalAlignment = "Center",
			HorizontalAlignment = "Right",
		}),
	})

	local titleStack = New("Frame", {
		Name = "Titles",
		Size = UDim2.new(1, -(chipWidth + headerReserve), 0, 0),
		Position = UDim2.new(0, chipWidth, 0, 0),
		AutomaticSize = "Y",
		BackgroundTransparency = 1,
		Parent = header,
	}, {
		New("UIListLayout", {
			FillDirection = "Vertical",
			Padding = UDim.new(0, 3),
			SortOrder = "LayoutOrder",
		}),
	})

	if kickerText or badgeText then
		local metaRow = New("Frame", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = "Y",
			BackgroundTransparency = 1,
			LayoutOrder = 1,
			Parent = titleStack,
		}, {
			New("UIListLayout", {
				FillDirection = "Horizontal",
				Padding = UDim.new(0, 8),
				SortOrder = "LayoutOrder",
				VerticalAlignment = "Center",
			}),
		})

		if kickerText then
			New("TextLabel", {
				Size = UDim2.new(0, 0, 0, 14),
				AutomaticSize = "X",
				BackgroundTransparency = 1,
				Text = string.upper(tostring(kickerText)),
				FontFace = Font.new(Creator.Font, Enum.FontWeight.Bold),
				TextSize = 10,
				TextTransparency = 0.45,
				ThemeTag = { TextColor3 = "Text" },
				LayoutOrder = 1,
				Parent = metaRow,
			})
		end

		if badgeText then
			local badge = makePill(badgeText, {
				Name = "HeaderBadge",
				Parent = metaRow,
				Height = 18,
				Padding = 7,
				TextSize = 9,
			})
			badge.LayoutOrder = 2
		end
	end

	local titleRow = New("Frame", {
		Name = "TitleRow",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = "Y",
		BackgroundTransparency = 1,
		LayoutOrder = 2,
		Parent = titleStack,
	}, {
		New("UIListLayout", {
			FillDirection = "Horizontal",
			Padding = UDim.new(0, 8),
			SortOrder = "LayoutOrder",
			VerticalAlignment = "Center",
		}),
	})

	headerTitle = New("TextLabel", {
		Name = "Title",
		Size = UDim2.new(0, 0, 0, 0),
		AutomaticSize = "XY",
		BackgroundTransparency = 1,
		Text = first(HeaderConfig.Title, KeySystemConfig.Title, Config.Title, "Access Required"),
		TextXAlignment = "Left",
		FontFace = Font.new(Creator.Font, Enum.FontWeight.SemiBold),
		TextSize = HeaderConfig.TitleSize or 23,
		ThemeTag = { TextColor3 = "Text" },
		LayoutOrder = 1,
		Parent = titleRow,
	})

	local tagConfig = type(HeaderConfig.Tag) == "table" and HeaderConfig.Tag or nil
	if tagConfig then
		headerTag = makeTag({
			Title = tagConfig.Title,
			Color = tagConfig.Color,
			Icon = tagConfig.Icon,
			IconSize = tagConfig.IconSize,
			Height = tagConfig.Height or 20,
			Padding = tagConfig.Padding or 8,
			TextSize = tagConfig.TextSize or 10,
		}, titleRow)
		headerTag.LayoutOrder = 2
	end

	local subtitleText = HeaderConfig.Subtitle
	if subtitleText == nil then
		subtitleText = "License is required to use the script"
	end

	if subtitleText ~= false then
		New("TextLabel", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = "Y",
			BackgroundTransparency = 1,
			Text = subtitleText,
			TextWrapped = true,
			TextXAlignment = "Left",
			FontFace = Font.new(Creator.Font, Enum.FontWeight.Medium),
			TextSize = HeaderConfig.SubtitleSize or 13,
			TextTransparency = 0.42,
			ThemeTag = { TextColor3 = "Text" },
			LayoutOrder = 3,
			Parent = titleStack,
		})
	end

	if linkEnabled then
		createButton({
			Name = "CopyLink",
			Icon = HeaderConfig.LinkIcon or "external-link",
			IconSize = 16,
			IconOnly = true,
			Height = 32,
			Style = "Ghost",
			Parent = headerRight,
			Order = 998,
			Callback = function()
				openURL(KeySystemConfig.URL)
			end,
		})
	end

	if HeaderConfig.Close ~= false then
		createButton({
			Name = "Close",
			Icon = ICON.Close,
			IconSize = 15,
			IconOnly = true,
			Height = 32,
			Style = "Ghost",
			Parent = headerRight,
			Order = 999,
			Callback = function()
				close()
			end,
		})
	end

	------------------------------------------------------------------
	-- Note
	------------------------------------------------------------------

	local noteText = first(KeySystemConfig.Note, Layout.Note)
	if type(noteText) == "string" and noteText ~= "" and Layout.ShowNote ~= false then
		local noteBlock = New("Frame", {
			Name = "Note",
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = "Y",
			BackgroundTransparency = 1,
			LayoutOrder = 2,
			Parent = body,
		})

		local noteParent = noteBlock

		if (Layout.NoteStyle or "Plain") == "Box" then
			Creator.NewRoundFrame(12, "Squircle", {
				Size = UDim2.new(1, 0, 1, 0),
				ThemeTag = {
					ImageColor3 = "LabelBackground",
					ImageTransparency = "LabelBackgroundTransparency",
				},
				ImageTransparency = 0.55,
				Parent = noteBlock,
			})

			noteParent = New("Frame", {
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = "Y",
				BackgroundTransparency = 1,
				Parent = noteBlock,
			}, {
				New("UIPadding", {
					PaddingTop = UDim.new(0, 12),
					PaddingLeft = UDim.new(0, 13),
					PaddingRight = UDim.new(0, 13),
					PaddingBottom = UDim.new(0, 12),
				}),
			})
		end

		New("TextLabel", {
			Name = "NoteLabel",
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = "Y",
			BackgroundTransparency = 1,
			Text = richText(noteText),
			TextWrapped = true,
			TextXAlignment = "Left",
			RichText = true,
			FontFace = Font.new(Creator.Font, Enum.FontWeight.Medium),
			TextSize = Layout.NoteSize or 14,
			TextTransparency = 0.4,
			ThemeTag = { TextColor3 = "Text" },
			Parent = noteParent,
		})
	end

	------------------------------------------------------------------
	-- Input
	------------------------------------------------------------------

	local inputHeight = InputConfig.Height or 54
	local inputRadius = InputConfig.Radius or 14
	local submitWidth = InputConfig.SubmitWidth or 112
	local inlineSubmit = InputConfig.Submit ~= false
	local clearEnabled = InputConfig.ClearButton ~= false

	local inputSlotEntries = {}
	if inlineSubmit then
		for _, entry in next, ButtonEntries do
			if entry.Slot == "Input" then
				table.insert(inputSlotEntries, entry)
			end
		end
	end

	local clearance = InputConfig.Clearance or 15
	local leftInset = clearance
	local inputIcon = first(InputConfig.Icon, ICON.Key)

	if inputIcon then
		leftInset = clearance + (InputConfig.IconSize or 20) + 10
	end

	inputCursorBase = 8
	if inlineSubmit then
		inputCursorBase = inputCursorBase + submitWidth + 8
	end
	if clearEnabled then
		inputCursorBase = inputCursorBase + 26
	end

	local inputExtra = 0
	for _, entry in next, inputSlotEntries do
		inputExtra = inputExtra + (entry.Width or 36) + 6
	end

	local rightInset = inputCursorBase + inputExtra

	local inputBlock = New("Frame", {
		Name = "InputBlock",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = "Y",
		BackgroundTransparency = 1,
		LayoutOrder = 3,
		Parent = body,
	}, {
		New("UIListLayout", {
			FillDirection = "Vertical",
			Padding = UDim.new(0, InputConfig.Label and 7 or 0),
			SortOrder = "LayoutOrder",
		}),
	})

	-- Small description line above the field.
	local inputLabel = InputConfig.Label
	if inputLabel == nil then
		inputLabel = "License key"
	end
	if inputLabel ~= false and inputLabel ~= "" then
		New("TextLabel", {
			Name = "InputLabel",
			Size = UDim2.new(1, 0, 0, 14),
			BackgroundTransparency = 1,
			Text = tostring(inputLabel),
			TextXAlignment = "Left",
			FontFace = Font.new(Creator.Font, Enum.FontWeight.Medium),
			TextSize = InputConfig.LabelSize or 12,
			TextTransparency = 0.5,
			ThemeTag = { TextColor3 = "Text" },
			LayoutOrder = 1,
			Parent = inputBlock,
		})
	end

	inputShell = Creator.NewRoundFrame(inputRadius, "Squircle", {
		Name = "Input",
		Size = UDim2.new(1, 0, 0, inputHeight),
		ThemeTag = {
			ImageColor3 = "LabelBackground",
			ImageTransparency = "LabelBackgroundTransparency",
		},
		LayoutOrder = 2,
		Parent = inputBlock,
	})
	controller.Shell = inputShell

	Creator.NewRoundFrame(math.max(inputRadius - 1, 0), "SquircleGlass", {
		Size = UDim2.new(1, 1, 1, 1),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		ThemeTag = { ImageColor3 = "Outline" },
		ImageTransparency = 0.88,
		Parent = inputShell,
	})

	local focusProps = {
		Name = "FocusRing",
		Size = UDim2.new(1, 2, 1, 2),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		ImageTransparency = 1,
		Parent = inputShell,
	}
	accentPaint(focusProps, accentTag, accentColor)
	local focusRing = Creator.NewRoundFrame(inputRadius, "SquircleOutline", focusProps)

	local inputImage, inputRectSize, inputRectOffset = iconData(inputIcon)
	if inputImage then
		New("ImageLabel", {
			Image = inputImage,
			ImageRectSize = inputRectSize,
			ImageRectOffset = inputRectOffset,
			Size = UDim2.new(0, InputConfig.IconSize or 20, 0, InputConfig.IconSize or 20),
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, clearance, 0.5, 0),
			BackgroundTransparency = 1,
			ImageTransparency = 0.15,
			ThemeTag = { ImageColor3 = "Icon" },
			Parent = inputShell,
		})
	end

	textBox = New("TextBox", {
		Name = "KeyInput",
		Size = UDim2.new(1, -(leftInset + rightInset), 1, 0),
		Position = UDim2.new(0, leftInset, 0, 0),
		BackgroundTransparency = 1,
		Text = "",
		PlaceholderText = InputConfig.Placeholder or "Enter Key",
		TextSize = InputConfig.TextSize or 16,
		FontFace = Font.new(Creator.Font, Enum.FontWeight.Medium),
		TextXAlignment = "Left",
		TextYAlignment = "Center",
		ClearTextOnFocus = false,
		ClipsDescendants = true,
		ThemeTag = {
			PlaceholderColor3 = "Placeholder",
			TextColor3 = "Text",
		},
		Parent = inputShell,
	})
	controller.Input = textBox

	local clearVisible = false
	local clearButton

	if clearEnabled then
		clearButton = createButton({
			Name = "Clear",
			Icon = ICON.Close,
			IconSize = 13,
			IconOnly = true,
			Height = 24,
			Style = "Ghost",
			Parent = inputShell,
			Visible = false,
			Callback = function()
				textBox.Text = ""
				pcall(function()
					textBox:CaptureFocus()
				end)
			end,
		})
		clearButton.AnchorPoint = Vector2.new(1, 0.5)
		clearButton.Position = UDim2.new(1, -inputCursorBase + 26, 0.5, 0)
	end

	textBox:GetPropertyChangedSignal("Text"):Connect(function()
		enteredKey = textBox.Text
		if clearButton then
			local shouldShow = #textBox.Text > 0
			if shouldShow ~= clearVisible then
				clearVisible = shouldShow
				clearButton.Visible = shouldShow
			end
		end
	end)

	textBox.Focused:Connect(function()
		Tween(focusRing, 0.15, { ImageTransparency = 0.35 }):Play()
		Tween(inputShell, 0.15, { ImageTransparency = 0.72 }):Play()
	end)

	textBox.FocusLost:Connect(function(enterPressed)
		Tween(focusRing, 0.2, { ImageTransparency = 1 }):Play()
		Tween(inputShell, 0.2, { ImageTransparency = 0.83 }):Play()
		if enterPressed and InputConfig.EnterToSubmit ~= false and Layout.EnterToSubmit ~= false then
			submit()
		end
	end)

	------------------------------------------------------------------
	-- Status
	------------------------------------------------------------------

	if StatusConfig.Show ~= false then
		local loadingConfig = type(Layout.LoadingPill) == "table" and Layout.LoadingPill or {}
		local pillEnabled = loadingConfig.Show ~= false
		local pillHeight = loadingConfig.Height or 24
		local statusHeight = pillEnabled and pillHeight or 18
		statusRowHeight = statusHeight
		pillRowHeight = pillHeight
		pillVisible = pillEnabled

		-- Idle height is zero so the card does not carry dead space under the input.
		local status = New("Frame", {
			Name = "Status",
			Size = UDim2.new(1, 0, 0, 0),
			BackgroundTransparency = 1,
			ClipsDescendants = false,
			LayoutOrder = 4,
			Parent = body,
		}, {
			New("UIListLayout", {
				FillDirection = "Horizontal",
				Padding = UDim.new(0, 7),
				VerticalAlignment = "Center",
				SortOrder = "LayoutOrder",
			}),
		})

		statusIcon = New("ImageLabel", {
			Size = UDim2.new(0, 14, 0, 14),
			BackgroundTransparency = 1,
			ImageTransparency = 1,
			LayoutOrder = 1,
			Parent = status,
		})

		statusLabel = New("TextLabel", {
			Size = UDim2.new(1, -21, 1, 0),
			BackgroundTransparency = 1,
			Text = "",
			TextXAlignment = "Left",
			FontFace = Font.new(Creator.Font, Enum.FontWeight.Medium),
			TextSize = StatusConfig.TextSize or 13,
			TextTransparency = 1,
			LayoutOrder = 2,
			Parent = status,
		})

		statusBlock = status

		if pillEnabled then
			-- Busy pill: replaces the status line while a key is being checked.
			loadingPill = New("Frame", {
				Name = "LoadingPill",
				Size = UDim2.new(0, 0, 0, pillHeight),
				AutomaticSize = "X",
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 0, 0.5, 0),
				BackgroundTransparency = 1,
				Visible = false,
				Parent = status,
			})

			local pillStyle = loadingConfig.Style or "Soft"
			local fill = {
				Name = "Fill",
				Size = UDim2.new(1, 0, 1, 0),
				Parent = loadingPill,
			}
			if pillStyle == "Solid" then
				accentPaint(fill, accentTag, accentColor)
				fill.ImageTransparency = 0
			elseif pillStyle == "Ghost" then
				fill.ThemeTag = { ImageColor3 = "LabelBackground", ImageTransparency = "LabelBackgroundTransparency" }
				fill.ImageTransparency = 0.4
			else
				fill.ThemeTag = { ImageColor3 = "LabelBackground", ImageTransparency = "LabelBackgroundTransparency" }
			end
			Creator.NewRoundFrame(999, "Squircle", fill)

			local pillContent = New("Frame", {
				Name = "Content",
				Size = UDim2.new(1, 0, 1, 0),
				BackgroundTransparency = 1,
				Parent = loadingPill,
			}, {
				New("UIPadding", {
					PaddingLeft = UDim.new(0, 10),
					PaddingRight = UDim.new(0, 11),
				}),
				New("UIListLayout", {
					FillDirection = "Horizontal",
					Padding = UDim.new(0, 7),
					SortOrder = "LayoutOrder",
					VerticalAlignment = "Center",
				}),
			})

			local spinnerProps = {
				Name = "Spinner",
				Size = UDim2.new(0, 13, 0, 13),
				BackgroundTransparency = 1,
				LayoutOrder = 1,
				Parent = pillContent,
			}
			if pillStyle == "Solid" then
				spinnerProps.ImageColor3 = onAccent
			elseif accentTag then
				spinnerProps.ThemeTag = { ImageColor3 = accentTag }
			else
				spinnerProps.ImageColor3 = accentColor
			end
			local spinner = New("ImageLabel", spinnerProps)
			applyIcon(spinner, loadingConfig.Icon or "loader")

			New("TextLabel", {
				Name = "Label",
				Size = UDim2.new(0, 0, 1, 0),
				AutomaticSize = "X",
				BackgroundTransparency = 1,
				Text = loadingConfig.Text or "Checking key\u{2026}",
				FontFace = Font.new(Creator.Font, Enum.FontWeight.Medium),
				TextSize = loadingConfig.TextSize or 12,
				TextColor3 = pillStyle == "Solid" and onAccent or nil,
				ThemeTag = pillStyle ~= "Solid" and { TextColor3 = "Text" } or nil,
				LayoutOrder = 2,
				Parent = pillContent,
			})

			task.spawn(function()
				local angle = 0
				while mount.Parent do
					if loadingPill.Visible then
						angle = (angle + 9) % 360
						spinner.Rotation = angle
					end
					task.wait(1 / 30)
				end
			end)
		end
	end

	------------------------------------------------------------------
	-- Footer
	------------------------------------------------------------------

	local footerEntries = {}
	for _, entry in next, ButtonEntries do
		local slot = entry.Slot or "Footer"
		if slot == "Footer" then
			table.insert(footerEntries, entry)
		end
	end

	local hasURLEntry = KeySystemConfig.URL ~= nil and Layout.ShowURL ~= false
	local needsFooter = not inlineSubmit or hasURLEntry or #footerEntries > 0 or FooterConfig.Text ~= nil

	if needsFooter and FooterConfig.Show ~= false then
		local footer = New("Frame", {
			Name = "Footer",
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = "Y",
			BackgroundTransparency = 1,
			LayoutOrder = 6,
			Parent = body,
		}, {
			New("UIListLayout", {
				FillDirection = "Vertical",
				Padding = UDim.new(0, FooterConfig.Gap or 12),
				SortOrder = "LayoutOrder",
			}),
		})

		if FooterConfig.Divider ~= false then
			New("Frame", {
				Name = "Divider",
				Size = UDim2.new(1, 0, 0, 1),
				BackgroundColor3 = resolveThemeColor("Outline"),
				BackgroundTransparency = 0.88,
				LayoutOrder = 1,
				Parent = footer,
			})
		end

		footerRow = New("Frame", {
			Name = "Row",
			Size = UDim2.new(1, 0, 0, 40),
			BackgroundTransparency = 1,
			LayoutOrder = 2,
			Parent = footer,
		})

		footerCluster = New("Frame", {
			Name = "Buttons",
			Size = UDim2.new(0, 0, 1, 0),
			AutomaticSize = "X",
			BackgroundTransparency = 1,
			Parent = footerRow,
		}, {
			New("UIListLayout", {
				FillDirection = "Horizontal",
				Padding = UDim.new(0, 8),
				SortOrder = "LayoutOrder",
				VerticalAlignment = "Center",
			}),
		})

		if FooterConfig.Align == "Center" then
			footerCluster.AnchorPoint = Vector2.new(0.5, 0.5)
			footerCluster.Position = UDim2.new(0.5, 0, 0.5, 0)
		elseif FooterConfig.Align == "Right" then
			footerCluster.AnchorPoint = Vector2.new(1, 0.5)
			footerCluster.Position = UDim2.new(1, 0, 0.5, 0)
		else
			footerCluster.AnchorPoint = Vector2.new(0, 0.5)
			footerCluster.Position = UDim2.new(0, 0, 0.5, 0)
		end

		if FooterConfig.Text then
			New("TextLabel", {
				Name = "FooterNote",
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = "Y",
				BackgroundTransparency = 1,
				Text = FooterConfig.Text,
				FontFace = Font.new(Creator.Font, Enum.FontWeight.Medium),
				TextSize = FooterConfig.TextSize or 12,
				TextTransparency = 0.5,
				TextXAlignment = FooterConfig.Align == "Center" and "Center" or FooterConfig.Align == "Right" and "Right" or "Left",
				ThemeTag = { TextColor3 = "Text" },
				LayoutOrder = 3,
				Parent = footer,
			})
		end
	end

	------------------------------------------------------------------
	-- Slots
	------------------------------------------------------------------

	local bodySlot

	local function slotTarget(slot)
		slot = slot or "Footer"
		if slot == "Header" then
			return headerRight
		elseif slot == "Footer" then
			return footerCluster
		elseif slot == "Thumbnail" then
			return thumbnail and thumbnail.Buttons or nil
		elseif slot == "Input" then
			return inputShell
		elseif slot == "Body" then
			if not bodySlot then
				bodySlot = New("Frame", {
					Name = "BodyButtons",
					Size = UDim2.new(1, 0, 0, 0),
					AutomaticSize = "Y",
					BackgroundTransparency = 1,
					LayoutOrder = 5,
					Parent = body,
				}, {
					New("UIListLayout", {
						FillDirection = "Horizontal",
						Padding = UDim.new(0, 8),
						SortOrder = "LayoutOrder",
						VerticalAlignment = "Center",
					}),
				})
			end
			return bodySlot
		end
		return nil
	end

	local inputCursor = inputCursorBase

	local function actionFor(entry)
		if entry.Callback then
			return function(ctrl)
				Creator.SafeCallback(entry.Callback, ctrl)
			end
		end

		local action = entry.Action
		if action == "Submit" then
			return function()
				submit()
			end
		elseif action == "Exit" then
			return function()
				close()
			end
		elseif action == "CopyURL" then
			return function()
				copyToClipboard(entry.URL or KeySystemConfig.URL, "Key link copied to clipboard.")
			end
		elseif action == "OpenURL" then
			return function()
				openURL(entry.URL or KeySystemConfig.URL)
			end
		elseif action == "CopyKey" then
			return function()
				copyToClipboard(enteredKey, "Key copied to clipboard.")
			end
		elseif action == "CopyText" then
			return function()
				copyToClipboard(entry.Text, "Copied to clipboard.")
			end
		end

		return nil
	end

	local function mountButton(entry, fallbackSlot, order)
		local slot = entry.Slot or fallbackSlot or "Footer"
		if slot == "Hidden" then
			return nil
		end
		if slot == "Input" and not inlineSubmit then
			slot = "Footer"
		end

		local target = slotTarget(slot)
		if not target then
			return nil
		end

		local defaultHeight = 38
		if slot == "Header" then
			defaultHeight = 32
		elseif slot == "Thumbnail" then
			defaultHeight = 34
		elseif slot == "Input" then
			defaultHeight = 36
		end

		local button = createButton({
			Name = entry.Name or entry.Title or entry.ID or "Button",
			Title = entry.Title,
			Icon = entry.Icon,
			IconSize = entry.IconSize,
			IconOnly = entry.IconOnly,
			Style = entry.Style or entry.Variant,
			Height = entry.Height or defaultHeight,
			Width = entry.Width,
			Radius = entry.Radius,
			Parent = target,
			Order = entry.Order or order,
			Disabled = entry.Disabled,
			FillColor = entry.FillColor or entry.Gradient,
			Callback = actionFor(entry),
		})

		if slot == "Input" then
			local buttonWidth = entry.Width or 36
			button.AnchorPoint = Vector2.new(1, 0.5)
			button.Position = UDim2.new(1, -(inputCursor + buttonWidth), 0.5, 0)
			inputCursor = inputCursor + buttonWidth + 6
		end

		if entry.ID then
			controller.Buttons[entry.ID] = button
		end

		return button
	end

	if hasURLEntry then
		mountButton({
			ID = "GetKey",
			Title = Layout.URLTitle or "Get Key",
			Icon = Layout.URLIcon ~= false and (Layout.URLIcon or "key") or nil,
			Style = Layout.URLStyle or "Secondary",
			Slot = Layout.URLSlot or "Footer",
			Order = Layout.URLOrder or 10,
			Action = Layout.URLAction or "OpenURL",
		}, "Footer")
	end

	if KeySystemConfig.API and Layout.ShowServices ~= false then
		local serviceIndex = 0
		for _, serviceConfig in next, KeySystemConfig.API do
			local serviceDef = Config.WindUI.Services[serviceConfig.Type]
			if serviceDef then
				serviceIndex = serviceIndex + 1

				local serviceInstance
				for _, instance in next, Services do
					if instance.Type == serviceConfig.Type then
						serviceInstance = instance
						break
					end
				end

				local entry = serviceConfig.Button or {}
				mountButton({
					ID = "Service:" .. tostring(serviceConfig.Type),
					Title = entry.Title or serviceConfig.Title or serviceDef.Name,
					Icon = entry.Icon or serviceConfig.Icon or serviceDef.Icon or "user",
					Style = entry.Style or "Secondary",
					Slot = entry.Slot or Layout.ServicesSlot or "Footer",
					Order = entry.Order or (20 + serviceIndex),
					Callback = function()
						if serviceInstance then
							serviceInstance.Copy()
						end
						setStatus("success", "Key link copied to clipboard.")
					end,
				}, "Footer")
			end
		end
	end

	for index, entry in next, ButtonEntries do
		mountButton(entry, entry.Slot or "Footer", 100 + index)
	end

	------------------------------------------------------------------
	-- Submit
	------------------------------------------------------------------

	local submitParent = inlineSubmit and inputShell or (footerCluster or slotTarget("Body"))
	local submitRoot, submitLabel = createButton({
		Name = "Submit",
		Title = InputConfig.SubmitText or "Submit",
		Icon = InputConfig.SubmitIcon ~= false and (InputConfig.SubmitIcon or ICON.Arrow) or nil,
		Style = InputConfig.SubmitStyle or "Solid",
		FillColor = InputConfig.SubmitFill or InputConfig.SubmitGradient,
		Height = InputConfig.SubmitHeight or (inlineSubmit and 40 or 38),
		Width = inlineSubmit and submitWidth or nil,
		Radius = InputConfig.SubmitRadius,
		Parent = submitParent,
		Order = 200,
		Callback = function()
			submit()
		end,
	})
	submitButton = submitRoot
	submitTextLabel = submitLabel

	if inlineSubmit then
		submitButton.AnchorPoint = Vector2.new(1, 0.5)
		submitButton.Position = UDim2.new(1, -8, 0.5, 0)
	end

	------------------------------------------------------------------
	-- Behaviour
	------------------------------------------------------------------

	copyToClipboard = function(text, message)
		if not text or text == "" then
			return
		end
		pcall(function()
			setclipboard(tostring(text))
		end)
		if message then
			setStatus("success", message)
		end
	end

	-- Opening a browser is executor-dependent: try the globals first, then the
	-- GuiService call, and fall back to copying the link so the button never dies.
	openURL = function(url)
		if not url or url == "" then
			return
		end
		local target = tostring(url)

		local function global(name)
			local envs = {}
			if getgenv then
				table.insert(envs, getgenv())
			end
			local ok, env = pcall(getfenv)
			if ok and env then
				table.insert(envs, env)
			end
			table.insert(envs, _G)
			for _, scope in next, envs do
				local value = rawget(scope, name)
				if type(value) == "function" then
					return value
				end
			end
			return nil
		end

		local opener = global("openurl") or global("openUrl") or global("open_browser")
		if opener then
			local ok = pcall(opener, target)
			if ok then
				setStatus("success", "Opening your browser\u{2026}")
				return
			end
		end

		local browserOk = pcall(function()
			game:GetService("GuiService"):OpenBrowserWindow(target)
		end)
		if browserOk then
			setStatus("success", "Opening your browser\u{2026}")
			return
		end

		pcall(function()
			setclipboard(target)
		end)
		setStatus("success", "Link copied \u{2014} open it in your browser.")
	end

	setStatus = function(kind, message)
		if not statusLabel then
			if kind == "error" and Layout.Notify ~= false then
				Config.WindUI:Notify({
					Title = "Key System",
					Content = message or "Invalid key.",
					Icon = ICON.Alert,
				})
			end
			return
		end

		statusToken = statusToken + 1
		local token = statusToken

		if statusBlock then
			Tween(statusBlock, 0.16, { Size = UDim2.new(1, 0, 0, statusRowHeight or 18) }):Play()
		end

		local color = kind == "error" and ERROR_COLOR or kind == "success" and SUCCESS_COLOR or resolveThemeColor("Text")
		local iconName = kind == "error" and ICON.Alert or kind == "success" and ICON.Check or nil

		statusLabel.Text = message or ""
		statusLabel.TextColor3 = color
		Tween(statusLabel, 0.18, { TextTransparency = 0 }):Play()

		if iconName then
			applyIcon(statusIcon, iconName)
			statusIcon.ImageColor3 = color
			Tween(statusIcon, 0.18, { ImageTransparency = 0 }):Play()
		else
			Tween(statusIcon, 0.18, { ImageTransparency = 1 }):Play()
		end

		local duration = tonumber(StatusConfig.Duration) or 3.2
		task.delay(duration, function()
			if statusToken ~= token then
				return
			end
			Tween(statusLabel, 0.3, { TextTransparency = 1 }):Play()
			Tween(statusIcon, 0.3, { ImageTransparency = 1 }):Play()
			task.delay(0.32, function()
				if statusToken ~= token then
					return
				end
				if statusBlock and not (loadingPill and loadingPill.Visible) then
					Tween(statusBlock, 0.2, { Size = UDim2.new(1, 0, 0, 0) }):Play()
				end
			end)
		end)
	end

	shake = function()
		if Layout.Shake == false or not inputShell then
			return
		end
		task.spawn(function()
			for _, offset in next, { 9, -9, 7, -7, 4, -4, 0 } do
				Tween(inputShell, 0.04, { Position = UDim2.new(0, offset, 0, 0) }):Play()
				task.wait(0.04)
			end
		end)
	end

	setBusy = function(value)
		busy = value
		if submitButton then
			submitButton.Active = not value
		end
		if submitTextLabel then
			submitTextLabel.Text = value
					and (InputConfig.SubmitBusyText or "Checking\u{2026}")
				or (InputConfig.SubmitText or "Submit")
		end
		if loadingPill then
			loadingPill.Visible = value
			if statusLabel then
				statusLabel.Visible = not value
			end
			if statusIcon then
				statusIcon.Visible = not value
			end
		end
		if statusBlock then
			if value and pillVisible then
				Tween(statusBlock, 0.14, { Size = UDim2.new(1, 0, 0, pillRowHeight or 24) }):Play()
			elseif not value and not (loadingPill and loadingPill.Visible) then
				Tween(statusBlock, 0.18, { Size = UDim2.new(1, 0, 0, 0) }):Play()
			end
		end
	end

	close = function()
		if closed then
			return
		end
		closed = true
		Tween(card, 0.18, { GroupTransparency = 1 }):Play()
		Tween(holderScale, 0.18, { Scale = 0.97 }, Enum.EasingStyle.Quint, Enum.EasingDirection.In):Play()
		task.delay(0.2, function()
			if mount then
				mount:Destroy()
			end
		end)
	end

	local function flash()
		Tween(focusRing, 0.16, { ImageTransparency = 0 }):Play()
		task.delay(0.24, function()
			Tween(focusRing, 0.4, { ImageTransparency = 1 }):Play()
		end)
	end

	submit = function()
		if busy or closed then
			return
		end

		local key = tostring(enteredKey or "")
		if key == "" then
			shake()
			setStatus("error", StatusConfig.Empty or "Enter a key to continue.")
			return
		end

		setBusy(true)

		-- One frame so the loading pill actually paints before a synchronous
		-- validator flips busy back off.
		if loadingPill then
			task.wait()
		end

		local isValid = false
		local failureMessage
		local failureReason

		if KeySystemConfig.KeyValidator then
			local success, result, reason = pcall(KeySystemConfig.KeyValidator, key)
			if success then
				isValid = result and true or false
				failureReason = reason
			else
				failureMessage = "Key validator failed."
			end
		elseif KeySystemConfig.API and #Services > 0 then
			for _, service in next, Services do
				local success, result = service.Verify(key)
				if success then
					isValid = true
					break
				end
				failureMessage = result
			end
		else
			local expected = KeySystemConfig.Key
			if type(expected) == "table" then
				isValid = table.find(expected, key) ~= nil
			elseif expected ~= nil then
				isValid = tostring(expected) == key
			end
		end

		-- Validators can return false, "expired" (or any reason code) and the
		-- message is looked up in Layout.Status.Errors. A raw string still works.
		if failureReason ~= nil and failureReason ~= false then
			failureMessage = StatusErrors[failureReason] or tostring(failureReason)
		elseif type(failureMessage) == "string" and StatusErrors[failureMessage] then
			failureMessage = StatusErrors[failureMessage]
		end

		if not isValid then
			setBusy(false)
			shake()
			setStatus("error", failureMessage or StatusConfig.Error or "Invalid key.")
			if Layout.Notify and StatusConfig.Show == false then
				Config.WindUI:Notify({
					Title = "Key System",
					Content = failureMessage or StatusConfig.Error or "Invalid key.",
					Icon = ICON.Alert,
				})
			end
			return
		end

		if KeySystemConfig.SaveKey then
			local keyPath = (Config.Folder or "Temp") .. "/" .. Filename .. ".key"
			pcall(function()
				writefile(keyPath, key)
			end)
		end

		-- Swap the pill back to the status line so the success message shows.
		if loadingPill then
			loadingPill.Visible = false
			if statusLabel then
				statusLabel.Visible = true
			end
			if statusIcon then
				statusIcon.Visible = true
			end
		end

		setStatus("success", StatusConfig.Success or "Key accepted. Loading\u{2026}")
		flash()

		task.delay(0.45, function()
			if closed then
				return
			end
			close()
			task.wait(0.35)
			if func then
				func(true)
			end
		end)
	end

	------------------------------------------------------------------
	-- Element offsets
	-- Each block can be nudged with Offset = { X, Y } (or { X =, Y = }).
	-- The nudge is visual only: flow keeps its original order and spacing,
	-- so a moved element draws over its neighbours instead of pushing them.
	------------------------------------------------------------------

	local offsetMap = {
		Header = (Layout.Header or {}).Offset or (Layout.Offsets or {}).Header,
		Note = (Layout.Offsets or {}).Note,
		InputBlock = (Layout.Input or {}).Offset or (Layout.Offsets or {}).Input or { 0, 8 },
		Status = (Layout.Status or {}).Offset or (Layout.Offsets or {}).Status,
		Footer = (Layout.Footer or {}).Offset or (Layout.Offsets or {}).Footer,
	}

	local function readOffset(value)
		if type(value) ~= "table" then
			return nil
		end
		local x = value.X or value[1] or 0
		local y = value.Y or value[2] or 0
		if x == 0 and y == 0 then
			return nil
		end
		return x, y
	end

	if body then
		for _, block in next, body:GetChildren() do
			local x, y = readOffset(offsetMap[block.Name])
			if x then
				local slot = New("Frame", {
					Name = block.Name .. "Slot",
					Size = UDim2.new(1, 0, 0, 0),
					AutomaticSize = "Y",
					BackgroundTransparency = 1,
					ClipsDescendants = false,
					LayoutOrder = block.LayoutOrder,
					Parent = body,
				})
				block.LayoutOrder = 0
				block.Parent = slot
				block.Position = UDim2.new(0, x, 0, y)
			end
		end
	end

	if thumbnail and thumbnail.Panel then
		local x, y = readOffset((Layout.Thumbnail or {}).Offset)
		if x then
			local base = thumbnail.Panel.Position
			thumbnail.Panel.Position = UDim2.new(base.X.Scale, base.X.Offset + x, base.Y.Scale, base.Y.Offset + y)
		end
	end

	------------------------------------------------------------------
	-- Measure, then reveal
	------------------------------------------------------------------

	task.wait()
	task.wait()

	local uiScale = Creator.UIScale or 1

	-- Badges measure after layout so the pill hugs the real text width.
	for _, item in next, pills do
		local textWidth = item.Label.AbsoluteSize.X / uiScale
		if textWidth > 0 then
			item.Pill.Size = UDim2.new(0, math.ceil(textWidth) + item.Padding * 2, 0, item.Height)
		end
	end

	-- Keep the tag from pushing the title under the top-right buttons: the title
	-- gets whatever the row has left and truncates instead of overlapping.
	if headerTitle and headerTag then
		local tagWidth = math.ceil(headerTag.AbsoluteSize.X / uiScale)
		if tagWidth > 0 then
			headerTitle.AutomaticSize = "Y"
			headerTitle.TextWrapped = false
			headerTitle.TextTruncate = Enum.TextTruncate.AtEnd
			headerTitle.Size = UDim2.new(1, -(tagWidth + 8), 0, 0)
		end
	end

	local function syncThumbnail()
		if not body or not thumbnail or thumbnail.Mode ~= "Side" then
			return
		end
		local bodyHeight = math.round(body.AbsoluteSize.Y / uiScale)
		if bodyHeight > 0 then
			thumbnail.Panel.Size = UDim2.new(0, ThumbSize, 0, bodyHeight)
		end
	end

	task.wait()

	syncThumbnail()

	local contentHeight = math.round(content.AbsoluteSize.Y / uiScale)
	if contentHeight > 0 then
		card.AutomaticSize = "None"
		card.Size = UDim2.new(1, 0, 0, contentHeight)
		holder.Size = UDim2.new(0, Width, 0, contentHeight)
	end

	-- Keep the card inside the viewport on small screens.
	local fitScale = 1
	local cameraOk, camera = pcall(function()
		return workspace.CurrentCamera
	end)
	if cameraOk and camera then
		local viewport = camera.ViewportSize
		if viewport.X > 0 and viewport.Y > 0 then
			local usableWidth = viewport.X - 48
			local usableHeight = viewport.Y - 48
			if Width > usableWidth then
				fitScale = usableWidth / Width
			end
			if contentHeight > 0 and contentHeight > usableHeight then
				fitScale = math.min(fitScale, usableHeight / contentHeight)
			end
		end
	end
	fitScale = math.clamp(fitScale, 0.55, 1)

	if body then
		body:GetPropertyChangedSignal("AbsoluteSize"):Connect(syncThumbnail)
	end

	holderScale.Scale = 0.96 * fitScale
	mount.Visible = true
	Tween(card, 0.28, { GroupTransparency = 0 }, Enum.EasingStyle.Quint, Enum.EasingDirection.Out):Play()
	Tween(holderScale, 0.32, { Scale = fitScale }, Enum.EasingStyle.Quint, Enum.EasingDirection.Out):Play()

	if InputConfig.AutoFocus ~= false then
		task.delay(0.3, function()
			if textBox and not closed then
				pcall(function()
					textBox:CaptureFocus()
				end)
			end
		end)
	end

	controller.Submit = submit
	controller.Close = close
	controller.SetStatus = setStatus
	controller.SetBusy = setBusy
	controller.Shake = shake
	controller.SetKey = function(value)
		if textBox then
			textBox.Text = tostring(value or "")
		end
	end

	if Layout.Debug then
		local runtime = getgenv and getgenv() or _G
		if runtime then
			local registry = runtime.WindUIKeySystems
			if type(registry) ~= "table" then
				registry = {}
				runtime.WindUIKeySystems = registry
			end
			table.insert(registry, controller)
			runtime.WindUIKeySystem = controller
		end
		_G.WindUIKeySystem = controller
	end

	return controller
end

return Modern
