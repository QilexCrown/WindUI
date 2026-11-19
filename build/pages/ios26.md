# iOS 26 inspired controls

The fork uses native Roblox surfaces to approximate Apple's material hierarchy:
a quiet translucent toolbar, compact status capsules, continuous window corners,
and inset content. It does not implement Apple's scene refraction shader.

```lua
local window = WindUI:CreateWindow({
    Title = "My window",
    IOS26 = true, -- default; false disables the material and responsive tag dock
    Radius = 26,
    ElementsRadius = 18,
    Topbar = {Height = 52, ButtonsType = "Mac"},
    ReducedMotion = false,
})
local version = window:Tag({Title = "v1.0", Style = "Glass", Priority = 100})
window:Tag({Title = "EN", Style = "Glass", Priority = 90})
window:Tag({Title = "GitHub", Icon = "github", Style = "Glass", Priority = 10})
version:SetTitle("v1.1")
```

Tags pack against the right edge with 6px gaps. Low priority tags compact to their
icon (or optional `CompactTitle`) before they disappear. Labels truncate within a
144px maximum; localized title changes remeasure automatically. `SetTitle`,
`SetIcon`, `SetColor` and `Destroy` remain available. Glass uses the active theme's
foreground; `Style = "Tinted"` uses `Color` including gradients.

Press feedback and page transitions use short, finite tweens. Rapid interaction
cancels the previous owned tween. The window's `ReducedMotion` option suppresses
page motion and press scaling. No persistent render connection, global Tween
replacement, screenshot capture or glass overlay on every content element is added.

`npm run build` overlays the tested components and asserted integration patches on
the pinned deployed runtime. It preserves the fork's existing icon, executor and
macOS window fixes. Run `luajit -joff tests/ToolbarLayout.lua`,
`luajit -joff tests/IOS26.lua` and `luajit -joff tests/InfoCard.lua` from the fork root.

Rollback: the `backup/pre-ios26-20261119` local branch retains the accepted v2.7.4
baseline. Revert the iOS 26 release commit to remove the full revision.
