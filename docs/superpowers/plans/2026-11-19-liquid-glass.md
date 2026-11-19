# Liquid Glass Implementation Plan

**Goal:** Improve the shared visual and motion foundation without changing controls.
**Architecture:** One event-driven motion owner per animated property; static
glass overlays use existing squircle textures. Patch the pinned runtime at its
shared Creator entry points so deployed and editable code receive the changes.
**Tech Stack:** Lua 5.1-compatible modules, Luau, Node release builder.
**Spec:** ../specs/2026-11-19-liquid-glass-design.md

- [x] Write failing motion ownership, cancellation and cleanup tests.
- [x] Implement the shared controller and reduced-motion setting.
- [x] Add bounded glass materials and integrate shared Creator entry points.
- [x] Verify Info controls, animation stress, release reproducibility and Luau compilation.
- [x] Review compatibility and preserve the baseline for an explicit undo.

Verification: three native Lua suites pass; 1000 motion completions drain ownership;
release reproduces byte-for-byte and compiles at Luau -O0. Fresh review identified
reentrant callback races, reduced-motion delay handling and disabled-surface
registration; fixes and regression checks passed. No live FPS guarantee claimed.
