-- CoverSize - width and height of a cover file, read from its header.
--
--   local W, H = CoverSize.Of("Ender Hub/songs/Artist - Song.jpg")
--
-- Roblox gives no way to ask an ImageLabel how big its texture is, and the
-- island samples single pixels out of the artwork to tint itself. This reads
-- the two numbers out of the file header instead: PNG IHDR, JPEG SOF, or the
-- WEBP VP8/VP8L/VP8X blocks. Anything it does not recognise returns nil and
-- the caller falls back to a fixed guess.

local CoverSize = {}

local function U16(Data, Index)
	local A, B = Data:byte(Index, Index + 1)
	if not A or not B then
		return nil
	end
	return A * 256 + B
end

local function U24(Data, Index)
	local A, B, C = Data:byte(Index, Index + 2)
	if not A or not B or not C then
		return nil
	end
	return A * 65536 + B * 256 + C
end

local function U32(Data, Index)
	local A, B, C, D = Data:byte(Index, Index + 3)
	if not A or not B or not C or not D then
		return nil
	end
	return A * 16777216 + B * 65536 + C * 256 + D
end

local function Png(Data)
	return U32(Data, 17), U32(Data, 21)
end

-- Walk the marker chain to the frame header. Every segment carries its own
-- length, so a bounded hop count is enough: a valid file reaches SOF in a
-- dozen segments, a corrupt one stops at the cap.
local function Jpeg(Data)
	local Index, Size = 3, #Data
	for _ = 1, 64 do
		if Index + 3 > Size then
			return nil
		end
		if Data:byte(Index) ~= 0xFF then
			Index += 1
		else
			local Marker = Data:byte(Index + 1)
			if Marker == 0xD8 or Marker == 0xD9 or (Marker >= 0xD0 and Marker <= 0xD7) or Marker == 0xFF then
				Index += 2
			else
				local Length = U16(Data, Index + 2)
				if not Length then
					return nil
				end
				local Frame = Marker >= 0xC0 and Marker <= 0xCF
					and Marker ~= 0xC4
					and Marker ~= 0xC8
					and Marker ~= 0xCC
				if Frame then
					return U16(Data, Index + 7), U16(Data, Index + 5)
				end
				Index += 2 + Length
			end
		end
	end
	return nil
end

local function Webp(Data)
	local Chunk = Data:sub(13, 16)
	if Chunk == "VP8X" then
		return U24(Data, 25) + 1, U24(Data, 28) + 1
	elseif Chunk == "VP8L" then
		local B1, B2, B3, B4 = Data:byte(22, 25)
		if not B4 then
			return nil
		end
		return 1 + B1 + (B2 % 64) * 256,
			1 + math.floor(B2 / 64) + B3 * 4 + (B4 % 16) * 1024
	elseif Chunk == "VP8 " then
		return U16(Data, 27) % 16384, U16(Data, 29) % 16384
	end
	return nil
end

function CoverSize.Of(Path)
	if type(Path) ~= "string" or Path == "" or type(readfile) ~= "function" then
		return nil
	end
	if type(isfile) == "function" and not isfile(Path) then
		return nil
	end

	local Ok, Data = pcall(readfile, Path)
	if not Ok or type(Data) ~= "string" or #Data < 32 then
		return nil
	end

	local W, H
	if Data:sub(2, 4) == "PNG" then
		W, H = Png(Data)
	elseif Data:byte(1) == 0xFF and Data:byte(2) == 0xD8 then
		W, H = Jpeg(Data)
	elseif Data:sub(1, 4) == "RIFF" and Data:sub(9, 12) == "WEBP" then
		W, H = Webp(Data)
	end

	if not W or not H or W <= 0 or H <= 0 then
		return nil
	end
	return W, H
end

return CoverSize
