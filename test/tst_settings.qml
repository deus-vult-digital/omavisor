import QtQuick
import QtTest
import "../lib/Settings.js" as Settings
import "../lib/Format.js" as Format

TestCase {
  name: "Settings"

  function test_missingSettingsUseDefaults() {
    var cfg = Settings.resolve(undefined)
    compare(cfg.format, "dddd h:mm AP")
    compare(cfg.formatAlt, "d MMMM 'W'ww yyyy")
    compare(cfg.verticalFormat, "HH\n—\nmm")
    compare(cfg.mode, "replace")
    compare(cfg.peekDelayMs, 250)
    compare(cfg.allowActions, true)
    compare(cfg.homeTiles, ["media", "weather", "timers", "updates"])
  }

  function test_validValuesPassThrough() {
    var cfg = Settings.resolve({ format: "HH:mm", mode: "wrap", peekDelayMs: 500, allowActions: false })
    compare(cfg.format, "HH:mm")
    compare(cfg.mode, "wrap")
    compare(cfg.peekDelayMs, 500)
    compare(cfg.allowActions, false)
  }

  function test_invalidValuesFallBack() {
    var cfg = Settings.resolve({ format: 42, formatAlt: "", mode: "explode", openOn: null, allowActions: "maybe" })
    compare(cfg.format, "dddd h:mm AP")
    compare(cfg.formatAlt, "d MMMM 'W'ww yyyy")
    compare(cfg.mode, "replace")
    compare(cfg.openOn, "hover")
    compare(cfg.allowActions, true)
  }

  function test_integersAreClampedAndParsed() {
    compare(Settings.coerce("peekDelayMs", -50), 0)
    compare(Settings.coerce("peekDelayMs", 99999), 2000)
    compare(Settings.coerce("peekDelayMs", "300"), 300)
    compare(Settings.coerce("peekDelayMs", 312.6), 313)
    compare(Settings.coerce("peekDelayMs", "abc"), 250)
    compare(Settings.coerce("peekDelayMs", ""), 250)
    compare(Settings.coerce("updatePollMinutes", 1), 30)
  }

  function test_booleanStrings() {
    compare(Settings.coerce("allowActions", "false"), false)
    compare(Settings.coerce("allowActions", "true"), true)
  }

  function test_multiselectDropsUnknownAndDuplicates() {
    compare(Settings.coerce("homeTiles", ["media", "bogus", "media", "power"]), ["media", "power"])
    compare(Settings.coerce("homeTiles", 3), ["media", "weather", "timers", "updates"])
    compare(Settings.coerce("homeTiles", []), [])
  }

  function test_defaultsAreNotShared() {
    var a = Settings.resolve({})
    a.homeTiles.push("hypr")
    compare(Settings.resolve({}).homeTiles, ["media", "weather", "timers", "updates"])
  }

  function test_unknownKeysAreKept() {
    var cfg = Settings.resolve({ id: "dev.deusvult.omavisor", futureKey: 7 })
    compare(cfg.id, "dev.deusvult.omavisor")
    compare(cfg.futureKey, 7)
  }

  function test_normalizeTab() {
    compare(Settings.normalizeTab("Media"), "media")
    compare(Settings.normalizeTab(" activities "), "activities")
    compare(Settings.normalizeTab("Theme"), "theme")
    compare(Settings.normalizeTab("nope"), "")
    compare(Settings.normalizeTab(undefined), "")
  }

  // `omarchy bar set <id> homeTiles "media weather stats"` stores a string.
  function test_multiselectFromString() {
    compare(Settings.coerce("homeTiles", "media"), ["media"])
    compare(Settings.coerce("homeTiles", "  media weather\tstats "), ["media", "weather", "stats"])
    compare(Settings.coerce("homeTiles", "media+hypr+bogus"), ["media", "hypr"])
    compare(Settings.coerce("homeTiles", ""), [])
    compare(Settings.coerce("homeTiles", "media,weather"), ["media", "weather"])
    compare(Settings.coerce("homeTiles", "media, weather, timers, updates"), ["media", "weather", "timers", "updates"])
    compare(Settings.coerce("homeTiles", '["media","weather"]'), ["media", "weather"])
    compare(Settings.coerce("homeTiles", "[media"), ["media", "weather", "timers", "updates"])
  }

  // Nothing written means the defaults, in the order the hub has always had.
  function test_tabs() {
    var minimal = ["media", "calendar", "activities"]
    compare(Settings.resolve({}).tabs, minimal)
    compare(Settings.coerce("tabs", 3), minimal)
    compare(Settings.coerce("tabs", "system home nope home"), ["system", "home"])
    compare(Settings.coerce("tabs", []), [])
    var a = Settings.resolve({})
    a.tabs.pop()
    compare(Settings.resolve({}).tabs, minimal)
  }

  function test_homeTilesTakesToday() {
    compare(Settings.coerce("homeTiles", "today stats"), ["today", "stats"])
  }

  // The defaults for an entry from before `pillItems` follow its `mode`.
  function test_pillItemsDeriveFromMode() {
    compare(Settings.resolve({}).pillItems, ["clock", "media", "badge"])
    compare(Settings.resolve({ mode: "replace" }).pillItems, ["clock", "media", "badge"])
    compare(Settings.resolve({ mode: "wrap" }).pillItems, ["glyph", "badge"])
    compare(Settings.resolve({ mode: "wrap", pillItems: 3 }).pillItems, ["glyph", "badge"])
    compare(Settings.resolve({ mode: "wrap", pillItems: "clock bogus" }).pillItems, ["clock"])
    compare(Settings.resolve({ mode: "wrap", pillItems: [] }).pillItems, [])
  }

  function test_activityRules() {
    compare(Settings.resolve({}).activityRules, {})
    compare(Settings.coerce("activityRules", { updates: "badge", other: "peek" }), { updates: "badge", other: "peek" })
    compare(Settings.coerce("activityRules", { updates: "loud", nope: "peek", timers: "quiet" }), { timers: "quiet" })
    compare(Settings.coerce("activityRules", '{"agents":"quiet"}'), { agents: "quiet" })
    compare(Settings.coerce("activityRules", "{bad"), {})
    compare(Settings.coerce("activityRules", ["peek"]), {})
    var a = Settings.resolve({})
    a.activityRules.updates = "quiet"
    compare(Settings.resolve({}).activityRules, {})
  }

  // Resolving writes nothing back, so a resolved entry never hides the
  // missing keys that mean "defaults".
  function test_resolveLeavesTheEntryAlone() {
    var entry = { id: "x", mode: "wrap" }
    Settings.resolve(entry)
    compare(Object.keys(entry).sort(), ["id", "mode"])
  }

  function test_isoWeek() {
    compare(Format.isoWeek(2026, 9, 29), 44)
    compare(Format.isoWeek(2021, 0, 1), 53)
    compare(Format.isoWeek(2024, 11, 30), 1)
  }

  function test_clockFormatSubstitutesWeek() {
    var date = new Date(2026, 9, 29, 13, 5)
    compare(Format.clockFormat("d MMMM 'W'ww yyyy", date), "d MMMM 'W'44 yyyy")
    compare(Qt.formatDateTime(date, Format.clockFormat("d MMMM 'W'ww yyyy", date)), "29 October W44 2026")
    compare(Format.clockFormat("HH:mm", date), "HH:mm")
  }

  function test_needsSeconds() {
    verify(Format.needsSeconds("HH:mm:ss"))
    verify(!Format.needsSeconds("dddd h:mm AP"))
    verify(!Format.needsSeconds("'secs' HH:mm"))
  }
}
