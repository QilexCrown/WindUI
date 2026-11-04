-- Transport layer for the Music widget.
--
-- One contract, five transports. The UI never learns which service is on the
-- other end:
--
--   Provider.Id        string          "spotify" | "files" | "sound" | "bridge" | "demo"
--   Provider.Name      string
--   Provider.Kind      "remote" | "files" | "sound" | "bridge" | "demo"
--   Provider.Connected boolean
--   Provider.Account   string?
--   Provider.Status    string          one line, rendered verbatim
--
--   Provider:Connect(options, done)    done(ok, message)
--   Provider:Poll(done)                done(ok, state | message)
--   Provider:Play(done)  :Pause(done)  :Next(done)  :Previous(done)
--   Provider:Seek(seconds, done)
--   Provider:SetVolume(percent, done)  0-100
--   Provider:Disconnect()
--
-- state = {
--     Title, Artist, Album, Cover,
--     Position, Duration, Playing, Volume,
--     CanSeek, CanSkip, Link,
-- }
--
-- Spotify talks to the Web API directly from the executor. Auth is PKCE with a
-- pasted redirect URL (the widget owns the form); nothing here opens a browser.
-- Local files are listed from a folder and played through a Sound whose SoundId
-- points at rbxasset://, which is how executors expose a file on disk.

local cloneref = (cloneref or clonereference or function(instance)
	return instance
end)

local HttpService = cloneref(game:GetService("HttpService"))
local SoundService = cloneref(game:GetService("SoundService"))

local Creator = require("./Creator")

local Providers = {}

------------------------------------------------------------------ encoding

local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

-- Spotify's token endpoint speaks form encoding and PKCE needs base64url, so
-- the encoder lives here rather than in a dependency.
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

local function Base64Url(Input)
	return (Base64(Input):gsub("%+", "-"):gsub("/", "_"):gsub("=", ""))
end

local function UrlEncode(Value)
	return (
		tostring(Value):gsub("[^%w%-%._~]", function(Character)
			return string.format("%%%02X", string.byte(Character))
		end)
	)
end

--------------------------------------------------------------- sha-256 core

local K = {
	0x428a2f98,
	0x71374491,
	0xb5c0fbcf,
	0xe9b5dba5,
	0x3956c25b,
	0x59f111f1,
	0x923f82a4,
	0xab1c5ed5,
	0xd807aa98,
	0x12835b01,
	0x243185be,
	0x550c7dc3,
	0x72be5d74,
	0x80deb1fe,
	0x9bdc06a7,
	0xc19bf174,
	0xe49b69c1,
	0xefbe4786,
	0x0fc19dc6,
	0x240ca1cc,
	0x2de92c6f,
	0x4a7484aa,
	0x5cb0a9dc,
	0x76f988da,
	0x983e5152,
	0xa831c66d,
	0xb00327c8,
	0xbf597fc7,
	0xc6e00bf3,
	0xd5a79147,
	0x06ca6351,
	0x14292967,
	0x27b70a85,
	0x2e1b2138,
	0x4d2c6dfc,
	0x53380d13,
	0x650a7354,
	0x766a0abb,
	0x81c2c92e,
	0x92722c85,
	0xa2bfe8a1,
	0xa81a664b,
	0xc24b8b70,
	0xc76c51a3,
	0xd192e819,
	0xd6990624,
	0xf40e3585,
	0x106aa070,
	0x19a4c116,
	0x1e376c08,
	0x2748774c,
	0x34b0bcb5,
	0x391c0cb3,
	0x4ed8aa4a,
	0x5b9cca4f,
	0x682e6ff3,
	0x748f82ee,
	0x78a5636f,
	0x84c87814,
	0x8cc70208,
	0x90befffa,
	0xa4506ceb,
	0xbef9a3f7,
	0xc67178f2,
}

local band = bit32.band
local bxor = bit32.bxor
local bnot = bit32.bnot
local rrotate = bit32.rrotate
local rshift = bit32.rshift

-- PKCE needs SHA-256 of the verifier and the engine exposes none, so the digest
-- is computed here. Messages are short — a 64 byte verifier, in practice.
local function Sha256(Message)
	local Bytes = { Message:byte(1, #Message) }
	local BitLength = #Message * 8

	Bytes[#Bytes + 1] = 0x80
	while #Bytes % 64 ~= 56 do
		Bytes[#Bytes + 1] = 0
	end
	for Index = 7, 0, -1 do
		Bytes[#Bytes + 1] = math.floor(BitLength / 2 ^ (Index * 8)) % 256
	end

	local H = {
		0x6a09e667,
		0xbb67ae85,
		0x3c6ef372,
		0xa54ff53a,
		0x510e527f,
		0x9b05688c,
		0x1f83d9ab,
		0x5be0cd19,
	}

	for Chunk = 1, #Bytes, 64 do
		local W = {}

		for Index = 1, 16 do
			local Offset = Chunk + (Index - 1) * 4
			W[Index] = Bytes[Offset] * 16777216
				+ Bytes[Offset + 1] * 65536
				+ Bytes[Offset + 2] * 256
				+ Bytes[Offset + 3]
		end

		for Index = 17, 64 do
			local A = W[Index - 15]
			local B = W[Index - 2]
			local S0 = bxor(rrotate(A, 7), rrotate(A, 18), rshift(A, 3))
			local S1 = bxor(rrotate(B, 17), rrotate(B, 19), rshift(B, 10))
			W[Index] = band(W[Index - 16] + S0 + W[Index - 7] + S1, 0xFFFFFFFF)
		end

		local A, B, C, D, E, F, G, Hh = H[1], H[2], H[3], H[4], H[5], H[6], H[7], H[8]

		for Index = 1, 64 do
			local S1 = bxor(rrotate(E, 6), rrotate(E, 11), rrotate(E, 25))
			local Ch = bxor(band(E, F), band(bnot(E), G))
			local Temp1 = band(Hh + S1 + Ch + K[Index] + W[Index], 0xFFFFFFFF)
			local S0 = bxor(rrotate(A, 2), rrotate(A, 13), rrotate(A, 22))
			local Maj = bxor(band(A, B), band(A, C), band(B, C))
			local Temp2 = band(S0 + Maj, 0xFFFFFFFF)

			Hh = G
			G = F
			F = E
			E = band(D + Temp1, 0xFFFFFFFF)
			D = C
			C = B
			B = A
			A = band(Temp1 + Temp2, 0xFFFFFFFF)
		end

		H[1] = band(H[1] + A, 0xFFFFFFFF)
		H[2] = band(H[2] + B, 0xFFFFFFFF)
		H[3] = band(H[3] + C, 0xFFFFFFFF)
		H[4] = band(H[4] + D, 0xFFFFFFFF)
		H[5] = band(H[5] + E, 0xFFFFFFFF)
		H[6] = band(H[6] + F, 0xFFFFFFFF)
		H[7] = band(H[7] + G, 0xFFFFFFFF)
		H[8] = band(H[8] + Hh, 0xFFFFFFFF)
	end

	local Out = {}
	for Index = 1, 8 do
		local Word = H[Index]
		Out[Index] = string.char(
			band(rshift(Word, 24), 0xFF),
			band(rshift(Word, 16), 0xFF),
			band(rshift(Word, 8), 0xFF),
			band(Word, 0xFF)
		)
	end

	return table.concat(Out)
end

local VerifierChars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"

local function RandomString(Length)
	local Out = {}
	for Index = 1, Length do
		local Pick = math.random(1, #VerifierChars)
		Out[Index] = VerifierChars:sub(Pick, Pick)
	end
	return table.concat(Out)
end

---------------------------------------------------------------------- http

local function Decode(Body)
	if type(Body) ~= "string" or Body == "" then
		return nil
	end
	local Ok, Data = pcall(function()
		return HttpService:JSONDecode(Body)
	end)
	if Ok and type(Data) == "table" then
		return Data
	end
	return nil
end

-- request() carries arbitrary methods and headers wherever it exists;
-- HttpService:RequestAsync is the fallback. Both return (ok, body, status).
local function Http(Options)
	local Url = Options.Url
	local Method = Options.Method or "GET"

	if type(request) == "function" then
		local Ok, Response = pcall(request, {
			Url = Url,
			Method = Method,
			Headers = Options.Headers,
			Body = Options.Body,
		})
		if Ok and type(Response) == "table" then
			return true, Response.Body or "", tonumber(Response.StatusCode) or 200
		end
		return false, tostring(Response), 0
	end

	local Ok, Response = pcall(function()
		return HttpService:RequestAsync({
			Url = Url,
			Method = Method,
			Headers = Options.Headers,
			Body = Options.Body,
		})
	end)

	if Ok and type(Response) == "table" then
		return Response.Success, Response.Body or "", tonumber(Response.StatusCode) or 200
	end

	return false, tostring(Response), 0
end

--------------------------------------------------------------------- utils

function Providers.FormatTime(Seconds)
	Seconds = tonumber(Seconds) or 0
	if Seconds < 0 or Seconds ~= Seconds then
		Seconds = 0
	end

	return string.format("%d:%02d", math.floor(Seconds / 60), math.floor(Seconds % 60))
end

function Providers.Idle(Message)
	return {
		Title = "",
		Hint = Message or "",
		Artist = "",
		Album = "",
		Cover = "",
		Position = 0,
		Duration = 0,
		Playing = false,
		Volume = nil,
		CanSeek = false,
		CanSkip = false,
		Link = "",
	}
end

------------------------------------------------------------------- spotify

local Spotify = {}
Spotify.__index = Spotify

local SpotifyScopes = table.concat({
	"user-read-playback-state",
	"user-modify-playback-state",
	"user-read-currently-playing",
	"user-read-private",
}, " ")

local SpotifyApi = "https://api.spotify.com/v1"
local SpotifyAccounts = "https://accounts.spotify.com"

function Spotify.new(Config)
	Config = Config or {}
	return setmetatable({
		Id = "spotify",
		Name = "Spotify",
		Kind = "remote",
		Connected = false,
		Account = nil,
		Status = "Not connected",
		ClientId = Config.ClientId or "",
		RedirectUri = Config.RedirectUri or "http://127.0.0.1:8888/callback",
		AccessToken = nil,
		RefreshToken = nil,
		ExpiresAt = 0,
		Verifier = nil,
		Link = "",
		Volume = 60,
	}, Spotify)
end

function Spotify:Save()
	return {
		ClientId = self.ClientId,
		RedirectUri = self.RedirectUri,
		AccessToken = self.AccessToken,
		RefreshToken = self.RefreshToken,
		ExpiresAt = self.ExpiresAt,
		Account = self.Account,
	}
end

function Spotify:Load(Data)
	if type(Data) ~= "table" then
		return
	end
	self.ClientId = Data.ClientId or self.ClientId
	self.RedirectUri = Data.RedirectUri or self.RedirectUri
	self.AccessToken = Data.AccessToken
	self.RefreshToken = Data.RefreshToken
	self.ExpiresAt = tonumber(Data.ExpiresAt) or 0
	self.Account = Data.Account

	if self:HasTokens() then
		self.Connected = true
		self.Status = self.Account and ("Connected — " .. self.Account) or "Connected"
	end
end

function Spotify:HasTokens()
	return type(self.AccessToken) == "string" and self.AccessToken ~= ""
end

-- The verifier is generated with the URL so the challenge baked into the
-- authorize request is the one the exchange proves.
function Spotify:AuthUrl(ClientId)
	local Id = ClientId or self.ClientId
	if type(Id) ~= "string" or Id == "" then
		return nil, "Paste a client id first"
	end

	self.ClientId = Id
	self.Verifier = RandomString(64)

	return SpotifyAccounts
		.. "/authorize?"
		.. table.concat({
			"client_id=" .. UrlEncode(Id),
			"response_type=code",
			"redirect_uri=" .. UrlEncode(self.RedirectUri),
			"code_challenge_method=S256",
			"code_challenge=" .. Base64Url(Sha256(self.Verifier)),
			"scope=" .. UrlEncode(SpotifyScopes),
		}, "&")
end

function Spotify:TokenRequest(Form, Done)
	local Ok, Body, Status = Http({
		Url = SpotifyAccounts .. "/api/token",
		Method = "POST",
		Headers = { ["Content-Type"] = "application/x-www-form-urlencoded" },
		Body = Form,
	})

	local Data = Decode(Body)
	if not Ok or not Data or not Data.access_token then
		local Reason = (Data and (Data.error_description or Data.error)) or ("HTTP " .. tostring(Status))
		Done(false, Reason)
		return
	end

	Done(true, Data)
end

function Spotify:ApplyToken(Data, Done)
	self.AccessToken = Data.access_token
	self.RefreshToken = Data.refresh_token or self.RefreshToken
	self.ExpiresAt = os.time() + (tonumber(Data.expires_in) or 3600)
	self.Connected = true
	self.Status = "Connected"

	self:FetchProfile(function(Ok, Name)
		if Ok and Name then
			self.Account = Name
			self.Status = "Connected — " .. Name
		end
		Done(true, self.Account or "Connected")
	end)
end

-- Accepts the full localhost redirect URL, just the query string, or the code.
function Spotify:Exchange(Input, Done)
	local Code = tostring(Input or ""):match("[?&]code=([^&%s]+)")
	if not Code then
		local Trimmed = tostring(Input or ""):gsub("%s", "")
		if Trimmed ~= "" and not Trimmed:find("error=") then
			Code = Trimmed
		end
	end

	if not Code then
		local Error = tostring(Input or ""):match("[?&]error=([^&%s]+)")
		Done(false, Error and ("Spotify said " .. Error) or "No code in that URL")
		return
	end

	if not self.Verifier then
		Done(false, "Press Sign in first — the challenge expired")
		return
	end

	self:TokenRequest(
		table.concat({
			"grant_type=authorization_code",
			"code=" .. UrlEncode(Code),
			"redirect_uri=" .. UrlEncode(self.RedirectUri),
			"client_id=" .. UrlEncode(self.ClientId),
			"code_verifier=" .. UrlEncode(self.Verifier),
		}, "&"),
		function(Ok, Data)
			if not Ok then
				Done(false, Data)
				return
			end
			self.Verifier = nil
			self:ApplyToken(Data, Done)
		end
	)
end

function Spotify:Refresh(Done)
	if not self.RefreshToken then
		Done(false, "Sign in again")
		return
	end

	self:TokenRequest(
		table.concat({
			"grant_type=refresh_token",
			"refresh_token=" .. UrlEncode(self.RefreshToken),
			"client_id=" .. UrlEncode(self.ClientId),
		}, "&"),
		function(Ok, Data)
			if not Ok then
				self.Connected = false
				self.Status = "Sign in again"
				Done(false, Data)
				return
			end
			self.AccessToken = Data.access_token
			if Data.refresh_token then
				self.RefreshToken = Data.refresh_token
			end
			self.ExpiresAt = os.time() + (tonumber(Data.expires_in) or 3600)
			Done(true)
		end
	)
end

function Spotify:FetchProfile(Done)
	local Ok, Body, Status = Http({
		Url = SpotifyApi .. "/me",
		Headers = { Authorization = "Bearer " .. tostring(self.AccessToken) },
	})

	if not Ok or Status >= 400 then
		Done(false, "HTTP " .. tostring(Status))
		return
	end

	local Data = Decode(Body)
	Done(true, Data and (Data.display_name or Data.id) or nil)
end

-- Every authenticated call funnels through here so a 401 refreshes the token
-- once and retries, instead of the widget dropping to "sign in again" mid-song.
function Spotify:Api(Method, Path, Body, Retried)
	if not self:HasTokens() then
		return false, "not connected", 0
	end

	local Ok, ResponseBody, Status = Http({
		Url = Path:find("^http") and Path or (SpotifyApi .. Path),
		Method = Method,
		Headers = {
			Authorization = "Bearer " .. tostring(self.AccessToken),
			["Content-Type"] = "application/json",
		},
		Body = Body and HttpService:JSONEncode(Body) or nil,
	})

	if Status == 401 and not Retried and self.RefreshToken then
		local Refreshed = false
		self:Refresh(function(Ok2)
			Refreshed = Ok2
		end)
		if Refreshed then
			return self:Api(Method, Path, Body, true)
		end
	end

	return Ok, ResponseBody, Status
end

function Spotify:Connect(Options, Done)
	Options = Options or {}
	if Options.ClientId then
		self.ClientId = Options.ClientId
	end
	if Options.RedirectUri then
		self.RedirectUri = Options.RedirectUri
	end
	if Options.AccessToken then
		self.AccessToken = Options.AccessToken
		self.Connected = true
		self:FetchProfile(function(Ok, Name)
			if Ok and Name then
				self.Account = Name
				self.Status = "Connected — " .. Name
			end
			Done(true, self.Account or "Connected")
		end)
		return
	end

	if not self:HasTokens() then
		Done(false, "Not signed in")
		return
	end

	if self.ExpiresAt > 0 and os.time() > self.ExpiresAt - 30 and self.RefreshToken then
		self:Refresh(function(Ok, Message)
			if not Ok then
				Done(false, Message)
				return
			end
			self:Connect(nil, Done)
		end)
		return
	end

	self:FetchProfile(function(Ok, Name)
		if not Ok then
			self.Connected = false
			self.Status = "Sign in again"
			Done(false, Name)
			return
		end
		self.Connected = true
		self.Account = Name
		self.Status = "Connected — " .. tostring(Name)
		Done(true, Name)
	end)
end

function Spotify:Poll(Done)
	local Ok, Body, Status = self:Api("GET", "/me/player")

	if Status == 204 or (Ok and (Body == "" or Body == nil)) then
		Done(true, Providers.Idle("Nothing playing"))
		return
	end

	if not Ok or Status >= 400 then
		if Status == 401 then
			self.Connected = false
			self.Status = "Sign in again"
		end
		Done(false, "HTTP " .. tostring(Status))
		return
	end

	local Data = Decode(Body)
	if not Data or not Data.item then
		Done(true, Providers.Idle("Nothing playing"))
		return
	end

	local Item = Data.item
	local Title = Item.name or "Unknown"
	local Artist = "Unknown"

	if Item.type == "episode" then
		Artist = (Item.show and Item.show.name) or "Podcast"
	elseif Item.artists and Item.artists[1] then
		local Names = {}
		for _, Entry in ipairs(Item.artists) do
			Names[#Names + 1] = Entry.name
		end
		Artist = table.concat(Names, ", ")
	end

	local Album = Item.type == "episode" and ((Item.show and Item.show.name) or "")
		or (Item.album and Item.album.name)
		or ""

	local Images = (Item.album and Item.album.images)
		or (Item.show and Item.show.images)
		or (Item.images)
		or {}

	local Cover = Images[1] and Images[1].url or ""
	self.Link = (Item.external_urls and Item.external_urls.spotify) or ""

	local Device = Data.device or {}
	if Device.volume_percent then
		self.Volume = Device.volume_percent
	end

	Done(true, {
		Title = Title,
		Artist = Artist,
		Album = Album,
		Cover = Cover,
		Position = (tonumber(Data.progress_ms) or 0) / 1000,
		Duration = (tonumber(Item.duration_ms) or 0) / 1000,
		Playing = Data.is_playing == true,
		Volume = Device.volume_percent,
		CanSeek = true,
		CanSkip = true,
		Link = self.Link,
	})
end

function Spotify:Command(Method, Path, Done)
	local Ok, Body, Status = self:Api(Method, Path)
	if not Ok or Status >= 400 then
		local Data = Decode(Body)
		local Reason = Data and Data.error and (Data.error.message or Data.error.reason) or ("HTTP " .. tostring(Status))
		if Done then
			Done(false, Reason)
		end
		return
	end
	if Done then
		Done(true)
	end
end

function Spotify:Play(Done)
	self:Command("PUT", "/me/player/play", Done)
end

function Spotify:Pause(Done)
	self:Command("PUT", "/me/player/pause", Done)
end

function Spotify:Next(Done)
	self:Command("POST", "/me/player/next", Done)
end

function Spotify:Previous(Done)
	self:Command("POST", "/me/player/previous", Done)
end

function Spotify:Seek(Seconds, Done)
	self:Command("PUT", "/me/player/seek?position_ms=" .. math.floor((tonumber(Seconds) or 0) * 1000), Done)
end

function Spotify:SetVolume(Percent, Done)
	local Value = math.clamp(math.floor(tonumber(Percent) or 0), 0, 100)
	self.Volume = Value
	self:Command("PUT", "/me/player/volume?volume_percent=" .. Value, Done)
end

function Spotify:Disconnect()
	self.AccessToken = nil
	self.RefreshToken = nil
	self.ExpiresAt = 0
	self.Connected = false
	self.Account = nil
	self.Status = "Not connected"
end

Providers.NewSpotify = Spotify.new
Providers.Spotify = Spotify

----------------------------------------------------------------- local files

local AUDIO_EXTENSIONS = {
	mp3 = true,
	ogg = true,
	wav = true,
	flac = true,
	m4a = true,
	aac = true,
	opus = true,
}

local IMAGE_EXTENSIONS = { "png", "jpg", "jpeg", "webp" }

local Folder = {}
Folder.__index = Folder

local function Basename(Path_)
	local Name = tostring(Path_):gsub("\\", "/")
	return (Name:match("([^/]+)$")) or Name
end

local function Stem(Name)
	return (Name:gsub("%.[^%.]+$", ""))
end

local function Extension(Name)
	return (Name:match("%.([^%.]+)$") or ""):lower()
end

function Folder.new(Config)
	Config = Config or {}
	return setmetatable({
		Id = "files",
		Name = "My files",
		Kind = "files",
		Path = Config.Path or "Ender Hub/songs",
		Status = "Not scanned",
		Connected = false,
		Tracks = {},
		Index = 0,
		Volume = 60,
		Sound = nil,
		LoadedPath = nil,
		Shuffle = false,
		Playlists = nil,
		CoverAttempts = {},
		CoverPending = {},
		OnCover = nil,
	}, Folder)
end

function Folder:EnsureSound()
	if self.Sound and self.Sound.Parent then
		return self.Sound
	end

	local Sound = Instance.new("Sound")
	Sound.Name = "WindUIMusicFile"
	Sound.Volume = self.Volume / 100
	Sound.Parent = SoundService
	self.Sound = Sound

	local ProviderSelf = self
	Sound.Ended:Connect(function()
		if ProviderSelf.LoadedPath then
			ProviderSelf:Next()
		end
	end)

	return Sound
end

function Folder:SidecarCover(Directory, Name)
	if type(isfile) ~= "function" or type(getcustomasset) ~= "function" then
		return ""
	end

	local StemName = Stem(Name)
	for _, Extension_ in ipairs(IMAGE_EXTENSIONS) do
		local Candidate = Directory .. "/" .. StemName .. "." .. Extension_
		if isfile(Candidate) then
			local Ok, Asset = pcall(getcustomasset, Candidate)
			if Ok and type(Asset) == "string" then
				return Asset
			end
		end
	end

	return ""
end

function Folder:PlaylistsPath()
	return (self.Path:gsub("[/\\]+$", "")) .. "/playlists.json"
end

-- The reference player keeps its library state next to the audio. Same file,
-- same shape, so a folder can move between the two without conversion:
-- {"playlists":[],"shuffle":false,"selected":[]}
function Folder:EnsurePlaylists()
	local File = self:PlaylistsPath()

	if self.Playlists and self.PlaylistsFile == File then
		return self.Playlists
	end

	local Default = '{"playlists":[],"shuffle":false,"selected":[]}'
	local Loaded

	if type(isfile) == "function" and type(readfile) == "function" and isfile(File) then
		local Ok, Body = pcall(readfile, File)
		if Ok and type(Body) == "string" and Body ~= "" then
			local Data = Decode(Body)
			if Data then
				Loaded = {
					playlists = type(Data.playlists) == "table" and Data.playlists or {},
					shuffle = Data.shuffle == true,
					selected = type(Data.selected) == "table" and Data.selected or {},
				}
			end
		end
	end

	if not Loaded then
		Loaded = { playlists = {}, shuffle = false, selected = {} }
		if type(writefile) == "function" then
			pcall(writefile, File, Default)
		end
	end

	self.Playlists = Loaded
	self.PlaylistsFile = File
	self.Shuffle = Loaded.shuffle

	return Loaded
end

function Folder:SavePlaylists()
	local Data = self:EnsurePlaylists()
	Data.shuffle = self.Shuffle == true

	if type(writefile) ~= "function" then
		return
	end

	local Ok, Body = pcall(function()
		return HttpService:JSONEncode(Data)
	end)
	if Ok then
		pcall(writefile, self:PlaylistsPath(), Body)
	end
end

local function HttpGet(Url)
	local Ok, Body = pcall(function()
		return game:HttpGet(Url)
	end)
	if Ok and type(Body) == "string" and Body ~= "" then
		return Body
	end
	return nil
end

local function CoverQuery(Track)
	local Title = tostring(Track.Title or "")
	Title = Title:gsub("%b[]", " "):gsub("%b()", " ")
	Title = Title:gsub("[_]+", " "):gsub("%s+", " ")
	Title = Title:gsub("^%s+", ""):gsub("%s+$", "")

	local Artist = tostring(Track.Artist or "")
	if Artist == "Local file" or Artist == "Local audio" then
		Artist = ""
	end
	Artist = Artist:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")

	return (Artist ~= "" and (Artist .. " " .. Title) or Title)
end

-- Cover lookup for tracks that arrive as bare audio files. Filename metadata
-- gets searched on iTunes (no key, no account), the first 600x600 artwork is
-- written next to the mp3 as <stem>.jpg, then handed to getcustomasset. Next
-- scan finds it through SidecarCover and nothing is fetched again.
function Folder:FetchCover(Track, Done)
	if not Track then
		if Done then
			Done("")
		end
		return
	end

	if type(Track.Cover) == "string" and Track.Cover ~= "" then
		if Done then
			Done(Track.Cover)
		end
		return
	end

	self.CoverAttempts = self.CoverAttempts or {}
	self.CoverPending = self.CoverPending or {}

	local Key = Track.Path
	if self.CoverPending[Key] or self.CoverAttempts[Key] then
		return
	end

	self.CoverPending[Key] = true

	task.spawn(function()
		local Query = CoverQuery(Track)
		local Art
		local Online = type(game.HttpGet) == "function" and type(game.GetService) == "function"

		if Online and Query ~= "" then
			local Body = HttpGet(
				"https://itunes.apple.com/search?term="
					.. UrlEncode(Query)
					.. "&entity=song&limit=1"
			)
			local Data = Decode(Body)
			local Hit = Data and Data.results and Data.results[1]
			Art = Hit and Hit.artworkUrl100
			if type(Art) == "string" then
				Art = Art:gsub("100x100bb", "600x600bb"):gsub("60x60bb", "600x600bb")
			end
		end

		local Asset = ""
		if type(Art) == "string" and Art ~= "" then
			local Bytes = HttpGet(Art)
			if Bytes and #Bytes > 512 then
				local Target = Track.Directory .. "/" .. Stem(Track.Name) .. ".jpg"
				local Wrote = type(writefile) == "function" and pcall(writefile, Target, Bytes)

				if Wrote and type(getcustomasset) == "function" then
					local Ok, Value = pcall(getcustomasset, Target)
					if Ok and type(Value) == "string" then
						Asset = Value
					end
				end
			end
		end

		self.CoverPending[Key] = nil
		self.CoverAttempts[Key] = true

		if Asset ~= "" then
			Track.Cover = Asset
			if self.OnCover then
				self.OnCover(Track, Asset)
			end
		end

		if Done then
			Done(Asset)
		end
	end)
end

function Folder:Scan()
	self.Tracks = {}
	self:EnsurePlaylists()

	if type(listfiles) ~= "function" then
		self.Status = "No file API in this executor"
		self.Connected = false
		return 0
	end

	local Ok, Files = pcall(listfiles, self.Path)
	if not Ok or type(Files) ~= "table" then
		self.Status = "No " .. self.Path .. " folder"
		self.Connected = false
		return 0
	end

	local Found = {}
	for _, Path_ in ipairs(Files) do
		local Name = Basename(Path_)
		if AUDIO_EXTENSIONS[Extension(Name)] then
			Found[#Found + 1] = {
				Path = Path_,
				Name = Name,
			}
		end
	end

	table.sort(Found, function(A, B)
		return A.Name:lower() < B.Name:lower()
	end)

	for Index, Entry in ipairs(Found) do
		local Title = Stem(Entry.Name)
		local Artist = "Local file"
		local Split = Title:find(" %- ")
		if Split then
			Artist = Title:sub(1, Split - 1)
			Title = Title:sub(Split + 3)
		end

		local Directory = (Entry.Path:gsub("\\", "/"):match("^(.*)/[^/]+$")) or self.Path

		self.Tracks[Index] = {
			Path = Entry.Path,
			Name = Entry.Name,
			Title = Title,
			Artist = Artist,
			Album = "Ender Hub / songs",
			Directory = Directory,
			Cover = self:SidecarCover(Directory, Entry.Name),
			Duration = 0,
		}
	end

	-- Poll can run straight after a scan with no explicit Connect, so a scan
	-- has to leave the cursor on a real track: Current() returns nil otherwise.
	if #self.Tracks > 0 and (self.Index == 0 or not self.Tracks[self.Index]) then
		self.Index = 1
	end

	self.Connected = #self.Tracks > 0
	self.Status = #self.Tracks == 0 and ("Empty — drop mp3/ogg in " .. self.Path) or (#self.Tracks .. " tracks")

	return #self.Tracks
end

function Folder:Current()
	return self.Tracks[self.Index]
end

function Folder:Load(Index_, Autoplay)
	local Track = self.Tracks[Index_]
	if not Track then
		return false, "No track"
	end

	local OkAsset, Asset = pcall(getcustomasset, Track.Path)
	if not OkAsset or type(Asset) ~= "string" then
		return false, tostring(Asset)
	end

	local Sound = self:EnsureSound()
	Sound:Stop()
	Sound.SoundId = Asset
	Sound.TimePosition = 0
	Sound.Volume = self.Volume / 100

	self.Index = Index_
	self.LoadedPath = Track.Path
	self.Status = "Playing — " .. Track.Title

	if Track.Cover == "" then
		Track.Cover = self:SidecarCover(Track.Directory, Track.Name)
	end

	if Track.Cover == "" then
		self:FetchCover(Track)
	end

	if Autoplay ~= false then
		Sound:Play()
	end

	task.spawn(function()
		local Deadline = tick() + 6
		while tick() < Deadline and self.LoadedPath == Track.Path do
			if Sound.TimeLength > 0 then
				Track.Duration = Sound.TimeLength
				return
			end
			task.wait(0.1)
		end
	end)

	return true
end

function Folder:Connect(Options, Done)
	if Options and Options.Path then
		self.Path = Options.Path
	end

	local Count = self:Scan()
	if Count == 0 then
		Done(false, self.Status)
		return
	end

	if self.Index == 0 then
		self.Index = 1
	end

	Done(true, self.Status)
end

function Folder:Poll(Done)
	if not self.Sound or not self.LoadedPath then
		if #self.Tracks > 0 then
			local Track = self:Current()
			if Track then
				Done(true, {
					Title = Track.Title,
					Artist = Track.Artist,
					Album = Track.Album,
					Cover = Track.Cover,
					Position = 0,
					Duration = Track.Duration,
					Playing = false,
					Volume = self.Volume,
					CanSeek = true,
					CanSkip = #self.Tracks > 1,
					Link = "",
				})
				return
			end
		end

		Done(true, Providers.Idle("Drop mp3/ogg in " .. self.Path))
		return
	end

	local Sound = self.Sound
	local Track = self:Current()
	if not Track then
		Done(true, Providers.Idle("Nothing playing"))
		return
	end

	if Sound.TimeLength > 0 then
		Track.Duration = Sound.TimeLength
	end

	Done(true, {
		Title = Track.Title,
		Artist = Track.Artist,
		Album = Track.Album,
		Cover = Track.Cover,
		Position = Sound.TimePosition,
		Duration = Track.Duration,
		Playing = Sound.IsPlaying,
		Volume = self.Volume,
		CanSeek = true,
		CanSkip = #self.Tracks > 1,
		Link = "",
	})
end

function Folder:Play(Done)
	if self.Index == 0 then
		local Ok, Message = self:Load(1, true)
		Done(Ok, Message)
		return
	end

	local Sound = self:EnsureSound()
	if Sound.SoundId == "" then
		local Ok, Message = self:Load(self.Index, true)
		Done(Ok, Message)
		return
	end

	-- Play() resumes a paused sound and starts one that never ran; Resume()
	-- does nothing on a sound that has not started yet.
	Sound:Play()
	self.Status = "Playing"
	Done(true)
end

function Folder:Pause(Done)
	if self.Sound then
		self.Sound:Pause()
	end
	self.Status = "Paused"
	Done(true)
end

function Folder:Next(Done)
	if #self.Tracks == 0 then
		if Done then
			Done(false, "No tracks")
		end
		return
	end

	local NextIndex
	if self.Shuffle and #self.Tracks > 1 then
		repeat
			NextIndex = math.random(1, #self.Tracks)
		until NextIndex ~= self.Index
	else
		NextIndex = self.Index % #self.Tracks + 1
	end

	local Ok, Message = self:Load(NextIndex, true)
	if Done then
		Done(Ok, Message)
	end
end

function Folder:Previous(Done)
	if #self.Tracks == 0 then
		if Done then
			Done(false, "No tracks")
		end
		return
	end

	local PreviousIndex = self.Index - 1
	if PreviousIndex < 1 then
		PreviousIndex = #self.Tracks
	end

	local Ok, Message = self:Load(PreviousIndex, true)
	if Done then
		Done(Ok, Message)
	end
end

function Folder:Seek(Seconds, Done)
	if self.Sound then
		self.Sound.TimePosition = math.clamp(tonumber(Seconds) or 0, 0, math.max(self.Sound.TimeLength - 0.1, 0))
	end
	Done(true)
end

function Folder:SetVolume(Percent, Done)
	local Value = math.clamp(tonumber(Percent) or 0, 0, 100)
	self.Volume = Value
	if self.Sound then
		self.Sound.Volume = Value / 100
	end
	Done(true)
end

function Folder:Disconnect()
	if self.Sound then
		self.Sound:Stop()
		self.Sound:Destroy()
		self.Sound = nil
	end
	self.LoadedPath = nil
	self.Connected = false
	self.Status = "Not scanned"
end

Providers.NewFolder = Folder.new
Providers.Folder = Folder

--------------------------------------------------------------- bound Sound

local Bound = {}
Bound.__index = Bound

function Bound.new(Config)
	Config = Config or {}
	return setmetatable({
		Id = "sound",
		Name = Config.Name or "Sound object",
		Kind = "sound",
		Connected = Config.Sound ~= nil,
		Status = Config.Sound and "Playing the game's sound" or "No sound bound",
		Sound = Config.Sound,
		Title = Config.Title or "Nothing playing",
		Artist = Config.Artist or "",
		Cover = Config.Cover or "",
		Volume = Config.Sound and math.floor((Config.Sound.Volume or 0.5) * 100) or 60,
	}, Bound)
end

function Bound:Connect(Options, Done)
	Done(self.Sound ~= nil, self.Status)
end

function Bound:Poll(Done)
	local Sound = self.Sound
	if not Sound then
		Done(true, Providers.Idle("No sound bound"))
		return
	end

	Done(true, {
		Title = self.Title,
		Artist = self.Artist,
		Album = "",
		Cover = self.Cover,
		Position = Sound.TimePosition,
		Duration = Sound.TimeLength,
		Playing = Sound.IsPlaying,
		Volume = math.floor((Sound.Volume or 0.5) * 100),
		CanSeek = true,
		CanSkip = false,
		Link = "",
	})
end

function Bound:Play(Done)
	if self.Sound then
		self.Sound:Play()
	end
	Done(true)
end

function Bound:Pause(Done)
	if self.Sound then
		self.Sound:Pause()
	end
	Done(true)
end

function Bound:Next(Done)
	Done(false, "One sound")
end

function Bound:Previous(Done)
	Done(false, "One sound")
end

function Bound:Seek(Seconds, Done)
	if self.Sound then
		self.Sound.TimePosition = math.clamp(tonumber(Seconds) or 0, 0, math.max(self.Sound.TimeLength - 0.1, 0))
	end
	Done(true)
end

function Bound:SetVolume(Percent, Done)
	local Value = math.clamp(tonumber(Percent) or 0, 0, 100)
	self.Volume = Value
	if self.Sound then
		self.Sound.Volume = Value / 100
	end
	Done(true)
end

function Bound:Disconnect()
	self.Sound = nil
	self.Connected = false
end

Providers.NewSound = Bound.new
Providers.Bound = Bound

------------------------------------------------------------------ bridge

local Bridge = {}
Bridge.__index = Bridge

function Bridge.new(Config)
	Config = Config or {}
	return setmetatable({
		Id = Config.Id or "bridge",
		Name = Config.Name or "Bridge",
		Kind = "bridge",
		Url = (Config.Url or "http://127.0.0.1:5764"):gsub("/+$", ""),
		Connected = false,
		Status = "Not connected",
		Account = Config.Account,
		Volume = 60,
	}, Bridge)
end

function Bridge:Connect(Options, Done)
	if Options and Options.Url then
		self.Url = Options.Url:gsub("/+$", "")
	end

	local Ok, Body = Http({ Url = self.Url .. "/now" })
	local Data = Decode(Body)

	if not Ok or not Data then
		self.Connected = false
		self.Status = "Bridge offline"
		Done(false, "Bridge offline")
		return
	end

	self.Connected = true
	self.Status = "Connected"
	Done(true, Data.player or "Bridge")
end

function Bridge:Poll(Done)
	local Ok, Body = Http({ Url = self.Url .. "/now" })
	local Data = Decode(Body)

	if not Ok or not Data then
		self.Connected = false
		self.Status = "Bridge offline"
		Done(false, "Bridge offline")
		return
	end

	self.Connected = true
	self.Status = "Connected"

	Done(true, {
		Title = Data.title or "Nothing playing",
		Artist = Data.artist or "",
		Album = Data.album or "",
		Cover = Data.cover or "",
		Position = tonumber(Data.position) or 0,
		Duration = tonumber(Data.duration) or 0,
		Playing = Data.playing == true,
		Volume = tonumber(Data.volume),
		CanSeek = true,
		CanSkip = true,
		Link = Data.link or "",
	})
end

function Bridge:Command(Path, Done)
	local Ok = Http({ Url = self.Url .. Path })
	Done(Ok)
end

function Bridge:Play(Done)
	self:Command("/play", Done)
end

function Bridge:Pause(Done)
	self:Command("/pause", Done)
end

function Bridge:Next(Done)
	self:Command("/next", Done)
end

function Bridge:Previous(Done)
	self:Command("/previous", Done)
end

function Bridge:Seek(Seconds, Done)
	self:Command("/seek?position=" .. math.floor(tonumber(Seconds) or 0), Done)
end

function Bridge:SetVolume(Percent, Done)
	self:Command("/volume?value=" .. math.floor(tonumber(Percent) or 0), Done)
end

function Bridge:Disconnect()
	self.Connected = false
	self.Status = "Not connected"
end

Providers.NewBridge = Bridge.new
Providers.Bridge = Bridge

-------------------------------------------------------------------- demo

local DemoTracks = {
	{
		Title = "Red Flags",
		Artist = "ny Howard",
		Album = "What Now",
		Duration = 267,
		Cover = "https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/ee/49/ac/ee49accc-78bd-bcdb-1aff-c40c1ac3ccc4/074643959520.jpg/600x600bb.jpg",
	},
	{
		Title = "One More Time",
		Artist = "Daft Punk",
		Album = "Discovery",
		Duration = 320,
		Cover = "https://is1-ssl.mzstatic.com/image/thumb/Music221/v4/fd/4a/77/fd4a77db-0ebc-d043-41a2-f32fa1bb0fb4/dj.qrikkdwj.jpg/600x600bb.jpg",
	},
	{
		Title = "Chrome Garden",
		Artist = "Mira Sextant",
		Album = "Bloom",
		Duration = 231,
		Cover = "",
	},
}

local Demo = {}
Demo.__index = Demo

function Demo.new()
	return setmetatable({
		Id = "demo",
		Name = "Demo",
		Kind = "demo",
		Connected = true,
		Account = "Local preview",
		Status = "Previewing",
		Index = 2,
		Position = 72,
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

	self.Position = self.Position + Delta
	local Track = DemoTracks[self.Index]
	if Track and Track.Duration > 0 and self.Position >= Track.Duration then
		self.Index = self.Index % #DemoTracks + 1
		self.Position = 0
	end
end

function Demo:State()
	local Track = DemoTracks[self.Index] or DemoTracks[1]
	return {
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
		Link = "",
	}
end

function Demo:Connect(Options, Done)
	Done(true, "Previewing")
end

function Demo:Poll(Done)
	self:Advance()
	Done(true, self:State())
end

function Demo:Play(Done)
	self.Advance()
	self.Playing = true
	self.Status = "Previewing"
	Done(true)
end

function Demo:Pause(Done)
	self.Advance()
	self.Playing = false
	self.Status = "Paused"
	Done(true)
end

function Demo:Next(Done)
	self.Advance()
	self.Index = self.Index % #DemoTracks + 1
	self.Position = 0
	Done(true)
end

function Demo:Previous(Done)
	self.Advance()
	self.Index = (self.Index - 2) % #DemoTracks + 1
	self.Position = 0
	Done(true)
end

function Demo:Seek(Seconds, Done)
	self.Advance()
	self.Position = math.clamp(tonumber(Seconds) or 0, 0, DemoTracks[self.Index].Duration)
	Done(true)
end

function Demo:SetVolume(Percent, Done)
	self.Volume = math.clamp(tonumber(Percent) or 0, 0, 100)
	Done(true)
end

function Demo:Disconnect()
	self.Playing = false
end

Providers.NewDemo = Demo.new
Providers.Demo = Demo
Providers.DemoTracks = DemoTracks

return Providers
