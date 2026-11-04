-- MusicSurface - the provider plumbing both music elements share.
--
--   MusicSurface.Bind(self, Config)
--
-- Gives `self` the source list, the poll loop and the transport methods, and
-- calls `self:RenderState(State)` whenever a provider hands back a track.
-- `Config.Providers` is an array of entries: "files", "spotify", "demo",
-- "sound", or a bridge table. `Config.Folder` is the folder the files
-- provider reads.

local Providers = require("./MusicProviders")

local Surface = {}

-- Elements that ask for the same sources share one provider set, so the island
-- and the mini player drive the same Sound: play in one, pause in the other.
local Shared = {}

local function ShareKey(Config)
	if Config.Share ~= nil then
		return tostring(Config.Share)
	end
	local Parts = {}
	for _, Entry in ipairs(Config.Providers or {}) do
		Parts[#Parts + 1] = type(Entry) == "table" and tostring(Entry.Id or Entry.Name or Entry.Url) or tostring(Entry)
	end
	return "auto|" .. (Config.Folder or "Ender Hub/songs") .. "|" .. table.concat(Parts, ",")
end

local function CreateProvider(Entry, Config)
	if type(Entry) == "table" then
		return Providers.NewBridge(Entry)
	end
	if Entry == "files" then
		return Providers.NewFolder({ Path = Config.Folder or "Ender Hub/songs" })
	end
	if Entry == "spotify" then
		return Providers.NewSpotify(Config.Spotify or {})
	end
	if Entry == "demo" then
		return Providers.NewDemo()
	end
	if Entry == "sound" then
		return Providers.NewSound({ Sound = Config.Sound })
	end
	return nil
end

function Surface.Bind(Object, Config)
	local Key = ShareKey(Config)
	local Record = Shared[Key]

	if not Record then
		Record = { Sources = {}, Index = 1, Refs = 0, Connected = false, Objects = {} }
		local Entries = Config.Providers or { "files", "spotify", "demo" }
		if type(Entries) ~= "table" then
			Entries = { Entries }
		end
		for _, Entry in ipairs(Entries) do
			local Provider = CreateProvider(Entry, Config)
			if Provider then
				table.insert(Record.Sources, Provider)
			end
		end
		if #Record.Sources == 0 then
			table.insert(Record.Sources, Providers.NewDemo())
		end
		Shared[Key] = Record
	end

	Record.Refs += 1
	table.insert(Record.Objects, Object)

	Object.Share = Record
	Object.Sources = Record.Sources
	Object.SourceIndex = Record.Index
	Object.Provider = Record.Sources[Record.Index]
	Object.MusicState = nil

	local Provider = Object.Provider
	if Provider then
		if not Record.Connected then
			Record.Connected = true
			if Provider.Connect then
				Provider:Connect({}, function() end)
			end
		end
		if Object.RenderSources then
			Object:RenderSources()
		end
	end

	task.spawn(function()
		while Object.Alive do
			local Active = Object.Provider
			if Active and Active.Poll then
				local Ok = pcall(function()
					Active:Poll(function(Success, State)
						if not Object.Alive or Object.Provider ~= Active then
							return
						end
						if Success and type(State) == "table" then
							Object.MusicState = State
							if Object.RenderState then
								Object:RenderState(State)
							end
						elseif Object.RenderError then
							Object:RenderError(tostring(State or "Unavailable"))
						end
					end)
				end)
				if not Ok and Object.RenderError then
					Object:RenderError("Poll error")
				end
			end
			task.wait(Config.PollRate or 0.25)
		end
	end)
end

function Surface.SelectSource(Object, Index, Silent)
	local Provider = Object.Sources[Index]
	if not Provider then
		return
	end

	Object.SourceIndex = Index
	Object.Provider = Provider

	local Record = Object.Share
	if Record then
		Record.Index = Index
		for _, Other in ipairs(Record.Objects) do
			if Other ~= Object and Other.Alive then
				Other.SourceIndex = Index
				Other.Provider = Provider
				if Other.RenderSources then
					Other:RenderSources()
				end
			end
		end
	end

	if not Silent and Provider.Connect then
		Provider:Connect({}, function(Ok, Message)
			if not Object.Alive then
				return
			end
			if not Ok and Object.RenderError then
				Object:RenderError(tostring(Message or "Unavailable"))
			end
		end)
	end

	if Object.RenderSources then
		Object:RenderSources()
	end
end

function Surface.SetSource(Object, Source)
	if type(Source) == "number" then
		Surface.SelectSource(Object, Source)
		return
	end
	for Index, Provider in ipairs(Object.Sources) do
		if Provider.Id == Source or Provider.Name == Source then
			Surface.SelectSource(Object, Index)
			return
		end
	end
end

function Surface.Release(Object)
	local Record = Object.Share
	if Record then
		Record.Refs = math.max(0, Record.Refs - 1)
		for Index, Other in ipairs(Record.Objects) do
			if Other == Object then
				table.remove(Record.Objects, Index)
				break
			end
		end
		Object.Share = nil
		if Record.Refs > 0 then
			return
		end
		for Key, Entry in pairs(Shared) do
			if Entry == Record then
				Shared[Key] = nil
			end
		end
	end

	for _, Provider in ipairs(Object.Sources or {}) do
		pcall(function()
			Provider:Disconnect()
		end)
	end
end

Surface.FormatTime = Providers.FormatTime

return Surface
