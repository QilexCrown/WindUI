A code block with a copy button. Useful for showing the exact loadstring or a snippet.

## Basic

```lua
Tab:Code({
    Title = "Example",
    Code = "print('Hello World')",
})
```

## Full

```lua
Tab:Code({
    Title = "Loadstring",
    Code = [[loadstring(game:HttpGet("https://raw.githubusercontent.com/QilexCrown/WindUI/main/dist/main.lua"))()]],
    CodeSize = 14,
    CanCopied = true,
    Height = UDim.new(0, 120),
    OnCopy = function()
        print("copied")
    end,
})
```

## Parameters

| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `Title` | `string?` | — | |
| `Code` | `string` | — | The text shown |
| `CodeSize` | `number` | `18` | Font size |
| `CodeTheme` | `table?` | — | Custom highlight table |
| `CanCopied` | `boolean?` | `true` | Show the copy button |
| `Height` | `UDim?` | auto | Fixed height, scrolls |
| `OnCopy` | `function?` | — | Fires after a successful copy |

## Methods

| Method | Notes |
| --- | --- |
| `Code:SetCode(text)` | Replace the content |
| `Code:GetCode()` | Current text |
| `Code:Destroy()` | |

## Notes

- Copy uses `setclipboard`; executors without it simply skip the button action.
- Long lines scroll horizontally instead of wrapping, so indentation stays intact.
