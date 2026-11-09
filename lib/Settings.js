.pragma library

// Defaults and coercion for Omavisor's inline shell.json settings.
//
// shell.json is hand-editable, so any key can be missing, null, the wrong
// type or out of range. Every read goes through resolve() so a bad value
// falls back to its default instead of breaking rendering. The defaults
// mirror manifest.json's barWidget.defaults; keep the two in step.
// birthYear, lifeExpectancy and weekStartDay are read like the stock
// clock's (lib/Calendar.js parses them) and pass through untouched.
// tabs, tabsSeen and pillItems are the exception to mirroring the manifest: they stay out
// of its defaults, because a missing key is what means "follow the defaults"
// (and for pillItems, follow `mode`). Nothing is written until the user changes
// something.

.import "Catalog.js" as Catalog
.import "Actions.js" as Actions
.import "Visualizer.js" as Visualizer

var DEFAULTS = {
  mode: "replace",
  format: "dddd h:mm AP",
  formatAlt: "d MMMM 'W'ww yyyy",
  verticalFormat: "HH\n—\nmm",
  verticalFormatAlt: "dd\nMMM",
  openOn: "hover",
  peekDelayMs: 250,
  tabs: Catalog.MINIMAL_TABS.slice(),
  tabsSeen: [],
  homeTiles: ["media", "weather", "timers", "updates"],
  pillItems: ["clock", "media", "badge"],
  activityRules: {},
  scrollAction: "auto",
  updatePollMinutes: 360,
  pkgPollMinutes: 60,
  statsWhileOpenMs: 1000,
  allowActions: true,
  reduceMotion: "auto",
  unit: "auto",
  remoteArt: true,
  actions: [],
  visualizerStyle: "bars",
  hubOpacity: 85,
  corners: "auto"
}

var SPECS = {
  mode: { type: "enum", options: ["replace", "wrap"] },
  format: { type: "string" },
  formatAlt: { type: "string" },
  verticalFormat: { type: "string" },
  verticalFormatAlt: { type: "string" },
  openOn: { type: "enum", options: ["hover", "click"] },
  peekDelayMs: { type: "integer", min: 0, max: 2000 },
  tabs: { type: "multiselect", options: Catalog.ids(Catalog.TABS) },
  tabsSeen: { type: "multiselect", options: Catalog.ids(Catalog.TABS) },
  homeTiles: { type: "multiselect", options: Catalog.ids(Catalog.TILES) },
  pillItems: { type: "multiselect", options: Catalog.ids(Catalog.PILL_ITEMS) },
  visualizerStyle: { type: "enum", options: Visualizer.STYLES },
  hubOpacity: { type: "integer", min: 40, max: 100 },
  corners: { type: "enum", options: ["auto", "square", "round"] },
  activityRules: { type: "rules" },
  scrollAction: { type: "enum", options: ["auto", "volume", "workspace", "none"] },
  updatePollMinutes: { type: "integer", min: 30, max: 1440 },
  pkgPollMinutes: { type: "integer", min: 15, max: 1440 },
  statsWhileOpenMs: { type: "integer", min: 250, max: 10000 },
  allowActions: { type: "boolean" },
  reduceMotion: { type: "enum", options: ["auto", "on", "off"] },
  unit: { type: "enum", options: ["auto", "metric", "imperial"] },
  remoteArt: { type: "boolean" },
  actions: { type: "actions" }
}

// What customizing the hub writes: a layout restore leaves these as they are
// (lib/Layout.js), since they are choices made after the backup, not layout.
var CUSTOMIZATION_KEYS = ["tabs", "tabsSeen", "homeTiles", "pillItems", "activityRules"]
// What a layout restore keeps as it is now: the customization, and your own
// commands (which Reset leaves alone too).
var RESTORE_KEEPS = CUSTOMIZATION_KEYS.concat(["actions"])

function copy(value) {
  if (Array.isArray(value)) return value.slice()
  return value !== null && typeof value === "object" ? Object.assign({}, value) : value
}

// The pill without a `pillItems` list, from the answer to the first-run card.
function defaultPillItems(mode) {
  return mode === "wrap" ? ["glyph", "badge"] : copy(DEFAULTS.pillItems)
}

// One key: the value when it is valid for the key, else the default.
// Unknown keys pass through untouched so later settings are not lost.
// `fallback` replaces the key's default, for one that depends on another key.
function coerce(key, value, fallback) {
  var spec = SPECS[key]
  if (fallback === undefined) fallback = copy(DEFAULTS[key])
  if (!spec) return value
  if (value === undefined || value === null) return fallback

  switch (spec.type) {
  case "string":
    return typeof value === "string" && value !== "" ? value : fallback
  case "enum":
    return spec.options.indexOf(value) !== -1 ? value : fallback
  case "boolean":
    if (typeof value === "boolean") return value
    if (value === "true") return true
    if (value === "false") return false
    return fallback
  case "integer": {
    var n = typeof value === "string" && value.trim() !== "" ? Number(value) : value
    if (typeof n !== "number" || !isFinite(n)) return fallback
    return Math.min(spec.max, Math.max(spec.min, Math.round(n)))
  }
  case "multiselect": {
    // A list given as one string ("media weather stats", spaces, commas or
    // "+" between names): `omarchy bar set … --json` can't pass a JSON array,
    // since omarchy-shell splits its arguments on commas.
    // A JSON array given without --json arrives as its text.
    if (typeof value === "string" && /^\s*\[/.test(value)) {
      try { value = JSON.parse(value) } catch (e) { return fallback }
    }
    if (typeof value === "string") value = value.split(/[\s,+]+/).filter(function(v) { return v !== "" })
    if (!Array.isArray(value)) return fallback
    var out = []
    for (var i = 0; i < value.length; i++) {
      if (spec.options.indexOf(value[i]) !== -1 && out.indexOf(value[i]) === -1) out.push(value[i])
    }
    return out
  }
  case "actions":
    return Actions.parse(value)
  case "rules": {
    // { category: level }. As text when given without --json.
    if (typeof value === "string") {
      try { value = JSON.parse(value) } catch (e) { return fallback }
    }
    if (value === null || typeof value !== "object" || Array.isArray(value)) return fallback
    var rules = {}
    for (var category in value) {
      if (Catalog.ACTIVITY_CATEGORIES.indexOf(category) !== -1 && Catalog.ACTIVITY_LEVELS.indexOf(value[category]) !== -1)
        rules[category] = value[category]
    }
    return rules
  }
  }
  return fallback
}

// The full settings object: every known key coerced, unknown keys kept.
function resolve(settings) {
  var source = settings && typeof settings === "object" && !Array.isArray(settings) ? settings : {}
  var out = {}
  for (var extra in source) {
    if (!(extra in SPECS)) out[extra] = source[extra]
  }
  for (var key in SPECS) out[key] = coerce(key, source[key])
  out.pillItems = coerce("pillItems", source.pillItems, defaultPillItems(out.mode))
  return out
}

// A tab name from a payload or IPC argument, or "" when it names none.
function normalizeTab(value) {
  var tab = String(value === undefined || value === null ? "" : value).toLowerCase().trim()
  return Catalog.find(Catalog.TABS, tab) !== null || tab === Catalog.SETTINGS_TAB.id ? tab : ""
}
