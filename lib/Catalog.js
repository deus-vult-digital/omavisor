.pragma library

// What the hub can show: its tabs, Home tiles and pill items, each with an id,
// a label and whether it can show right now. The Settings keys `tabs`,
// `homeTiles` and `pillItems` list these ids (lib/Settings.js), and everything
// below is worked out when read: listed means shown, in that order.
//
// Each `available` takes Omavisor's service and the resolved settings. Called from
// a QML binding it reads live properties, so the binding follows them.
// docs/customization-plan.md has the rules.

function always() { return true }

var TABS = [
  { id: "home", label: "Home", icon: "󰋜", available: always },
  { id: "media", label: "Now playing", icon: "󰝚", available: always },
  { id: "calendar", label: "Calendar", icon: "󰃭", available: always },
  { id: "capture", label: "Capture", icon: "󰄀", available: always },
  { id: "system", label: "System", icon: "󰍛", available: always },
  { id: "theme", label: "Theme", icon: "󰏘", available: function(s) { return !!s && !!s.theme && s.theme.available } },
  { id: "activities", label: "Activity", icon: "󱐋", available: always },
  { id: "keys", label: "Keys", icon: "󰌌", available: always }
]

var TILES = [
  { id: "media", label: "Media", available: function(s) { return !!s && !!s.media && s.media.available } },
  { id: "weather", label: "Weather", available: function(s) { return !!s && !!s.weather && s.weather.available } },
  { id: "timers", label: "Timers", available: function(s) { return !!s && !!s.timers } },
  { id: "updates", label: "Updates", available: function(s) {
    return !!s && ((!!s.updates && s.updates.available) || (!!s.packages && s.packages.available))
  } },
  { id: "capture", label: "Capture", available: function(s) { return !!s && !!s.capture } },
  { id: "stats", label: "Stats", available: function(s) { return !!s && !!s.stats } },
  { id: "power", label: "Power", available: function(s) { return !!s && !!s.power && s.power.available } },
  { id: "hypr", label: "Hyprland", available: function(s) { return !!s && !!s.hypr && s.hypr.available } },
  // Your own commands (`actions`); only once there is one.
  { id: "actions", label: "Actions", available: function(s, c) { return !!c && Array.isArray(c.actions) && c.actions.length > 0 } },
  { id: "today", label: "Today", available: always }
]

var PILL_ITEMS = [
  { id: "clock", label: "Clock", available: always },
  { id: "weather", label: "Weather", available: function(s) { return !!s && !!s.weather && s.weather.available } },
  { id: "glyph", label: "Glyph", available: always },
  // The track while a player plays (pillParts drops it while paused). Listed
  // as available while there is a player at all, so Settings doesn't dim it
  // for a pause.
  // While a player plays, one spot left of the clock shows the album art or
  // a small level meter: the two share it (MEDIA_SPOT), so listing one
  // takes the other off. The spot keeps its room while either is listed.
  { id: "media", label: "Album art", available: function(s) { return !!s && !!s.media && s.media.available } },
  { id: "meter", label: "Audio levels", available: function(s) { return !!s && !!s.media && s.media.available } },
  // Sits around the rest of the pill, so its place in the list means nothing.
  { id: "badge", label: "Badge", available: always, fixed: true }
]

// What a new install shows: now playing, the calendar and live activity. The
// rest are a switch away on the Settings page.
var MINIMAL_TABS = ["media", "calendar", "activities"]

// The pill items that share the spot left of the clock.
var MEDIA_SPOT = ["media", "meter"]

// What the spot shows while a player plays: "media" (art), "meter" or "".
// The first listed wins, should a list name both.
function pillSpot(config) {
  var list = config && Array.isArray(config.pillItems) ? config.pillItems : []
  for (var i = 0; i < list.length; i++) if (MEDIA_SPOT.indexOf(list[i]) !== -1) return list[i]
  return ""
}

// The Settings page: a tab no list can hide, reached by the gear and by name.
var SETTINGS_TAB = { id: "settings", label: "Settings", icon: "󰒓" }

// An activity's interruption levels, least first, and the groups a rule can
// name (`activityRules`).
var ACTIVITY_LEVELS = ["quiet", "badge", "peek", "bloom"]
var ACTIVITY_CATEGORIES = ["timers", "recording", "updates", "units", "privacy", "dictation", "agents", "notices", "other"]
var ACTIVITY_LABELS = {
  timers: "Timers", recording: "Recording", updates: "Updates", units: "Failed units",
  privacy: "Mic & camera", dictation: "Dictation", agents: "Agents", notices: "Notices", other: "Other"
}

// Home holds this many tiles.
var HOME_SLOTS = 4

function ids(list) {
  return list.map(function(item) { return item.id })
}

function find(list, id) {
  for (var i = 0; i < list.length; i++) if (list[i].id === id) return list[i]
  return null
}

// The ids in `wanted` that can show now, in that order.
function shown(list, wanted, service, config) {
  if (!Array.isArray(wanted)) return []
  return wanted.filter(function(id) {
    var item = find(list, id)
    return item !== null && item.available(service, config)
  })
}

function tabAvailable(id, service, config) {
  if (id === SETTINGS_TAB.id) return true
  return shown(TABS, [id], service, config).length === 1
}

// The tab strip. Never empty: with nothing to show, Home.
function shownTabs(config, service) {
  var wanted = config && Array.isArray(config.tabs) ? config.tabs : ids(TABS)
  var out = shown(TABS, wanted, service, config)
  return out.length > 0 ? out : ["home"]
}

// Strip entries for tab ids, in that order.
function tabEntries(tabIds) {
  return tabIds.map(function(id) { return find(TABS, id) }).filter(function(tab) { return tab !== null })
}

// Where an open with no tab named lands: the last tab viewed while the strip
// still has it, else the first in the strip. (A hidden tab opens only when
// asked for by name.) `by` is how it was opened, kept for callers.
function startTab(current, tabs, by) {
  if (tabs.indexOf(current) !== -1) return current
  return tabs.length > 0 ? tabs[0] : "home"
}

// The Home tiles. The first ones listed that can show, up to the slots there
// are. A Today tile fills in for a listed tile that can't show, and shows alone
// when nothing else does.
function homeTiles(config, service) {
  var wanted = config && Array.isArray(config.homeTiles) ? config.homeTiles : []
  var out = []
  var skipped = false
  for (var i = 0; i < wanted.length && out.length < HOME_SLOTS; i++) {
    var tile = find(TILES, wanted[i])
    if (tile === null) continue
    if (tile.available(service, config)) out.push(tile.id)
    else skipped = true
  }
  if ((skipped && out.length < HOME_SLOTS && out.indexOf("today") === -1) || out.length === 0) out.unshift("today")
  return out
}

// Whether Home is where the timers are, so System need not show them too.
function timersOnHome(config, service) {
  return shownTabs(config, service).indexOf("home") !== -1
    && homeTiles(config, service).indexOf("timers") !== -1
}

// What the pill shows. Never empty, or it would have nothing to hover or click:
// the clock, or the glyph in wrap mode.
function shownPillItems(config, service) {
  var out = shown(PILL_ITEMS, config ? config.pillItems : [], service, config)
  if (out.length > 0) return out
  return [config && config.mode === "wrap" ? "glyph" : "clock"]
}

// The pill's text parts, in order: the items that aren't the badge or the
// album art / levels spot (drawn, not text; pillRow places it). On a left
// or right bar weather has no room. Never empty, for the reason above, even
// with only the badge listed: a badge shows only while there is an activity.
function pillParts(config, service, vertical) {
  var out = shownPillItems(config, service).filter(function(id) {
    if (id === "badge" || MEDIA_SPOT.indexOf(id) !== -1) return false
    if (vertical && id === "weather") return false
    return true
  })
  return out.length > 0 ? out : [config && config.mode === "wrap" ? "glyph" : "clock"]
}

// What the pill draws along a top or bottom bar, in order: the text parts
// (pillParts) and the album art or levels spot (pillSpot), which keeps its
// place whether or not a player plays. The badge sits around it all, so it
// is not here. Never empty (pillParts never is).
function pillRow(config, service) {
  var parts = pillParts(config, service, false)
  var spot = pillSpot(config)
  var list = config && Array.isArray(config.pillItems) ? config.pillItems : []
  var out = []
  list.forEach(function(id) {
    if (id === spot || parts.indexOf(id) !== -1) out.push(id)
  })
  // A fallback part (the clock when nothing listed shows) isn't in the list.
  parts.forEach(function(id) { if (out.indexOf(id) === -1) out.push(id) })
  return out
}

// The group an activity's id belongs to, for `activityRules`.
function activityCategory(id) {
  var text = String(id)
  if (text.indexOf("timer:") === 0) return "timers"
  if (text.indexOf("claude:") === 0) return "agents"
  // The recording, and the bloom when it is saved (omavisor:recording-saved).
  if (text.indexOf("omavisor:recording") === 0) return "recording"
  // Power, monitors, Bluetooth (lib/Notices.js).
  if (text.indexOf("omavisor:notice-") === 0) return "notices"
  switch (text) {
  case "omavisor:update": return "updates"
  case "omavisor:units": return "units"
  case "omavisor:mic": case "omavisor:camera": return "privacy"
  case "omavisor:dictation": return "dictation"
  }
  return "other"
}

// Whether a rule lets this activity reach `level`. A rule is a ceiling: it only
// lowers what an activity asks for, and no rule means no limit.
function activityAllows(rules, id, level) {
  var ceiling = rules ? rules[activityCategory(id)] : undefined
  if (ACTIVITY_LEVELS.indexOf(ceiling) === -1) return true
  return ACTIVITY_LEVELS.indexOf(level) <= ACTIVITY_LEVELS.indexOf(ceiling)
}

// The activity the pill's badge shows: the first one allowed one.
function firstBadged(items, rules) {
  for (var i = 0; i < items.length; i++) if (activityAllows(rules, items[i].id, "badge")) return items[i]
  return null
}
