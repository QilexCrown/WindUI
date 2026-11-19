// Build the InfoCard release on the pinned, deployed Ender Hub runtime.
// The base retains existing chrome, icons and executor fixes. New components
// come directly from src; no game-specific hub code is bundled here.
const fs = require('node:fs');
const path = require('node:path');
const fork = path.resolve(__dirname, '..');
const file = path.join(fork, 'build/enderhub-base.lua');
let bundle = fs.readFileSync(file, 'utf8').replace(/\r\n/g, '\n');
const moduleIds = ['src/components/InfoCardLayout.lua', 'src/components/InfoCard.lua'];
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
bundle = bundle.replace(/-- enderhub-windui-[^\n]+\nreturn __require\("src\/Init.lua"\)/,
    '-- enderhub-windui-mac-chrome43-info\nreturn __require("src/Init.lua")');
const count = [...bundle.matchAll(/^__modules\[/gm)].length;
bundle = bundle.replace(/\(modules: \d+\)/, `(modules: ${count})`);
fs.writeFileSync(path.join(fork, 'dist/main.lua'), bundle);
console.log(`Updated tested WindUI bundle: ${count} modules, ${Buffer.byteLength(bundle)} bytes`);
