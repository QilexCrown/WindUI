# Focused glass controls and sidebar

Goal: rebuild Main as design-only native cards, match the supplied World segmented control, restyle Info actions, and refine the collapsed rail.

Use existing checkouts and publishing authorization. Preserve startup consent and functional withdrawal in Settings while collection remains enabled; remove the Main consent card. Keep Main feature callbacks unconnected. No privacy bypasses or new collection.

Design: one reusable GlassButton component for Main actions/segments and Info actions. Native squircle fill, restrained glass bezel, theme-aware labels, finite hover/press motion. A scoped motion helper owns cancellation and teardown. Rail fades/slides on collapse, uses original tab icons, includes sparse-index tabs, and uses the eye icon for the existing ESP/visual tab. No continuous render loops. Do not change Visuals' controls.

- [x] Implement and test owned motion and glass button lifecycle.
- [x] Use shared controls in Main and Info; retain UI handles and clean card layout.
- [x] Refine rail lifecycle, icon completeness, selection and collapse transitions.
- [x] Move withdrawal to Settings, verify consent invariants, review, compile and prepare matching source/fork/protected artifacts as QilexCrown.

Baseline: fork42ec727, source627d8f1, loader698835b. Previous broad liquid-glass designs were rejected; this revision is limited to requested controls.

Verification: fork InfoCard and GlassControls suites pass, including cancellation, parent destruction, sparse eye-icon entries, rapid collapse generation guards and centered feedback icon. Source UI-only and privacy/withdrawal harnesses pass. Fresh review found the feedback offset regression; it was fixed with a failing-then-passing check. Native Roblox UI-only construction and two-width geometry probe returned 14 action measurements, 0 reported overflow, Info glass present, and successful rail collapse/expand. This was not a screenshot review. Full hub rendering remains subject to the player consent choice.
