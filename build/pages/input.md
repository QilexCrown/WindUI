An input collects text. Single line by default; `Type = "Textarea"` gives a multiline box.

## Basic

```lua
local Input = Tab:Input({
    Title = "Username",
    Callback = function(text)
        print("input:", text)
    end,
})
```

## Full

```lua
local Input = Tab:Input({
    Title = "Webhook",
    Desc = "Paste the full URL",
    Placeholder = "https://discord.com/api/webhooks/...",
    Value = "",
    Type = "Input",              -- "Input" | "Textarea"
    ClearTextOnFocus = false,
    InputIcon = "link",
    Locked = false,
    Callback = function(text)
        print("webhook:", text)
    end,
})
```

## Parameters

| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `Title` | `string` | `"Input"` | |
| `Desc` | `string?` | — | |
| `Placeholder` | `string?` | — | |
| `Value` | `string?` | `""` | Initial text |
| `Type` | `string?` | `"Input"` | `"Input"` or `"Textarea"` |
| `ClearTextOnFocus` | `boolean?` | `false` | Select-all on focus |
| `InputIcon` | `string?` | — | Leading icon |
| `Locked` | `boolean?` | `false` | |
| `Callback` | `function` | — | Fires on text change |

## Methods

| Method | Notes |
| --- | --- |
| `Input:SetValue(text)` | Sets without firing the callback |
| `Input:GetValue()` | Current text |
| `Input:SetTitle(text)` / `Input:SetDesc(text)` | |
| `Input:Destroy()` | |

## Notes

- `Callback` fires on every keystroke, not on submit. Debounce it yourself if you hit an API.
- Textarea grows with the content and keeps the newline characters.
