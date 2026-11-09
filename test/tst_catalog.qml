import QtQuick
import QtTest
import "../lib/Catalog.js" as Catalog
import "../lib/Settings.js" as Settings

TestCase {
  name: "Catalog"

  // A service with every module, then the ones a test turns off.
  function service(off) {
    return Object.assign({
      media: { available: true }, weather: { available: true }, timers: {},
      updates: { available: true }, packages: { available: true }, capture: {}, stats: {},
      power: { available: true }, hypr: { available: true }, theme: { available: true }
    }, off)
  }
  readonly property var none: ({ available: false })

  function cfg(settings) { return Settings.resolve(settings) }

  // A new install is minimal: now playing, the calendar and live activity.
  function test_tabsDefaultToTheMinimalThree() {
    compare(Catalog.shownTabs(cfg({}), service()), ["media", "calendar", "activities"])
    compare(Catalog.MINIMAL_TABS, ["media", "calendar", "activities"])
  }

  function test_tabsFollowTheList() {
    compare(Catalog.shownTabs(cfg({ tabs: "system home keys" }), service()), ["system", "home", "keys"])
  }

  function test_listedTabThatCannotShow() {
    compare(Catalog.shownTabs(cfg({ tabs: "theme keys" }), service({ theme: none })), ["keys"])
    // A tab id that no longer exists (the old Widgets tab) is dropped.
    compare(Catalog.shownTabs(cfg({ tabs: "widgets keys" }), service()), ["keys"])
  }

  function test_noTabsFallsBackToHome() {
    compare(Catalog.shownTabs(cfg({ tabs: [] }), service()), ["home"])
    compare(Catalog.shownTabs(cfg({ tabs: "bogus" }), service()), ["home"])
    compare(Catalog.shownTabs(cfg({ tabs: "theme" }), service({ theme: none })), ["home"])
    compare(Catalog.shownTabs(cfg({ tabs: "" }), null), ["home"])
  }

  function test_newTabStaysHiddenOnceAListExists() {
    // A list from before a tab existed leaves it out, unlike no list at all.
    var before = ["home", "media", "system"]
    verify(Catalog.shownTabs(cfg({ tabs: before }), service()).indexOf("keys") === -1)
    verify(Catalog.shownTabs(cfg({ tabs: before }), service()).indexOf("calendar") === -1)
    // No list at all: the minimal three, whatever else exists.
    verify(Catalog.shownTabs(cfg({}), service()).indexOf("calendar") !== -1)
    verify(Catalog.shownTabs(cfg({}), service()).indexOf("keys") === -1)
  }

  function test_tabAvailable() {
    verify(Catalog.tabAvailable("media", null, {}))
    verify(!Catalog.tabAvailable("theme", service({ theme: none }), {}))
    verify(!Catalog.tabAvailable("widgets", service(), {}))
    verify(!Catalog.tabAvailable("nope", service(), {}))
  }

  function test_tabEntries() {
    var entries = Catalog.tabEntries(["keys", "home"])
    compare(entries.map(function(t) { return t.label }), ["Keys", "Home"])
    verify(entries[0].icon !== "")
  }

  function test_startTab() {
    var tabs = ["media", "home", "calendar"]
    compare(Catalog.startTab("", tabs, "hover"), "media")
    compare(Catalog.startTab("home", tabs, "hover"), "home")
    compare(Catalog.startTab("calendar", tabs, "click"), "calendar")
    // A tab hidden since (or opened by name) is not where a plain open lands.
    compare(Catalog.startTab("keys", tabs, "keyboard"), "media")
    compare(Catalog.startTab("keys", [], "hover"), "home")
  }

  function test_homeTilesInOrderUpToFour() {
    compare(Catalog.homeTiles(cfg({}), service()), ["media", "weather", "timers", "updates"])
    compare(Catalog.homeTiles(cfg({ homeTiles: "hypr power stats capture updates" }), service()), ["hypr", "power", "stats", "capture"])
  }

  function test_homeTilesStepAsideForToday() {
    compare(Catalog.homeTiles(cfg({}), service({ media: none })), ["today", "weather", "timers", "updates"])
    compare(Catalog.homeTiles(cfg({}), service({ media: none, weather: none })), ["today", "timers", "updates"])
    // A fifth listed tile takes the place first, before Today would.
    compare(Catalog.homeTiles(cfg({ homeTiles: "media weather timers updates stats" }), service({ media: none })),
      ["weather", "timers", "updates", "stats"])
    compare(Catalog.homeTiles(cfg({ homeTiles: "media" }), null), ["today"])
  }

  function test_homeTilesFewerStayWide() {
    // The change from before: no Today tile added to a short list.
    compare(Catalog.homeTiles(cfg({ homeTiles: "weather stats" }), service()), ["weather", "stats"])
  }

  function test_homeTilesToday() {
    compare(Catalog.homeTiles(cfg({ homeTiles: [] }), service()), ["today"])
    compare(Catalog.homeTiles(cfg({ homeTiles: "stats today" }), service()), ["stats", "today"])
    compare(Catalog.homeTiles(cfg({ homeTiles: "media today" }), service({ media: none })), ["today"])
    compare(Catalog.homeTiles({}, service()), ["today"])
  }

  // The bug: System filtered the list to six kinds and took four, Home took the
  // first four of all eight, so here neither showed the timers.
  function test_timersOnHomeAgreesWithHome() {
    var c = cfg({ tabs: "home system", homeTiles: "power hypr stats media timers" })
    verify(Catalog.homeTiles(c, service()).indexOf("timers") === -1)
    verify(!Catalog.timersOnHome(c, service()))
    // With the battery gone timers move up to Home, and System follows.
    verify(Catalog.homeTiles(c, service({ power: none })).indexOf("timers") !== -1)
    verify(Catalog.timersOnHome(c, service({ power: none })))
    // Home is not in the default strip, so neither are its timers.
    verify(!Catalog.timersOnHome(cfg({}), service()))
    verify(Catalog.timersOnHome(cfg({ tabs: "home" }), service()))
  }

  function test_timersOnHiddenHomeAreNotOnHome() {
    verify(!Catalog.timersOnHome(cfg({ tabs: "media system" }), service()))
  }

  function test_pillItems() {
    compare(Catalog.shownPillItems(cfg({}), service()), ["clock", "media", "badge"])
    compare(Catalog.shownPillItems(cfg({}), service({ media: none })), ["clock", "badge"])
    compare(Catalog.shownPillItems(cfg({ pillItems: "clock weather badge" }), service({ weather: none })), ["clock", "badge"])
    compare(Catalog.shownPillItems(cfg({ mode: "wrap" }), service()), ["glyph", "badge"])
  }

  // Now playing is in the text only while a player plays, and never on a
  // left or right bar.
  // The art (and levels) are drawn, never text: the clock is the only part
  // left, and only media listed still leaves the clock to hover.
  function test_pillMedia() {
    var playing = { media: { available: true, playing: true } }
    var paused = { media: { available: true, playing: false } }
    compare(Catalog.pillParts(cfg({}), service(playing), false), ["clock"])
    compare(Catalog.pillParts(cfg({}), service(paused), false), ["clock"])
    compare(Catalog.pillParts(cfg({ pillItems: "media clock" }), service(playing), false), ["clock"])
    compare(Catalog.pillParts(cfg({ pillItems: "media" }), service(paused), false), ["clock"])
    compare(Catalog.pillParts(cfg({ mode: "wrap", pillItems: "media" }), service(paused), false), ["glyph"])
    compare(Catalog.pillRow(cfg({ pillItems: "media clock" }), service(playing)), ["media", "clock"])
  }

  // Art and levels share one spot: the first listed, else none.
  function test_pillSpot() {
    compare(Catalog.pillSpot(cfg({})), "media")
    compare(Catalog.pillSpot(cfg({ pillItems: "clock meter" })), "meter")
    compare(Catalog.pillSpot(cfg({ pillItems: "meter media" })), "meter")
    compare(Catalog.pillSpot(cfg({ pillItems: "clock weather" })), "")
  }

  // The meter is drawn beside the text, never part of it.
  function test_pillMeterIsNotText() {
    var playing = { media: { available: true, playing: true } }
    compare(Catalog.pillParts(cfg({ pillItems: "clock meter" }), service(playing), false), ["clock"])
    compare(Catalog.pillParts(cfg({ pillItems: "meter" }), service(playing), false), ["clock"])
  }

  function test_pillNeverEmpty() {
    compare(Catalog.shownPillItems(cfg({ pillItems: [] }), service()), ["clock"])
    compare(Catalog.shownPillItems(cfg({ pillItems: [], mode: "wrap" }), service()), ["glyph"])
    compare(Catalog.shownPillItems(cfg({ pillItems: "weather" }), service({ weather: none })), ["clock"])
  }

  function test_everyEntryIsComplete() {
    Catalog.TABS.concat(Catalog.TILES, Catalog.PILL_ITEMS).forEach(function(item) {
      verify(item.id !== "" && item.label !== "", item.id)
      compare(typeof item.available, "function")
    })
  }
}
