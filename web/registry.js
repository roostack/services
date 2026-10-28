// The registry's page: lists every service from v1/index.json (search,
// filters, order), and shows one service's full record from its newest
// package file, fetched when it's opened, checked against the index's
// SHA-256, and read with the vendored yaml (YAML.parse). Everything is
// built with DOM calls, never from markup in the data. The address says
// what's shown (#/ the list with its filters, #/<name> a service), so
// links can be shared.
"use strict";

// The icons the page draws, copied from Roostack's internal/web/icons.go
// (Apache-2.0), where they're drawn for its UI.
const ICONS = {
 "photos": "<rect x=\"3\" y=\"5\" width=\"18\" height=\"14\" rx=\"2\"/><circle cx=\"9\" cy=\"10\" r=\"1.6\"/><path d=\"m4 17 5-5 4 4 2.5-2.5L20 17\"/>",
 "media": "<rect x=\"3\" y=\"4\" width=\"18\" height=\"16\" rx=\"2\"/><path d=\"M7 4v16M17 4v16M3 9h4M3 15h4M17 9h4M17 15h4\"/>",
 "documents": "<path d=\"M14 3H6a1 1 0 0 0-1 1v16a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1V8z\"/><path d=\"M14 3v5h5M9 13h6M9 17h6\"/>",
 "productivity": "<rect x=\"3\" y=\"4\" width=\"18\" height=\"16\" rx=\"2\"/><path d=\"M9 4v16M15 4v16\"/><path d=\"M5.5 8h1.5M11 8h2M11 11h2M17 8h1.5\"/>",
 "home": "<path d=\"M3 11 12 4l9 7\"/><path d=\"M5 10v9a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1v-9\"/><circle cx=\"12\" cy=\"14.5\" r=\"2.5\"/>",
 "passwords": "<circle cx=\"8\" cy=\"15\" r=\"4\"/><path d=\"m11 12 8-8M16 7l2 2M14 9l2 2\"/>",
 "development": "<circle cx=\"6\" cy=\"5\" r=\"2\"/><circle cx=\"6\" cy=\"19\" r=\"2\"/><circle cx=\"18\" cy=\"8\" r=\"2\"/><path d=\"M6 7v10M18 10c0 4-6 3-11 7\"/>",
 "publishing": "<path d=\"M4 20l4-1 11-11-3-3L5 16z\"/><path d=\"M14 7l3 3M4 20h16\"/>",
 "network": "<circle cx=\"5\" cy=\"12\" r=\"2.5\"/><circle cx=\"19\" cy=\"5\" r=\"2.5\"/><circle cx=\"19\" cy=\"19\" r=\"2.5\"/><path d=\"m7.2 10.9 9.6-4.8M7.2 13.1l9.6 4.8\"/>",
 "services": "<rect x=\"3\" y=\"3\" width=\"7\" height=\"7\" rx=\"1.5\"/><rect x=\"14\" y=\"3\" width=\"7\" height=\"7\" rx=\"1.5\"/><rect x=\"3\" y=\"14\" width=\"7\" height=\"7\" rx=\"1.5\"/><rect x=\"14\" y=\"14\" width=\"7\" height=\"7\" rx=\"1.5\"/>",
 "check": "<path d=\"m5 12.5 4.5 4.5L19 7.5\"/>",
 "close": "<path d=\"M6 6l12 12M18 6 6 18\"/>",
 "copy": "<rect x=\"8\" y=\"8\" width=\"12\" height=\"12\" rx=\"2\"/><path d=\"M16 8V5a1 1 0 0 0-1-1H5a1 1 0 0 0-1 1v10a1 1 0 0 0 1 1h3\"/>",
 "globe": "<circle cx=\"12\" cy=\"12\" r=\"9\"/><path d=\"M3 12h18M12 3c3 3.5 3 14.5 0 18M12 3c-3 3.5-3 14.5 0 18\"/>",
 "new-window": "<path d=\"M14 4h6v6\"/><path d=\"M20 4l-9 9\"/><path d=\"M18 14v5a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V7a1 1 0 0 1 1-1h5\"/>",
 "light": "<circle cx=\"12\" cy=\"12\" r=\"4\"/><path d=\"M12 2.5v2M12 19.5v2M2.5 12h2M19.5 12h2M5.3 5.3l1.4 1.4M17.3 17.3l1.4 1.4M5.3 18.7l1.4-1.4M17.3 6.7l1.4-1.4\"/>",
 "dark": "<path d=\"M20 14.5A8 8 0 0 1 9.5 4 8 8 0 1 0 20 14.5z\"/>",
 "warn": "<path d=\"M12 4 2.5 20h19z\"/><path d=\"M12 10v4M12 17h.01\"/>",
 "chevron": "<path d=\"m10 7 5 5-5 5\"/>",
 "tag": "<path d=\"M3 12V4a1 1 0 0 1 1-1h8l9 9-9 9z\"/><circle cx=\"8\" cy=\"8\" r=\"1.5\"/>",
 "disk": "<ellipse cx=\"12\" cy=\"6\" rx=\"8\" ry=\"3\"/><path d=\"M4 6v12c0 1.7 3.6 3 8 3s8-1.3 8-3V6\"/><path d=\"M4 12c0 1.7 3.6 3 8 3s8-1.3 8-3\"/>",
 "certificate": "<path d=\"M12 3 5 6v5c0 4.5 3 8.3 7 10 4-1.7 7-5.5 7-10V6l-7-3z\"/><path d=\"m9 12 2 2 4-4\"/>",
 "sign-in": "<rect x=\"4\" y=\"11\" width=\"16\" height=\"9\" rx=\"2\"/><path d=\"M8 11V8a4 4 0 0 1 8 0v3\"/><path d=\"M12 15v2\"/>",
 "server": "<rect x=\"3\" y=\"4\" width=\"18\" height=\"7\" rx=\"2\"/><rect x=\"3\" y=\"13\" width=\"18\" height=\"7\" rx=\"2\"/><path d=\"M7 7.5h.01M7 16.5h.01\"/>",
 "terminal": "<rect x=\"3\" y=\"4\" width=\"18\" height=\"16\" rx=\"2\"/><path d=\"m7 9 3 3-3 3M13 15h4\"/>",
 "clock": "<circle cx=\"12\" cy=\"12\" r=\"9\"/><path d=\"M12 7v5l3 2\"/>",
 "users": "<circle cx=\"9\" cy=\"8\" r=\"3.5\"/><path d=\"M3 20c0-3.3 2.7-6 6-6s6 2.7 6 6\"/><circle cx=\"17\" cy=\"9\" r=\"2.5\"/><path d=\"M16 14c2.8 0 5 2.2 5 5\"/>"
};

ICONS.search = '<circle cx="11" cy="11" r="7"/><path d="m20 20-4.2-4.2"/>';
ICONS.back = '<path d="M15 18l-6-6 6-6"/>';

// Roostack's pkgspec.Categories, in their order: a category added there
// shows here by its key until it's added below too.
const CATEGORIES = [
  ["photos", "Photos and videos"], ["media", "Films, TV and music"], ["documents", "Documents and notes"],
  ["productivity", "Tasks and planning"], ["home", "Smart home and cameras"], ["passwords", "Passwords and security"],
  ["development", "Developer tools"], ["publishing", "Websites and blogs"], ["network", "Network"],
];
const CATEGORY = Object.fromEntries(CATEGORIES);
const BASE = "v1/";
// The processors Roostack runs on (SPEC.md §3.1); an image's others aren't shown.
const ARCHES = { amd64: "PC (amd64)", arm64: "ARM (arm64)" };
const DATABASE = { sqlite: "SQLite", postgres: "PostgreSQL", mariadb: "MariaDB", mysql: "MySQL", redis: "Redis" };
const arches = entry => (entry.architectures || []).filter(a => a in ARCHES);

// Notices a project asks for on its service's page (notices.json, kept by
// the registry's maintainers: package files can't change once published).
let notices = null;
function loadNotices() {
  notices ??= fetch("notices.json").then(r => r.ok ? r.json() : {}).catch(() => ({}));
  return notices;
}

const state = { index: null, list: [], q: "", cat: "", tier: "", arch: "", sort: "name", files: new Map() };

// h builds an element: h("a", {href: "#"}, "text", child…). Attributes
// starting "on" are listeners; false and null ones are left out.
function h(tag, attrs, ...children) {
  const el = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs || {})) {
    if (v === false || v == null) continue;
    if (k.startsWith("on")) el.addEventListener(k.slice(2), v);
    else if (k === "class") el.className = v;
    else el.setAttribute(k, v === true ? "" : v);
  }
  for (const c of children.flat(Infinity)) {
    if (c == null || c === false) continue;
    el.append(c instanceof Node ? c : String(c));
  }
  return el;
}

// icon draws one of ICONS, as Roostack's icon component does.
function icon(name) {
  const svg = document.createElementNS("http://www.w3.org/2000/svg", "svg");
  for (const [k, v] of Object.entries({ class: "icon", viewBox: "0 0 24 24", "aria-hidden": "true", focusable: "false", fill: "none",
    stroke: "currentColor", "stroke-width": "1.8", "stroke-linecap": "round", "stroke-linejoin": "round" })) svg.setAttribute(k, v);
  svg.innerHTML = ICONS[name] || ICONS.services; // our own drawings, never data
  return svg;
}

// Versions are "<app version>-roostack.<revision>"; newest compares the
// app's version part by part (numbers as numbers), then the revision.
function splitVersion(v) {
  const m = /^(.*)-roostack\.(\d+)$/.exec(v);
  return m ? { app: m[1], rev: Number(m[2]) } : { app: v, rev: 0 };
}
function compareVersions(a, b) {
  const A = splitVersion(a), B = splitVersion(b);
  const pa = A.app.split(/[.+-]/), pb = B.app.split(/[.+-]/);
  for (let i = 0; i < Math.max(pa.length, pb.length); i++) {
    const x = pa[i] ?? "", y = pb[i] ?? "";
    const nx = /^\d+$/.test(x), ny = /^\d+$/.test(y);
    const c = nx && ny ? Number(x) - Number(y) : x.localeCompare(y);
    if (c) return c;
  }
  return A.rev - B.rev;
}

function logo(p, size) {
  const tile = h("span", { class: "logo-tile" });
  if (size) Object.assign(tile.style, { width: size + "px", height: size + "px" });
  if (p.icon) {
    const img = h("img", { src: BASE + p.icon.path, alt: "", width: 40, height: 40, loading: "lazy" });
    img.addEventListener("error", () => img.replaceWith(icon((p.categories || [])[0])));
    tile.append(img);
  } else tile.append(icon((p.categories || [])[0]));
  return tile;
}

function tierBadge(tier) {
  if (tier === "official") return h("span", { class: "badge" }, "Official");
  if (tier === "community") return h("span", { class: "badge badge-warn" }, "Community");
  return null;
}

function when(iso, month = "long") {
  const d = new Date(iso);
  return isNaN(d) ? iso : d.toLocaleDateString("en-GB", { day: "numeric", month, year: "numeric" });
}

async function load() {
  const res = await fetch(BASE + "index.json", { cache: "no-cache" });
  if (!res.ok) throw new Error(`the registry answered ${res.status} for v1/index.json`);
  const index = await res.json();
  state.index = index;
  state.list = Object.entries(index.packages).map(([name, p]) => {
    const versions = Object.keys(p.versions).sort(compareVersions);
    const newest = versions[versions.length - 1];
    return { name, ...p, versions, newest, latest: p.versions[newest],
      search: [name, p.title, p.description, ...(p.categories || []).map(c => CATEGORY[c] || c), p.tier].join(" ").toLowerCase() };
  });
  document.getElementById("foot-index").textContent =
    `This is index ${index.serial}, published ${when(index.date)} from the registry's commit ${String(index.commit || "").slice(0, 7)}.`;
}

// ---------- The list ----------

function readFilters() {
  const p = new URLSearchParams(location.hash.replace(/^#\/?\??/, ""));
  state.q = p.get("q") || ""; state.cat = p.get("cat") || ""; state.tier = p.get("tier") || "";
  state.arch = p.get("arch") || ""; state.sort = p.get("sort") || "name";
}
function writeFilters() {
  const p = new URLSearchParams();
  for (const k of ["q", "cat", "tier", "arch"]) if (state[k]) p.set(k, state[k]);
  if (state.sort !== "name") p.set("sort", state.sort);
  const hash = "#/" + (p.toString() ? "?" + p : "");
  if (location.hash !== hash) history.replaceState(null, "", hash);
}

function matches(p, ignore) {
  const words = state.q.toLowerCase().split(/\s+/).filter(Boolean);
  return words.every(w => p.search.includes(w)) &&
    (ignore === "cat" || !state.cat || (p.categories || []).includes(state.cat)) &&
    (!state.tier || p.tier === state.tier) &&
    (!state.arch || arches(p.latest).includes(state.arch));
}

function segmented(label, name, options, value, onchange) {
  return h("div", { class: "segmented small", role: "radiogroup", "aria-label": label },
    options.map(([v, text, title]) => h("label", { title },
      h("input", { type: "radio", name, value: v, checked: v === value, onchange: () => onchange(v) }), text)));
}

// filterGroup is a filter with its label, kept together when the row wraps.
function filterGroup(label, control) {
  return h("div", { class: "reg-filter-group" }, h("span", { class: "reg-filter-label", "aria-hidden": "true" }, label), control);
}

function renderList() {
  readFilters();
  const main = document.getElementById("main");
  const versions = state.list.reduce((n, p) => n + p.versions.length, 0);
  const grid = h("ul", { class: "reg-grid" });
  const shown = h("p", { class: "reg-shown", "aria-live": "polite" });
  const chips = h("div", { class: "filter-chips reg-cats", role: "group", "aria-label": "Categories" });

  const update = () => {
    writeFilters();
    let items = state.list.filter(p => matches(p));
    items.sort(state.sort === "category"
      ? (a, b) => CATEGORIES.findIndex(c => c[0] === (a.categories || [])[0]) - CATEGORIES.findIndex(c => c[0] === (b.categories || [])[0]) || a.title.localeCompare(b.title)
      : (a, b) => a.title.localeCompare(b.title));
    grid.replaceChildren(...items.map(card));
    if (!items.length) grid.append(h("li", { class: "card reg-empty" }, h("p", {}, "No services match."),
      h("button", { type: "button", class: "secondary", onclick: () => { Object.assign(state, { q: "", cat: "", tier: "", arch: "" }); writeFilters(); renderList(); } }, "Show all")));
    shown.textContent = items.length === state.list.length ? `${items.length} services` : `${items.length} of ${state.list.length} services`;
    // Chip counts follow the other filters, so a chip says what it would show.
    chips.replaceChildren(...[["", "All"], ...CATEGORIES].flatMap(([key, title]) => {
      const n = state.list.filter(p => matches(p, "cat") && (!key || (p.categories || []).includes(key))).length;
      if (key && !n && state.cat !== key) return [];
      return h("button", { type: "button", "aria-pressed": String(state.cat === key),
        onclick: () => { state.cat = key; update(); } }, title, h("span", { class: "reg-count" }, n));
    }));
  };

  const search = h("input", { type: "search", value: state.q, placeholder: "Search: photos, Git…", autocomplete: "off",
    "aria-label": "Search services", oninput: e => { state.q = e.target.value; update(); } });

  main.replaceChildren(
    h("section", { class: "reg-hero" },
      h("h1", {}, "Services for your ", h("span", { class: "gradient-text" }, "Roostack")),
      h("p", { class: "lede" }, "Every service a Roostack lab can install, reviewed by the registry's maintainers and read here from the same signed index your lab uses."),
      h("ul", { class: "figures reg-figures" },
        h("li", { class: "card" }, h("span", { class: "figure-value" }, state.list.length), h("span", { class: "figure-label" }, "services")),
        h("li", { class: "card" }, h("span", { class: "figure-value" }, versions), h("span", { class: "figure-label" }, "package versions")),
        h("li", { class: "card" }, h("span", { class: "figure-value" }, when(state.index.date, "short")), h("span", { class: "figure-label" }, "last published")))),
    // Wide screens: the filters down the left, the results beside them.
    h("div", { class: "reg-browse" },
    h("aside", { class: "reg-filters", "aria-label": "Search and filters" },
      h("label", { class: "reg-search" }, icon("search"), search),
      chips,
      h("details", { class: "reg-more", open: !matchMedia("(max-width: 640px)").matches || !!(state.tier || state.arch || state.sort !== "name") },
        h("summary", {}, "More filters"),
        h("div", { class: "reg-filter-row" },
        filterGroup("Who looks after it", segmented("Who looks after it", "tier", [["", "Any"], ["official", "Official"], ["community", "Community"]], state.tier, v => { state.tier = v; update(); })),
        filterGroup("Runs on", segmented("Runs on", "arch", [["", "Any"], ["amd64", "PC", "A PC: amd64, also called x86-64"], ["arm64", "ARM", "An ARM computer: arm64"]], state.arch, v => { state.arch = v; update(); })),
        filterGroup("Order", segmented("Order", "sort", [["name", "A–Z"], ["category", "Category"]], state.sort, v => { state.sort = v; update(); }))))),
    h("div", { class: "reg-results" }, shown, grid)));
  update();
}

function card(p) {
  const v = splitVersion(p.newest);
  return h("li", {}, h("article", { class: "card reg-card" },
    h("div", { class: "reg-card-head" }, logo(p),
      h("div", {}, h("h2", {}, h("a", { href: "#/" + encodeURIComponent(p.name) }, p.title)), tierBadge(p.tier))),
    h("p", { class: "reg-card-desc" }, p.description),
    h("div", { class: "reg-tags" }, (p.categories || []).map(c => h("span", { class: "reg-tag" }, CATEGORY[c] || c))),
    h("div", { class: "reg-card-foot" },
      h("span", { class: "reg-version", title: `Package ${p.newest}` }, v.app),
      h("span", {}, "·"), h("span", {}, arches(p.latest).join(", ")),
      p.versions.length > 1 ? [h("span", {}, "·"), h("span", {}, `${p.versions.length} versions`)] : null)));
}

// ---------- A service ----------

async function sha256(buf) {
  const d = await crypto.subtle.digest("SHA-256", buf);
  return [...new Uint8Array(d)].map(b => b.toString(16).padStart(2, "0")).join("");
}

// packageFile fetches a version's file, checks it against the index and
// reads it; each once.
function packageFile(entry) {
  if (!state.files.has(entry.path)) state.files.set(entry.path, (async () => {
    const res = await fetch(BASE + entry.path);
    if (!res.ok) throw new Error(`the registry answered ${res.status} for ${entry.path}`);
    const buf = await res.arrayBuffer();
    const sum = await sha256(buf);
    const text = new TextDecoder().decode(buf);
    return { text, sum, ok: sum === entry.sha256, pkg: sum === entry.sha256 ? YAML.parse(text) : null };
  })());
  return state.files.get(entry.path);
}

function section(title, ...body) {
  return h("section", { class: "card" }, h("div", { class: "card-head" }, h("h2", {}, title)), ...body);
}
function facts(rows) {
  rows = rows.filter(r => r && r[1] != null && r[1] !== "" && !(Array.isArray(r[1]) && !r[1].length));
  return rows.length ? h("dl", { class: "facts facts-lined" }, rows.flatMap(([k, v]) => [h("dt", {}, k), h("dd", {}, v)])) : null;
}
function link(url, text) {
  return /^https:\/\//.test(url || "") ? h("a", { href: url, rel: "noopener" }, text || url.replace(/^https:\/\//, "")) : null;
}
function code(text) { return h("code", {}, text); }

function imageParts(image) {
  const m = /^(.+?)(?::([^@/]+))?(?:@(sha256:[0-9a-f]{64}))?$/.exec(image || "");
  return m ? { repo: m[1], tag: m[2] || "", digest: m[3] || "" } : { repo: image, tag: "", digest: "" };
}

function settingType(s) {
  return ({ bool: "On or off", secret: s.generate ? "Secret, made by Roostack" : "Secret", string: "Text", int: "Number", choice: "A choice" })[s.type] || s.type || "Text";
}

async function renderService(name) {
  const p = state.list.find(x => x.name === name);
  const main = document.getElementById("main");
  if (!p) {
    main.replaceChildren(h("a", { class: "reg-back", href: "#/" }, icon("back"), "All services"),
      h("div", { class: "notice notice-warn" }, h("p", {}, `The registry has no service called “${name}”.`)));
    return;
  }
  document.title = `${p.title} · Roostack service registry`;
  const v = splitVersion(p.newest);
  const body = h("div", { class: "reg-cols" }, h("p", { class: "hint" }, "Reading its package file…"));
  main.replaceChildren(h("article", { class: "reg-detail" },
    h("a", { class: "reg-back", href: "#/" }, icon("back"), "All services"),
    h("div", { class: "page-head" },
      h("div", { class: "page-head-title" }, logo(p, 64),
        h("div", {}, h("h1", {}, p.title, " ", tierBadge(p.tier)),
          h("p", { class: "lede" }, p.description)))),
    body));
  window.scrollTo(0, 0);

  let file;
  try { file = await packageFile(p.latest); } catch (e) {
    body.replaceChildren(h("div", { class: "notice notice-error" }, h("p", {}, `This service's package file couldn't be read: ${e.message}.`)));
    return;
  }
  if (!file.ok) {
    body.replaceChildren(h("div", { class: "notice notice-error" }, h("p", {},
      `${p.latest.path} isn't the file the signed index names (its SHA-256 is ${file.sum}, the index says ${p.latest.sha256}), so this page won't show it.`)));
    return;
  }
  const pkg = file.pkg, about = pkg.about || {};
  const notice = (await loadNotices())[p.name];
  // The logo links to the project (as Plex's guidelines ask of its logo).
  const home = about.website || about.source;
  if (/^https:\/\//.test(home || "")) {
    const tile = main.querySelector(".page-head-title > .logo-tile");
    const a = h("a", { href: home, rel: "noopener", class: "reg-logo-link", title: `${p.title}'s website` });
    tile.before(a);
    a.append(tile);
  }
  const routes = Object.entries(pkg.routes || {}), storage = Object.entries(pkg.storage || {});
  const containers = Object.entries(pkg.containers || {});
  const memory = containers.map(([, c]) => c.memory).filter(Boolean);

  const left = h("div", { class: "reg-col" },
    section("About",
      facts([
        ["Made by", about.maker],
        ["Licence", about.licence === "closed" ? "Not open source" : about.licence],
        ["Source code", link(about.source)],
        ["Website", link(about.website)],
        ["Support the project", link(about.support)],
        ["Release notes", about.releases ? link(about.releases.replace("{version}", v.app), "For " + v.app) : null],
        ["Categories", (about.categories || p.categories || []).map(c => CATEGORY[c] || c).join(", ")],
        ["Keywords", (about.keywords || []).join(", ")],
      ]),
      notice ? h("p", { class: "hint reg-notice" }, notice) : null),
    routes.length ? section("Web addresses", ...routes.map(([key, r]) => h("div", { class: "reg-route" },
      h("h3", {}, r.subdomain ? [code(r.subdomain + "."), " your lab's address"] : key),
      facts([
        ["Who can reach it", r.exposure === "public" ? "Anyone on the internet, by default" : "Only your home and your devices, until you make it public"],
        ["Kept private when public", (r.public?.private_paths || []).length ? h("ul", { class: "reg-paths" },
          r.public.private_paths.map(pp => h("li", {}, code(pp.path), pp.reason ? h("span", { class: "hint" }, pp.reason) : null))) : null],
        ["Sign-in pages, rate-limited", (r.public?.login_paths || []).length ? h("ul", { class: "reg-paths" }, r.public.login_paths.map(lp => h("li", {}, code(lp)))) : null],
      ])))) : null,
    (pkg.settings || []).length ? section("Settings you choose",
      h("div", { class: "table-wrap" }, h("table", { class: "list" },
        h("thead", {}, h("tr", {}, h("th", {}, "Setting"), h("th", {}, "Kind"), h("th", {}, "Default"))),
        h("tbody", {}, pkg.settings.map(s => h("tr", {},
          h("td", { class: "wrap" }, s.title || s.key, s.description ? h("small", {}, s.description) : null),
          h("td", {}, settingType(s)),
          h("td", {}, s.type === "secret" ? "—" : s.default === undefined ? "—" : s.type === "bool" ? (s.default ? "On" : "Off") : String(s.default)))))))) : null,
    storage.length || pkg.databases ? section("What it keeps",
      h("div", { class: "table-wrap" }, h("table", { class: "list" },
        h("thead", {}, h("tr", {}, h("th", {}, "Data"), h("th", {}, "Backed up"))),
        h("tbody", {}, storage.map(([key, st]) => h("tr", {},
          h("td", { class: "wrap" }, st.title || key, h("small", {}, key)),
          h("td", {}, st.class === "critical" ? "Yes, by default" : st.class === "cache" ? "No: it can be made again" : st.class === "media" ? "Separately, as media" : (st.class || "Yes"))))))),
      Object.keys(pkg.databases || {}).length ? h("p", { class: "hint" }, "Databases: ",
        Object.entries(pkg.databases).map(([k, d]) => (DATABASE[d.type] || d.type || "a database") + (k === "main" ? "" : ` (${k})`)).join(", "),
        ". Roostack backs them up consistently, with the rest of its data.") : null) : null,
    pkg.sso ? section("Single sign-on",
      h("p", {}, "People sign in with their Roostack account (OpenID Connect), and the lab chooses who may."),
      pkg.sso.note ? h("p", { class: "hint" }, pkg.sso.note) : null) : null,
    (pkg.links || []).length ? section("Inside the app",
      facts(pkg.links.map(l => [l.title, [l.description || "", l.path ? [" ", code(l.path)] : null]]))) : null,
    h("details", { class: "card reg-file" },
      h("summary", {}, "The package file"),
      h("p", { class: "hint" }, "Exactly what your lab installs from, comments and all."),
      h("figure", { class: "code-panel" },
        h("figcaption", { class: "code-bar" }, p.latest.path),
        h("pre", {}, file.text))));

  const right = h("div", { class: "reg-col" },
    section("Checked",
      h("div", { class: "reg-check ok" }, icon("check"),
        h("div", {}, h("p", {}, "This package file matches the registry's signed index."),
          h("p", { class: "hint" }, "SHA-256 ", code(file.sum.slice(0, 16) + "…"), ", worked out in your browser.")))),
    section("This version",
      facts([
        ["App version", code(v.app)],
        ["Package revision", String(v.rev)],
        ["Runs on", arches(p.latest).map(a => ARCHES[a]).join(", ")],
        ["Needs Roostack", p.latest.requires_roostack ? p.latest.requires_roostack + " or newer" : null],
        ["Memory", memory.length ? memory.join(" + ") + ", typically" : null],
      ])),
    containers.length ? section("Containers",
      facts(containers.map(([key, c]) => { const im = imageParts(c.image);
        return [key, [code(im.repo + (im.tag ? ":" + im.tag : "")), im.digest ? h("small", { class: "hint", style: "display:block" }, "pinned to ", code(im.digest.slice(0, 19) + "…")) : null]]; }))) : null,
    section("Versions",
      h("div", { class: "table-wrap" }, h("table", { class: "list" },
        h("thead", {}, h("tr", {}, h("th", {}, "Package"), h("th", {}, "File"))),
        h("tbody", {}, [...p.versions].reverse().map(ver => h("tr", {},
          h("td", {}, code(ver), ver === p.newest ? h("small", {}, "Offered to labs") : null),
          h("td", {}, h("a", { href: BASE + state.index.packages[p.name].versions[ver].path }, "YAML")))))))),
    section("Install it",
      h("p", {}, "In your lab: ", h("strong", {}, "Services → Add a service"), ", then ", h("strong", {}, p.title), "."),
      h("p", { class: "hint" }, "Your lab checks this file's signature itself before it installs anything.")));
  body.replaceChildren(left, right);
}

// ---------- Routing and the mode ----------

function route() {
  const m = /^#\/([^?]+)$/.exec(location.hash);
  if (m) renderService(decodeURIComponent(m[1]));
  else { document.title = "Roostack service registry"; renderList(); }
}

function setUpMode() {
  const btn = document.getElementById("mode");
  const dark = () => document.documentElement.dataset.mode === "dark" ||
    (!document.documentElement.dataset.mode && matchMedia("(prefers-color-scheme: dark)").matches);
  const paint = () => btn.replaceChildren(icon(dark() ? "light" : "dark"));
  try { const m = localStorage.getItem("reg-mode"); if (m) document.documentElement.dataset.mode = m; } catch {}
  btn.addEventListener("click", () => {
    const m = dark() ? "light" : "dark";
    document.documentElement.dataset.mode = m;
    try { localStorage.setItem("reg-mode", m); } catch {}
    paint();
  });
  paint();
}

addEventListener("DOMContentLoaded", async () => {
  setUpMode();
  try { await load(); } catch (e) {
    document.getElementById("main").replaceChildren(h("div", { class: "notice notice-error" },
      h("p", {}, `The registry's index couldn't be read: ${e.message}.`)));
    return;
  }
  addEventListener("hashchange", route);
  route();
});
