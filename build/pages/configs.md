WindUI saves element state to disk and loads it back, so a hub reopens where the user left it. The config manager hangs off the window.

## Create a config

```lua
local Config = Window.ConfigManager:CreateConfig("main", true) -- name, autoload
Config:SetAsCurrent()
```

`SetAsCurrent` is what makes `Flag` registration automatic: every element created afterwards with a `Flag` is registered to this config.

## Register elements

```lua
Tab:Toggle({
    Title = "Enabled",
    Flag = "enabled",
    Value = false,
})

Tab:Slider({
    Title = "Volume",
    Flag = "volume",
    Value = { Min = 0, Max = 100, Default = 50 },
})
```

Without a current config, flagged elements are parked in `Window.PendingFlags` and registered on the next `Config:Save()`.

## Save, load, delete

```lua
Config:Save()
Config:Load()
Config:Delete()

Config:SetAutoLoad(true)   -- load automatically next launch
Config:Set("theme", "Dark") -- arbitrary custom value
Config:Get("theme")
Config:GetData()            -- raw table
```

## Manager methods

| Method | Notes |
| --- | --- |
| `CreateConfig(name, autoload)` | Returns a `ConfigModule` |
| `Config(name, autoload)` | Alias for `CreateConfig` |
| `GetConfig(name)` | Fetch an existing config module |
| `DeleteConfig(name)` | Remove a saved file |
| `AllConfigs()` | Table of saved configs |
| `GetAutoLoadConfigs()` | Configs with autoload set |
| `SetPath(path)` | Override the folder |

## Supported elements

| Element | Saved data |
| --- | --- |
| `Toggle` | boolean |
| `Slider` | number |
| `Input` | string |
| `Dropdown` | value or array |
| `Keybind` | key name |
| `Colorpicker` | hex + alpha |
| `ProgressBar` | value |

## Notes

- Files live under `WindUI/<Folder>/<name>.json`; `Folder` comes from the window.
- Loading applies saved values through the element's own update path, so callbacks are not re-fired.
- A flag that no longer exists is skipped, not an error.
- `SetAutoLoad(true)` combined with `CreateConfig(name, true)` is the usual one-liner for a persistent hub.
