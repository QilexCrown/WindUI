-- Transport layer for the Music Mini Player widget.
--
-- Every provider answers the same contract, so the widget never has to know
-- which service is on the other end:
--
--   Provider.Id        string          "spotify" | "bridge" | "local" | "demo"
--   Provider.Name      string
--   Provider.Kind      "remote" | "bridge" | "local" | "demo"
--   Provider.Connected boolean
--   Provider.Account   string?
--   Provider.Status    string          one line, widget renders it verbatim
--
--   Provider:Connect(options, done)    done(ok, message)
--   Provider:Poll(done)                done(ok, state | message)
--   Provider:Play(done)  :Pause(done)  :Next(done)  :Previous(done)
--   Provider:Seek(seconds, done)
--   Provider:SetVolume(percent, done)  0-100
--   Provider:Disconnect()
--
-- state = {
--     Title    = string,
--     Artist   = string,
--     Album    = string,
--     Cover    = string,     -- http url, asset id or "" for the gradient fallback
--     Position = number,     -- seconds
--     Duration = number,     -- seconds, 0 when unknown
--     Playing  = boolean,
--     Volume   = number?,    -- 0-100, nil when the service cannot report it
--     CanSeek  = boolean,
--     CanSkip  = boolean,
-- }

local cloneref = (cloneref or clonereference or function(instance)
	return instance
end)

local HttpService = cloneref(game:GetService("HttpService"))

local Creator = require("./Creator")

local Providers = {}

local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

-- Spotify's refresh flow authenticates with HTTP Basic, and Luau ships no
-- base64, so the encoder lives here rather than a dependency.
local function Base64(Input)
	local Output = {}
	Input = tostring(Input)

	for Index = 1, #Input, 3 do
		local First, Second, Third = Input:byte(Index, Index + 2)
		local Value = First * 65536 + (Second or 0) * 256 + (Third or 0)

		local A = math.floor(Value / 262144) % 64
		local B = math.floor(Value / 4096) % 64
		local C = math.floor(Value / 64) % 64
		local D = Value % 64

		Output[#Output + 1] = B64:sub(A + 1, A + 1) .. B64:sub(B + 1, B + 1)
		Output[#Output + 1] = Second and B64:sub(C + 1, C + 1) or "="
		Output[#Output + 1] = Third and B64:sub(D + 1, D + 1) or "="
	end

	return table.concat(Output)
end

local function UrlEncode(Value)
	return (
		tostring(Value):gsub("[^%w%-%._~]", function(Character)
			return string.format("%%%02X", string.byte(Character))
		end)
	)
end

local function Decode(Body)
	if type(Body) ~= "string" or Body == "" then
		return nil
	end

	local Success, Data = pcall(HttpService.JSONDecode, HttpService, Body)
	if Success and type(Data) == "table" then
		return Data
	end

	return nil
end

local function Encode(Data)
	local Success, Body = pcall(HttpService.JSONEncode, HttpService, Data)
	return Success and Body or nil
end

local function Idle(Message)
	return {
		Title = Message or "Nothing playing",
		Artist = "Press play in the source app",
		Album = "",
		Cover = "",
		Position = 0,
		Duration = 0,
		Playing = false,
		Volume = nil,
		CanSeek = false,
		CanSkip = false,
	}
end

-- One HTTP call, always off the widget's thread: a stalled request must never
-- freeze a drag. Returns the parsed body when the payload is JSON.
local function Http(Options, Done)
	Done = Done or function() end

	task.spawn(function()
		local Transport = Creator.Request or http_request
		if not Transport then
			Done(false, "This executor has no HTTP API", 0, nil)
			return
		end

		local Success, Response = pcall(Transport, {
			Url = Options.Url,
			Method = Options.Method or "GET",
			Headers = Options.Headers,
			Body = Options.Body,
		})

		if not Success or type(Response) ~= "table" then
			Done(false, "Request failed: " .. tostring(Response), 0, nil)
			return
		end

		local Status = tonumber(Response.StatusCode or Response.Status) or 0
		local Body = Response.Body or Response.body
		Done(Status >= 200 and Status < 300, Body, Status, Decode(Body))
	end)
end

Providers.Http = Http
Providers.Base64 = Base64
Providers.UrlEncode = UrlEncode
Providers.Idle = Idle
Providers.Decode = Decode

-- ------------------------------------------------------------------ Spotify
--
-- Token in, /me/player polled at the widget's own interval. Volume goes
-- through player/volume, which sets the volume of whichever device is
-- playing — the phone in a pocket, the desktop app, the speaker.

local Spotify = {}
Spotify.__index = Spotify

Spotify.Id = "spotify"
Spotify.Name = "Spotify"
Spotify.Kind = "remote"
Spotify.Scopes = "user-read-playback-state user-modify-playback-state user-read-currently-playing"

local SpotifyApi = "https://api.spotify.com/v1"
local SpotifyToken = "https://accounts.spotify.com/api/token"

function Spotify.new()
	return setmetatable({
		Id = Spotify.Id,
		Name = Spotify.Name,
		Kind = Spotify.Kind,
		Connected = false,
		Account = nil,
		Status = "Not connected",
		AccessToken = nil,
		RefreshToken = nil,
		ClientId = nil,
		ClientSecret = nil,
		ExpiresAt = 0,
	}, Spotify)
end

function Spotify:Load(Data)
	if type(Data) ~= "table" then
		return false
	end

	self.AccessToken = Data.AccessToken or self.AccessToken
	self.RefreshToken = Data.RefreshToken or self.RefreshToken
	self.ClientId = Data.ClientId or self.ClientId
	self.ClientSecret = Data.ClientSecret or self.ClientSecret
	self.ExpiresAt = tonumber(Data.ExpiresAt) or self.ExpiresAt

	return self.AccessToken ~= nil
end

function Spotify:Save()
	return {
		AccessToken = self.AccessToken,
		RefreshToken = self.RefreshToken,
		ClientId = self.ClientId,
		ClientSecret = self.ClientSecret,
		ExpiresAt = self.ExpiresAt,
	}
end

function Spotify:RefreshTokenNow(Done)
	if not (self.RefreshToken and self.ClientId and self.ClientSecret) then
		Done(false, "Token expired and no refresh credentials were given")
		return
	end

	local Basic = Base64(self.ClientId .. ":" .. self.ClientSecret)
	local Body = "grant_type=refresh_token&refresh_token=" .. UrlEncode(self.RefreshToken)

	Http({
		Url = SpotifyToken,
		Method = "POST",
		Headers = {
			["Authorization"] = "Basic " .. Basic,
			["Content-Type"] = "application/x-www-form-urlencoded",
		},
		Body = Body,
	}, function(Ok, Payload, Status, Data)
		if not Ok or not Data then
			Done(false, "Token refresh failed (" .. tostring(Status) .. ")")
			return
		end

		self.AccessToken = Data.access_token or self.AccessToken
		self.RefreshToken = Data.refresh_token or self.RefreshToken
		self.ExpiresAt = os.time() + (tonumber(Data.expires_in) or 3600)

		if not self.AccessToken then
			Done(false, "Token refresh returned no access token")
			return
		end

		Done(true, "Token refreshed")
	end)
end

function Spotify:Api(Method, Path, Body, Done, Retried)
	Done = Done or function() end

	if not self.AccessToken then
		Done(false, "Connect Spotify first")
		return
	end

	local function Dispatch()
		local Payload = Body and Encode(Body) or nil

		Http({
			Url = SpotifyApi .. Path,
			Method = Method,
			Headers = {
				["Authorization"] = "Bearer " .. self.AccessToken,
				["Content-Type"] = "application/json",
			},
			Body = Payload,
		}, function(Ok, ResponseBody, Status, Data)
			if Status == 401 and not Retried and self.RefreshToken then
				self:RefreshTokenNow(function(Refreshed)
					if not Refreshed then
						self.Connected = false
						self.Status = "Token expired"
						Done(false, "Token expired")
						return
					end
					self:Api(Method, Path, Body, Done, true)
				end)
				return
			end

			if not Ok then
				local Message = Data and (Data.error and (Data.error.message or Data.error))
					or ("HTTP " .. tostring(Status))
				Done(false, tostring(Message), Data)
				return
			end

			Done(true, Data or ResponseBody, Data)
		end)
	end

	-- A token close to expiry is refreshed before the call, not after a 401.
	if self.ExpiresAt > 0 and os.time() >= self.ExpiresAt - 30 and self.RefreshToken and not Retried then
		self:RefreshTokenNow(function(Refreshed)
			if Refreshed then
				Dispatch()
			else
				Dispatch()
			end
		end)
		return
	end

	Dispatch()
end

function Spotify:Connect(Options, Done)
	Done = Done or function() end
	Options = Options or {}

	local Token = Options.AccessToken or Options.Token
	if type(Token) ~= "string" or Token == "" then
		Done(false, "Paste a Spotify access token")
		return
	end

	self.AccessToken = Token:gsub("^%s+", ""):gsub("%s+$", "")
	self.RefreshToken = Options.RefreshToken or self.RefreshToken
	self.ClientId = Options.ClientId or self.ClientId
	self.ClientSecret = Options.ClientSecret or self.ClientSecret
	self.ExpiresAt = tonumber(Options.ExpiresAt) or 0
	if self.ExpiresAt > 0 and self.ExpiresAt < 1e9 then
		-- Callers that pass expires_in get it converted once, here.
		self.ExpiresAt = os.time() + self.ExpiresAt
	end

	self:Api("GET", "/me", nil, function(Ok, Data)
		if not Ok then
			self.Connected = false
			self.Status = "Token rejected"
			Done(false, "Spotify rejected the token")
			return
		end

		self.Connected = true
		self.Account = Data and (Data.display_name or Data.id) or nil
		self.Status = "Connected" .. (self.Account and (" as " .. self.Account) or "")
		Done(true, self.Status)
	end)
end

function Spotify:Disconnect()
	self.Connected = false
	self.Account = nil
	self.Status = "Not connected"
	self.AccessToken = nil
	self.RefreshToken = nil
	self.ExpiresAt = 0
end

function Spotify:Poll(Done)
	self:Api("GET", "/me/player", nil, function(Ok, Data)
		if not Ok then
			Done(false, tostring(Data or "Spotify unreachable"))
			return
		end

		if type(Data) ~= "table" or not Data.item then
			Done(true, Idle("Nothing playing"))
			return
		end

		local Item = Data.item
		local Artists = {}
		for _, Artist in ipairs(Item.artists or {}) do
			Artists[#Artists + 1] = Artist.name
		end

		local Images = (Item.album and Item.album.images) or {}
		local Cover = ""
		for _, Image in ipairs(Images) do
			if Image.url then
				Cover = Image.url
				break
			end
		end

		Done(true, {
			Title = Item.name or "Unknown track",
			Artist = table.concat(Artists, ", "),
			Album = (Item.album and Item.album.name) or "",
			Cover = Cover,
			Position = (tonumber(Data.progress_ms) or 0) / 1000,
			Duration = (tonumber(Item.duration_ms) or 0) / 1000,
			Playing = Data.is_playing == true,
			Volume = Data.device and tonumber(Data.device.volume_percent) or nil,
			CanSeek = Item.duration_ms ~= nil,
			CanSkip = true,
		})
	end)
end

function Spotify:Play(Done)
	self:Api("PUT", "/me/player/play", nil, function(Ok, Message)
		Done = Done or function() end
		Done(Ok, Message)
	end)
end

function Spotify:Pause(Done)
	self:Api("PUT", "/me/player/pause", nil, function(Ok, Message)
		Done = Done or function() end
		Done(Ok, Message)
	end)
end

function Spotify:Next(Done)
	self:Api("POST", "/me/player/next", nil, function(Ok, Message)
		Done = Done or function() end
		Done(Ok, Message)
	end)
end

function Spotify:Previous(Done)
	self:Api("POST", "/me/player/previous", nil, function(Ok, Message)
		Done = Done or function() end
		Done(Ok, Message)
	end)
end

function Spotify:Seek(Seconds, Done)
	local Position = math.max(0, math.floor((tonumber(Seconds) or 0) * 1000))
	self:Api("PUT", "/me/player/seek?position_ms=" .. tostring(Position), nil, function(Ok, Message)
		Done = Done or function() end
		Done(Ok, Message)
	end)
end

function Spotify:SetVolume(Percent, Done)
	local Volume = math.clamp(math.floor(tonumber(Percent) or 0), 0, 100)
	self:Api("PUT", "/me/player/volume?volume_percent=" .. tostring(Volume), nil, function(Ok, Message)
		Done = Done or function() end
		Done(Ok, Message)
	end)
end

Providers.Spotify = Spotify
Providers.NewSpotify = Spotify.new

-- ------------------------------------------------------------------- Bridge
--
-- Anything the widget cannot talk to directly gets a tiny JSON bridge on
-- localhost: Apple Music through the Music app or iTunes, YouTube Music
-- through a player script, a hub's own backend. See bridge/server.js for a
-- reference implementation of the four routes.

local Bridge = {}
Bridge.__index = Bridge

function Bridge.new(Config)
	Config = Config or {}

	return setmetatable({
		Id = Config.Id or "bridge",
		Name = Config.Name or "Bridge",
		Kind = "bridge",
		Connected = false,
		Account = Config.Account,
		Status = Config.Url and "Bridge set" or "No bridge url",
		Url = Config.Url and Config.Url:gsub("/+$", "") or nil,
		Cover = Config.Cover,
	}, Bridge)
end

function Bridge:Request(Path, Body, Done)
	if not self.Url then
		Done(false, "No bridge url configured")
		return
	end

	Http({
		Url = self.Url .. Path,
		Method = Body and "POST" or "GET",
		Headers = { ["Content-Type"] = "application/json" },
		Body = Body and Encode(Body) or nil,
	}, function(Ok, ResponseBody, Status, Data)
		if not Ok then
			Done(false, "Bridge " .. tostring(Status), Data)
			return
		end
		Done(true, Data or ResponseBody, Data)
	end)
end

function Bridge:Connect(Options, Done)
	Done = Done or function() end
	Options = Options or {}

	if Options.Url then
		self.Url = Options.Url:gsub("/+$", "")
	end

	self:Request("/now", nil, function(Ok, _, Data)
		if not Ok or type(Data) ~= "table" then
			self.Connected = false
			self.Status = "Bridge unreachable"
			Done(false, "Bridge unreachable")
			return
		end

		self.Connected = true
		self.Account = Data.app or self.Account or self.Name
		self.Status = "Connected to " .. tostring(self.Account)
		Done(true, self.Status)
	end)
end

function Bridge:Disconnect()
	self.Connected = false
	self.Status = "Not connected"
end

function Bridge:Poll(Done)
	self:Request("/now", nil, function(Ok, _, Data)
		if not Ok or type(Data) ~= "table" then
			Done(false, "Bridge unreachable")
			return
		end

		local Cover = Data.cover or ""
		if Cover ~= "" and not Cover:match("^https?://") and not Cover:match("^rbxasset") then
			Cover = self.Url .. "/" .. Cover:gsub("^/+", "")
		end

		Done(true, {
			Title = Data.title or "Nothing playing",
			Artist = Data.artist or "",
			Album = Data.album or "",
			Cover = Cover,
			Position = tonumber(Data.position) or 0,
			Duration = tonumber(Data.duration) or 0,
			Playing = Data.playing == true,
			Volume = tonumber(Data.volume),
			CanSeek = (tonumber(Data.duration) or 0) > 0,
			CanSkip = Data.canSkip ~= false,
		})
	end)
end

function Bridge:Play(Done)
	self:Request("/play", {}, Done or function() end)
end

function Bridge:Pause(Done)
	self:Request("/pause", {}, Done or function() end)
end

function Bridge:Next(Done)
	self:Request("/next", {}, Done or function() end)
end

function Bridge:Previous(Done)
	self:Request("/previous", {}, Done or function() end)
end

function Bridge:Seek(Seconds, Done)
	self:Request("/seek", { position = tonumber(Seconds) or 0 }, Done or function() end)
end

function Bridge:SetVolume(Percent, Done)
	self:Request("/volume", { volume = math.clamp(tonumber(Percent) or 0, 0, 100) }, Done or function() end)
end

Providers.Bridge = Bridge
Providers.NewBridge = Bridge.new

-- -------------------------------------------------------------------- Local
--
-- A Sound in the game, with an optional playlist. Volume is the sound's own
-- gain, so nothing leaves the process.

local Local = {}
Local.__index = Local

function Local.new(Config)
	Config = Config or {}

	local Provider = setmetatable({
		Id = "local",
		Name = Config.Name or "Local audio",
		Kind = "local",
		Connected = false,
		Account = nil,
		Status = "Idle",
		Sound = Config.Sound,
		Playlist = Config.Playlist or {},
		Index = 1,
		Cover = Config.Cover,
		Title = Config.Title,
		Artist = Config.Artist,
	}, Local)

	if Provider.Sound then
		Provider.Connected = true
		Provider.Status = "Sound bound"
	end

	return Provider
end

function Local:Current()
	local Track = self.Playlist[self.Index]
	if Track then
		return Track
	end
	return nil
end

function Local:Bind(Sound)
	self.Sound = Sound
	self.Connected = Sound ~= nil
	self.Status = Sound and "Sound bound" or "Idle"
	return self
end

function Local:Connect(Options, Done)
	Options = Options or {}
	Done = Done or function() end

	local Sound = Options.Sound or self.Sound
	if not Sound then
		Done(false, "No Sound instance given")
		return
	end

	self:Bind(Sound)
	self.Title = Options.Title or self.Title
	self.Artist = Options.Artist or self.Artist
	self.Cover = Options.Cover or self.Cover

	Done(true, "Sound bound")
end

function Local:Disconnect()
	self.Connected = false
	self.Status = "Idle"
end

function Local:Poll(Done)
	local Sound = self.Sound
	if not Sound or not Sound.Parent then
		Done(false, "Sound is gone")
		return
	end

	local Track = self:Current()

	Done(true, {
		Title = (Track and Track.Title) or self.Title or "Local audio",
		Artist = (Track and Track.Artist) or self.Artist or "",
		Album = (Track and Track.Album) or "",
		Cover = (Track and Track.Cover) or self.Cover or "",
		Position = Sound.TimePosition,
		Duration = Sound.TimeLength,
		Playing = Sound.IsPlaying,
		Volume = math.floor(Sound.Volume * 100 + 0.5),
		CanSeek = Sound.TimeLength > 0,
		CanSkip = #self.Playlist > 1,
	})
end

function Local:Play(Done)
	if self.Sound then
		self.Sound:Resume()
	end
	Done = Done or function() end
	Done(true)
end

function Local:Pause(Done)
	if self.Sound then
		self.Sound:Pause()
	end
	Done = Done or function() end
	Done(true)
end

function Local:Step(Direction)
	if #self.Playlist == 0 then
		return
	end

	self.Index = ((self.Index - 1 + Direction) % #self.Playlist) + 1
	local Track = self:Current()

	if self.Sound and Track and Track.SoundId then
		self.Sound.SoundId = Track.SoundId
		self.Sound.TimePosition = 0
		self.Sound:Play()
	end
end

function Local:Next(Done)
	self:Step(1)
	Done = Done or function() end
	Done(true)
end

function Local:Previous(Done)
	self:Step(-1)
	Done = Done or function() end
	Done(true)
end

function Local:Seek(Seconds, Done)
	if self.Sound then
		self.Sound.TimePosition = math.clamp(tonumber(Seconds) or 0, 0, math.max(self.Sound.TimeLength, 0))
	end
	Done = Done or function() end
	Done(true)
end

function Local:SetVolume(Percent, Done)
	if self.Sound then
		self.Sound.Volume = math.clamp((tonumber(Percent) or 0) / 100, 0, 1)
	end
	Done = Done or function() end
	Done(true)
end

Providers.Local = Local
Providers.NewLocal = Local.new

-- --------------------------------------------------------------------- Demo
--
-- Runs without a service so a hub can drop the widget on screen before anyone
-- has connected anything. Position advances off the clock.

local Demo = {}
Demo.__index = Demo

local DemoTracks = {
	{ Title = "Red Flags", Artist = "ny Howard", Album = "What Now", Duration = 267, Cover = "" },
	{ Title = "Static Bloom", Artist = "Vesper Lane", Album = "Nightshift", Duration = 214, Cover = "" },
	{ Title = "Chrome Garden", Artist = "Mira Sextant", Album = "Bloom", Duration = 231, Cover = "" },
}

function Demo.new()
	return setmetatable({
		Id = "demo",
		Name = "Demo",
		Kind = "demo",
		Connected = true,
		Account = "Local preview",
		Status = "Previewing",
		Index = 1,
		Position = 33,
		Playing = true,
		Volume = 62,
		Clock = tick(),
	}, Demo)
end

function Demo:Advance()
	local Now = tick()
	local Delta = Now - self.Clock
	self.Clock = Now

	if not self.Playing then
		return
	end

	local Track = DemoTracks[self.Index]
	self.Position = self.Position + Delta

	if self.Position >= Track.Duration then
		self.Index = (self.Index % #DemoTracks) + 1
		self.Position = 0
	end
end

function Demo:Connect(_, Done)
	Done = Done or function() end
	Done(true, "Previewing")
end

function Demo:Disconnect()
	self.Connected = false
	self.Status = "Preview off"
end

function Demo:Poll(Done)
	self:Advance()

	local Track = DemoTracks[self.Index]
	Done(true, {
		Title = Track.Title,
		Artist = Track.Artist,
		Album = Track.Album,
		Cover = Track.Cover,
		Position = self.Position,
		Duration = Track.Duration,
		Playing = self.Playing,
		Volume = self.Volume,
		CanSeek = true,
		CanSkip = true,
	})
end

function Demo:Play(Done)
	self.Playing = true
	Done = Done or function() end
	Done(true)
end

function Demo:Pause(Done)
	self.Playing = false
	Done = Done or function() end
	Done(true)
end

function Demo:Next(Done)
	self.Index = (self.Index % #DemoTracks) + 1
	self.Position = 0
	Done = Done or function() end
	Done(true)
end

function Demo:Previous(Done)
	self.Index = ((self.Index - 2) % #DemoTracks) + 1
	self.Position = 0
	Done = Done or function() end
	Done(true)
end

function Demo:Seek(Seconds, Done)
	self.Position = math.clamp(tonumber(Seconds) or 0, 0, DemoTracks[self.Index].Duration)
	Done = Done or function() end
	Done(true)
end

function Demo:SetVolume(Percent, Done)
	self.Volume = math.clamp(tonumber(Percent) or 0, 0, 100)
	Done = Done or function() end
	Done(true)
end

Providers.Demo = Demo
Providers.NewDemo = Demo.new
Providers.DemoTracks = DemoTracks

-- ------------------------------------------------------------------- Format

function Providers.FormatTime(Seconds)
	Seconds = tonumber(Seconds) or 0
	if Seconds < 0 or Seconds ~= Seconds then
		Seconds = 0
	end

	local Minutes = math.floor(Seconds / 60)
	local Rest = math.floor(Seconds % 60)

	return string.format("%d:%02d", Minutes, Rest)
end

return Providers
