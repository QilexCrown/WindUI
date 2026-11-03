This repository is a fork of [Footagesus/WindUI](https://github.com/Footagesus/WindUI), maintained by QilexCrown. Upstream stays the source of truth for the library; the fork adds one opt-in system and keeps everything else behaviourally identical.

## What changed

| Area | Fork change | Default effect |
| --- | --- | --- |
| Key screen | `KeySystemModern.lua` + a 3-line dispatch in `KeySystem.lua` | None — stock dialog unless `KeySystem.Layout` is a table |
| Key screen look | theme-driven colours, no watermark, no premium tag | Only inside the modern screen |
| Splash | optional icon + title intro (`Layout.Splash`) | Off by default, card opens at once |
| Error animation | shake + red ring flash | Only inside the modern screen |
| Docs | this site | — |
| Everything else | untouched | Identical to upstream |

## Revert

Two levels, both clean:

1. **Per script** — stop passing `KeySystem.Layout`. The stock dialog renders, unchanged.
2. **Per repository** — delete the dispatch at the top of `src/components/KeySystem.lua`:

```lua
function KeySystem.new(Config, Filename, func, keyValidator)
    if type(Config.KeySystem.Layout) == "table" then
        return require("./KeySystemModern").new(Config, Filename, func, keyValidator)
    end
    -- stock path follows, untouched
```

Then delete `src/components/KeySystemModern.lua`. Nothing else references it.

## Source map

| Path | Purpose |
| --- | --- |
| `src/components/KeySystemModern.lua` | The whole modern key screen |
| `src/components/KeySystem.lua` | Dispatch + stock key dialog |
| `src/ui/Tag.lua` | Tag renderer reused by `Header.Tag` |
| `src/modules/Creator.lua` | `New`, `Tween`, theme colours, icon lookup |
| `build/docs.js` | This site's generator |
| `dist/main.lua` | The built bundle loadstring serves |

## Building the bundle

The repository ships prebuilt output. If you edit `src/`, rebuild:

```
node build/bundle.js . src/Init.lua dist/main.lua
```

Then push `dist/main.lua` — every script loading the raw URL picks it up on the next run.

## Contributing

- Keep the key screen opt-in. A change that alters behaviour without `Layout` set is a regression.
- Colours go through `ThemeTag`; raw `Color3` is an override, never a default.
- Match the surrounding style: tabs, `New`/`Tween` helpers, no globals.
- Upstream bug fixes belong upstream first.

## Links

| Resource | URL |
| --- | --- |
| Fork | `https://github.com/QilexCrown/WindUI` |
| Bundle | `https://raw.githubusercontent.com/QilexCrown/WindUI/main/dist/main.lua` |
| Upstream | `https://github.com/Footagesus/WindUI` |
| Upstream docs | `https://footagesus.github.io/treehub-web/docs/windui` |
