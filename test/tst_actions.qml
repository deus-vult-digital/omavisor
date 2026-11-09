import QtQuick
import QtTest
import "../lib/Actions.js" as Actions
import "../lib/Settings.js" as Settings
import "../lib/Catalog.js" as Catalog
import "../lib/Customize.js" as Customize

TestCase {
  name: "Actions"

  function test_object() {
    var list = Actions.parse({
      "Lock": ["omarchy-lock-screen"],
      "btop": { argv: ["omarchy-launch-or-focus-tui", "btop"], icon: "󰍛" }
    })
    compare(list.length, 2)
    compare(list[0], { label: "Lock", argv: ["omarchy-lock-screen"], icon: Actions.DEFAULT_ICON })
    compare(list[1].icon, "󰍛")
    compare(list[1].argv, ["omarchy-launch-or-focus-tui", "btop"])
  }

  // As `omarchy bar set … actions '{…}'` without --json passes it.
  function test_text() {
    compare(Actions.parse('{"Lock":["omarchy-lock-screen"]}')[0].label, "Lock")
    compare(Actions.parse("{nope"), [])
  }

  function test_list() {
    var list = Actions.parse([
      { label: "Files", argv: ["nautilus"] },
      { label: "Files", argv: ["thunar"] },
      { label: "", argv: ["x"] },
      "junk",
      { label: "Term", argv: ["ghostty"], icon: "too long icon" }
    ])
    compare(list.map(function(a) { return a.label }), ["Files", "Term"])
    compare(list[0].argv, ["nautilus"])
    compare(list[1].icon, Actions.DEFAULT_ICON)
  }

  function test_rejects() {
    compare(Actions.parse({ "Empty": [] }), [])
    compare(Actions.parse({ "Blank": [" "] }), [])
    compare(Actions.parse({ "Number": [1, 2] }), [])
    compare(Actions.parse({ "Nul": ["a\u0000b"] }), [])
    compare(Actions.parse({ "Str": "rm -rf /" }), [])
    compare(Actions.parse({ "NoArgv": { icon: "x" } }), [])
    compare(Actions.parse(42), [])
    compare(Actions.parse(null), [])
    // Never joined into a shell string: arguments stay as they are.
    compare(Actions.parse({ "Quote": ["echo", "a b; rm -rf ~"] })[0].argv, ["echo", "a b; rm -rf ~"])
  }

  function test_label() {
    var long = Actions.parse({ "A label that is much too long to fit": ["x"] })[0].label
    compare(long.length, Actions.LABEL_MAX)
    verify(long.endsWith("…"))
    compare(Actions.parse({ "  two\n words ": ["x"] })[0].label, "two words")
  }

  function test_chips() {
    var many = {}
    for (let i = 0; i < 9; i++) many["A" + i] = ["true"]
    var list = Actions.parse(many)
    compare(list.length, 9)
    var chips = Actions.chips(list)
    compare(chips.length, Actions.SHOWN)
    compare(chips[0], { key: "0", icon: Actions.DEFAULT_ICON, label: "A0", tooltip: "A0: true" })
  }

  function test_settingsAndTile() {
    var empty = Settings.resolve({})
    compare(empty.actions, [])
    verify(!Catalog.find(Catalog.TILES, "actions").available({}, empty))
    var c = Settings.resolve({ actions: { "Lock": ["omarchy-lock-screen"] }, homeTiles: "actions weather" })
    compare(c.actions.length, 1)
    verify(Catalog.find(Catalog.TILES, "actions").available({}, c))
    compare(Catalog.homeTiles(c, { weather: { available: true } }), ["actions", "weather"])
    // Without actions the tile steps aside for Today.
    compare(Catalog.homeTiles(Settings.resolve({ homeTiles: "actions weather" }), { weather: { available: true } }), ["today", "weather"])
  }

  // Reset leaves your commands alone; a layout restore keeps them.
  function test_resetAndRestore() {
    verify(Settings.CUSTOMIZATION_KEYS.indexOf("actions") === -1)
    verify(Settings.RESTORE_KEEPS.indexOf("actions") !== -1)
    var raw = { actions: { "Lock": ["x"] }, tabs: ["home"] }
    compare(Customize.applyChanges(raw, Customize.resetChanges(Settings.CUSTOMIZATION_KEYS)), { actions: { "Lock": ["x"] } })
  }
}
