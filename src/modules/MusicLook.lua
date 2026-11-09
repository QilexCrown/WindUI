-- MusicLook - the black-and-white surface the music widgets are drawn on.
--
--   local MusicLook = require("../modules/MusicLook")
--   MusicLook.Glow(MainContainer, 26)
--   MusicLook.PaintText(Title, MusicLook.Text)
--
-- One palette, one gradient, shared by the loading pill, the key system and
-- anything else that has to sit next to the island and the mini player: a
-- near-black shell, white type, and a single coloured bloom rising from the
-- bottom edge. Nothing here carries artwork, so the bloom is a fixed hue
-- instead of the sleeve colour.

local Creator = require("./Creator")
local New = Creator.New

local MusicLook = {}

MusicLook.Shell = Color3.fromRGB(9, 9, 11)
MusicLook.ShellTransparency = 0.06
MusicLook.Glow = Color3.fromRGB(108, 84, 255)
MusicLook.Text = Color3.new(1, 1, 1)
MusicLook.Muted = Color3.fromRGB(150, 152, 160)

local function Corner(Object, Radius)
	return New("UICorner", { Parent = Object, CornerRadius = UDim.new(0, Radius) })
end

-- A rounded bloom that sits on the bottom of a card. Parent it first, then the
-- card's own content draws over it: the layer carries ZIndex -1 relative to
-- its siblings by being inserted before them, so callers add it early.
function MusicLook.Glow(Parent, Radius, Height)
	local Frame = New("Frame", {
		Parent = Parent,
		Name = "MusicGlow",
		BackgroundColor3 = MusicLook.Glow,
		BackgroundTransparency = 0.55,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, Height or 120),
		ZIndex = -1,
	})
	Corner(Frame, Radius)
	New("UIGradient", {
		Parent = Frame,
		Rotation = 90,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.45, 0.72),
			NumberSequenceKeypoint.new(1, 0.12),
		}),
	})
	return Frame
end

function MusicLook.PaintText(Object, Color)
	Object.TextColor3 = Color or MusicLook.Text
	return Object
end

-- Primary reads as a solid white pill with black type, the way the transport
-- row reads on the mini player. Secondary and Tertiary stay glass.
function MusicLook.PaintButton(Button, Variant)
	local Fill = Button:FindFirstChild("Squircle")
	local Outline = Button:FindFirstChild("Outline")
	local Label = Button:FindFirstChild("Frame")
		and Button.Frame:FindFirstChildOfClass("TextLabel")
		or Button:FindFirstChildOfClass("TextLabel")

	if Fill then
		Fill.ImageColor3 = MusicLook.Text
		Fill.ImageTransparency = Variant == "Primary" and 0 or Variant == "Secondary" and 0.9 or 0.96
	end
	if Outline then
		Outline.ImageColor3 = MusicLook.Text
		Outline.ImageTransparency = Variant == "Primary" and 1 or 0.78
	end
	if Label then
		Label.TextColor3 = Variant == "Primary" and Color3.new(0, 0, 0) or MusicLook.Text
	end
	return Button
end

function MusicLook.PaintInput(InputFrame)
	local Box = InputFrame:FindFirstChildOfClass("TextBox")
	if Box then
		Box.TextColor3 = MusicLook.Text
		Box.PlaceholderColor3 = MusicLook.Muted
	end
	for _, Desc in ipairs(InputFrame:GetDescendants()) do
		if Desc:IsA("ImageLabel") then
			if Desc.Name == "Frame" then
				Desc.ImageColor3 = Color3.fromRGB(22, 22, 26)
				Desc.ImageTransparency = 0.15
			elseif Desc.Name == "Squircle" or Desc.Name == "SquircleGlass" then
				Desc.ImageColor3 = MusicLook.Text
				Desc.ImageTransparency = math.max(Desc.ImageTransparency, 0.84)
			end
		end
	end
	return InputFrame
end

return MusicLook
