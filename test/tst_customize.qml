import QtQuick
import QtTest
import "../lib/Catalog.js" as Catalog
import "../lib/Customize.js" as Customize
import "../lib/Settings.js" as Settings

TestCase {
  name: "Customize"

  function service(off) {
    return Object.assign({
      media: { available: true }, weather: { available: true }, timers: {},
      updates: { available: true }, packages: { available: true }, capture: {}, stats: {},
      power: { available: true }, hypr: { available: true }, theme: { available: true }
    }, off)
  }
  function cfg(settings) { return Settings.resolve(settings) }
  function row(rows, id) { return rows.filter(function(r) { return r.id === id })[0] }
  function ids(rows) { return rows.map(function(r) { return r.id }) }

  function test_changesGoOverTheRawEntryOnly() {
    var raw = { mode: "wrap", format: "HH:mm", tabs: ["home"] }
    compare(Customize.applyChanges(raw, { tabs: ["keys"], homeTiles: ["media"] }),
      { mode: "wrap", format: "HH:mm", tabs: ["keys"], homeTiles: ["media"] })
    compare(Customize.applyChanges(raw, { tabs: null }), { mode: "wrap", format: "HH:mm" })
    compare(raw.tabs, ["home"])
  }

  function test_unsavedDropsWhatTheEntryHas() {
    compare(Customize.unsaved({ tabs: ["home"] }, { tabs: ["home"], pillItems: ["clock"] }), { pillItems: ["clock"] })
    compare(Customize.unsaved({ tabs: ["home"] }, { tabs: null }), { tabs: null })
    compare(Customize.unsaved({}, { tabs: null }), {})
  }

  function test_toggled() {
    compare(Customize.toggled(["a", "b"], "a"), ["b"])
    compare(Customize.toggled(["a", "b"], "c"), ["a", "b", "c"])
  }

  function test_moved() {
    compare(Customize.moved(["a", "b", "c"], "b", -1, []), ["b", "a", "c"])
    compare(Customize.moved(["a", "b", "c"], "b", 1, []), ["a", "c", "b"])
    compare(Customize.moved(["a", "b"], "a", -1, []), ["a", "b"])
    compare(Customize.moved(["a", "b"], "b", 1, []), ["a", "b"])
    compare(Customize.moved(["a", "b"], "z", 1, []), ["a", "b"])
    // Over the badge, whose place means nothing.
    compare(Customize.moved(["clock", "badge", "weather"], "clock", 1, ["badge"]), ["weather", "badge", "clock"])
    compare(Customize.moved(["clock", "badge"], "clock", 1, ["badge"]), ["clock", "badge"])
  }

  function test_tabRowsListedFirstThenTheRest() {
    var rows = Customize.tabRows(cfg({ tabs: "keys home" }), service())
    compare(ids(rows).slice(0, 3), ["keys", "home", "media"])
    compare(row(rows, "keys").listed, true)
    compare(row(rows, "keys").canMoveUp, false)
    compare(row(rows, "keys").canMoveDown, true)
    compare(row(rows, "home").canMoveDown, false)
    compare(row(rows, "media").listed, false)
    compare(row(rows, "media").canMoveUp, false)
    compare(rows.length, Catalog.TABS.length)
  }

  function test_lastTabCannotBeHidden() {
    var rows = Customize.tabRows(cfg({ tabs: "keys" }), service())
    compare(row(rows, "keys").canToggle, false)
    compare(row(rows, "home").canToggle, true)
    // A listed tab that can't show doesn't count.
    rows = Customize.tabRows(cfg({ tabs: "keys theme" }), service({ theme: { available: false } }))
    compare(row(rows, "keys").canToggle, false)
    compare(row(rows, "theme").canToggle, true)
  }

  function test_toggleTab() {
    compare(Customize.toggleTab(cfg({ tabs: "home" }), "keys").tabs, ["home", "keys"])
    compare(Customize.toggleTab(cfg({ tabs: "home keys" }), "keys").tabs, ["home"])
  }

  function test_firstEditMovesTheDefaults() {
    var out = Customize.moveTab(cfg({}), "calendar", -1)
    compare(out.tabs, ["calendar", "media", "activities"])
  }

  function test_newTabsStayHiddenAndMarked() {
    // A tab the list never knew of: the first entry here is one from a later version.
    var known = Catalog.ids(Catalog.TABS).filter(function(id) { return id !== "keys" })
    var config = cfg({ tabs: "home media", tabsSeen: known })
    compare(Customize.newTabs(config), ["keys"])
    var rows = Customize.tabRows(config, service())
    compare(row(rows, "keys").isNew, true)
    compare(row(rows, "keys").listed, false)
    compare(row(rows, "media").isNew, false)
    // No list, or a list from the command line, has nothing new.
    compare(Customize.newTabs(cfg({})), [])
    compare(Customize.newTabs(cfg({ tabs: "home" })), [])
    // Listed by hand it is no longer new.
    compare(Customize.newTabs(cfg({ tabs: "home keys", tabsSeen: known })), [])
  }

  function test_newMarkClearsOnlyWhenTouched() {
    var known = Catalog.ids(Catalog.TABS).filter(function(id) { return id !== "keys" && id !== "theme" })
    var config = cfg({ tabs: "home media", tabsSeen: known })
    // Another tab's change leaves both marks.
    compare(Customize.newTabs(cfg(Object.assign({}, { tabs: "home" }, { tabsSeen: Customize.toggleTab(config, "media").tabsSeen }))), ["theme", "keys"])
    compare(Customize.newTabs(cfg({ tabs: "home media", tabsSeen: Customize.moveTab(config, "media", -1).tabsSeen })), ["theme", "keys"])
    // Turned on, then off again, it has been seen.
    var seen = Customize.toggleTab(config, "keys").tabsSeen
    compare(Customize.newTabs(cfg({ tabs: "home media", tabsSeen: seen })), ["theme"])
  }

  function test_firstEditRecordsWhatExists() {
    compare(Customize.toggleTab(cfg({}), "media").tabsSeen, Catalog.ids(Catalog.TABS))
    compare(Customize.moveTab(cfg({ tabs: "home keys" }), "keys", -1).tabsSeen, Catalog.ids(Catalog.TABS))
  }

  function test_pillKeepsAClockOrGlyph() {
    var rows = Customize.pillRows(cfg({ pillItems: "clock weather badge" }), service())
    compare(row(rows, "clock").canToggle, false)
    compare(row(rows, "weather").canToggle, true)
    compare(row(rows, "glyph").canToggle, true)
    rows = Customize.pillRows(cfg({ pillItems: "clock glyph" }), service())
    compare(row(rows, "clock").canToggle, true)
    compare(row(rows, "glyph").canToggle, true)
  }

  function test_badgeHasNoPlaceToMove() {
    var rows = Customize.pillRows(cfg({ pillItems: "clock badge weather" }), service())
    compare(row(rows, "badge").movable, false)
    compare(row(rows, "badge").canMoveUp, false)
    compare(row(rows, "badge").canMoveDown, false)
    compare(row(rows, "clock").movable, true)
    compare(row(rows, "clock").canMoveDown, true)
    compare(row(rows, "weather").canMoveUp, true)
    rows = Customize.pillRows(cfg({ pillItems: "clock badge" }), service())
    compare(row(rows, "clock").canMoveDown, false)
  }

  function test_tileRowsMayAllGoOff() {
    var rows = Customize.tileRows(cfg({ homeTiles: "media" }), service())
    compare(row(rows, "media").canToggle, true)
    compare(row(rows, "power").available, true)
    rows = Customize.tileRows(cfg({ homeTiles: "power" }), service({ power: { available: false } }))
    compare(row(rows, "power").available, false)
    compare(row(rows, "power").listed, true)
  }

  function test_levelsCycleAndBloomMeansNoRule() {
    compare(Customize.activityRows(cfg({}))[0], { id: "timers", label: "Timers", level: "bloom" })
    compare(Customize.nextLevelChanges(cfg({}), "timers"), { activityRules: { timers: "quiet" } })
    compare(Customize.nextLevelChanges(cfg({ activityRules: { timers: "quiet" } }), "timers"), { activityRules: { timers: "badge" } })
    compare(Customize.nextLevelChanges(cfg({ activityRules: { timers: "badge" } }), "timers"), { activityRules: { timers: "peek" } })
    compare(Customize.nextLevelChanges(cfg({ activityRules: { timers: "peek" } }), "timers"), { activityRules: null })
    compare(Customize.nextLevelChanges(cfg({ activityRules: { timers: "peek", other: "quiet" } }), "timers"), { activityRules: { other: "quiet" } })
  }

  function test_resetClearsOnlyTheCustomization() {
    var raw = { mode: "wrap", format: "HH:mm", tabs: ["home"], tabsSeen: ["home"], homeTiles: ["media"], pillItems: ["clock"], activityRules: { other: "quiet" }, birthYear: 1983 }
    compare(Customize.applyChanges(raw, Customize.resetChanges(Settings.CUSTOMIZATION_KEYS)), { mode: "wrap", format: "HH:mm", birthYear: 1983 })
  }

  function test_timersUnseen() {
    // The minimal strip has no Home or System; a running timer shows on
    // Activity, so nothing is hidden from you.
    compare(Customize.timersUnseen(cfg({}), service()), false)
    compare(Customize.timersUnseen(cfg({ tabs: "media calendar" }), service()), true)
    compare(Customize.timersUnseen(cfg({ tabs: "home keys", homeTiles: "media" }), service()), true)
    compare(Customize.timersUnseen(cfg({ tabs: "home system", homeTiles: "media" }), service()), false)
    compare(Customize.timersUnseen(cfg({ tabs: "home keys", homeTiles: "timers" }), service()), false)
  }

  // ---- The catalog's side of pill items and rules.

  function test_settingsTabOpensByNameOnly() {
    compare(Settings.normalizeTab("settings"), "settings")
    compare(Catalog.tabAvailable("settings", null, cfg({})), true)
    compare(Catalog.shownTabs(cfg({ tabs: "settings home" }), service()), ["home"])
    compare(Catalog.startTab("settings", ["home", "keys"], "hover"), "home")
  }

  // Dragging in the pill reorders what it draws and keeps the rest.
  function test_movePillItem() {
    var list = ["clock", "media", "badge", "weather"]
    var row = ["clock", "media", "weather"]
    compare(Customize.movePillItem(list, row, "media", 0), ["media", "clock", "weather", "badge"])
    compare(Customize.movePillItem(list, row, "media", 9), ["clock", "weather", "media", "badge"])
    compare(Customize.movePillItem(list, row, "clock", 2), ["media", "weather", "clock", "badge"])
    compare(Customize.movePillItem(list, row, "nope", 0), list)
    // Something listed that can't show now keeps its place at the end.
    compare(Customize.movePillItem(["glyph", "clock", "weather"], ["clock", "weather"], "weather", 0), ["weather", "clock", "glyph"])
  }

  function test_pillRow() {
    var playing = { media: { available: true, playing: true }, weather: { available: true } }
    var paused = { media: { available: true, playing: false }, weather: { available: true } }
    compare(Catalog.pillRow(cfg({ pillItems: "media clock weather badge" }), service(paused)), ["media", "clock", "weather"])
    compare(Catalog.pillRow(cfg({ pillItems: "clock weather meter" }), service(playing)), ["clock", "weather", "meter"])
    // Both spot choices listed: only the first draws.
    compare(Catalog.pillRow(cfg({ pillItems: "meter clock media" }), service(playing)), ["meter", "clock"])
    // Nothing that shows: the clock, still.
    compare(Catalog.pillRow(cfg({ pillItems: "badge" }), service(paused)), ["clock"])
  }

  // Switching the levels on takes the art off, and the other way round.
  function test_mediaSpotIsOne() {
    compare(Customize.togglePillItem(cfg({ pillItems: "clock media badge" }), "meter"), ["clock", "badge", "meter"])
    compare(Customize.togglePillItem(cfg({ pillItems: "clock meter" }), "media"), ["clock", "media"])
    compare(Customize.togglePillItem(cfg({ pillItems: "clock meter" }), "meter"), ["clock"])
    compare(Customize.togglePillItem(cfg({ pillItems: "clock" }), "weather"), ["clock", "weather"])
  }

  function test_pillParts() {
    compare(Catalog.pillParts(cfg({}), service(), false), ["clock"])
    compare(Catalog.pillParts(cfg({}), service(), true), ["clock"])
    compare(Catalog.pillParts(cfg({ mode: "wrap" }), service(), false), ["glyph"])
    compare(Catalog.pillParts(cfg({ pillItems: "weather badge clock" }), service(), false), ["weather", "clock"])
    // Nothing that always shows: the clock, or the glyph in wrap mode.
    compare(Catalog.pillParts(cfg({ pillItems: "badge" }), service(), false), ["clock"])
    compare(Catalog.pillParts(cfg({ mode: "wrap", pillItems: "badge" }), service(), false), ["glyph"])
    compare(Catalog.pillParts(cfg({ pillItems: "weather" }), service({ weather: { available: false } }), false), ["clock"])
    compare(Catalog.pillParts(cfg({ pillItems: "weather" }), service(), true), ["clock"])
  }

  function test_activityCategories() {
    compare(Catalog.activityCategory("timer:abc-1"), "timers")
    compare(Catalog.activityCategory("omavisor:recording"), "recording")
    compare(Catalog.activityCategory("omavisor:recording-saved"), "recording")
    compare(Catalog.activityCategory("omavisor:update"), "updates")
    compare(Catalog.activityCategory("omavisor:units"), "units")
    compare(Catalog.activityCategory("omavisor:mic"), "privacy")
    compare(Catalog.activityCategory("omavisor:camera"), "privacy")
    compare(Catalog.activityCategory("omavisor:dictation"), "dictation")
    compare(Catalog.activityCategory("claude:session"), "agents")
    compare(Catalog.activityCategory("build:api"), "other")
    compare(Catalog.activityCategory("omavisor:unknown"), "other")
  }

  function test_rulesAreCeilings() {
    verify(Catalog.activityAllows({}, "build:api", "bloom"))
    verify(Catalog.activityAllows(null, "build:api", "bloom"))
    verify(!Catalog.activityAllows({ other: "peek" }, "build:api", "bloom"))
    verify(Catalog.activityAllows({ other: "peek" }, "build:api", "peek"))
    verify(Catalog.activityAllows({ other: "peek" }, "build:api", "badge"))
    verify(!Catalog.activityAllows({ other: "badge" }, "build:api", "peek"))
    verify(!Catalog.activityAllows({ other: "quiet" }, "build:api", "badge"))
    // Another group's rule, or a level that isn't one, changes nothing.
    verify(Catalog.activityAllows({ timers: "quiet" }, "build:api", "bloom"))
    verify(Catalog.activityAllows({ other: "loud" }, "build:api", "bloom"))
  }

  function test_badgeSkipsQuietActivities() {
    var items = [{ id: "timer:a" }, { id: "build:b" }]
    compare(Catalog.firstBadged(items, {}).id, "timer:a")
    compare(Catalog.firstBadged(items, { timers: "quiet" }).id, "build:b")
    compare(Catalog.firstBadged(items, { timers: "quiet", other: "quiet" }), null)
    compare(Catalog.firstBadged([], {}), null)
  }
}
