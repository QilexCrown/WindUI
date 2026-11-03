// Static docs generator for the WindUI fork.
// Emits a multi-page site into docs/ — same nav shape as the upstream
// treehub WindUI docs, plus the fork's key-screen pages.
//
//   node build/docs.js
//
const fs = require("fs");
const path = require("path");

const ROOT = path.resolve(__dirname, "..");
const DOCS = path.join(ROOT, "docs");
const REPO = "https://github.com/QilexCrown/WindUI";
const RAW = "https://raw.githubusercontent.com/QilexCrown/WindUI/main/dist/main.lua";
const DISCORD = "https://discord.gg/ojailbreaks";

const { PAGES } = require("./docs-content.js");

const escapeHtml = (value) =>
	value.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");

function inline(text) {
	let out = escapeHtml(text);
	out = out.replace(/`([^`]+)`/g, "<code>$1</code>");
	out = out.replace(/\*\*([^*]+)\*\*/g, "<strong>$1</strong>");
	out = out.replace(/(^|[^*])\*([^*]+)\*/g, "$1<em>$2</em>");
	out = out.replace(/\[([^\]]+)\]\(([^)]+)\)/g, '<a href="$2">$1</a>');
	return out;
}

function slugify(value) {
	return value
		.toLowerCase()
		.replace(/`/g, "")
		.replace(/[^a-z0-9]+/g, "-")
		.replace(/^-|-$/g, "");
}

function render(markdown) {
	const lines = markdown.replace(/\r\n/g, "\n").split("\n");
	const html = [];
	const toc = [];
	let index = 0;

	while (index < lines.length) {
		const line = lines[index];

		if (!line.trim()) {
			index += 1;
			continue;
		}

		const fence = line.match(/^```(\w*)/);
		if (fence) {
			const lang = fence[1] || "lua";
			const body = [];
			index += 1;
			while (index < lines.length && !/^```/.test(lines[index])) {
				body.push(lines[index]);
				index += 1;
			}
			index += 1;
			html.push(
				`<pre class="code" data-lang="${lang}"><code>${escapeHtml(body.join("\n"))}</code></pre>`
			);
			continue;
		}

		const heading = line.match(/^(#{1,4})\s+(.*)$/);
		if (heading) {
			const level = heading[1].length;
			const text = heading[2].trim();
			const id = slugify(text);
			if (level >= 2) toc.push({ level, text, id });
			html.push(
				`<h${level} id="${id}">${inline(text)}<a class="anchor" href="#${id}" aria-hidden="true">#</a></h${level}>`
			);
			index += 1;
			continue;
		}

		if (/^---+$/.test(line.trim())) {
			html.push("<hr />");
			index += 1;
			continue;
		}

		if (/^\|/.test(line) && /^\|[\s\-:|]+\|?$/.test(lines[index + 1] || "")) {
			const splitRow = (row) => {
				const cells = [];
				let cell = "";
				for (let i = 0; i < row.length; i += 1) {
					const ch = row[i];
					if (ch === "\\" && row[i + 1] === "|") {
						cell += "|";
						i += 1;
						continue;
					}
					if (ch === "|") {
						cells.push(cell.trim());
						cell = "";
						continue;
					}
					cell += ch;
				}
				cells.push(cell.trim());
				// A leading and trailing pipe produce empty edge cells.
				if (cells.length && cells[0] === "") cells.shift();
				if (cells.length && cells[cells.length - 1] === "") cells.pop();
				return cells;
			};

			const head = splitRow(lines[index].trim());
			const rows = [];
			index += 2;
			while (index < lines.length && /^\|/.test(lines[index])) {
				rows.push(splitRow(lines[index].trim()));
				index += 1;
			}
			const thead = head.map((cell) => `<th>${inline(cell)}</th>`).join("");
			const tbody = rows
				.map((row) => `<tr>${row.map((cell) => `<td>${inline(cell)}</td>`).join("")}</tr>`)
				.join("");
			html.push(`<div class="table-wrap"><table><thead><tr>${thead}</tr></thead><tbody>${tbody}</tbody></table></div>`);
			continue;
		}

		if (/^\s*[-*]\s+/.test(line)) {
			const items = [];
			while (index < lines.length && /^\s*[-*]\s+/.test(lines[index])) {
				let text = lines[index].replace(/^\s*[-*]\s+/, "");
				index += 1;
				// Wrapped bullets: keep trailing lines that are indented or that
				// simply continue the sentence, until a blank line or new block.
				while (
					index < lines.length &&
					lines[index].trim() &&
					!/^\s*[-*]\s+/.test(lines[index]) &&
					!/^(#|```|\||----|>)/.test(lines[index]) &&
					!/^\s*\d+[.)]\s+/.test(lines[index])
				) {
					text += " " + lines[index].trim();
					index += 1;
				}
				items.push(`<li>${inline(text)}</li>`);
			}
			html.push(`<ul>${items.join("")}</ul>`);
			continue;
		}

		if (/^\s*\d+[.)]\s+/.test(line)) {
			const items = [];
			while (index < lines.length && /^\s*\d+[.)]\s+/.test(lines[index])) {
				let text = lines[index].replace(/^\s*\d+[.)]\s+/, "");
				index += 1;
				while (
					index < lines.length &&
					lines[index].trim() &&
					!/^\s*[-*]\s+/.test(lines[index]) &&
					!/^(#|```|\||----|>)/.test(lines[index]) &&
					!/^\s*\d+[.)]\s+/.test(lines[index])
				) {
					text += " " + lines[index].trim();
					index += 1;
				}
				items.push(`<li>${inline(text)}</li>`);
			}
			html.push(`<ol>${items.join("")}</ol>`);
			continue;
		}

		if (/^>\s?/.test(line)) {
			const quote = [];
			while (index < lines.length && /^>\s?/.test(lines[index])) {
				quote.push(lines[index].replace(/^>\s?/, ""));
				index += 1;
			}
			html.push(`<blockquote>${inline(quote.join(" "))}</blockquote>`);
			continue;
		}

		const paragraph = [];
		while (
			index < lines.length &&
			lines[index].trim() &&
			!/^(#|```|\||\s*[-*]\s+|\s*\d+[.)]\s+|----|>)/.test(lines[index])
		) {
			paragraph.push(lines[index].trim());
			index += 1;
		}
		html.push(`<p>${inline(paragraph.join(" "))}</p>`);
	}

	return { html: html.join("\n"), toc };
}

const STYLE = `
:root {
  --bg: #08080a;
  --panel: #101013;
  --panel-2: #16161a;
  --stroke: rgba(255,255,255,0.08);
  --stroke-2: rgba(255,255,255,0.14);
  --text: #f4f4f5;
  --muted: #9b9ba4;
  --dim: #6b6b75;
  --code: #0c0c0f;
  --accent: #e4e4e7;
}
* { box-sizing: border-box; }
html { scroll-behavior: smooth; }
body {
  margin: 0;
  background: var(--bg);
  color: var(--text);
  font-family: "Inter", "Segoe UI", system-ui, -apple-system, sans-serif;
  font-size: 15px;
  line-height: 1.7;
  -webkit-font-smoothing: antialiased;
}
a { color: #ededf0; text-decoration: none; }
a:hover { color: #fff; text-decoration: underline; text-underline-offset: 2px; }
code {
  font-family: "JetBrains Mono", "Cascadia Code", ui-monospace, monospace;
  font-size: 12.5px; background: rgba(255,255,255,0.06);
  border: 1px solid rgba(255,255,255,0.05);
  padding: 1px 6px; border-radius: 6px; color: #f0f0f2; white-space: nowrap;
}
pre.code {
  background: var(--code); border: 1px solid var(--stroke); border-radius: 14px;
  padding: 18px 20px; overflow: auto; margin: 0 0 22px; position: relative;
}
pre.code code {
  background: none; border: 0; padding: 0; font-size: 12.5px;
  line-height: 1.7; white-space: pre; color: #e6e6ea;
}
pre.code::before {
  content: attr(data-lang); position: absolute; top: 10px; right: 16px;
  font-size: 10px; letter-spacing: 0.1em; text-transform: uppercase; color: #4b4b55;
}

/* top bar */
header.top {
  position: sticky; top: 0; z-index: 30;
  backdrop-filter: blur(18px);
  background: rgba(8,8,10,0.86);
  border-bottom: 1px solid var(--stroke);
}
.top-inner { display: flex; align-items: center; gap: 18px; height: 60px; padding: 0 26px; }
.brand { display: flex; align-items: center; gap: 10px; font-weight: 600; letter-spacing: 0.01em; }
.brand img { width: 26px; height: 26px; border-radius: 8px; }
.brand span { font-size: 15px; }
.brand .tag {
  font-size: 10.5px; font-weight: 600; letter-spacing: 0.04em; text-transform: uppercase;
  color: #0b0b0d; background: #e4e4e7; border-radius: 6px; padding: 2px 6px;
}
.top-links { margin-left: auto; display: flex; align-items: center; gap: 8px; }
.top-links a {
  font-size: 12.5px; color: var(--muted); padding: 6px 10px; border-radius: 8px;
  border: 1px solid transparent;
}
.top-links a:hover { color: var(--text); background: rgba(255,255,255,0.05); text-decoration: none; }
.top-links a.ghost { border-color: var(--stroke); }

/* shell */
.shell { display: grid; grid-template-columns: 268px minmax(0, 1fr); min-height: calc(100vh - 60px); }
aside.side {
  border-right: 1px solid var(--stroke);
  padding: 22px 18px 60px;
  position: sticky; top: 60px; align-self: start;
  height: calc(100vh - 60px); overflow-y: auto;
  scrollbar-width: thin;
}
.search {
  width: 100%; margin-bottom: 18px; padding: 9px 12px;
  background: var(--panel); border: 1px solid var(--stroke); border-radius: 10px;
  color: var(--text); font-size: 13px; font-family: inherit; outline: none;
}
.search:focus { border-color: var(--stroke-2); }
.search::placeholder { color: var(--dim); }
nav.side .group {
  color: var(--dim); text-transform: uppercase; letter-spacing: 0.11em;
  font-size: 10px; font-weight: 600; margin: 18px 0 6px 10px;
}
nav.side .group:first-of-type { margin-top: 0; }
nav.side a {
  display: block; padding: 6px 10px; border-radius: 8px;
  color: var(--muted); font-size: 13.5px; line-height: 1.5;
}
nav.side a:hover { color: var(--text); background: rgba(255,255,255,0.04); text-decoration: none; }
nav.side a.active { color: #fff; background: rgba(255,255,255,0.07); font-weight: 500; }
nav.side a.deprecated::after { content: "deprecated"; margin-left: 6px; font-size: 9.5px; color: #7c7c86; }

main { min-width: 0; padding: 46px 52px 90px; max-width: 980px; }
article h1 {
  font-size: 38px; line-height: 1.15; margin: 0 0 14px; letter-spacing: -0.025em; font-weight: 650;
}
article .lead { font-size: 16px; color: var(--muted); margin: 0 0 30px; max-width: 70ch; }
article h2 {
  font-size: 22px; margin: 44px 0 12px; letter-spacing: -0.012em;
  padding-top: 16px; border-top: 1px solid var(--stroke); scroll-margin-top: 80px;
}
article h3 { font-size: 16px; margin: 28px 0 8px; color: #fafafa; scroll-margin-top: 80px; }
article h4 {
  font-size: 12px; margin: 22px 0 8px; color: var(--dim);
  text-transform: uppercase; letter-spacing: 0.09em;
}
article a.anchor { opacity: 0; margin-left: 8px; color: var(--dim); font-weight: 400; }
article h2:hover a.anchor, article h3:hover a.anchor { opacity: 1; }
article p { margin: 0 0 15px; color: #d3d3d9; }
article ul, article ol { margin: 0 0 18px; padding-left: 22px; color: #d3d3d9; }
article li { margin: 5px 0; }
article li > code { font-size: 12px; }
article strong { color: #fff; font-weight: 600; }
article blockquote {
  margin: 0 0 20px; padding: 12px 16px; border-left: 2px solid #3f3f48;
  background: rgba(255,255,255,0.03); border-radius: 0 10px 10px 0; color: #cfcfd6;
}
article blockquote p { margin: 0; }
article hr { border: none; border-top: 1px solid var(--stroke); margin: 34px 0; }
.table-wrap { overflow-x: auto; margin: 0 0 24px; }
table { width: 100%; border-collapse: collapse; font-size: 13.5px; }
th {
  text-align: left; font-weight: 600; color: #fff; padding: 9px 13px;
  background: var(--panel-2); border-bottom: 1px solid var(--stroke); white-space: nowrap;
}
th:first-child { border-top-left-radius: 10px; }
th:last-child { border-top-right-radius: 10px; }
td { padding: 9px 13px; border-bottom: 1px solid rgba(255,255,255,0.045); color: #cfcfd6; vertical-align: top; }
td code { white-space: normal; word-break: break-word; }
tr:hover td { background: rgba(255,255,255,0.018); }

.pager {
  display: flex; gap: 12px; justify-content: space-between;
  margin-top: 54px; padding-top: 22px; border-top: 1px solid var(--stroke);
}
.pager a {
  flex: 1; border: 1px solid var(--stroke); border-radius: 12px;
  padding: 12px 16px; background: var(--panel);
}
.pager a:hover { border-color: var(--stroke-2); text-decoration: none; }
.pager a.next { text-align: right; }
.pager small { display: block; color: var(--dim); font-size: 10.5px; text-transform: uppercase; letter-spacing: 0.09em; }
.pager span { font-size: 14px; color: var(--text); }

/* landing */
.landing { max-width: 1040px; }
.hero { padding: 34px 0 18px; }
.hero .eyebrow {
  display: inline-flex; align-items: center; gap: 8px; font-size: 11.5px;
  color: var(--muted); border: 1px solid var(--stroke); border-radius: 999px;
  padding: 4px 12px; margin-bottom: 20px; letter-spacing: 0.02em;
}
.hero .dot { width: 5px; height: 5px; border-radius: 50%; background: #4ade80; }
.hero h1 { font-size: 50px; line-height: 1.06; letter-spacing: -0.035em; margin: 0 0 18px; max-width: 15ch; }
.hero p { font-size: 17px; color: var(--muted); max-width: 62ch; margin: 0 0 26px; }
.cta { display: flex; gap: 10px; flex-wrap: wrap; }
.btn {
  display: inline-flex; align-items: center; gap: 8px; padding: 11px 18px;
  border-radius: 11px; border: 1px solid var(--stroke); font-size: 14px;
  font-weight: 500; background: var(--panel); color: var(--text);
}
.btn:hover { border-color: var(--stroke-2); background: var(--panel-2); text-decoration: none; }
.btn.primary { background: #f4f4f5; color: #08080a; border-color: #f4f4f5; font-weight: 600; }
.btn.primary:hover { background: #fff; }
.section-title { font-size: 13px; text-transform: uppercase; letter-spacing: 0.1em; color: var(--dim); margin: 56px 0 14px; }
.cards { display: grid; grid-template-columns: repeat(auto-fill, minmax(250px, 1fr)); gap: 14px; }
.card {
  display: block; border: 1px solid var(--stroke); border-radius: 14px; padding: 18px;
  background: linear-gradient(180deg, rgba(255,255,255,0.028), rgba(255,255,255,0.006));
}
.card:hover { border-color: var(--stroke-2); text-decoration: none; }
.card h3 { margin: 0 0 5px; font-size: 15px; color: #fff; font-weight: 600; }
.card p { margin: 0; font-size: 13px; color: var(--muted); line-height: 1.55; }
footer.site {
  border-top: 1px solid var(--stroke); padding: 22px 52px 46px;
  color: var(--dim); font-size: 12.5px; display: flex; gap: 16px; flex-wrap: wrap;
}
footer.site a { color: var(--muted); }

@media (max-width: 940px) {
  .shell { grid-template-columns: 1fr; }
  aside.side {
    position: static; height: auto; border-right: 0; border-bottom: 1px solid var(--stroke);
    padding: 16px 18px; max-height: 320px;
  }
  main { padding: 30px 20px 70px; }
  .hero h1 { font-size: 36px; }
  footer.site { padding: 20px; }
}
`;

function shell(page, pages) {
	const bySlug = new Map(pages.map((entry) => [entry.slug, entry]));
	const groups = [];
	for (const entry of pages) {
		if (entry.hidden) continue;
		let group = groups.find((item) => item.title === entry.group);
		if (!group) {
			group = { title: entry.group, items: [] };
			groups.push(group);
		}
		group.items.push(entry);
	}

	const nav = groups
		.map(
			(group) => `<p class="group">${group.title}</p>
${group.items
	.map(
		(item) =>
			`<a href="./${item.slug}.html"${item.slug === page.slug ? ' class="active"' : ""}${
				item.deprecated ? ' data-deprecated="1"' : ""
			}>${item.nav || item.title}</a>`
	)
	.join("\n")}`
		)
		.join("\n");

	const index = pages.findIndex((entry) => entry.slug === page.slug);
	const prev = index > 0 ? pages[index - 1] : null;
	const next = index >= 0 && index < pages.length - 1 ? pages[index + 1] : null;

	const pager =
		prev || next
			? `<div class="pager">
${prev ? `<a href="./${prev.slug}.html"><small>Previous</small><span>${prev.title}</span></a>` : "<span></span>"}
${next ? `<a class="next" href="./${next.slug}.html"><small>Next</small><span>${next.title}</span></a>` : "<span></span>"}
</div>`
			: "";

	return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>${page.title} — WindUI docs</title>
<meta name="description" content="${page.description || "WindUI interface library documentation."}" />
<link rel="icon" href="./logo.png" />
<style>${STYLE}</style>
</head>
<body>
<header class="top">
  <div class="top-inner">
    <a class="brand" href="./index.html">
      <img src="./logo.png" alt="" />
      <span>WindUI</span>
      <em class="tag">fork</em>
    </a>
    <div class="top-links">
      <a class="ghost" href="${REPO}">GitHub</a>
      <a class="ghost" href="${DISCORD}">Discord</a>
      <a class="ghost" href="${RAW}">dist/main.lua</a>
    </div>
  </div>
</header>
<div class="shell">
<aside class="side">
  <input class="search" id="nav-search" placeholder="Search docs…" autocomplete="off" />
  <nav class="side" id="nav">${nav}</nav>
</aside>
<main>
<article>
<h1>${page.title}</h1>
${page.lead ? `<p class="lead">${inline(page.lead)}</p>` : ""}
${page.html}
${pager}
</article>
</main>
</div>
<footer class="site">
  <span>WindUI fork — MIT licensed.</span>
  <a href="${REPO}">QilexCrown/WindUI</a>
  <a href="${RAW}">dist/main.lua</a>
</footer>
<script>
(function () {
  var input = document.getElementById("nav-search");
  var nav = document.getElementById("nav");
  if (!input || !nav) return;
  input.addEventListener("input", function () {
    var q = input.value.trim().toLowerCase();
    nav.querySelectorAll("a").forEach(function (link) {
      var hit = !q || link.textContent.toLowerCase().indexOf(q) !== -1;
      link.style.display = hit ? "" : "none";
    });
    nav.querySelectorAll(".group").forEach(function (group) {
      var visible = false;
      var node = group.nextElementSibling;
      while (node && node.tagName === "A") {
        if (node.style.display !== "none") visible = true;
        node = node.nextElementSibling;
      }
      group.style.display = visible ? "" : "none";
    });
  });
})();
</script>
</body>
</html>`;
}

function landing(pages) {
	const cards = pages
		.filter((entry) => !entry.hidden && entry.group === "UI")
		.map(
			(entry) => `<a class="card" href="./${entry.slug}.html">
  <h3>${entry.nav || entry.title}</h3>
  <p>${entry.card || entry.lead || ""}</p>
</a>`
		)
		.join("\n");

	const elementCards = pages
		.filter((entry) => !entry.hidden && entry.group === "Elements")
		.map(
			(entry) => `<a class="card" href="./${entry.slug}.html">
  <h3>${entry.title}</h3>
  <p>${entry.card || entry.lead || ""}</p>
</a>`
		)
		.join("\n");

	const install = `local WindUI = loadstring(game:HttpGet("${RAW}"))()`;

	const body = `<div class="landing">
<section class="hero">
  <span class="eyebrow"><span class="dot"></span> beta · fork of Footagesus/WindUI</span>
  <h1>WindUI documentation</h1>
  <p>Interface library for Roblox scripts. This fork adds a fully configurable key screen — instant open, theme-driven colours, movable blocks and a wrong-key animation — all opt-in through one table.</p>
  <div class="cta">
    <a class="btn primary" href="./key-system.html">Key system docs</a>
    <a class="btn" href="./loadstring.html">Loadstring</a>
    <a class="btn" href="${REPO}">Repository</a>
  </div>
</section>
<p class="section-title">Install</p>
<pre class="code" data-lang="lua"><code>${escapeHtml(install)}</code></pre>
<p class="section-title">UI</p>
<div class="cards">
${cards}
</div>
<p class="section-title">Elements</p>
<div class="cards">
${elementCards}
</div>
</div>`;

	return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>WindUI docs</title>
<meta name="description" content="WindUI documentation — window, key system, themes and every element." />
<link rel="icon" href="./logo.png" />
<style>${STYLE}</style>
</head>
<body>
<header class="top">
  <div class="top-inner">
    <a class="brand" href="./index.html">
      <img src="./logo.png" alt="" />
      <span>WindUI</span>
      <em class="tag">fork</em>
    </a>
    <div class="top-links">
      <a class="ghost" href="${REPO}">GitHub</a>
      <a class="ghost" href="${DISCORD}">Discord</a>
      <a class="ghost" href="${RAW}">dist/main.lua</a>
    </div>
  </div>
</header>
<div class="shell">
<aside class="side">
  <input class="search" id="nav-search" placeholder="Search docs…" autocomplete="off" />
  <nav class="side" id="nav">${navFor(pages, "index")}</nav>
</aside>
<main>
${body}
</main>
</div>
<footer class="site">
  <span>WindUI fork — MIT licensed.</span>
  <a href="${REPO}">QilexCrown/WindUI</a>
  <a href="${RAW}">dist/main.lua</a>
</footer>
<script>
(function () {
  var input = document.getElementById("nav-search");
  var nav = document.getElementById("nav");
  if (!input || !nav) return;
  input.addEventListener("input", function () {
    var q = input.value.trim().toLowerCase();
    nav.querySelectorAll("a").forEach(function (link) {
      var hit = !q || link.textContent.toLowerCase().indexOf(q) !== -1;
      link.style.display = hit ? "" : "none";
    });
    nav.querySelectorAll(".group").forEach(function (group) {
      var visible = false;
      var node = group.nextElementSibling;
      while (node && node.tagName === "A") {
        if (node.style.display !== "none") visible = true;
        node = node.nextElementSibling;
      }
      group.style.display = visible ? "" : "none";
    });
  });
})();
</script>
</body>
</html>`;
}

function navFor(pages, activeSlug) {
	const groups = [];
	for (const entry of pages) {
		if (entry.hidden) continue;
		let group = groups.find((item) => item.title === entry.group);
		if (!group) {
			group = { title: entry.group, items: [] };
			groups.push(group);
		}
		group.items.push(entry);
	}
	return groups
		.map(
			(group) => `<p class="group">${group.title}</p>
${group.items
	.map(
		(item) =>
			`<a href="./${item.slug}.html"${item.slug === activeSlug ? ' class="active"' : ""}>${
				item.nav || item.title
			}</a>`
	)
	.join("\n")}`
		)
		.join("\n");
}

function build() {
	const pages = PAGES.map((entry) => {
		const { html, toc } = render(entry.md || "");
		return { ...entry, html, toc };
	});

	for (const page of pages) {
		fs.writeFileSync(path.join(DOCS, `${page.slug}.html`), shell(page, pages), "utf8");
	}

	fs.writeFileSync(path.join(DOCS, "index.html"), landing(pages), "utf8");
	fs.writeFileSync(path.join(DOCS, ".nojekyll"), "", "utf8");

	// The first fork build shipped key-system-modern.html; keep old links alive.
	fs.writeFileSync(
		path.join(DOCS, "key-system-modern.html"),
		`<!doctype html><html lang="en"><head><meta charset="utf-8" />
<meta http-equiv="refresh" content="0; url=./key-system.html" />
<link rel="canonical" href="./key-system.html" />
<title>Key system — WindUI docs</title></head>
<body><p>Moved to <a href="./key-system.html">key-system.html</a>.</p></body></html>`,
		"utf8"
	);

	console.log(`docs built: ${pages.length} pages + landing`);
}

build();
