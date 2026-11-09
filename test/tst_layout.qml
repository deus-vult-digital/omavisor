import QtQuick
import QtTest
import "../lib/Layout.js" as Layout

TestCase {
  name: "Layout"

  readonly property string omavisor: "dev.deusvult.omavisor"

  // A stock 4.0 bar before onboarding (Omavisor added last).
  function stock() {
    return {
      bar: {
        position: "top",
        centerAnchor: "omarchy.clock",
        layout: {
          left: [{ id: "omarchy.workspaces" }],
          center: [
            { id: "omarchy.indicators" },
            { id: "omarchy.clock", format: "dddd h:mm AP", formatAlt: "d MMMM 'W'ww yyyy",
              verticalFormat: "HH\n—\nmm", birthYear: 1983, lifeExpectancy: 85 },
            { id: "omarchy.keyboard-layout" },
            { id: "omarchy.weather" },
            { id: "omarchy.system-update" },
            { id: omavisor }
          ],
          right: [{ id: "omarchy.tray" }]
        }
      }
    }
  }

  // What the commands do to the layout, for checking plans end to end.
  function apply(config, argv, ownEntry) {
    var c = JSON.parse(JSON.stringify(config))
    var L = c.bar.layout
    function take(section, index) { return L[section].splice(index, 1)[0] }
    function opt(name) { var i = argv.indexOf(name); return i === -1 ? undefined : argv[i + 1] }
    var verb = argv[1] + " " + argv[2]
    var id = argv[3]
    if (verb === "plugin disable") {
      const at = Layout.locate(c, id)
      if (at) take(at.section, at.index)
    } else if (verb === "plugin enable") {
      if (!Layout.locate(c, id)) L[opt("--section")].splice(Number(opt("--index")), 0, { id: id })
    } else if (verb === "bar move") {
      const from = opt("--from-section") ? { section: opt("--from-section"), index: Number(opt("--from-index")) } : Layout.locate(c, id)
      verify(Layout.entryId(L[from.section][from.index]) === id, "move source is " + id)
      const entry = take(from.section, from.index)
      L[opt("--section")].splice(Math.min(Number(opt("--index")), L[opt("--section")].length), 0, entry)
    } else if (verb === "bar set") {
      const e = L[opt("--section")][Number(opt("--index"))]
      verify(e.id === id, "set target is " + id)
      e[argv[4]] = JSON.parse(argv[5])
    } else {
      fail("unexpected command " + argv.join(" "))
    }
    return c
  }

  function run(config, steps) {
    for (let i = 0; i < steps.length; i++) config = apply(config, steps[i])
    return config
  }

  function setOwn(config, settings) {
    var at = Layout.locate(config, omavisor)
    var entry = { id: omavisor }
    for (const k in settings) entry[k] = settings[k]
    config.bar.layout[at.section][at.index] = entry
    return config
  }

  function setAnchor(config, anchor) {
    if (anchor === null) delete config.bar.centerAnchor
    else config.bar.centerAnchor = anchor
    return config
  }

  function ids(config) { return config.bar.layout.center.map(Layout.entryId) }

  function test_onboarding() {
    verify(Layout.needsOnboarding(stock(), omavisor))
    var picked = setOwn(stock(), { mode: "wrap" })
    verify(!Layout.needsOnboarding(picked, omavisor))
    // Nothing to replace.
    var bare = stock()
    bare.bar.layout.center = [{ id: omavisor }]
    verify(!Layout.needsOnboarding(bare, omavisor))
    // Omavisor not on the bar.
    var off = stock()
    off.bar.layout.center.pop()
    verify(!Layout.needsOnboarding(off, omavisor))
  }

  function test_backup() {
    var b = Layout.makeBackup(stock(), omavisor, "2026-10-29T00:00:00Z")
    compare(b.centerAnchor, "omarchy.clock")
    compare(b.center.length, 6)
    compare(b.center[1].birthYear, 1983)
    compare(b.omavisor.section, "center")
    compare(b.omavisor.index, 5)
    var parsed = Layout.parseBackup(JSON.stringify(b))
    compare(parsed.center[1].format, "dddd h:mm AP")
    compare(Layout.parseBackup("{nope"), null)
    compare(Layout.parseBackup('{"version":1,"center":[{"id":"x;rm -rf"}],"centerAnchor":null}'), null)
    compare(Layout.parseBackup('{"version":2,"center":[]}'), null)
    // No anchor in shell.json is kept as null.
    compare(Layout.makeBackup(setAnchor(stock(), null), omavisor, "").centerAnchor, null)
  }

  function test_replace() {
    var plan = Layout.replacePlan(stock(), omavisor)
    compare(plan.steps.length, 3)
    compare(plan.steps[0], ["omarchy", "plugin", "disable", "omarchy.clock"])
    compare(plan.steps[1], ["omarchy", "plugin", "disable", "omarchy.weather"])
    compare(plan.steps[2], ["omarchy", "bar", "move", omavisor, "--section", "center", "--index", "1"])
    compare(plan.settings.mode, "replace")
    compare(plan.settings.format, "dddd h:mm AP")
    compare(plan.settings.birthYear, 1983)
    verify(plan.anchorNeeded)
    var after = run(stock(), plan.steps)
    compare(ids(after), ["omarchy.indicators", omavisor, "omarchy.keyboard-layout", "omarchy.system-update"])
    compare(Layout.centerAfterReplace(stock(), omavisor), ids(after))
  }

  function test_replaceKeepsOwnSettings() {
    var plan = Layout.replacePlan(setOwn(stock(), { format: "HH:mm", openOn: "click" }), omavisor)
    compare(plan.settings.format, "HH:mm")
    compare(plan.settings.openOn, "click")
    compare(plan.settings.formatAlt, "d MMMM 'W'ww yyyy")
  }

  function test_replaceFromRightSection() {
    var c = stock()
    c.bar.layout.center.pop()
    c.bar.layout.right.push({ id: omavisor })
    var plan = Layout.replacePlan(c, omavisor)
    var after = run(c, plan.steps)
    compare(ids(after), ["omarchy.indicators", omavisor, "omarchy.keyboard-layout", "omarchy.system-update"])
    compare(after.bar.layout.right.map(Layout.entryId), ["omarchy.tray"])
  }

  // Replace, then restore: the center, every inline setting and Omavisor's
  // entry read exactly as before; only the anchor is left to the user.
  function roundTrip(before) {
    var backup = Layout.makeBackup(before, omavisor, "t")
    var r = Layout.replacePlan(before, omavisor)
    var replaced = setAnchor(setOwn(run(before, r.steps), r.settings), omavisor)
    var plan = Layout.restorePlan(backup, replaced, omavisor)
    var restored = run(replaced, plan.steps)
    if (plan.ownEntry) restored = setOwn(restored, plan.ownEntry)
    compare(plan.anchor, backup.centerAnchor)
    verify(plan.anchorNeeded)
    compare(Layout.centerDiff(backup, restored), ["centerAnchor is " + omavisor + ", was " + (backup.centerAnchor || "unset")])
    restored = setAnchor(restored, plan.anchor)
    compare(Layout.centerDiff(backup, restored), [])
    compare(JSON.stringify(restored), JSON.stringify(before))
    return plan
  }

  function test_roundTrip() {
    var plan = roundTrip(stock())
    // The clock comes back bare, then gets its five settings.
    var sets = plan.steps.filter(function(s) { return s[2] === "set" })
    compare(sets.length, 5)
    compare(sets[0].slice(0, 7), ["omarchy", "bar", "set", "omarchy.clock", "format", "\"dddd h:mm AP\"", "--json"])
    compare(plan.extras, [])
    compare(plan.leftovers, [])
  }

  function test_roundTripOmavisorElsewhere() {
    var c = stock()
    c.bar.layout.center.pop()
    c.bar.layout.right.unshift({ id: omavisor, openOn: "click" })
    roundTrip(c)
  }

  function test_roundTripNoAnchor() {
    roundTrip(setAnchor(stock(), null))
  }

  function test_restoreNothingToDo() {
    var backup = Layout.makeBackup(stock(), omavisor, "t")
    var plan = Layout.restorePlan(backup, stock(), omavisor)
    compare(plan.steps, [])
    verify(!plan.anchorNeeded)
    compare(Layout.centerDiff(backup, stock()), [])
  }

  function test_restoreKeepsExtras() {
    var backup = Layout.makeBackup(stock(), omavisor, "t")
    var r = Layout.replacePlan(stock(), omavisor)
    var replaced = run(stock(), r.steps)
    replaced.bar.layout.center.splice(0, 0, { id: "omarchy.microphone" })
    replaced.bar.layout.center[3].extraKey = true // keyboard-layout
    var plan = Layout.restorePlan(backup, replaced, omavisor)
    var restored = run(replaced, plan.steps)
    compare(ids(restored).slice(0, 6), ids(stock()))
    compare(plan.extras, ["omarchy.microphone"])
    compare(plan.leftovers, ["omarchy.keyboard-layout.extraKey"])
  }

  function test_anchorCommand() {
    compare(Layout.anchorCommand("omarchy.clock"),
      "f=\"$HOME/.config/omarchy/shell.json\"; cp \"$f\" \"$f.bak.$(date +%s)\" && t=$(mktemp \"$f.XXXXXX\") && jq -S '.bar.centerAnchor = \"omarchy.clock\"' \"$f\" > \"$t\" && chmod --reference=\"$f\" \"$t\" && mv \"$t\" \"$f\"")
    verify(Layout.anchorCommand(null).indexOf("'del(.bar.centerAnchor)'") !== -1)
    compare(Layout.anchorCommand("x'; rm -rf ~"), "")
  }

  function test_showCommand() {
    compare(Layout.showCommand(["omarchy", "bar", "set", "omarchy.clock", "format", "\"dddd h:mm AP\"", "--json"]),
      "omarchy bar set omarchy.clock format '\"dddd h:mm AP\"' --json")
  }

  function test_anchorJq() {
    compare(Layout.anchorJqArgv("/h/shell.json", omavisor),
      ["jq", "-S", "--arg", "anchor", omavisor, ".bar.centerAnchor = $anchor", "--", "/h/shell.json"])
    compare(Layout.anchorJqArgv("/h/shell.json", null), ["jq", "-S", "del(.bar.centerAnchor)", "--", "/h/shell.json"])
    compare(Layout.anchorJqArgv("/h/shell.json", "x'y"), null)
  }

  function test_checkAnchorEdit() {
    const live = stock()
    const edited = setAnchor(stock(), omavisor)
    compare(Layout.checkAnchorEdit(JSON.stringify(edited), omavisor, live), "")
    compare(Layout.checkAnchorEdit("{nope", omavisor, live), "jq printed no JSON")
    compare(Layout.checkAnchorEdit(JSON.stringify(stock()), omavisor, live), "the anchor did not change")
    // Disk still has the clock the shell already took off.
    const replaced = run(stock(), Layout.replacePlan(stock(), omavisor).steps)
    verify(Layout.checkAnchorEdit(JSON.stringify(edited), omavisor, replaced).indexOf("does not match") !== -1)
    compare(Layout.checkAnchorEdit(JSON.stringify(setAnchor(stock(), null)), null, live), "")
  }

  // A clock or weather outside the center is not the center's: left alone.
  function test_replaceLeavesOtherSections() {
    const c = stock()
    c.bar.layout.center.splice(3, 1)
    c.bar.layout.right.push({ id: "omarchy.weather", unit: "metric" })
    const plan = Layout.replacePlan(c, omavisor)
    compare(plan.steps.filter(function(s) { return s[3] === "omarchy.weather" }), [])
    const after = run(c, plan.steps)
    compare(after.bar.layout.right[1], { id: "omarchy.weather", unit: "metric" })
    const onlyRight = stock()
    onlyRight.bar.layout.center = [{ id: omavisor }]
    onlyRight.bar.layout.right.push({ id: "omarchy.clock" })
    verify(!Layout.needsOnboarding(onlyRight, omavisor))
  }

  // Extras and settings added since do not fail a restore.
  function test_restoreDiff() {
    const backup = Layout.makeBackup(stock(), omavisor, "t")
    const c = stock()
    c.bar.layout.center.push({ id: "x.y" })
    c.bar.layout.center[2].extra = 1
    compare(Layout.restoreDiff(backup, c), [])
    c.bar.layout.center[1].format = "HH:mm"
    compare(Layout.restoreDiff(backup, c), ["omarchy.clock.format differs"])
    c.bar.layout.center.splice(0, 1)
    compare(Layout.restoreDiff(backup, c)[0], "center[0] is omarchy.clock, was omarchy.indicators")
  }

  // Customizing after the backup survives a restore, and is no difference.
  function customized(backup) {
    var before = stock()
    var saved = Layout.entryOf(before, omavisor)
    saved.homeTiles = ["media"]
    saved.tabsSeen = ["home"]
    saved.format = "HH:mm"
    var b = Layout.makeBackup(before, omavisor, "t")
    var r = Layout.replacePlan(before, omavisor)
    var now = setOwn(run(before, r.steps), Object.assign({}, r.settings, {
      tabs: ["system", "home"], pillItems: ["clock"], activityRules: { updates: "badge" }, homeTiles: ["stats"]
    }))
    delete Layout.entryOf(now, omavisor).tabsSeen
    return { backup: b, now: now }
  }

  function test_restoreKeepsCustomization() {
    var c = customized()
    var plan = Layout.restorePlan(c.backup, c.now, omavisor)
    compare(plan.ownEntry.tabs, ["system", "home"])
    compare(plan.ownEntry.pillItems, ["clock"])
    compare(plan.ownEntry.activityRules, { updates: "badge" })
    compare(plan.ownEntry.homeTiles, ["stats"])
    // Unset since the backup stays unset; the rest comes back.
    verify(!("tabsSeen" in plan.ownEntry))
    compare(plan.ownEntry.format, "HH:mm")
  }

  function test_restoreDiffSkipsCustomization() {
    var c = customized()
    var plan = Layout.restorePlan(c.backup, c.now, omavisor)
    var restored = setOwn(run(c.now, plan.steps), plan.ownEntry)
    compare(Layout.restoreDiff(c.backup, restored, omavisor), [])
    compare(Layout.centerDiff(c.backup, setAnchor(restored, c.backup.centerAnchor), omavisor), [])
    // Another widget's key of the same name still counts.
    var other = Layout.makeBackup(stock(), omavisor, "t")
    other.center[0].tabs = ["a"]
    compare(Layout.restoreDiff(other, stock(), omavisor), ["omarchy.indicators.tabs differs"])
    // And Omavisor's other settings do.
    Layout.entryOf(restored, omavisor).format = "h:mm"
    compare(Layout.restoreDiff(c.backup, restored, omavisor), [omavisor + ".format differs"])
  }

  // Off the bar an entry has lost its settings: the backup's come back whole.
  function test_restoreOffTheBarUsesTheBackup() {
    var c = customized()
    c.now.bar.layout.center = c.now.bar.layout.center.filter(function(e) { return Layout.entryId(e) !== omavisor })
    var plan = Layout.restorePlan(c.backup, c.now, omavisor)
    compare(plan.ownEntry.homeTiles, ["media"])
    compare(plan.ownEntry.tabsSeen, ["home"])
  }

  function test_replaceWeatherOnly() {
    const c = stock()
    c.bar.layout.center.splice(1, 1) // no clock
    delete c.bar.centerAnchor
    const after = run(c, Layout.replacePlan(c, omavisor).steps)
    compare(ids(after), ["omarchy.indicators", "omarchy.keyboard-layout", omavisor, "omarchy.system-update"])
  }

  function test_checkAnchorEditNested() {
    const live = stock()
    live.bar.layout.center[0].nested = { b: 1, a: 2 }
    const edited = setAnchor(JSON.parse(JSON.stringify(live)), omavisor)
    edited.bar.layout.center[0].nested = { a: 2, b: 1 }
    compare(Layout.checkAnchorEdit(JSON.stringify(edited), omavisor, live), "")
  }

  function test_anchorManual() {
    compare(Layout.anchorManual(omavisor), "In ~/.config/omarchy/shell.json, under \"bar\", set \"centerAnchor\": \"" + omavisor + "\".")
    compare(Layout.anchorManual("a b"), "")
  }

  // ---- Omarchy 4.5: centerBegin, center and centerEnd, no anchor.

  // A 4.5.0-3 bar after `omarchy plugin enable` put Omavisor in centerEnd.
  function stock45() {
    return {
      bar: {
        position: "top",
        layout: {
          left: [{ id: "omarchy.menu" }, { id: "omarchy.workspaces" }],
          centerBegin: [],
          center: [
            { id: "omarchy.indicators" },
            { id: "omarchy.clock", format: "ddd d MMM h:mm AP" },
            { id: "omarchy.system-update" },
            { id: "omarchy.weather" }
          ],
          centerEnd: [{ id: omavisor }],
          right: [{ id: "omarchy.tray" }],
          tray: [{ id: "omarchy.network" }]
        }
      }
    }
  }

  function sectionIds(config, section) { return config.bar.layout[section].map(Layout.entryId) }

  function test_slots() {
    verify(Layout.hasSlots(stock45()))
    verify(!Layout.hasSlots(stock()))
    verify(Layout.needsOnboarding(stock45(), omavisor))
    compare(Layout.locate(stock45(), omavisor), { section: "centerEnd", index: 0 })
    compare(Layout.locate(stock45(), "omarchy.network"), { section: "tray", index: 0 })
    var b = Layout.makeBackup(stock45(), omavisor, "t")
    compare(b.centerBegin, [])
    compare(b.centerEnd, [{ id: omavisor }])
    compare(b.centerAnchor, null)
    compare(Layout.parseBackup(JSON.stringify(b)).centerEnd, [{ id: omavisor }])
    compare(Layout.parseBackup('{"version":1,"center":[],"centerAnchor":null,"centerEnd":[{"id":"a b"}]}'), null)
    compare(Layout.parseBackup('{"version":1,"center":[],"centerAnchor":null,"centerEnd":{}}'), null)
    // A 4.0 backup has no begin or end.
    compare(Layout.makeBackup(stock(), omavisor, "t").centerBegin, undefined)
  }

  // Omavisor alone in the box; what stood before the clock ends centerBegin,
  // what stood after it starts centerEnd.
  function test_replaceSlots() {
    var plan = Layout.replacePlan(stock45(), omavisor)
    verify(!plan.anchorNeeded)
    compare(plan.settings.format, "ddd d MMM h:mm AP")
    compare(plan.steps[0], ["omarchy", "plugin", "disable", "omarchy.clock"])
    compare(plan.steps[1], ["omarchy", "plugin", "disable", "omarchy.weather"])
    var after = run(stock45(), plan.steps)
    compare(sectionIds(after, "centerBegin"), ["omarchy.indicators"])
    compare(sectionIds(after, "center"), [omavisor])
    compare(sectionIds(after, "centerEnd"), ["omarchy.system-update"])
    compare(sectionIds(after, "left"), ["omarchy.menu", "omarchy.workspaces"])
    compare(Layout.centerAfterReplace(stock45(), omavisor), [omavisor])
    verify(!Layout.needsOnboarding(setOwn(after, plan.settings), omavisor))
    verify(!Layout.hasReplaceable(after))
  }

  function test_replaceSlotsKeepsBeginAndEnd() {
    var c = stock45()
    c.bar.layout.centerBegin = [{ id: "omarchy.media" }]
    c.bar.layout.centerEnd = [{ id: "omarchy.agents" }, { id: omavisor }]
    var after = run(c, Layout.replacePlan(c, omavisor).steps)
    compare(sectionIds(after, "centerBegin"), ["omarchy.media", "omarchy.indicators"])
    compare(sectionIds(after, "center"), [omavisor])
    compare(sectionIds(after, "centerEnd"), ["omarchy.system-update", "omarchy.agents"])
  }

  function test_replaceSlotsWeatherOnly() {
    var c = stock45()
    c.bar.layout.center.splice(1, 1) // no clock
    var after = run(c, Layout.replacePlan(c, omavisor).steps)
    compare(sectionIds(after, "centerBegin"), ["omarchy.indicators", "omarchy.system-update"])
    compare(sectionIds(after, "center"), [omavisor])
    compare(sectionIds(after, "centerEnd"), [])
  }

  function test_replaceSlotsOmavisorOnTheRight() {
    var c = stock45()
    c.bar.layout.centerEnd = []
    c.bar.layout.right.push({ id: omavisor, openOn: "click" })
    var plan = Layout.replacePlan(c, omavisor)
    var after = setOwn(run(c, plan.steps), plan.settings)
    compare(sectionIds(after, "center"), [omavisor])
    compare(sectionIds(after, "right"), ["omarchy.tray"])
    compare(Layout.entryOf(after, omavisor).openOn, "click")
  }

  function roundTrip45(before) {
    var backup = Layout.parseBackup(JSON.stringify(Layout.makeBackup(before, omavisor, "t")))
    var r = Layout.replacePlan(before, omavisor)
    var replaced = setOwn(run(before, r.steps), r.settings)
    var plan = Layout.restorePlan(backup, replaced, omavisor)
    verify(!plan.anchorNeeded)
    var restored = run(replaced, plan.steps)
    if (plan.ownEntry) restored = setOwn(restored, plan.ownEntry)
    compare(Layout.restoreDiff(backup, restored, omavisor), [])
    compare(Layout.centerDiff(backup, restored), [])
    compare(JSON.stringify(restored), JSON.stringify(before))
    return plan
  }

  function test_roundTripSlots() {
    var plan = roundTrip45(stock45())
    compare(plan.extras, [])
    compare(plan.leftovers, [])
    // The clock comes back bare, then gets its format.
    compare(plan.steps.filter(function(s) { return s[2] === "set" }).length, 1)
  }

  function test_roundTripSlotsBusy() {
    var c = stock45()
    c.bar.layout.centerBegin = [{ id: "omarchy.media", compact: true }]
    c.bar.layout.centerEnd = [{ id: "omarchy.agents" }, { id: omavisor, tabs: ["home"] }]
    roundTrip45(c)
  }

  function test_roundTripSlotsOmavisorElsewhere() {
    var c = stock45()
    c.bar.layout.centerEnd = []
    c.bar.layout.right.unshift({ id: omavisor, openOn: "click" })
    roundTrip45(c)
  }

  function test_restoreSlotsNothingToDo() {
    var backup = Layout.makeBackup(stock45(), omavisor, "t")
    var plan = Layout.restorePlan(backup, stock45(), omavisor)
    compare(plan.steps, [])
    verify(!plan.anchorNeeded)
    compare(Layout.centerDiff(backup, stock45()), [])
  }

  function test_restoreSlotsKeepsExtras() {
    var backup = Layout.makeBackup(stock45(), omavisor, "t")
    var replaced = run(stock45(), Layout.replacePlan(stock45(), omavisor).steps)
    replaced.bar.layout.centerEnd.push({ id: "omarchy.microphone" })
    var plan = Layout.restorePlan(backup, replaced, omavisor)
    var restored = run(replaced, plan.steps)
    compare(Layout.restoreDiff(backup, restored, omavisor), [])
    compare(plan.extras, ["omarchy.microphone"])
    compare(sectionIds(restored, "centerEnd"), [omavisor, "omarchy.microphone"])
  }

  // A backup from 4.0 (center and anchor only) restored on 4.5.
  function test_restore40BackupOn45() {
    var backup = Layout.makeBackup(stock45(), omavisor, "t")
    delete backup.centerBegin
    delete backup.centerEnd
    backup.centerAnchor = "omarchy.clock"
    var replaced = run(stock45(), Layout.replacePlan(stock45(), omavisor).steps)
    var plan = Layout.restorePlan(backup, replaced, omavisor)
    verify(!plan.anchorNeeded)
    var restored = run(replaced, plan.steps)
    compare(sectionIds(restored, "center"), sectionIds(stock45(), "center").concat([]).slice(0, 4))
    compare(Layout.restoreDiff(backup, restored, omavisor), [])
  }
}
