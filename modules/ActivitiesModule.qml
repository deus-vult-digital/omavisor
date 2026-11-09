pragma ComponentBehavior: Bound

import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.Commons
import "../lib/ActivityStore.js" as Store
import "../lib/Catalog.js" as Catalog
import "../lib/Settings.js" as Settings

// Live activities (SPEC.md section 8): the one store, the spool directory,
// expiry, and what the pills should peek or bloom.
//
// The store is a plain JS object mutated in place; `items` is the snapshot
// the UI binds to, refreshed at most 10 times a second however fast pushes
// arrive. IPC answers (`list`, ids, errors) read the store directly, so they
// are never stale.
//
// The service does not hold the pills: imported from the service,
// PillRegistry turned out not to see them (tested: `expand` found no pill;
// the service is created outside the bar's component tree), so it reaches
// them through the shell (expand/collapse go through
// Omavisor's Hub panel route) and the bloom signal (the focused pill answers).
Item {
  id: root
  visible: false

  // The service's scoped shell facade and Omavisor's plugin id.
  property var shell: null
  property string pluginId: "dev.deusvult.omavisor"

  // An urgent activity should bloom out of the focused monitor's pill.
  signal bloomRequested(string id)
  // A countdown reached its deadline (TimerModule listens for its own).
  signal finished(string id)

  // Normalised (no doubled or trailing slashes), so it compares equal to
  // the paths the folder model reports.
  readonly property string stateDir: ((Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/omavisor").replace(/\/+/g, "/")
  readonly property string spoolDir: stateDir + "/activities"

  property var store: Store.create()
  // Sorted snapshot for the UI (see ActivityStore.sorted).
  property var items: []
  // `activityRules`: the most each kind of activity may do (the pills set it).
  property var rules: ({})
  // The first activity allowed a badge, which the pill's peek and badge show.
  readonly property var first: Catalog.firstBadged(items, rules)

  // Pills peek for 4 s when this changes; peekId names the new activity.
  property string peekId: ""
  property int peekSerial: 0

  property real _lastRender: 0
  // id -> spool file path, for activities that came from the spool.
  property var _spoolFiles: Object.create(null)
  // id -> the spool file content last pushed, so a file read again
  // unchanged (the folder model re-lists every file on any change in the
  // directory) is not pushed again.
  property var _spoolContent: Object.create(null)
  // id -> the last warning logged for its spool file (once per problem).
  property var _spoolErrors: Object.create(null)
  // Urgent ids waiting on the DND check before they bloom.
  property var _bloomQueue: []

  // Spool files written before this start are restored quietly (no peek or
  // bloom on every shell restart).
  readonly property real startedAt: Date.now()

  readonly property string focusedScreen: Hyprland.focusedMonitor ? String(Hyprland.focusedMonitor.name || "") : ""

  // ------------------------------------------------------------ mutations

  // Each returns the IPC answer. `at` backdates the push (a spool file's
  // mtime), so its ttl runs from when it was written.
  function push(input, extra, at) {
    var data = input
    if (typeof input === "string") {
      try { data = JSON.parse(input) } catch (e) { return "error: invalid JSON" }
    }
    if (!data || typeof data !== "object" || Array.isArray(data)) return "error: activity must be a JSON object"
    var existed = data && typeof data === "object" && !Array.isArray(data) && typeof data.id === "string"
      ? store.items[data.id] : null
    var wasUrgent = !!existed && existed.priority === "urgent" && existed.endsAt === 0
    var now = Date.now()
    var time = at > 0 && at < now ? at : now
    var result = Store.push(store, data, time, extra)
    if (result.error) return "error: " + result.error
    changed()
    // Gone already: a backdated push older than its ttl, or evicted.
    if (!store.items[result.id]) return time < now ? "expired" : "error: evicted: 20 live activities outrank it"
    if (time >= startedAt && store.items[result.id]) {
      if (!existed) announce(result.id)
      if (!wasUrgent) maybeBloom(result.id)
    }
    return result.id
  }

  function update(id, patch) {
    var before = store.items[id]
    var wasUrgent = !!before && before.priority === "urgent" && before.endsAt === 0
    var answer = Store.update(store, String(id), patch, Date.now())
    if (answer === "ok") {
      changed()
      if (!wasUrgent) maybeBloom(String(id))
    }
    return answer
  }

  function end(id, result) {
    var answer = Store.end(store, String(id), result || "", Date.now())
    if (answer === "ok") changed()
    return answer
  }

  // The tab's dismiss: gone at once, not reported as done.
  function dismiss(id) {
    var answer = Store.remove(store, String(id))
    if (answer === "ok") changed()
    return answer
  }

  function list() {
    return JSON.stringify(Store.snapshot(store))
  }

  // Run an activity's action: argv only, only from a click, only when the
  // pill's allowActions setting is on (the caller passes it) or the
  // activity is Omavisor's own (the store keeps senders from claiming that).
  function runAction(id, index, allowed) {
    var item = store.items[String(id)]
    if (!allowed && !(item && item.own === true)) return false
    var action = item && item.actions ? item.actions[index] : null
    if (!action || !Array.isArray(action.exec) || action.exec.length === 0) return false
    Util.execArgv(action.exec)
    return true
  }

  // Something changed: sweep, reschedule and render (coalesced).
  function changed() {
    sweep()
    if (renderTimer.running) return
    var wait = Store.renderDelay(_lastRender, Date.now())
    if (wait === 0) render()
    else { renderTimer.interval = wait; renderTimer.start() }
  }

  function render() {
    _lastRender = Date.now()
    items = Store.snapshot(store)
  }

  function sweep() {
    var now = Date.now()
    var done = Store.expire(store, now)
    // A finished timer peeks and blooms once (it is not urgent, so it does
    // not hold the top spot or answer to `end top` afterwards).
    for (let i = 0; i < done.finished.length; i++) {
      announce(done.finished[i])
      maybeBloom(done.finished[i], true)
      // After this sweep, so a listener may push again.
      let id = done.finished[i]
      Qt.callLater(function() { root.finished(id) })
    }
    // Activities that left the store take their spool file with them, so a
    // restart does not bring them back.
    var files = _spoolFiles
    for (let id in files) {
      if (!store.items[id]) {
        // Only ever a *.json directly in the spool dir.
        if (root.isSpoolPath(files[id])) Quickshell.execDetached(["rm", "-f", "--", files[id]])
        delete files[id]
      }
    }
    var next = Store.nextDeadline(store)
    if (next > 0) {
      deadlineTimer.interval = Math.max(10, Math.min(next - now, 2147483000))
      deadlineTimer.restart()
    } else {
      deadlineTimer.stop()
    }
    if (done.removed.length > 0 || done.finished.length > 0) changed()
  }

  function announce(id) {
    if (!Catalog.activityAllows(rules, id, "peek")) return
    peekId = id
    peekSerial++
  }

  // Urgent activities bloom out of the focused monitor's pill, unless
  // notifications are silenced (Do Not Disturb), checked each time.
  function maybeBloom(id, always) {
    var item = store.items[id]
    if (!item || ((item.priority !== "urgent" || item.quiet) && !always) || item.endsAt > 0) return
    if (_bloomQueue.indexOf(id) < 0) _bloomQueue = _bloomQueue.concat([id])
    if (!dnd.running) dnd.running = true
  }

  function bloomQueued(silenced) {
    var queue = _bloomQueue
    _bloomQueue = []
    if (silenced) return
    for (let i = 0; i < queue.length; i++) {
      if (!store.items[queue[i]]) continue
      // Asked to bloom but held to less: the most it may do.
      if (!Catalog.activityAllows(rules, queue[i], "bloom")) { announce(queue[i]); continue }
      render()
      bloomRequested(queue[i])
    }
  }

  // ------------------------------------------------------------ hub

  function expand(tab) {
    if (tab !== "" && Settings.normalizeTab(tab) === "") return "error: unknown tab: " + tab
    if (!shell || typeof shell.summon !== "function") return "error: shell unavailable"
    return shell.summon(pluginId, JSON.stringify({ tab: tab })) === false ? "error: could not open the hub" : "ok"
  }

  function collapse() {
    if (shell && typeof shell.hide === "function") shell.hide(pluginId)
    return "ok"
  }

  // ------------------------------------------------------------ timers

  Timer {
    id: renderTimer
    repeat: false
    onTriggered: root.render()
  }

  Timer {
    id: deadlineTimer
    repeat: false
    onTriggered: root.changed()
  }

  Process {
    id: dnd
    command: ["omarchy-shell", "notifications", "dndState"]
    stdout: StdioCollector {
      id: dndOut
      waitForEnd: true
    }
    // Unknown (the call failed) counts as not silenced.
    onExited: function(code) { root.bloomQueued(code === 0 && dndOut.text.trim() === "on") }
  }

  // ------------------------------------------------------------ spool

  // Any *.json in the spool dir is a push named by its file; removing the
  // file ends it. The folder model watches the directory in-process; each
  // file's FileView watches its content.
  property bool spoolReady: false

  Process {
    id: makeSpool
    running: true
    command: ["mkdir", "-p", "--", root.spoolDir]
    onExited: function(code) {
      if (code !== 0) console.warn("omavisor: cannot create the spool directory", root.spoolDir, "- spool files are ignored")
      else root.spoolReady = true
    }
  }

  // The model gets a folder only once mkdir is done: an empty folder would
  // make it list the shell's working directory (the home folder).
  FolderListModel {
    id: spoolModel
    folder: root.spoolReady ? "file://" + root.spoolDir : "file:///nonexistent-omavisor-spool"
    nameFilters: ["*.json"]
    showDirs: false
    showDotAndDotDot: false
    showHidden: false
    sortField: FolderListModel.Name
  }

  Instantiator {
    model: root.spoolReady ? spoolModel : null

    delegate: Item {
      id: entry
      required property string fileName
      required property string filePath
      required property date fileModified
      readonly property string activityId: fileName.slice(0, -5)

      FileView {
        path: root.isSpoolPath(entry.filePath) ? entry.filePath : ""
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: entry.load(text())
      }

      function load(content) {
        // A file caught between create and write is empty: wait for it.
        if (String(content || "").trim() === "") return
        var answer = root.pushSpool(entry.activityId, entry.filePath, content, entry.fileModified)
        // One warning per distinct problem, not one per write (the
        // delegate is recreated on every re-list, so this lives on root).
        var failed = answer.indexOf("error") === 0
        if (failed && root._spoolErrors[entry.activityId] !== answer)
          console.warn("omavisor: ignoring spool file", entry.fileName + ":", answer.slice(7))
        if (failed) root._spoolErrors[entry.activityId] = answer
        else delete root._spoolErrors[entry.activityId]
      }
    }

    // The model drops and re-lists every row whenever the directory
    // changes, so a removed row only means a removed file once the listing
    // has settled without it.
    onObjectRemoved: function(index, object) {
      root._maybeRemoved = root._maybeRemoved.concat([object.activityId])
      removalCheck.restart()
    }
  }

  property var _maybeRemoved: []

  Timer {
    id: removalCheck
    interval: 250
    onTriggered: {
      if (spoolModel.status !== FolderListModel.Ready) { restart(); return }
      var present = Object.create(null)
      for (let i = 0; i < spoolModel.count; i++) present[String(spoolModel.get(i, "fileName")).slice(0, -5)] = true
      var ids = root._maybeRemoved
      root._maybeRemoved = []
      for (let k = 0; k < ids.length; k++) if (!present[ids[k]]) root.spoolRemoved(ids[k])
    }
  }

  // Omavisor only reads, and only deletes, *.json files directly in its spool
  // directory, whatever a model hands it.
  function isSpoolPath(path) {
    var p = String(path || "")
    var prefix = spoolDir + "/"
    return spoolReady && p.indexOf(prefix) === 0 && p.slice(-5) === ".json"
      && p.slice(prefix.length).indexOf("/") < 0
  }

  function pushSpool(id, path, content, modified) {
    if (!isSpoolPath(path)) return "error: outside the spool directory"
    var data
    try { data = JSON.parse(String(content || "")) } catch (e) { return "error: invalid JSON" }
    if (!data || typeof data !== "object" || Array.isArray(data)) return "error: activity must be a JSON object"
    // The file name is the id.
    data.id = id
    var text = String(content)
    if (_spoolContent[id] === text) return id
    // A file left from before this start keeps its age, so its ttl runs
    // from when it was written (one older than its ttl is swept right away,
    // file and all). Later reads are rewrites: they count from now (the
    // model's mtime is not refreshed by a rewrite in place).
    var mtime = modified ? modified.getTime() : NaN
    var restored = _spoolContent[id] === undefined && isFinite(mtime) && mtime < startedAt
    var answer = push(data, null, restored ? mtime : 0)
    // Left from before this start and already past its ttl: sweep it.
    if (answer === "expired") {
      Quickshell.execDetached(["rm", "-f", "--", path])
      return id
    }
    if (answer.indexOf("error") === 0) return answer
    _spoolContent[id] = text
    var files = _spoolFiles
    files[id] = path
    sweep()
    return answer
  }

  function spoolRemoved(id) {
    delete _spoolContent[id]
    if (!_spoolFiles[id]) return
    delete _spoolFiles[id]
    end(id, "")
  }
}
