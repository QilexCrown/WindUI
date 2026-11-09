--[[
	ui-stealer.lua - dumps every third-party ScreenGui in the game to a Lua
	table so it can be rebuilt 1:1 somewhere else.

	Run it while the UI you want is on screen. It writes ui-dump.lua next to
	the executor workspace (or to the given path), one entry per ScreenGui,
	with the full instance tree and every layout/visual property that matters.

	    local dump = loadstring(readfile("ui-stealer.lua"))()
	    print(dump.Path)
]]

local OUT = "ui-dump.lua"

-- Roblox's own trees. Anything named here is skipped; add names if a game
-- ships its UI under one of these by accident.
local SKIP = {
	RobloxGui = true,
	ShortcutBar = true,
	RobloxPromptGui = true,
	ScreenshotsCarousel = true,
	CaptureManager = true,
	CaptureOverlay = true,
	MomentsCreationFlow = true,
	RobloxNetworkPauseNotification = true,
	TeleportEffectGui = true,
	ImmersiveBrandedAds = true,
	RewardedVideoAdPlayer = true,
	SystemScrim = true,
	_FullscreenTestGui = true,
	_DeviceTestGui = true,
	InExperienceInterventionApp = true,
	PurchasePromptApp = true,
	InGameFullscreenTitleBarScreen = true,
	ExperienceChat = true,
	HeadsetDisconnectedDialog = true,
	FoundationOverlay = true,
	NV_PreviewBackdrop = true,
	PlayerList = true,
	WindUIWidgetPreview = true,
	EmbeddedHost = true,
}

local function num(n)
	if n ~= n or n == math.huge or n == -math.huge then
		return "0"
	end
	return string.format("%.4f", n)
end

local function color(c)
	return string.format("Color3.fromRGB(%d, %d, %d)", math.floor(c.R + 0.5), math.floor(c.G + 0.5), math.floor(c.B + 0.5))
end

local function udim2(u)
	return string.format("UDim2.new(%s, %s, %s, %s)", num(u.X.Scale), num(u.X.Offset), num(u.Y.Scale), num(u.Y.Offset))
end

local function udim(u)
	return string.format("UDim.new(%s, %s)", num(u.Scale), num(u.Offset))
end

local function vec2(v)
	return string.format("Vector2.new(%s, %s)", num(v.X), num(v.Y))
end

local function str(s)
	return string.format("%q", s)
end

local function sequence(seq)
	local parts = {}
	for _, keypoint in ipairs(seq.Keypoints) do
		table.insert(parts, string.format("NumberSequenceKeypoint.new(%s, %s)", num(keypoint.Time), num(keypoint.Value)))
	end
	return "NumberSequence.new({" .. table.concat(parts, ", ") .. "})"
end

local function colorSequence(seq)
	local parts = {}
	for _, keypoint in ipairs(seq.Keypoints) do
		table.insert(parts, string.format("ColorSequenceKeypoint.new(%s, %s)", num(keypoint.Time), color(keypoint.Value)))
	end
	return "ColorSequence.new({" .. table.concat(parts, ", ") .. "})"
end

-- Every property worth copying. Anything not listed still gets its class,
-- name and children, so the shape is never lost.
local PROPS = {
	GuiObject = {
		"Size", "Position", "AnchorPoint", "BackgroundColor3", "BackgroundTransparency",
		"BorderSizePixel", "BorderColor3", "Visible", "ZIndex", "ClipsDescendants",
		"Rotation", "LayoutOrder", "AutomaticSize", "SizeConstraint",
	},
	Frame = { "Style" },
	ScrollingFrame = {
		"CanvasSize", "CanvasPosition", "ScrollBarThickness", "ScrollBarImageColor3",
		"ScrollBarImageTransparency", "ScrollingEnabled", "AutomaticCanvasSize",
		"ElasticBehavior", "ScrollBarVisibility",
	},
	TextLabel = {
		"Text", "TextSize", "TextColor3", "TextTransparency", "TextXAlignment",
		"TextYAlignment", "TextScaled", "TextWrapped", "Font", "FontFace",
		"RichText", "LineHeight",
	},
	TextButton = {
		"Text", "TextSize", "TextColor3", "TextTransparency", "TextXAlignment",
		"TextYAlignment", "TextScaled", "TextWrapped", "Font", "FontFace",
		"RichText", "LineHeight", "AutoButtonColor",
	},
	TextBox = { "Text", "TextSize", "TextColor3", "PlaceholderText", "ClearTextOnFocus" },
	ImageLabel = {
		"Image", "ImageColor3", "ImageTransparency", "ScaleType", "SliceCenter",
		"SliceScale", "ImageRectOffset", "ImageRectSize", "ResampleMode",
	},
	ImageButton = {
		"Image", "ImageColor3", "ImageTransparency", "ScaleType", "SliceCenter",
		"SliceScale", "ImageRectOffset", "ImageRectSize", "ResampleMode", "AutoButtonColor",
	},
	ViewportFrame = { "ImageColor3", "ImageTransparency", "Ambient", "LightColor", "LightDirection" },
	UICorner = { "CornerRadius" },
	UIGradient = { "Color", "Transparency", "Rotation", "Offset", "Enabled" },
	UIStroke = { "Color", "Thickness", "Transparency", "ApplyStrokeMode", "LineJoinMode", "Enabled" },
	UIPadding = { "PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight" },
	UIListLayout = { "Padding", "FillDirection", "HorizontalAlignment", "VerticalAlignment", "SortOrder", "Wraps" },
	UIGridLayout = { "CellSize", "CellPadding", "FillDirection", "FillDirectionMaxCells", "HorizontalAlignment", "VerticalAlignment", "SortOrder" },
	UIScale = { "Scale" },
	UIAspectRatioConstraint = { "AspectRatio", "AspectType", "DominantAxis" },
	UISizeConstraint = { "MaxSize", "MinSize" },
	UITextSizeConstraint = { "MaxTextSize", "MinTextSize" },
	UICanvasGroup = {},
	CanvasGroup = { "GroupTransparency", "GroupColor3" },
	UIShadow = { "BlurRadius", "Color", "Offset", "Spread", "Transparency" },
	UIBlur = { "Size" },
	Frame_Shadow = {},
}

local ORDER = {
	"GuiObject", "Frame", "ScrollingFrame", "TextLabel", "TextButton", "TextBox",
	"ImageLabel", "ImageButton", "ViewportFrame", "CanvasGroup", "UICorner", "UIGradient",
	"UIStroke", "UIPadding", "UIListLayout", "UIGridLayout", "UIScale",
	"UIAspectRatioConstraint", "UISizeConstraint", "UITextSizeConstraint",
	"UIShadow", "UIBlur",
}

local function serialize(object, depth, lines)
	local indent = string.rep("\t", depth)
	local class = object.ClassName

	table.insert(lines, string.format("%s{ Class = %s, Name = %s,", indent, str(class), str(object.Name)))

	local seen = {}
	for _, key in ipairs(ORDER) do
		if object:IsA(key) and PROPS[key] then
			for _, prop in ipairs(PROPS[key]) do
				if not seen[prop] then
					seen[prop] = true
					local ok, value = pcall(function()
						return object[prop]
					end)
					if ok and value ~= nil then
						local encoded
						if type(value) == "string" then
							encoded = str(value)
						elseif type(value) == "number" then
							encoded = num(value)
						elseif type(value) == "boolean" then
							encoded = tostring(value)
						elseif typeof(value) == "UDim2" then
							encoded = udim2(value)
						elseif typeof(value) == "UDim" then
							encoded = udim(value)
						elseif typeof(value) == "Vector2" then
							encoded = vec2(value)
						elseif typeof(value) == "Color3" then
							encoded = color(value)
						elseif typeof(value) == "NumberSequence" then
							encoded = sequence(value)
						elseif typeof(value) == "ColorSequence" then
							encoded = colorSequence(value)
						elseif typeof(value) == "EnumItem" then
							encoded = "Enum." .. tostring(value.EnumType):gsub("^Enum%.", "") .. "." .. value.Name
						elseif typeof(value) == "Rect" then
							encoded = string.format("Rect.new(%s, %s, %s, %s)", num(value.Min.X), num(value.Min.Y), num(value.Max.X), num(value.Max.Y))
						elseif typeof(value) == "Vector3" then
							encoded = string.format("Vector3.new(%s, %s, %s)", num(value.X), num(value.Y), num(value.Z))
						end
						if encoded then
							table.insert(lines, string.format("%s\t%s = %s,", indent, prop, encoded))
						end
					end
				end
			end
		end
	end

	local children = {}
	for _, child in ipairs(object:GetChildren()) do
		if child:IsA("GuiObject") or child.ClassName:match("^UI") or child:IsA("LayerCollector") then
			table.insert(children, child)
		end
	end

	if #children > 0 then
		table.insert(lines, indent .. "\tChildren = {")
		for _, child in ipairs(children) do
			serialize(child, depth + 2, lines)
		end
		table.insert(lines, indent .. "\t},")
	end

	table.insert(lines, indent .. "},")
end

local roots = {}
local function collect(container)
	local ok, children = pcall(function()
		return container:GetChildren()
	end)
	if not ok then
		return
	end
	for _, child in ipairs(children) do
		if child:IsA("LayerCollector") and not SKIP[child.Name] then
			local count = 0
			for _ in child:GetDescendants() do
				count = count + 1
			end
			if count >= 8 then
				table.insert(roots, child)
			end
		end
	end
end

collect(game:GetService("CoreGui"))

local player = game:GetService("Players").LocalPlayer
local playerGui = player and player:FindFirstChild("PlayerGui")
if playerGui then
	collect(playerGui)
end

local lines = {
	"-- ui-dump.lua - generated by ui-stealer.lua",
	"return {",
}

for _, root in ipairs(roots) do
	table.insert(lines, string.format("\t{ Root = %s, ScreenGui = {", str(root.Name)))
	serialize(root, 2, lines)
	table.insert(lines, "\t},")
end

table.insert(lines, "}")

local body = table.concat(lines, "\n")
if writefile then
	writefile(OUT, body)
end

return {
	Path = OUT,
	Bytes = #body,
	Count = #roots,
	Names = (function()
		local names = {}
		for _, root in ipairs(roots) do
			table.insert(names, root.Name)
		end
		return table.concat(names, ", ")
	end)(),
}
