--[[
    Overhead player tags.

    A BillboardGui above the head of every player that has a rank in
    Config.Ranks. Layout, matching the Dynamic Island:

        (icon) Ender Hub                    (age) 3y  (clock) 7436
                       Rank
                    @DisplayName

    The brand sits in the top-left, the rank is the loudest centred line, the
    handle is the subtle description under it, and the status row in the
    top-right mirrors the island's icon + value pairing: account age and the
    player's leaderboard time. Both are replicated, so they read correctly on
    someone else's tag.
    The tag has a solid rounded background with the island's shadow stack,
    colours follow the active WindUI theme unless Config.Colors pins them,
    and it re-attaches on respawn so a dead owner keeps the label over the
    body until the character is replaced.
]]

local Players = game:GetService("Players")

local Creator = require("../modules/Creator")
local New = Creator.New

local PlayerTags = {}
PlayerTags.__index = PlayerTags

local DEFAULT_TEXT = Color3.new(1, 1, 1)
local DEFAULT_SUBTLE = Color3.fromRGB(154, 156, 164)
local DEFAULT_ACCENT = Color3.fromRGB(110, 220, 170)
local DEFAULT_BACKGROUND = Color3.fromRGB(16, 16, 18)
local DEFAULT_ICON = "rbxassetid://84919257334887"

-- Same corner and shadow stack as the Dynamic Island: 20 px radius when the
-- island is collapsed, a 38 px dark glow and a tight contact shadow.
local DEFAULT_CORNER = 20

-- AccountAge is replicated for every player, so the age chip reads correctly
-- on someone else's tag. One unit, no label: 3y, 7mo, 12d.
local function AgeText(days)
	days = math.max(0, math.floor(tonumber(days) or 0))
	if days >= 365 then
		return (days // 365) .. "y"
	end
	if days >= 30 then
		return (days // 30) .. "mo"
	end
	return days .. "d"
end

-- Theme values may be gradients; TextColor3 cannot take one, so the first
-- keypoint is the readable stand-in.
local function colorOf(value, fallback)
	if typeof(value) == "Color3" then
		return value
	end
	if type(value) == "table" and value.Color then
		local points = value.Color.Keypoints
		if points and points[1] then
			return points[1].Value
		end
	end
	return fallback
end

local function normalizeMap(map)
	local out = {}
	for key, value in pairs(map or {}) do
		out[string.lower(tostring(key))] = value
	end
	return out
end

function PlayerTags.New(Config, WindUI)
	local self = setmetatable({
		Config = Config or {},
		WindUI = WindUI,
		Tags = {},
		PlayerConns = {},
		StatConns = {},
		Alive = true,
		LocalPlayer = Players.LocalPlayer,
	}, PlayerTags)

	self.Ranks = normalizeMap(self.Config.Ranks)
	self.RankColors = normalizeMap(self.Config.RankColors)
	self.Colors = {}
	self:ResolveColors()

	self:Scan()
	self.PlayerAddedConn = Players.PlayerAdded:Connect(function(player)
		self:Watch(player)
	end)
	self.PlayerRemovingConn = Players.PlayerRemoving:Connect(function(player)
		self:DestroyTag(player)
		local conns = self.PlayerConns[player]
		if conns then
			for _, conn in pairs(conns) do
				conn:Disconnect()
			end
			self.PlayerConns[player] = nil
		end
		local statConn = self.StatConns[player]
		if statConn then
			statConn:Disconnect()
			self.StatConns[player] = nil
		end
	end)

	return self
end

function PlayerTags:ResolveColors()
	local theme = self.WindUI and self.WindUI.Theme or nil
	local custom = self.Config.Colors or {}
	self.Colors = {
		Text = custom.Text or colorOf(theme and theme.Text, DEFAULT_TEXT),
		Subtle = custom.Subtle or colorOf(theme and theme.Placeholder, DEFAULT_SUBTLE),
		Accent = custom.Accent or colorOf(theme and theme.Accent, DEFAULT_ACCENT),
		Icon = custom.Icon or colorOf(theme and theme.Icon, DEFAULT_TEXT),
		Background = custom.Background or colorOf(theme and theme.Dialog, DEFAULT_BACKGROUND),
	}
	return self
end

function PlayerTags:RankOf(player)
	return self.Ranks[string.lower(player.Name)] or self.Ranks[tostring(player.UserId)]
end

function PlayerTags:TimeOf(player)
	local stats = player:FindFirstChild("leaderstats")
	local stat = stats and stats:FindFirstChild(self.Config.TimeStat or "Time")
	if stat and (stat:IsA("IntValue") or stat:IsA("NumberValue") or stat:IsA("StringValue")) then
		return stat.Value
	end
	return nil
end

function PlayerTags:FormatTime(value)
	local format = self.Config.TimeFormat
	if type(format) == "function" then
		local ok, text = pcall(format, value)
		if ok and text ~= nil then
			return tostring(text)
		end
	end
	if typeof(value) == "number" then
		return tostring(math.floor(value))
	end
	return tostring(value)
end

function PlayerTags:UpdateTime(player)
	local tag = self.Tags[player]
	if not tag then
		return
	end
	local value = self:TimeOf(player)
	local label = tag:FindFirstChild("TimeText", true)
	if not label then
		return
	end
	local icon = tag:FindFirstChild("TimeIcon", true)
	local show = value ~= nil
	label.Text = show and self:FormatTime(value) or ""
	label.Visible = show
	if icon then
		icon.Visible = show
	end
end

function PlayerTags:BindStat(player)
	local old = self.StatConns[player]
	if old then
		old:Disconnect()
		self.StatConns[player] = nil
	end
	local stats = player:FindFirstChild("leaderstats")
	local stat = stats and stats:FindFirstChild(self.Config.TimeStat or "Time")
	if stat then
		self.StatConns[player] = stat:GetPropertyChangedSignal("Value"):Connect(function()
			self:UpdateTime(player)
		end)
	end
	self:UpdateTime(player)
end

function PlayerTags:BuildTag(player)
	self:DestroyTag(player)

	local rank = self:RankOf(player)
	if not rank then
		return
	end
	if self.Config.ShowSelf == false and player == self.LocalPlayer then
		return
	end

	local char = player.Character
	local head = char and (char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart"))
	if not head then
		return
	end

	local colors = self.Colors
	local rankKey = string.lower(tostring(rank))
	local rankColor = self.RankColors[rankKey] or colors.Text
	local radius = self.Config.CornerRadius or DEFAULT_CORNER

	local billboard = New("BillboardGui", {
		Name = "WindUI_PlayerTag",
		Adornee = head,
		Size = UDim2.fromOffset(self.Config.Width or 220, self.Config.Height or 84),
		StudsOffset = self.Config.Offset or Vector3.new(0, 3, 0),
		AlwaysOnTop = true,
		LightInfluence = 0,
		MaxDistance = self.Config.MaxDistance or 0,
		Parent = head,
	})

	-- Island shadow stack: a wide dark glow and a tight contact shadow. Both
	-- are pcall'd because UIShadow is not available on every client build.
	pcall(function()
		New("UIShadow", {
			Name = "DarkGlow",
			Color = Color3.new(0, 0, 0),
			BlurRadius = UDim.new(0, 24),
			Offset = UDim2.fromOffset(0, 8),
			Transparency = self.Config.ShadowTransparency or 0.45,
			ZIndex = -2,
			Parent = billboard,
		})
		New("UIShadow", {
			Name = "Contact",
			Color = Color3.new(0, 0, 0),
			BlurRadius = UDim.new(0, 8),
			Offset = UDim2.fromOffset(0, 2),
			Transparency = 0.55,
			ZIndex = -1,
			Parent = billboard,
		})
	end)

	local root = New("Frame", {
		Name = "TagRoot",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = colors.Background,
		BackgroundTransparency = self.Config.BackgroundTransparency or 0,
		BorderSizePixel = 0,
		Parent = billboard,
	}, {
		New("UICorner", {
			CornerRadius = UDim.new(0, radius),
		}),
	})

	-- Brand, pinned top-left: hub icon and name on one row.
	local brand = New("Frame", {
		Name = "Brand",
		Position = UDim2.fromOffset(12, 9),
		Size = UDim2.fromOffset(130, 20),
		BackgroundTransparency = 1,
		Parent = root,
	}, {
		New("UIListLayout", {
			SortOrder = "LayoutOrder",
			FillDirection = "Horizontal",
			HorizontalAlignment = "Left",
			VerticalAlignment = "Center",
			Padding = UDim.new(0, 6),
		}),
	})

	local iconData = Creator.Icon(self.Config.Icon or DEFAULT_ICON)
	New("ImageLabel", {
		Image = iconData.Image,
		ImageRectOffset = iconData.ImageRectPosition,
		ImageRectSize = iconData.ImageRectSize,
		ImageColor3 = colors.Text,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(18, 18),
		LayoutOrder = 1,
		Parent = brand,
	})
	New("TextLabel", {
		Text = self.Config.Title or "Ender Hub",
		TextColor3 = colors.Text,
		TextSize = 13,
		FontFace = Font.new(Creator.Font, Enum.FontWeight.SemiBold),
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(104, 18),
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 2,
		Parent = brand,
	})

	-- Status row, pinned top-right: account age + leaderboard time, the same
	-- icon/value pairing the island uses for ping + uptime. Both values are
	-- replicated, so they are correct on every player's tag.
	local status = New("Frame", {
		Name = "Status",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 9),
		Size = UDim2.fromOffset(96, 20),
		BackgroundTransparency = 1,
		Parent = root,
	}, {
		New("UIListLayout", {
			SortOrder = "LayoutOrder",
			FillDirection = "Horizontal",
			HorizontalAlignment = "Right",
			VerticalAlignment = "Center",
			Padding = UDim.new(0, 4),
		}),
	})

	local ageIcon = Creator.Icon(self.Config.AgeIcon or "lucide:calendar")
	New("ImageLabel", {
		Name = "AgeIcon",
		Image = ageIcon.Image,
		ImageRectOffset = ageIcon.ImageRectPosition,
		ImageRectSize = ageIcon.ImageRectSize,
		ImageColor3 = colors.Subtle,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(13, 13),
		LayoutOrder = 1,
		Parent = status,
	})
	New("TextLabel", {
		Name = "AgeText",
		Text = AgeText(player.AccountAge),
		TextColor3 = colors.Subtle,
		TextSize = 11,
		FontFace = Font.new(Creator.Font, Enum.FontWeight.Medium),
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 20),
		LayoutOrder = 2,
		Parent = status,
	})
	New("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(4, 1),
		LayoutOrder = 3,
		Parent = status,
	})

	local timeIcon = Creator.Icon(self.Config.TimeIcon or "lucide:clock")
	New("ImageLabel", {
		Name = "TimeIcon",
		Image = timeIcon.Image,
		ImageRectOffset = timeIcon.ImageRectPosition,
		ImageRectSize = timeIcon.ImageRectSize,
		ImageColor3 = colors.Subtle,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(13, 13),
		LayoutOrder = 4,
		Parent = status,
	})
	New("TextLabel", {
		Name = "TimeText",
		Text = "",
		TextColor3 = colors.Subtle,
		TextSize = 11,
		FontFace = Font.new(Creator.Font, Enum.FontWeight.Medium),
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 20),
		LayoutOrder = 5,
		Parent = status,
	})

	-- Rank is the loudest line; the handle sits under it like a description.
	New("TextLabel", {
		Name = "Rank",
		Position = UDim2.fromOffset(0, 32),
		Text = tostring(rank),
		TextColor3 = rankColor,
		TextSize = self.Config.RankTextSize or 22,
		FontFace = Font.new(Creator.Font, Enum.FontWeight.Bold),
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 24),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = root,
	})

	New("TextLabel", {
		Name = "Handle",
		Position = UDim2.fromOffset(0, 58),
		Text = "@" .. tostring(player.DisplayName),
		TextColor3 = colors.Subtle,
		TextSize = 11,
		FontFace = Font.new(Creator.Font, Enum.FontWeight.Regular),
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 14),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = root,
	})

	self.Tags[player] = billboard
	self:UpdateTime(player)
end

function PlayerTags:DestroyTag(player, char)
	local billboard = self.Tags[player]
	if billboard then
		-- A fast respawn can deliver CharacterRemoving for the old rig after
		-- the new tag already exists; only drop the tag that belongs to it.
		if char and billboard.Adornee and not billboard.Adornee:IsDescendantOf(char) then
			return
		end
		billboard:Destroy()
		self.Tags[player] = nil
	end
end

-- Some games hand CharacterAdded a rig with no Head yet (it is assembled a
-- frame or two later). Poll briefly instead of building once and losing the
-- tag until the next respawn.
function PlayerTags:AttachWhenReady(player, char, attempt)
	if not self.Alive or player.Character ~= char then
		return
	end
	local head = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
	if head then
		self:BuildTag(player)
		return
	end
	attempt = attempt or 0
	if attempt >= 200 then
		return
	end
	task.delay(0.05, function()
		self:AttachWhenReady(player, char, attempt + 1)
	end)
end

function PlayerTags:Watch(player)
	if not self.Alive then
		return
	end

	self.PlayerConns[player] = {
		player.CharacterAdded:Connect(function(char)
			task.defer(function()
				if self.Alive then
					self:AttachWhenReady(player, char)
				end
			end)
		end),
		player.CharacterRemoving:Connect(function(char)
			self:DestroyTag(player, char)
		end),
		player.ChildAdded:Connect(function(child)
			if child.Name == "leaderstats" then
				task.defer(function()
					if self.Alive then
						self:BindStat(player)
					end
				end)
			end
		end),
	}

	self:BindStat(player)
	if player.Character then
		self:AttachWhenReady(player, player.Character)
	end
end

function PlayerTags:Scan()
	for _, player in ipairs(Players:GetPlayers()) do
		self:Watch(player)
	end
	return self
end

-- Rebuild every tag against the current theme / rank table.
function PlayerTags:Refresh()
	self:ResolveColors()
	for _, player in ipairs(Players:GetPlayers()) do
		self:BuildTag(player)
	end
	return self
end

function PlayerTags:SetRank(name, rank)
	local key = string.lower(tostring(name or ""))
	if key == "" then
		return self
	end
	if rank == nil then
		self.Ranks[key] = nil
	else
		self.Ranks[key] = rank
	end
	for _, player in ipairs(Players:GetPlayers()) do
		if string.lower(player.Name) == key then
			self:BuildTag(player)
		end
	end
	return self
end

function PlayerTags:Destroy()
	self.Alive = false
	if self.PlayerAddedConn then
		self.PlayerAddedConn:Disconnect()
	end
	if self.PlayerRemovingConn then
		self.PlayerRemovingConn:Disconnect()
	end
	for player, conns in pairs(self.PlayerConns) do
		for _, conn in pairs(conns) do
			conn:Disconnect()
		end
		self.PlayerConns[player] = nil
	end
	for player, conn in pairs(self.StatConns) do
		conn:Disconnect()
		self.StatConns[player] = nil
	end
	for player in pairs(self.Tags) do
		self:DestroyTag(player)
	end
end

return PlayerTags
