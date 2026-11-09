import QtQuick
import QtTest
import "../lib/Timers.js" as Timers

TestCase {
  name: "Timers"

  readonly property real t0: 1700000000000

  function make(minutes, kind, label) {
    return Timers.create("timer:a", minutes, label || "", kind || "timer", t0).timer
  }

  function test_create() {
    var t = make(25)
    compare(t.deadline, t0 + 25 * 60000)
    compare(t.label, "Timer")
    compare(t.kind, "timer")
    compare(make(25, "focus").label, "Focus")
    compare(make(5, "nope").kind, "timer")
    verify(Timers.create("timer:a", 0, "", "timer", t0).error !== undefined)
    verify(Timers.create("timer:a", 1441, "", "timer", t0).error !== undefined)
    verify(Timers.create("timer:a", "x", "", "timer", t0).error !== undefined)
    verify(Timers.create("bad id", 5, "", "timer", t0).error !== undefined)
  }

  function test_label() {
    // Never an option to the notification command.
    compare(make(5, "timer", "--help").label, "help")
    compare(make(5, "timer", " -").label, "Timer")
    compare(make(5, "timer", "a\nb").label, "a b")
    compare(make(5, "timer", "x".repeat(60)).label.length, 40)
  }

  function test_pauseResume() {
    var t = make(10)
    var p = Timers.pause(t, t0 + 60000)
    verify(Timers.isPaused(p))
    compare(p.left, 9 * 60000)
    compare(Timers.remaining(p, t0 + 10 * 3600000), 9 * 60000)
    // The original is untouched.
    verify(!Timers.isPaused(t))
    compare(Timers.pause(p, t0), p)
    var r = Timers.resume(p, t0 + 120000)
    compare(r.deadline, t0 + 120000 + 9 * 60000)
    compare(r.startedAt, t0 + 120000)
    compare(Timers.remaining(r, t0 + 120000 + 9 * 60000 + 5), 0)
  }

  function test_clock() {
    compare(Timers.clock(25 * 60000), "25:00")
    compare(Timers.clock(59500), "1:00")
    compare(Timers.clock(3723000), "1:02:03")
    compare(Timers.clock(-5), "0:00")
  }

  function test_activity() {
    var t = make(25)
    var a = Timers.activity(t, t0 + 1000, 0)
    compare(a.data.id, "timer:a")
    compare(a.extra.deadline, t.deadline)
    compare(a.extra.own, true)
    compare(a.at, t0)
    // The ttl covers the run from `at`, plus the minute shown as Done.
    compare(a.data.ttl, 25 * 60 + 60)
    // Backdated for a restore.
    var b = Timers.activity(t, t0 + 1000, t0 - 5000)
    compare(b.at, t0 - 5000)
    compare(b.data.ttl, 25 * 60 + 5 + 60)
    var p = Timers.activity(Timers.pause(t, t0 + 60000), t0 + 90000, 0)
    compare(p.extra.deadline, undefined)
    compare(p.data.compact.trailing, "24:00")
    compare(p.data.subtitle, "Paused")
    compare(p.at, t0 + 90000)
    // A 24-hour timer stays within the store's ttl limit.
    compare(Timers.activity(make(1440), t0, 0).data.ttl, 86400)
  }

  function test_next() {
    var after = Timers.next(make(25, "focus"), "timer:b", t0)
    compare(after.kind, "break")
    compare(after.minutes, 5)
    compare(after.id, "timer:b")
    compare(Timers.next(make(5, "break"), "timer:c", t0), null)
    compare(Timers.next(make(5), "timer:c", t0), null)
    compare(Timers.notice(make(5, "timer", "Tea"))[1], "Tea")
    compare(Timers.notice(make(25, "focus"))[0], "Focus done")
  }

  function test_persist() {
    var list = [make(25), Timers.pause(Timers.create("timer:b", 5, "Tea", "timer", t0).timer, t0 + 1000)]
    var back = Timers.parse(Timers.serialize(list))
    compare(back.length, 2)
    compare(back[0].deadline, list[0].deadline)
    compare(back[1].left, 5 * 60000 - 1000)
    compare(back[1].label, "Tea")
    compare(Timers.parse("not json"), [])
    compare(Timers.parse("{}"), [])
    // Malformed, duplicate and spent entries are dropped.
    var bad = JSON.stringify({ version: 1, timers: [
      { id: "timer:x", kind: "timer", minutes: 5, deadline: t0 },
      { id: "timer:x", kind: "timer", minutes: 5, deadline: t0 },
      { id: "nope", kind: "timer", minutes: 5, deadline: t0 },
      { id: "timer:y", kind: "weird", minutes: 5, deadline: t0 },
      { id: "timer:z", kind: "timer", minutes: 0, deadline: t0 },
      { id: "timer:w", kind: "timer", minutes: 5, deadline: 0, left: 0 },
      null
    ] })
    compare(Timers.parse(bad).length, 1)
  }
}
