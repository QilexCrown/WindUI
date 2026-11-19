// Build the InfoCard release on the pinned, deployed Ender Hub runtime.
// The base retains existing chrome, icons and executor fixes. New components
// come directly from src; no game-specific hub code is bundled here.
const fs = require('node:fs');
const path = require('node:path');
const fork = path.resolve(__dirname, '..');
const file = path.join(fork, 'build/enderhub-base.lua');
let bundle = fs.readFileSync(file, 'utf8').replace(/\r\n/g, '\n');
const moduleIds = ['src/modules/Motion.lua', 'src/modules/Glass.lua', 'src/components/InfoCardLayout.lua', 'src/components/InfoCard.lua'];
for (const id of moduleIds) {
    const source = fs.readFileSync(path.join(fork, id), 'utf8').replace(/\r\n/g, '\n');
    const chunk = `__modules[${JSON.stringify(id)}] = function(require)\n` + source.replace(
        /require\("([^"\n]+)"\)/g,
        (_, spec) => `require(${JSON.stringify(path.posix.normalize(path.posix.join(path.posix.dirname(id), spec)) + '.lua')})`,
    ) + '\nend\n';
    const startMarker = `__modules[${JSON.stringify(id)}] = function(require)\n`;
    const start = bundle.indexOf(startMarker);
    if (start >= 0) {
        const next = bundle.indexOf('\n__modules[', start + startMarker.length);
        const tail = bundle.lastIndexOf('\n-- enderhub-windui-');
        const end = next < 0 ? tail : Math.min(next, tail);
        if (end <= start) throw Error(`Cannot locate module boundary: ${id}`);
        bundle = bundle.slice(0, start) + chunk + bundle.slice(end);
    } else {
        const tail = bundle.lastIndexOf('\n-- enderhub-windui-');
        if (tail < 0) throw Error('Missing bundle marker');
        bundle = bundle.slice(0, tail) + '\n' + chunk + bundle.slice(tail);
    }
}
if (!bundle.includes('function WindUI:InfoCard(Config)')) {
    const marker = 'function WindUI:PlayerTags(Config)';
    if (bundle.split(marker).length !== 2) throw Error('Ambiguous Init module');
    bundle = bundle.replace(marker, 'function WindUI:InfoCard(Config)\n\treturn require("src/components/InfoCard.lua").New(Config)\nend\n\n' + marker);
}
if (!bundle.includes('function WindUI:InfoCredits(Config)')) {
    const marker = 'function WindUI:InfoCard(Config)';
    bundle = bundle.replace(marker, 'function WindUI:InfoCredits(Config)\n\treturn require("src/components/InfoCard.lua").Credits(Config)\nend\n\nfunction WindUI:InfoFeedback(Config)\n\treturn require("src/components/InfoCard.lua").Feedback(Config)\nend\n\n' + marker);
}
const oldTween = 'function Creator.Tween(Object, Time, Properties, ...)\n\treturn TweenService:Create(Object, TweenInfo.new(Time, ...), Properties)\nend';
if (bundle.split(oldTween).length !== 2) throw Error('Pinned tween entry changed');
bundle = bundle.replace(oldTween, `local MotionController = require("src/modules/Motion.lua").New(TweenService, function(duration, style, direction, ...) return TweenInfo.new(duration, style or Enum.EasingStyle.Quint, direction or Enum.EasingDirection.Out, ...) end)
local GlassMaterial = require("src/modules/Glass.lua")
function Creator.SetEffects(options)
    options = options or {}
    if options.ReducedMotion ~= nil then MotionController.ReducedMotion = options.ReducedMotion == true end
    if options.Animations ~= nil then MotionController.Enabled = options.Animations ~= false end
    if options.Glass ~= nil then GlassMaterial.SetEnabled(options.Glass) end
end
function Creator.GetActiveAnimations() return MotionController:GetActiveCount() end
function Creator.Tween(Object, Time, Properties, ...)
    return MotionController:Create(Object, Time, Properties, ...)
end`);
const oldShape = 'return DynamicShapeModule:New(Radius, Type, Properties, Children, IsButton, nil)';
if (bundle.split(oldShape).length !== 2) throw Error('Pinned surface entry changed');
bundle = bundle.replace(oldShape, 'local frame, wrapper = DynamicShapeModule:New(Radius, Type, Properties, Children, IsButton, nil)\n\tGlassMaterial.Apply(Creator, frame, Radius, Type, Properties)\n\treturn frame, wrapper');
bundle = bundle.replace('function WindUI:InfoCard(Config)', 'function WindUI:SetEffects(Options)\n\tCreator.SetEffects(Options)\nend\n\nfunction WindUI:InfoCard(Config)');
bundle = bundle.replace(/-- enderhub-windui-[^\n]+\nreturn __require\("src\/Init.lua"\)/,
    '-- enderhub-windui-mac-chrome44-glass\nreturn __require("src/Init.lua")');
const count = [...bundle.matchAll(/^__modules\[/gm)].length;
bundle = bundle.replace(/\(modules: \d+\)/, `(modules: ${count})`);
fs.writeFileSync(path.join(fork, 'dist/main.lua'), bundle);
console.log(`Updated tested WindUI bundle: ${count} modules, ${Buffer.byteLength(bundle)} bytes`);
