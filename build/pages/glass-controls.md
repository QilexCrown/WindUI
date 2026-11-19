# Glass controls

The fork uses native squircle and glass-bezel UI surfaces to approximate the supplied World-tab reference. It does not perform scene refraction. Glass is limited to the requested actions/segments and selected navigation.

WindUI:GlassButton(config) returns Button, Label, Fill, Bezel, SetSelected(value), and Destroy(). Use Title, Icon, Parent, Size, Radius, TextSize, Callback and Mode = "Segment" as needed. Main preserves native GuiButton handles in HX.MainUI for later wiring.

ControlMotion owns each tween slot, cancels superseded work and disconnects completed callbacks. ReducedMotion skips animated interpolation. No render loop or global Creator.Tween replacement is added.

The collapsed rail supports sparse indices, respects locked tabs, removes destroyed rows and uses the source tab icon. It fades/slides with a generation guard so a stale close cannot hide a reopened rail. Its hover, selection and press motion ends without an idle task.

Tests: luajit -joff tests/GlassControls.lua and luajit -joff tests/InfoCard.lua. Build with npm run build.
