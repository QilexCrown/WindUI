// Bundles src/Init.lua and every module it requires into one flat chunk.
// The output shape is the one the hub loads: a module table, a cache, and a
// require that walks the table. Package metadata is embedded as a Lua string
// so src/Init.lua can JSONDecode it without a filesystem.
const fs = require("fs");
const path = require("path");

const root = path.resolve(__dirname, "..");
const entry = path.join(root, "src", "Init.lua");
const outFile = path.join(root, "dist", "main.lua");

const pkg = JSON.parse(fs.readFileSync(path.join(root, "package.json"), "utf8"));

const modules = new Map(); // repo-relative path -> source
const order = [];

function normalize(fromFile, spec) {
  // Lua require paths are relative to the requiring file, with or without .lua.
  // A path that lands on a folder means that folder's Init.lua.
  const base = path.dirname(fromFile);
  let target = path.resolve(base, spec);
  if (target.endsWith(".lua")) {
    return path.relative(root, target).split(path.sep).join("/");
  }
  if (fs.existsSync(target) && fs.statSync(target).isDirectory()) {
    target = path.join(target, "Init.lua");
    return path.relative(root, target).split(path.sep).join("/");
  }
  target += ".lua";
  return path.relative(root, target).split(path.sep).join("/");
}

const requirePattern = /require\(\s*["']([^"']+)["']\s*\)/g;

// Rewrite every relative require to the module id the bundle table uses, so a
// module body's bare `require("./modules/Creator")` resolves through __require.
function rewriteRequires(source, file) {
  return source.replace(requirePattern, (whole, spec) => {
    if (!spec.startsWith(".")) return whole;
    const id = normalize(file, spec);
    return `require("${id}")`;
  });
}

// Requires inside comments are not real edges (several modules keep an old
// require commented out). Strip comments and blank the strings before scanning;
// the module source itself is still inlined verbatim.
function stripComments(source) {
  let out = "";
  let i = 0;
  const n = source.length;
  while (i < n) {
    const c = source[i];
    const next = source[i + 1];
    if (c === "-" && next === "-") {
      const isLong = source[i + 2] === "[";
      if (isLong) {
        let level = 0;
        let j = i + 2;
        while (source[j] === "=") {
          level += 1;
          j += 1;
        }
        if (source[j] === "[") {
          const close = "]" + "=".repeat(level) + "]";
          const end = source.indexOf(close, j + 1);
          i = end === -1 ? n : end + close.length;
          continue;
        }
      }
      const end = source.indexOf("\n", i);
      i = end === -1 ? n : end;
      continue;
    }
    if (c === '"' || c === "'") {
      out += c;
      i += 1;
      while (i < n) {
        if (source[i] === "\\") {
          out += source[i] + (source[i + 1] || "");
          i += 2;
          continue;
        }
        out += source[i];
        if (source[i] === c) {
          i += 1;
          break;
        }
        i += 1;
      }
      continue;
    }
    out += c;
    i += 1;
  }
  return out;
}

function collect(file) {
  const rel = path.relative(root, file).split(path.sep).join("/");
  if (modules.has(rel)) return;
  const source = fs.readFileSync(file, "utf8");
  modules.set(rel, source);
  order.push(rel);

  const scanned = stripComments(source);
  let match;
  requirePattern.lastIndex = 0;
  while ((match = requirePattern.exec(scanned)) !== null) {
    const spec = match[1];
    if (spec.startsWith(".")) {
      const targetRel = normalize(file, spec);
      const targetAbs = path.join(root, targetRel);
      if (!fs.existsSync(targetAbs)) {
        throw new Error(`${rel}: require("${spec}") -> missing ${targetRel}`);
      }
      collect(targetAbs);
    } else {
      // Non-relative requires are Roblox services or globals; nothing to inline.
    }
  }
}

collect(entry);

const lines = [];
lines.push(`-- Bundled WindUI fork: src/Init.lua (modules: ${order.length})`);
lines.push("local __modules = {}");
lines.push("local __cache = {}");
lines.push("local function __require(id)");
lines.push("  local cached = __cache[id]");
lines.push("  if cached ~= nil then return cached end");
lines.push("  local chunk = __modules[id]");
lines.push("  if not chunk then error('module not found: ' .. tostring(id), 0) end");
lines.push("  local result = chunk(__require)");
lines.push("  __cache[id] = result");
lines.push("  return result");
lines.push("end");

for (const rel of order) {
  lines.push("");
  lines.push(`__modules["${rel}"] = function(require)`);
  lines.push(rewriteRequires(modules.get(rel), path.join(root, rel)).replace(/\s+$/, ""));
  lines.push("end");
}

lines.push("");
lines.push('return __require("src/Init.lua")');
lines.push("");

// One return at the end of the chunk: the module table itself.
const body = lines.join("\n");
fs.writeFileSync(outFile, body, "utf8");
console.log(`modules ${order.length} -> ${path.relative(root, outFile)} (${body.length} bytes)`);
