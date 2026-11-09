`Group` is kept for compatibility with older WindUI layouts. New code should use [`HStack` and `VStack`](./hstack-vstack.html) instead.

## Usage

```lua
local Group = Tab:Group()

Group:Button({ Title = "A" })
Group:Button({ Title = "B" })
```

## Notes

- `Group` does not lay elements out automatically — it is a plain container. Spacing and alignment are what `HStack` / `VStack` add.
- Existing scripts keep working; nothing about `Group` is scheduled to break.
- For a labelled block, use [`Tab:Section`](./section.html).
