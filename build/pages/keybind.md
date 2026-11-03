A keybind captures one keyboard key and fires when it is pressed.

## Basic

```lua
local Keybind = Tab:Keybind({
    Title = "Toggle UI",
    Value = "V",
    Callback = function(key)
        print("pressed:", key)
    end,
})
```

## Full

```lua
local Keybind = Tab:Keybind({
    Title = "Panic",
    Desc = "Hides everything",
    Value = "RightShift",
    CanChange = true,
    Blacklist = { "Escape", "F1" },
    Locked = false,
    Callback = function(key)
        print("panic:", key)
    end,
})
```

## Parameters

| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `Title` | `string` | `"Keybind"` | |
| `Desc` | `string?` | — | |
| `Value` | `string` | `"V"` | Default key name |
| `CanChange` | `boolean?` | `true` | Allow rebinding |
| `Blacklist` | `table?` | — | Keys that cannot be bound |
| `Locked` | `boolean?` | `false` | |
| `Callback` | `function` | — | Receives the key name |

## Methods

| Method | Notes |
| --- | --- |
| `Keybind:SetValue(key)` | |
| `Keybind:GetValue()` | Current key |
| `Keybind:Destroy()` | |

## Notes

- Key names follow `Enum.KeyCode` names without the prefix: `"V"`, `"RightShift"`, `"F1"`.
- The element shows a "press a key" state while listening; pressing `Escape` cancels the rebind.
