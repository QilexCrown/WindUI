-- Miniplayer example. Floating island plus the same element docked in a tab.
--
--   loadstring(game:HttpGet("http://127.0.0.1:8642/examples/miniplayer.lua"))()

local WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/QilexCrown/WindUI/main/dist/main.lua"))()

local Window = WindUI:CreateWindow({
	Title = "Miniplayer",
	Subtitle = "dynamic island demo",
	Icon = "sf:musicNote",
	Size = UDim2.fromOffset(680, 460),
})

local Home = Window:Tab({ Title = "Home", Icon = "sf:house" })

Home:Section({ Title = "Floating" })

Home:Button({
	Title = "Spawn the island",
	Icon = "sf:playFill",
	Callback = function()
		if Window.Music then
			Window.Music:Destroy()
		end

		Window.Music = WindUI:Miniplayer({
			Providers = { "files", "spotify", "demo" },
			Folder = "Ender Hub/songs",
			Top = 14,
			OnLike = function(Liked, State)
				WindUI:Notify({
					Title = Liked and "Liked" or "Unliked",
					Content = State and State.Title or "Nothing playing",
					Icon = Liked and "sf:heartFill" or "sf:heart",
					Duration = 2,
				})
			end,
		})
	end,
})

Home:Button({
	Title = "Open the card",
	Icon = "sf:arrowUpRightSquare",
	Callback = function()
		if Window.Music then
			Window.Music:Expand()
		end
	end,
})

Home:Button({
	Title = "Switch to the demo track",
	Icon = "sf:waveform",
	Callback = function()
		if Window.Music then
			Window.Music:SetSource("demo")
			Window.Music:Play()
		end
	end,
})

Home:Section({ Title = "Inside the window" })

local Player = WindUI:Miniplayer({
	Parent = Home.UIElements.ContainerFrame,
	Providers = { "files", "demo" },
	Folder = "Ender Hub/songs",
	Expanded = true,
})

Home:Button({
	Title = "Play",
	Icon = "sf:playFill",
	Callback = function()
		Player:Play()
	end,
})

Home:Button({
	Title = "Next",
	Icon = "sf:forwardFill",
	Callback = function()
		Player:Next()
	end,
})

Window:SelectTab(1)

return {
	Window = Window,
	Player = Player,
}
