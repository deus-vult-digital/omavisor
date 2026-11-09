import QtQuick
import QtTest
import "../lib/ActivityStore.js" as Store

TestCase {
  name: "ActivityStore"

  function fresh() { return Store.create() }

  function test_minimalPushIsFilledWithDefaults() {
    var s = fresh()
    var r = Store.push(s, '{"id":"build:api","title":"Building api"}', 1000)
    compare(r.id, "build:api")
    var a = s.items["build:api"]
    compare(a.state, "running")
    compare(a.priority, "normal")
    compare(a.progress, null)
    compare(a.ttl, 3600)
    compare(a.source, "")
    compare(a.compact.leading, "")
    compare(a.actions.length, 0)
  }

  function test_invalidJsonIsAnError() {
    compare(Store.push(fresh(), "{nope", 0).error, "invalid JSON")
    verify(Store.push(fresh(), "[1,2]", 0).error)
    verify(Store.push(fresh(), "42", 0).error)
    verify(Store.push(fresh(), "null", 0).error)
  }

  function test_idRules() {
    verify(Store.push(fresh(), { title: "x" }, 0).error)
    verify(Store.push(fresh(), { id: "", title: "x" }, 0).error)
    verify(Store.push(fresh(), { id: "has space", title: "x" }, 0).error)
    verify(Store.push(fresh(), { id: "../etc", title: "x" }, 0).error)
    verify(Store.push(fresh(), { id: 12, title: "x" }, 0).error)
    verify(Store.push(fresh(), { id: new Array(66).join("a"), title: "x" }, 0).error)
    compare(Store.push(fresh(), { id: new Array(65).join("a"), title: "x" }, 0).id.length, 64)
    compare(Store.push(fresh(), { id: "A-z_0.9:x", title: "x" }, 0).id, "A-z_0.9:x")
  }

  function test_titleRequired() {
    verify(Store.push(fresh(), { id: "a" }, 0).error)
    verify(Store.push(fresh(), { id: "a", title: "  " }, 0).error)
    verify(Store.push(fresh(), { id: "a", title: 5 }, 0).error)
  }

  function test_unknownTypesAndValuesAreRejected() {
    verify(Store.push(fresh(), { id: "a", title: "x", state: "paused" }, 0).error)
    verify(Store.push(fresh(), { id: "a", title: "x", priority: "high" }, 0).error)
    verify(Store.push(fresh(), { id: "a", title: "x", progress: "50%" }, 0).error)
    verify(Store.push(fresh(), { id: "a", title: "x", ttl: "1h" }, 0).error)
    verify(Store.push(fresh(), { id: "a", title: "x", subtitle: 3 }, 0).error)
    verify(Store.push(fresh(), { id: "a", title: "x", compact: "37%" }, 0).error)
    verify(Store.push(fresh(), { id: "a", title: "x", compact: { trailing: 37 } }, 0).error)
  }

  function test_unknownKeysAreDropped() {
    var s = fresh()
    Store.push(s, { id: "a", title: "x", colour: "red", endsAt: 5, deadline: 9 }, 0)
    compare(s.items.a.colour, undefined)
    compare(s.items.a.endsAt, 0)
    compare(s.items.a.deadline, undefined)
  }

  function test_lengthsAreClamped() {
    var s = fresh()
    var long = new Array(300).join("x")
    Store.push(s, { id: "a", title: long, subtitle: long, source: long, glyph: "abcdefg",
                    compact: { leading: long, trailing: long } }, 0)
    compare(s.items.a.title.length, 80)
    compare(s.items.a.subtitle.length, 120)
    compare(s.items.a.source.length, 32)
    compare(s.items.a.glyph, "abcd")
    compare(s.items.a.compact.leading.length, 24)
  }

  function test_glyphClampKeepsSurrogatePairs() {
    var s = fresh()
    Store.push(s, { id: "a", title: "x", glyph: new Array(6).join("\uDB82\uDD54") }, 0)
        compare(s.items.a.glyph.length, 8)
  }

  function test_progressAndTtlAreClamped() {
    var s = fresh()
    Store.push(s, { id: "a", title: "x", progress: 7, ttl: 999999 }, 0)
    compare(s.items.a.progress, 1)
    compare(s.items.a.ttl, 86400)
    Store.push(s, { id: "a", title: "x", progress: -1, ttl: 0 }, 0)
    compare(s.items.a.progress, 0)
    compare(s.items.a.ttl, 1)
  }

  function test_actionsAreArgvOnly() {
    verify(Store.push(fresh(), { id: "a", title: "x", actions: [{ label: "Go", exec: "rm -rf ~" }] }, 0).error)
    verify(Store.push(fresh(), { id: "a", title: "x", actions: [{ label: "Go", exec: [] }] }, 0).error)
    verify(Store.push(fresh(), { id: "a", title: "x", actions: [{ label: "Go", exec: ["ls", 3] }] }, 0).error)
    verify(Store.push(fresh(), { id: "a", title: "x", actions: [{ exec: ["ls"] }] }, 0).error)
    verify(Store.push(fresh(), { id: "a", title: "x", actions: { label: "Go" } }, 0).error)
    var s = fresh()
    var acts = []
    for (let i = 0; i < 5; i++) acts.push({ label: "A" + i, exec: ["echo", String(i)], shell: true })
    Store.push(s, { id: "a", title: "x", actions: acts }, 0)
    compare(s.items.a.actions.length, 3)
    compare(s.items.a.actions[2].exec, ["echo", "2"])
    compare(s.items.a.actions[0].shell, undefined)
  }

  function test_pushReplacesById() {
    var s = fresh()
    Store.push(s, { id: "a", title: "one", subtitle: "keep?" }, 0)
    Store.push(s, { id: "a", title: "two" }, 10)
    compare(Store.count(s), 1)
    compare(s.items.a.title, "two")
    compare(s.items.a.subtitle, "")
  }

  function test_updateShallowMerges() {
    var s = fresh()
    Store.push(s, { id: "a", title: "Build", subtitle: "1/3", compact: { leading: "L", trailing: "1" } }, 0)
    compare(Store.update(s, "a", '{"progress":0.5,"compact":{"trailing":"50%"}}', 50), "ok")
    compare(s.items.a.title, "Build")
    compare(s.items.a.subtitle, "1/3")
    compare(s.items.a.progress, 0.5)
    // Shallow: compact is replaced whole.
    compare(s.items.a.compact.leading, "")
    compare(s.items.a.compact.trailing, "50%")
    compare(s.items.a.updatedAt, 50)
    compare(s.items.a.createdAt, 0)
  }

  function test_updateErrors() {
    var s = fresh()
    compare(Store.update(s, "nope", "{}", 0), "unknown")
    Store.push(s, { id: "a", title: "x" }, 0)
    verify(Store.update(s, "a", "{bad", 0).indexOf("error") === 0)
    verify(Store.update(s, "a", '{"state":"zzz"}', 0).indexOf("error") === 0)
    verify(Store.update(s, "a", '{"id":"b"}', 0).indexOf("error") === 0)
    compare(s.items.a.state, "running")
  }

  function test_endShowsResultThenRemoves() {
    var s = fresh()
    Store.push(s, { id: "a", title: "x", progress: 0.4 }, 0)
    compare(Store.end(s, "a", "success", 1000), "ok")
    compare(s.items.a.state, "success")
    compare(s.items.a.progress, 1)
    compare(Store.expire(s, 3999).removed.length, 0)
    compare(Store.expire(s, 4000).removed, ["a"])
    compare(Store.count(s), 0)
  }

  function test_endDefaultsAndErrors() {
    var s = fresh()
    compare(Store.end(s, "x", "", 0), "unknown")
    Store.push(s, { id: "a", title: "x", state: "error" }, 0)
    Store.end(s, "a", "", 0)
    compare(s.items.a.state, "error")
    Store.push(s, { id: "b", title: "x" }, 0)
    verify(Store.end(s, "b", "maybe", 0).indexOf("error") === 0)
    Store.end(s, "b", "", 0)
    compare(s.items.b.state, "success")
  }

  function test_endTopPicksFirstLive() {
    var s = fresh()
    Store.push(s, { id: "low", title: "x", priority: "low" }, 0)
    Store.push(s, { id: "hot", title: "x", priority: "urgent" }, 0)
    Store.end(s, "top", "", 10)
    verify(s.items.hot.endsAt > 0)
    Store.end(s, "top", "error", 20)
    compare(s.items.low.state, "error")
    compare(Store.end(s, "top", "", 30), "unknown")
  }

  function test_ttlExpiry() {
    var s = fresh()
    Store.push(s, { id: "a", title: "x", ttl: 10 }, 0)
    Store.push(s, { id: "b", title: "x" }, 0)
    compare(Store.nextDeadline(s), 10000)
    compare(Store.expire(s, 9999).removed.length, 0)
    compare(Store.expire(s, 10000).removed, ["a"])
    // An update refreshes the ttl.
    Store.push(s, { id: "c", title: "x", ttl: 10 }, 0)
    Store.update(s, "c", "{}", 8000)
    compare(Store.expire(s, 12000).removed.length, 0)
    compare(Store.expire(s, 18000).removed, ["c"])
  }

  function test_sorting() {
    var s = fresh()
    Store.push(s, { id: "done", title: "x", state: "success" }, 10)
    Store.push(s, { id: "run1", title: "x" }, 20)
    Store.push(s, { id: "wait", title: "x", state: "waiting" }, 5)
    Store.push(s, { id: "run2", title: "x" }, 30)
    Store.push(s, { id: "urgent", title: "x", priority: "urgent", state: "success" }, 1)
    Store.push(s, { id: "ending", title: "x", priority: "urgent" }, 40)
    Store.end(s, "ending", "", 40)
    var ids = Store.sorted(s).map(function(a) { return a.id })
    compare(ids, ["urgent", "wait", "run2", "run1", "done", "ending"])
    compare(Store.top(s).id, "urgent")
  }

  function test_sameTimeUsesPushOrder() {
    var s = fresh()
    Store.push(s, { id: "a", title: "x" }, 0)
    Store.push(s, { id: "b", title: "x" }, 0)
    compare(Store.sorted(s)[0].id, "b")
  }

  function test_maxTwentyEvictsLowPriorityFirst() {
    var s = fresh()
    Store.push(s, { id: "old-low", title: "x", priority: "low" }, 0)
    Store.push(s, { id: "urgent", title: "x", priority: "urgent" }, 0)
    for (let i = 0; i < 18; i++) Store.push(s, { id: "n" + i, title: "x" }, i + 1)
    compare(Store.count(s), 20)
    Store.push(s, { id: "new-low", title: "x", priority: "low" }, 100)
    compare(Store.count(s), 20)
    compare(s.items["old-low"], undefined)
    verify(s.items["new-low"])
    // The next push evicts the remaining low one before any normal one.
    Store.push(s, { id: "another", title: "x" }, 101)
    compare(s.items["new-low"], undefined)
    verify(s.items.n0)
    // Then the oldest normal; urgent stays.
    Store.push(s, { id: "more", title: "x" }, 102)
    compare(s.items.n0, undefined)
    verify(s.items.urgent)
  }

  function test_evictionPrefersEnded() {
    var s = fresh()
    for (let i = 0; i < 20; i++) Store.push(s, { id: "n" + i, title: "x", priority: "low" }, i)
    Store.end(s, "n19", "", 50)
    Store.push(s, { id: "z", title: "x" }, 60)
    compare(s.items.n19, undefined)
    verify(s.items.n0)
  }

  function test_countdownFinishes() {
    var s = fresh()
    Store.push(s, { id: "timer:1", title: "Focus", ttl: 1560 }, 0, { deadline: 1500000 })
    compare(Store.nextDeadline(s), 1500000)
    var r = Store.expire(s, 1500000)
    compare(r.finished, ["timer:1"])
    compare(s.items["timer:1"].priority, "normal")
    compare(s.items["timer:1"].state, "success")
    compare(Store.expire(s, 1500001).finished.length, 0)
    compare(Store.expire(s, 1560000).removed, ["timer:1"])
  }

  function test_updateKeepsDeadline() {
    var s = fresh()
    Store.push(s, { id: "t", title: "x" }, 0, { deadline: 5000 })
    Store.update(s, "t", '{"title":"y"}', 10)
    compare(s.items.t.deadline, 5000)
  }

  function test_snapshotIsACopy() {
    var s = fresh()
    Store.push(s, { id: "a", title: "x" }, 0)
    var snap = Store.snapshot(s)
    snap[0].title = "changed"
    compare(s.items.a.title, "x")
  }

  function test_renderDelayCoalescesToTenPerSecond() {
    compare(Store.renderDelay(0, 100), 0)
    compare(Store.renderDelay(0, 500), 0)
    compare(Store.renderDelay(1000, 1030), 70)
    compare(Store.renderDelay(1000, 1000), 100)
  }

  function test_countdownText() {
    compare(Store.countdownText(25 * 60000, 0), "25:00")
    compare(Store.countdownText(61000, 500), "1:01")
    compare(Store.countdownText(3723000, 0), "1:02:03")
    compare(Store.countdownText(0, 5000), "0:00")
  }

  function test_trailingAndLeading() {
    compare(Store.trailingText(null, 0), "")
    compare(Store.trailingText({ compact: { trailing: "REC" }, progress: 0.5 }, 0), "REC")
    compare(Store.trailingText({ compact: { trailing: "" }, progress: 0.374 }, 0), "37%")
    compare(Store.trailingText({ compact: { trailing: "" }, progress: null, deadline: 90000, endsAt: 0, state: "running" }, 0), "1:30")
    compare(Store.trailingText({ compact: { trailing: "" }, progress: null }, 0), "")
    compare(Store.leadingGlyph({ compact: { leading: "L" }, glyph: "G" }), "L")
    compare(Store.leadingGlyph({ compact: { leading: "" }, glyph: "G" }), "G")
    verify(Store.leadingGlyph({ compact: { leading: "" }, glyph: "", state: "error" }) !== "")
    verify(Store.hasCountdown([{ deadline: 5, endsAt: 0, state: "running", compact: { trailing: "" } }]))
    verify(!Store.hasCountdown([{ deadline: 5, endsAt: 0, state: "success", compact: { trailing: "Done" } }]))
  }

  function test_updateAfterEndIsUnknown() {
    var s = fresh()
    Store.push(s, { id: "a", title: "x" }, 0)
    Store.end(s, "a", "success", 10)
    compare(Store.update(s, "a", '{"progress":0.9}', 20), "unknown")
    verify(s.items.a.endsAt > 0)
  }

  function test_removeIsImmediate() {
    var s = fresh()
    Store.push(s, { id: "a", title: "x", progress: 0.3 }, 0)
    compare(Store.remove(s, "a"), "ok")
    compare(Store.count(s), 0)
    compare(Store.remove(s, "a"), "unknown")
  }

  function test_newLowIsEvictedWhenAllOthersOutrankIt() {
    var s = fresh()
    for (let i = 0; i < 20; i++) Store.push(s, { id: "u" + i, title: "x", priority: "urgent" }, i)
    Store.push(s, { id: "low", title: "x", priority: "low" }, 100)
    compare(s.items.low, undefined)
    compare(Store.count(s), 20)
    // A new urgent one replaces the oldest urgent.
    Store.push(s, { id: "u20", title: "x", priority: "urgent" }, 101)
    compare(s.items.u0, undefined)
    verify(s.items.u20)
  }

  function test_longestTimerStillFinishes() {
    var s = fresh()
    Store.push(s, { id: "t", title: "x", ttl: 86460 }, 0, { deadline: 86400000 })
    var r = Store.expire(s, 86400000)
    compare(r.finished, ["t"])
    compare(r.removed.length, 0)
  }

  function test_prototypeNamesArePlainIds() {
    var s = fresh()
    compare(Store.push(s, '{"id":"__proto__","title":"Evil"}', 0).id, "__proto__")
    Store.push(s, { id: "ok", title: "x" }, 1)
    compare(Store.count(s), 2)
    compare(Store.sorted(s).length, 2)
    compare(Store.expire(s, 2).removed.length, 0)
    compare(Store.end(s, "toString", "", 3), "unknown")
    compare(Store.remove(s, "hasOwnProperty"), "unknown")
    compare(Store.update(s, "constructor", "{}", 3), "unknown")
    compare(Store.end(s, "__proto__", "", 4), "ok")
  }

  function test_markupIsDroppedFromGlyphLikeFields() {
    var s = fresh()
    Store.push(s, { id: "a", title: "x", glyph: "<b>", compact: { leading: "<img src=/a.png>" },
                    actions: [{ label: "<i>Go</i>", exec: ["true"] }] }, 0)
    compare(s.items.a.glyph, "b")
    compare(s.items.a.compact.leading, "img src=/a.png")
    compare(s.items.a.actions[0].label, "iGo/i")
  }

  function test_countUp() {
    var s = fresh()
    Store.push(s, { id: "rec", title: "Recording" }, 1000, { since: 1000, own: true, quiet: true })
    compare(Store.trailingText(s.items.rec, 1000 + 192500), "3:12")
    compare(Store.elapsedText(0, 3723000), "1:02:03")
    verify(Store.isCounting(s.items.rec))
    verify(Store.hasCountdown(Store.sorted(s)))
    // A count-up never finishes on its own.
    compare(Store.expire(s, 5000).finished.length, 0)
  }

  function test_pulsing() {
    var s = fresh()
    Store.push(s, { id: "claude:1", title: "Claude Code needs you", state: "waiting", priority: "urgent" }, 0)
    verify(Store.isPulsing(s.items["claude:1"]))
    // Going on (the recipe's update) stops it; so does ending.
    compare(Store.update(s, "claude:1", { state: "running", priority: "normal" }, 10), "ok")
    verify(!Store.isPulsing(s.items["claude:1"]))
    Store.update(s, "claude:1", { state: "waiting", priority: "urgent" }, 20)
    Store.end(s, "claude:1", "success", 30)
    verify(!Store.isPulsing(s.items["claude:1"]))
    Store.push(s, { id: "w", title: "x", state: "waiting" }, 0)
    verify(!Store.isPulsing(s.items.w))
    verify(!Store.isPulsing(null))
  }

  function test_serviceFieldsSurviveUpdatesAndCannotBeSent() {
    var s = fresh()
    Store.push(s, { id: "a", title: "x", own: true, since: 5, quiet: true, deadline: 9 }, 0)
    compare(s.items.a.own, undefined)
    compare(s.items.a.since, undefined)
    compare(s.items.a.deadline, undefined)
    // Omavisor's own activities cannot be updated by senders (no swapped-in
    // actions that would run as Omavisor's).
    Store.push(s, { id: "b", title: "x" }, 0, { own: true, since: 7, quiet: true })
    verify(Store.update(s, "b", { actions: [{ label: "Go", exec: ["rm", "-rf", "/x"] }] }, 1).indexOf("error") === 0)
    compare(s.items.b.actions.length, 0)
    compare(s.items.b.own, true)
    // Other service fields survive a sender's update.
    Store.push(s, { id: "c", title: "x" }, 0, { since: 7, deadline: 9 })
    compare(Store.update(s, "c", { subtitle: "y", since: 1 }, 1), "ok")
    compare(s.items.c.since, 7)
    compare(s.items.c.deadline, 9)
  }

  function test_ownCannotBeReplacedOrEndedAsTop() {
    var s = fresh()
    Store.push(s, { id: "rec", title: "REC", priority: "urgent" }, 0, { own: true, quiet: true })
    Store.push(s, { id: "mine", title: "x" }, 1)
    verify(Store.push(s, { id: "rec", title: "fake" }, 2).error !== undefined)
    compare(s.items.rec.title, "REC")
    // Omavisor itself may push it again.
    compare(Store.push(s, { id: "rec", title: "REC 2", priority: "urgent" }, 3, { own: true }).id, "rec")
    compare(Store.end(s, "top", "", 4), "ok")
    compare(s.items.mine.endsAt > 0, true)
    compare(s.items.rec.endsAt, 0)
  }

  function test_ownIsEvictedLast() {
    var s = fresh()
    Store.push(s, { id: "timer:a", title: "Focus" }, 0, { own: true, deadline: 99999 })
    Store.push(s, { id: "upd", title: "Update", priority: "low" }, 0, { own: true })
    for (let i = 0; i < 25; i++) Store.push(s, { id: "n" + i, title: "x" }, 10 + i)
    verify(s.items["timer:a"] !== undefined)
    verify(s.items.upd !== undefined)
    compare(Store.count(s), 20)
  }
}
