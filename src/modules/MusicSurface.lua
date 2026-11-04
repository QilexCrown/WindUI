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
	Object.Sources = {}
	Object.SourceIndex = 0
	Object.Provider = nil
	Object.MusicState = nil

	local Entries = Config.Providers or { "files", "spotify", "demo" }
	if type(Entries) ~= "table" then
		Entries = { Entries }
	end

	for _, Entry in ipairs(Entries) do
		local Provider = CreateProvider(Entry, Config)
		if Provider then
			table.insert(Object.Sources, Provider)
		end
	end

	if #Object.Sources == 0 then
		table.insert(Object.Sources, Providers.NewDemo())
	end

	Object:SelectSource(1)

	task.spawn(function()
		while Object.Alive do
			local Provider = Object.Provider
			if Provider and Provider.Poll then
				local Ok = pcall(function()
					Provider:Poll(function(Success, State)
						if not Object.Alive or Object.Provider ~= Provider then
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

	if Object.Provider and Object.Provider ~= Provider then
		pcall(function()
			Object.Provider:Disconnect()
		end)
	end

	Object.SourceIndex = Index
	Object.Provider = Provider

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
	for _, Provider in ipairs(Object.Sources or {}) do
		pcall(function()
			Provider:Disconnect()
		end)
	end
end

Surface.FormatTime = Providers.FormatTime

return Surface
