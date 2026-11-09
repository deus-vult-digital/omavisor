import QtQuick
import Quickshell
import Quickshell.Io
import "../lib/Timers.js" as Timers

// Countdowns and pomodoro (SPEC.md section 7). Each timer is shown as a
// live activity (lib/Timers.js `activity`): the store counts it down,
// finishes it at its deadline and blooms it; this module keeps the timer
// list, pause and cancel, and persists it in $XDG_STATE_HOME/omavisor/
// timers.json so timers survive `omarchy restart shell`. A timer that ran
// out while the shell was down finishes (bloom and notification) as soon
// as it is restored.
//
// When one ends: `omarchy notification send -u normal "Timer done"
// "<label>"`, and a pomodoro focus block starts its break. Dismissing or
// ending a timer's activity (Activities tab, `omavisor end <id>`) cancels it.
Item {
  id: root
  visible: false

  property var activities: null

  readonly property string stateDir: ((Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/omavisor").replace(/\/+/g, "/")
  readonly property string path: stateDir + "/timers.json"

  // Live timers, oldest first. Replaced (never mutated), so bindings see
  // each change.
  property var timers: []
  readonly property var presets: Timers.PRESETS
  property bool restored: false
  property int _seq: 0

  function find(id) {
    for (let i = 0; i < timers.length; i++) if (timers[i].id === id) return timers[i]
    return null
  }

  function replace(t) {
    var next = []
    var found = false
    for (let i = 0; i < timers.length; i++) {
      if (timers[i].id === t.id) { next.push(t); found = true }
      else next.push(timers[i])
    }
    if (!found) next.push(t)
    timers = next
  }

  function drop(id) {
    timers = timers.filter(function(t) { return t.id !== id })
  }

  function newId() {
    return "timer:" + Date.now().toString(36) + "-" + (++_seq)
  }

  // "25" or "25 Focus block" from IPC or a tile: its id, or "error: …".
  function start(minutes, label, kind) {
    if (!activities) return "error: not ready"
    var made = Timers.create(newId(), minutes, label, kind || "timer", Date.now())
    if (made.error) return "error: " + made.error
    var answer = show(made.timer)
    if (answer.indexOf("error") === 0) return answer
    replace(made.timer)
    save()
    return made.timer.id
  }

  function startPomodoro() {
    return start(Timers.POMODORO.focus, "Focus", "focus")
  }

  function pause(id) {
    var t = find(id)
    if (!t || Timers.isPaused(t)) return false
    t = Timers.pause(t, Date.now())
    replace(t)
    show(t)
    save()
    return true
  }

  function resume(id) {
    var t = find(id)
    if (!t || !Timers.isPaused(t)) return false
    t = Timers.resume(t, Date.now())
    replace(t)
    show(t)
    save()
    return true
  }

  function cancel(id) {
    if (!find(id)) return false
    drop(id)
    if (activities && activities.store.items[id]) activities.dismiss(id)
    save()
    return true
  }

  // `restoring` dates the push before this start, so a restored timer
  // does not peek again.
  function show(t, restoring) {
    var now = Date.now()
    var a = Timers.activity(t, now, restoring ? Math.min(now, activities.startedAt - 1) : 0)
    return activities.push(a.data, a.extra, a.at)
  }

  // The store finished a countdown; ours end here.
  function timerFinished(id) {
    var t = find(id)
    if (!t) return
    drop(id)
    var words = Timers.notice(t)
    Quickshell.execDetached(["omarchy", "notification", "send", "-u", "normal", words[0], words[1]])
    var after = Timers.next(t, newId(), Date.now())
    if (after && show(after).indexOf("error") !== 0) replace(after)
    save()
  }

  // A timer whose activity is gone or ending was dismissed or ended from
  // outside: cancel it (a finished one has left the list already).
  function reconcile() {
    if (!restored || !activities) return
    var store = activities.store.items
    var gone = timers.filter(function(t) { return !store[t.id] || store[t.id].endsAt > 0 })
    if (gone.length === 0) return
    // A paused timer's activity only lapses after a day untouched: show it
    // again (dismissing it also lands here, so one paused for a day comes
    // back once; cancel removes it for good).
    var now = Date.now()
    var reshown = false
    gone = gone.filter(function(t) {
      var lapsed = Timers.isPaused(t) && !store[t.id] && now - (t.pausedAt || 0) >= 86000000
      if (lapsed) {
        const again = Timers.copy(t)
        again.pausedAt = now
        root.replace(again)
        root.show(again)
        reshown = true
      }
      return !lapsed
    })
    if (gone.length === 0) { if (reshown) save(); return }
    for (let i = 0; i < gone.length; i++) drop(gone[i].id)
    save()
  }

  function restore(text) {
    if (restored || !activities) return
    var list = Timers.parse(text)
    var kept = []
    for (let i = 0; i < list.length; i++) {
      const answer = show(list[i], true)
      if (answer.indexOf("error") !== 0) kept.push(list[i])
    }
    // A timer started before the file was read (a script right after a
    // restart) is kept too.
    for (let j = 0; j < timers.length; j++)
      if (!kept.some(function(t) { return t.id === timers[j].id })) kept.push(timers[j])
    var early = kept.length > list.length
    timers = kept
    restored = true
    // Ones already due finish on the store's next sweep; they are still in
    // `timers`, so timerFinished notifies and saves.
    if (early || kept.length !== list.length) save()
  }

  function save() {
    if (!restored) return
    if (dirReady) file.setText(Timers.serialize(timers))
    else pendingSave = true
  }

  property bool dirReady: false
  property bool pendingSave: false

  Connections {
    target: root.activities
    function onFinished(id) { root.timerFinished(id) }
    function onItemsChanged() { root.reconcile() }
  }

  Process {
    running: true
    command: ["mkdir", "-p", "--", root.stateDir]
    onExited: function(code) {
      if (code !== 0) {
        console.warn("omavisor: cannot create", root.stateDir, "- timers are not kept across restarts")
        return
      }
      root.dirReady = true
      if (root.pendingSave) { root.pendingSave = false; root.save() }
    }
  }

  FileView {
    id: file
    path: root.path
    printErrors: false
    atomicWrites: true
    onLoaded: { root._read = true; root._text = text(); root.restore(root._text) }
    onLoadFailed: { root._read = true; root._text = ""; root.restore("") }
  }

  property bool _read: false
  property string _text: ""

  // The service may hand the activities over after the file has loaded.
  onActivitiesChanged: if (_read) restore(_text)
}
