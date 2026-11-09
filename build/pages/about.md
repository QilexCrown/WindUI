WindUI is an interface library for Roblox scripts: one `loadstring`, then windows, tabs, and a full set of elements. It is a fork of [Footagesus/WindUI](https://github.com/Footagesus/WindUI) maintained by [QilexCrown](https://github.com/QilexCrown).

The fork keeps the upstream API intact and adds one opt-in system: a configurable key screen that opens instantly, with theme-driven colours, movable blocks and a wrong-key animation.

## What is in the fork

- **Modern key screen** — one `KeySystem.Layout` table drives every block. No table, no change: the stock key dialog stays exactly as it was.
- **Instant open** — the card is the first thing you see; the optional icon/title intro is opt-in through `Layout.Splash`.
- **Error animation** — decaying shake plus a red ring flash on a rejected key.
- **Theme-first colours** — every accent resolves through the active theme, so the default is grey-on-dark rather than blue.
- **Movable everything** — header, note, input, footer, thumbnail and buttons are each configurable, and each block can be nudged with `Offset`.

## Design rules

1. **Opt-in.** Nothing in the fork changes behaviour unless the matching config exists.
2. **Reversible.** Removing `KeySystem.Layout` (or the three-line dispatch at the top of `src/components/KeySystem.lua`) restores stock WindUI.
3. **Theme-driven.** Colours go through `ThemeTag`; raw `Color3` is an override, not the default.
4. **One window per bundle.** Create one `CreateWindow` per loaded instance; reload the bundle for a second window.

## Layout of the docs

- **Getting Started** — install, themes, first window.
- **UI** — window, key system, tabs, dialogs, popups, notifications, tags.
- **Elements** — every element with its parameters.
- **Advanced** — configs, icons and the fork's source map.

## Requirements

- Roblox client with `loadstring` / `game:HttpGet` (any executor).
- Nothing else. No dependencies, no build step on your side.

## Links

| Resource | URL |
| --- | --- |
| Fork repository | `https://github.com/QilexCrown/WindUI` |
| Built bundle | `https://raw.githubusercontent.com/QilexCrown/WindUI/main/dist/main.lua` |
| Upstream repository | `https://github.com/Footagesus/WindUI` |
| Upstream docs | `https://footagesus.github.io/treehub-web/docs/windui` |
