# WindUI glass and motion

User direction: Apple-like liquid glass, smooth animations, optimized elements,
and a reversible change. Existing layouts and public control APIs remain intact.

Use the existing image-based squircles rather than camera blur or per-element
render loops. Add restrained glass highlights to visible semantic surfaces.
Route existing Creator.Tween calls through one motion controller that cancels
conflicting transitions only when the replacement plays. Preserve independent
property animations, Completed events, pause/cancel, and explicit TweenInfo options.
Reduced motion uses immediate transitions. Destroyed controls release active
animations and listeners. No service runs while the UI is idle.

Alternative: replace every element independently. Rejected: inconsistent visual
behavior and much larger regression surface. Full-screen blur/refraction rejected:
cost depends heavily on GPU and conflicts with the requested low overhead.

Baseline: WindUI 37cba3a, source 67641fc, loader c767ed1. WindUI backup branch:
backup/pre-liquid-glass-20261119. Undo uses git revert of this feature's commits,
never a hard reset that could discard later work. A zero-lag guarantee is not a
testable promise; test event/tween cleanup and report live performance limits.
