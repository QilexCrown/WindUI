// Small asserted edits to deployed modules preserve the fork's executor/chrome fixes.
module.exports = function applyIOS26(bundle) {
    function modulePatch(id, transform) {
        const marker = `__modules[${JSON.stringify(id)}] = function(require)\n`;
        const start = bundle.indexOf(marker);
        if (start < 0) throw Error(`Missing pinned module ${id}`);
        const end = bundle.indexOf('\n__modules[', start + marker.length);
        if (end < 0) throw Error(`Missing module boundary ${id}`);
        const source = bundle.slice(start, end);
        bundle = bundle.slice(0, start) + transform(source) + bundle.slice(end);
    }
    function once(source, from, to) {
        if (source.split(from).length !== 2) throw Error(`Ambiguous iOS 26 integration: ${from.slice(0, 65)}`);
        return source.replace(from, to);
    }
    modulePatch('src/components/window/Init.lua', source => {
        source = once(source, '\t\tTitle = Config.Title or "UI Library",', '\t\tIOS26 = Config.IOS26 ~= false,\n\t\tReducedMotion = Config.ReducedMotion == true,\n\t\tTitle = Config.Title or "UI Library",');
        source = once(source, 'Config.Radius or 16,', 'Config.Radius or (Config.IOS26 ~= false and 26 or 16),');
        source = once(source, 'Window.ElementsRadius or (Window.NewElements and 23 or 16)', 'Window.ElementsRadius or (Window.IOS26 and 18 or (Window.NewElements and 23 or 16))');
        source = once(source, '\t\treturn Tag:New(TagConfig, Window.UIElements.Main.Main.Topbar.Center.Holder)',
            '\t\tlocal tag = Tag:New(TagConfig, Window.UIElements.Main.Main.Topbar.Center.Holder)\n\t\tif Window.TagDock then Window.TagDock:Add(tag) end\n\t\treturn tag');
        source = once(source, '\treturn Window\nend', '\trequire("src/components/IOS26.lua").Attach(Window, Config)\n\treturn Window\nend');
        const down = '\t\tCreator.AddSignal(Button.MouseButton1Down, function()\n\t\t\tTween(Button.UIScale, 0.2, { Scale = 0.9 }, Enum.EasingStyle.Quint, Enum.EasingDirection.Out):Play()\n\t\tend)';
        const up = '\t\tCreator.AddSignal(Button.InputEnded, function()\n\t\t\tTween(Button.UIScale, 0.2, { Scale = 1 }, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut):Play()\n\t\tend)';
        if (source.split(down).length !== 3 || source.split(up).length !== 3) throw Error('Toolbar press owners changed');
        source = source.split(down).join('\t\trequire("src/components/PressMotion.lua").Bind(Button, Window.ReducedMotion, Button.UIScale)');
        source = source.split(up).join('');
        return source;
    });
    modulePatch('src/components/ui/Button.lua', source => once(source, '\treturn ButtonFrame\nend',
        '\trequire("src/components/PressMotion.lua").Bind(ButtonFrame)\n\treturn ButtonFrame\nend'));
    modulePatch('src/components/window/Tab.lua', source => {
        const start = source.indexOf('\t\ttask.spawn(function()\n\t\t\tfor _, ContainerObject');
        const end = source.indexOf('\n\t\tTabModule.OnChangeFunc(TabIndex)', start);
        if (start < 0 || end < 0) throw Error('Missing tab transition integration');
        return source.slice(0, start) + '\t\trequire("src/components/TabMotion.lua").Select(TabModule.Containers, TabIndex, Window.ReducedMotion)\n' + source.slice(end);
    });
    return bundle;
};
