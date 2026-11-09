Load the bundle once at the top of your script and keep the returned table.

## Fork bundle

```lua
local WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/QilexCrown/WindUI/main/dist/main.lua"))()
```

This is the built `dist/main.lua` from `QilexCrown/WindUI`. It is the same file the repository ships, so a push to `main` updates every script that loads it.

## Pinned version

Pin a commit when you do not want the bundle to move under you:

```lua
local _commit = "b9655db"
local WindUI = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/QilexCrown/WindUI/" .. _commit .. "/dist/main.lua"
))()
```

## Upstream bundle

If you do not need the fork's key screen:

```lua
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
```

## Load order

1. Load the bundle.
2. `WindUI:SetTheme("Dark")` if you do not want the default.
3. `WindUI:CreateWindow{...}`.
4. Build tabs and elements inside `task.spawn` or directly — both work.

> Loading the bundle twice in the same executor session creates two independent copies of the library and two `ScreenGui` trees. Load it once.

## Checking the version

```lua
print(WindUI.Version) -- e.g. "1.6.66"
```
