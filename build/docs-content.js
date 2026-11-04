// Page registry for build/docs.js.
// Body copy lives in build/pages/*.md so code fences stay readable.
const fs = require("fs");
const path = require("path");

const PAGES_DIR = path.join(__dirname, "pages");

function md(name) {
	const file = path.join(PAGES_DIR, `${name}.md`);
	return fs.readFileSync(file, "utf8").replace(/\r\n/g, "\n");
}

// The key screen reference is shared with the repository docs, so it keeps
// living in docs/key-system-modern.md and is pulled in here.
function keySystemMd() {
	const file = path.join(__dirname, "..", "docs", "key-system-modern.md");
	const source = fs.readFileSync(file, "utf8").replace(/\r\n/g, "\n");
	return source.replace(/^#\s+.*\n+/, "");
}

const PAGES = [
	// ---------------------------------------------------------------- start
	{
		slug: "about",
		group: "Getting Started",
		title: "About WindUI",
		nav: "About WindUI",
		lead: "Interface library for Roblox scripts — and the fork's additions.",
		card: "What this fork changes and what it leaves alone.",
		md: md("about"),
	},
	{
		slug: "loadstring",
		group: "Getting Started",
		title: "Loadstring",
		nav: "Loadstring",
		lead: "Load the bundle in one line.",
		card: "Fork bundle, pinned commit and upstream fallback.",
		md: md("loadstring"),
	},
	{
		slug: "themes",
		group: "Getting Started",
		title: "Themes",
		nav: "Themes",
		lead: "Create themes or use the sixteen that ship.",
		card: "Sixteen built-in themes, custom themes and gradients.",
		md: md("themes"),
	},

	// ------------------------------------------------------------------- UI
	{
		slug: "window",
		group: "UI",
		title: "Window",
		nav: "Window",
		lead: "Configure and create windows.",
		card: "Every CreateWindow field and window method.",
		md: md("window"),
	},
	{
		slug: "key-system",
		group: "UI",
		title: "Key System",
		nav: "Key System",
		lead: "Implement access control with key validation.",
		card: "The fork's key screen: layout, optional splash, error animation, controller.",
		md: keySystemMd(),
	},
	{
		slug: "tab",
		group: "UI",
		title: "Tab",
		nav: "Tab",
		lead: "Create and configure tabs.",
		card: "Pages inside the window and the elements they hold.",
		md: md("tab"),
	},
	{
		slug: "dialog",
		group: "UI",
		title: "Dialog",
		nav: "Dialog",
		lead: "Confirmation dialogs and prompts.",
		card: "Modal panels with action buttons.",
		md: md("dialog"),
	},
	{
		slug: "popup",
		group: "UI",
		title: "Popup",
		nav: "Popup",
		lead: "Standalone popup windows.",
		card: "Announcements that outlive the main window.",
		md: md("popup"),
	},
	{
		slug: "notification",
		group: "UI",
		title: "Notification",
		nav: "Notification",
		lead: "Toasts in the corner, stacked and timed.",
		card: "Title, content, icon, duration and buttons.",
		md: md("notification"),
	},
	{
		slug: "musicminiplayer",
		group: "UI",
		title: "Music Mini Player",
		nav: "Music Mini Player",
		lead: "A dynamic-island pill that springs into a glass player - local songs with real cover art, Spotify, or a bridge.",
		card: "Top-docked island and expanded card: songs folder, cover fetch, sources.",
		md: md("musicminiplayer"),
	},
	{
		slug: "tag",
		group: "UI",
		title: "Tag",
		nav: "Tag",
		lead: "Pills in the window topbar.",
		card: "Topbar pills with theme or gradient fills.",
		md: md("tag"),
	},
	{
		slug: "tab-section",
		group: "UI",
		title: "Tab Section",
		nav: "Tab Section",
		lead: "Group tabs in the sidebar.",
		card: "Collapsible sidebar groups.",
		md: md("tab-section"),
	},

	// ------------------------------------------------------------- elements
	{
		slug: "section",
		group: "Elements",
		title: "Section",
		nav: "Section",
		lead: "A labelled, collapsible block of elements.",
		card: "Group elements inside a tab.",
		md: md("section"),
	},
	{
		slug: "button",
		group: "Elements",
		title: "Button",
		nav: "Button",
		lead: "Interactive buttons that run a callback.",
		card: "Icons, descriptions, tags and lock state.",
		md: md("button"),
	},
	{
		slug: "toggle",
		group: "Elements",
		title: "Toggle",
		nav: "Toggle",
		lead: "Switches and checkboxes.",
		card: "Binary state with a callback.",
		md: md("toggle"),
	},
	{
		slug: "slider",
		group: "Elements",
		title: "Slider",
		nav: "Slider",
		lead: "Numeric input across a range.",
		card: "Steps, floats and an inline textbox.",
		md: md("slider"),
	},
	{
		slug: "input",
		group: "Elements",
		title: "Input",
		nav: "Input",
		lead: "Text fields, single line or multiline.",
		card: "Placeholder, icons and live callbacks.",
		md: md("input"),
	},
	{
		slug: "dropdown",
		group: "Elements",
		title: "Dropdown",
		nav: "Dropdown",
		lead: "Pick one value, or several.",
		card: "Multi-select, search and custom menu width.",
		md: md("dropdown"),
	},
	{
		slug: "paragraph",
		group: "Elements",
		title: "Paragraph",
		nav: "Paragraph",
		lead: "Static text, images and inline buttons.",
		card: "Info blocks and changelogs.",
		md: md("paragraph"),
	},
	{
		slug: "keybind",
		group: "Elements",
		title: "Keybind",
		nav: "Keybind",
		lead: "Capture a keyboard shortcut.",
		card: "Rebinding with a blacklist.",
		md: md("keybind"),
	},
	{
		slug: "colorpicker",
		group: "Elements",
		title: "Colorpicker",
		nav: "Colorpicker",
		lead: "Visual colour selection.",
		card: "Color3 output with optional alpha.",
		md: md("colorpicker"),
	},
	{
		slug: "code",
		group: "Elements",
		title: "Code",
		nav: "Code",
		lead: "Formatted code with a copy button.",
		card: "Readable snippets inside the UI.",
		md: md("code"),
	},
	{
		slug: "divider",
		group: "Elements",
		title: "Divider",
		nav: "Divider",
		lead: "A hairline between elements.",
		card: "Visual separation without a section.",
		md: md("divider"),
	},
	{
		slug: "space",
		group: "Elements",
		title: "Space",
		nav: "Space",
		lead: "Blank gaps between elements.",
		card: "One or more columns of empty space.",
		md: md("space"),
	},
	{
		slug: "image",
		group: "Elements",
		title: "Image",
		nav: "Image",
		lead: "Full-width images with an aspect ratio.",
		card: "URLs, asset ids and rounded corners.",
		md: md("image"),
	},
	{
		slug: "group",
		group: "Elements",
		title: "Group",
		nav: "Group",
		deprecated: true,
		lead: "Legacy container. Use HStack / VStack.",
		card: "Kept for older layouts.",
		md: md("group"),
	},
	{
		slug: "hstack-vstack",
		group: "Elements",
		title: "HStack & VStack",
		nav: "HStack & VStack",
		lead: "Horizontal and vertical layout containers.",
		card: "Build rows and columns that nest.",
		md: md("hstack-vstack"),
	},
	{
		slug: "progressbar",
		group: "Elements",
		title: "ProgressBar",
		nav: "ProgressBar",
		lead: "Determinate and indeterminate progress.",
		card: "Downloads, loaders and numeric readouts.",
		md: md("progressbar"),
	},

	// ------------------------------------------------------------- advanced
	{
		slug: "configs",
		group: "Advanced",
		title: "Configs",
		nav: "Configs",
		lead: "Save and load element state.",
		card: "Flags, profiles and autoload.",
		md: md("configs"),
	},
	{
		slug: "icons",
		group: "Advanced",
		title: "Icons",
		nav: "Icons",
		lead: "Bundled icon packs and custom packs.",
		card: "Names, packs, assets and thumbnails.",
		md: md("icons"),
	},
	{
		slug: "fork",
		group: "Advanced",
		title: "Fork",
		nav: "Fork",
		lead: "What this fork adds, and how to remove it.",
		card: "Diff against upstream and the revert path.",
		md: md("fork"),
	},
];

module.exports = { PAGES };
