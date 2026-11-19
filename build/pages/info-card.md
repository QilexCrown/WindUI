# Ender Hub Info components

The fork exposes three components using the same `Creator.NewRoundFrame`,
theme keys, font and element radius as the rest of the window. They do not fetch
profile data, send feedback, or start a telemetry loop. The calling application
supplies values and callbacks.

```lua
local card = WindUI:InfoCard({
    Parent = tab.UIElements.ContainerFrame,
    Window = Window,
    Avatar = "rbxthumb://type=AvatarHeadShot&id=1&w=150&h=150",
    Welcome = "Welcome,",
    DisplayName = "Player",
    Username = "@Player",
})
card:SetStats({ping = "42 ms", fps = "60", players = "8/12", session = "4:32", server = "Public", region = "Europe"})
card:SetActions({{Title = "Rejoin", Icon = "rotate-cw", Callback = onRejoin}})

local credits = WindUI:InfoCredits({
    Parent = tab.UIElements.ContainerFrame, Window = Window, Title = "Credits",
    Rows = {{Role = "Owner", Handle = "@Owner", Icon = "crown"}},
})
local feedback = WindUI:InfoFeedback({Parent = tab.UIElements.ContainerFrameCanvas, Window = Window})
feedback.Visible = true
feedback.Activated:Connect(openFeedback)
```

`Values`, `Labels`, `Chips`, `Welcome`, `Display`, `User` and action `Label`
references remain available for localization. Long names truncate in their own
column. Four inline metrics become two columns only below 280 pixels. Credits
keep roles and handles in separate columns. The feedback button anchors to the
bottom-right of its parent and uses the same secondary button surface.

`card:Destroy()` and `credits:Destroy()` release their UI; destroying the parent
also disconnects action and resize listeners. Destroy `feedback` as an Instance.

Run `lua tests/InfoCard.lua` and `npm run build`. The release builder combines
the pinned deployed library in `build/enderhub-base.lua` with these source
components. This retains deployed chrome and icon fixes that predate the older
upstream source tree. `npm run build:upstream` remains available separately;
CI verifies the committed release is reproducible instead of pushing bot commits.
