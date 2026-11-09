.pragma library

// What the Settings page does to the customization keys: rows to draw and the
// changes a toggle or a move makes. Pure, so it is tested without a window.
// docs/customization-plan.md has the rules.

.import "Catalog.js" as Catalog

// `raw` with `changes` laid over it: null removes a key. What the page writes
// is this, never the resolved settings, or every default would land in
// shell.json.
function applyChanges(raw, changes) {
  var out = {}
  for (var key in raw) out[key] = raw[key]
  for (var change in changes) {
    if (changes[change] === null) delete out[change]
    else out[change] = changes[change]
  }
  return out
}

// `changes` less the ones `raw` already has: what is still to be written.
function unsaved(raw, changes) {
  var out = {}
  for (var key in changes) {
    var wanted = changes[key] === null ? undefined : changes[key]
    if (JSON.stringify(raw ? raw[key] : undefined) !== JSON.stringify(wanted)) out[key] = changes[key]
  }
  return out
}

// The list with `id` on (at its end) or off.
function toggled(list, id) {
  return list.indexOf(id) !== -1 ? list.filter(function(item) { return item !== id }) : list.concat([id])
}

// `id` swapped with its neighbour `direction` (-1 or 1) away, stepping over the
// `fixed` ids, whose place means nothing. The same list when it can't go there.
function moved(list, id, direction, fixed) {
  var from = list.indexOf(id)
  if (from === -1) return list
  var to = from + direction
  while (to >= 0 && to < list.length && fixed.indexOf(list[to]) !== -1) to += direction
  if (to < 0 || to >= list.length) return list
  var out = list.slice()
  out[from] = list[to]
  out[to] = id
  return out
}

function fixedIds(catalog) {
  return catalog.filter(function(item) { return item.fixed === true }).map(function(item) { return item.id })
}

// The tabs the switches stand for.
function tabList(config) {
  return config.tabs.slice()
}

// Tabs an update added since the list was last edited here, which stay hidden.
// A list set from the command line has no record of what it knew, so nothing in
// it counts as new.
function newTabs(config) {
  var seen = config.tabsSeen
  if (seen.length === 0) return []
  return Catalog.ids(Catalog.TABS).filter(function(id) { return seen.indexOf(id) === -1 && config.tabs.indexOf(id) === -1 })
}

// One row per catalog item: the listed ones in their order, then the rest.
// `canHide(id)` says whether the switch may turn a listed one off.
function rows(catalog, list, service, config, canHide, isNew) {
  var fixed = fixedIds(catalog)
  var rest = Catalog.ids(catalog).filter(function(id) { return list.indexOf(id) === -1 })
  return list.concat(rest).map(function(id) {
    var item = Catalog.find(catalog, id)
    var listed = list.indexOf(id) !== -1
    return {
      id: id,
      label: item.label,
      listed: listed,
      available: item.available(service, config),
      isNew: isNew.indexOf(id) !== -1,
      canToggle: !listed || canHide(id),
      canMoveUp: listed && fixed.indexOf(id) === -1 && moved(list, id, -1, fixed) !== list,
      canMoveDown: listed && fixed.indexOf(id) === -1 && moved(list, id, 1, fixed) !== list,
      movable: fixed.indexOf(id) === -1
    }
  })
}

function tabRows(config, service) {
  var list = tabList(config)
  function canHide(id) {
    return Catalog.shown(Catalog.TABS, toggled(list, id), service, config).length > 0
  }
  return rows(Catalog.TABS, list, service, config, canHide, newTabs(config))
}

function tileRows(config, service) {
  return rows(Catalog.TILES, config.homeTiles, service, config, function() { return true }, [])
}

function pillRows(config, service) {
  var list = config.pillItems
  // The pill needs something that always shows, to be hovered and clicked.
  function canHide(id) {
    if (id !== "clock" && id !== "glyph") return true
    return list.indexOf(id === "clock" ? "glyph" : "clock") !== -1
  }
  return rows(Catalog.PILL_ITEMS, list, service, config, canHide, [])
}

// A drag in the pill: `id` moved to `index` among what the pill draws
// (`row`, Catalog.pillRow). The new pillItems: the row in its new order,
// then whatever the list has that isn't drawn (an item that can't show
// now, the badge, the spot's other choice), as it was.
function movePillItem(list, row, id, index) {
  var from = row.indexOf(id)
  if (from === -1) return list.slice()
  var next = row.filter(function(item) { return item !== id })
  var to = Math.max(0, Math.min(next.length, index))
  next.splice(to, 0, id)
  return next.concat(list.filter(function(item) { return next.indexOf(item) === -1 }))
}

// The Pill switch: as toggled(), but the album art and the levels share one
// spot, so switching one on takes the other off.
function togglePillItem(config, id) {
  var list = config.pillItems
  if (Catalog.MEDIA_SPOT.indexOf(id) === -1 || list.indexOf(id) !== -1) return toggled(list, id)
  return list.filter(function(item) { return Catalog.MEDIA_SPOT.indexOf(item) === -1 }).concat([id])
}

function activityRows(config) {
  return Catalog.ACTIVITY_CATEGORIES.map(function(category) {
    return { id: category, label: Catalog.ACTIVITY_LABELS[category], level: config.activityRules[category] || "bloom" }
  })
}

// The changes the Tabs switch makes. What the list has known so far is
// written with it (see newTabs): everything
// on the first edit, after that only the tab just touched, so another tab's New mark
// stays until it is touched too.
function tabChanges(config, id, list) {
  var seen = config.tabsSeen.length > 0 ? config.tabsSeen : Catalog.ids(Catalog.TABS)
  var out = { tabs: list, tabsSeen: id !== "" && seen.indexOf(id) === -1 ? seen.concat([id]) : seen }
  return out
}

function toggleTab(config, id) { return tabChanges(config, id, toggled(tabList(config), id)) }
function moveTab(config, id, direction) { return tabChanges(config, "", moved(tabList(config), id, direction, [])) }

// The next level up, wrapping round to quiet. Bloom is the same as no rule, so
// it removes the rule, and an empty set of rules removes the key.
function nextLevelChanges(config, category) {
  var levels = Catalog.ACTIVITY_LEVELS
  var now = config.activityRules[category] || "bloom"
  var next = levels[(levels.indexOf(now) + 1) % levels.length]
  var rules = {}
  for (var key in config.activityRules) if (key !== category) rules[key] = config.activityRules[key]
  if (next !== "bloom") rules[category] = next
  return { activityRules: Object.keys(rules).length > 0 ? rules : null }
}

// What Reset clears. `mode`, the clock's formats and the rest are not choices
// made on this page.
function resetChanges(keys) {
  var out = {}
  keys.forEach(function(key) { out[key] = null })
  return out
}

// Whether the choices leave the timers on no tab, for the page to say so.
// A running timer is a live activity, so Activity shows it too.
function timersUnseen(config, service) {
  var tabs = Catalog.shownTabs(config, service)
  return tabs.indexOf("system") === -1 && tabs.indexOf("activities") === -1 && !Catalog.timersOnHome(config, service)
}
