A hairline separator between elements.

## Usage

```lua
Tab:Button({ Title = "Option 1" })
Tab:Button({ Title = "Option 2" })

Tab:Divider()

Tab:Button({ Title = "Option 3" })
```

## Parameters

`Divider()` takes no arguments.

## Notes

- The line uses the theme's `Outline` colour at low opacity, so it works on every theme.
- Dividers are elements: they participate in search highlighting like anything else.
- To group a whole block with a heading, use [`Tab:Section`](./section.html) instead.
