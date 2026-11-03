A spacer. `Columns` controls how many element columns it occupies.

## Usage

```lua
Tab:Button({ Title = "Button 1" })
Tab:Space()
Tab:Button({ Title = "Button 2" })
```

## Parameters

| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `Columns` | `number?` | `1` | How many columns the gap spans |

## Multi-column

```lua
Tab:Space({ Columns = 3 })
```

## Notes

- In a single-column tab, `Columns = 1` is a blank row the height of one element gap.
- With `NewElements = true`, elements can sit side by side: `Space` is how you push them apart.
- `Space` is invisible — it never draws a background or border.
