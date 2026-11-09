import QtQuick
import "../lib/System.js" as System

// Do Not Disturb, night light and stay awake (SPEC.md section 7), through
// Omarchy's own commands: Omavisor cannot reach the shell's notification,
// nightlight or idle services (first-party only), so it asks and toggles
// the way a keybind would.
//
// - DND: `omarchy-shell notifications isDnd` (`dndState` before 4.5) /
//   `toggleDnd`.
// - Night light: `omarchy-toggle-nightlight --status` (reads hyprsunset
//   directly, so it is current right after a toggle) / `omarchy toggle
//   nightlight`.
// - Stay awake: `omarchy-toggle-idle status` (the stay-awake flag file) /
//   `omarchy toggle idle`.
//
// State is read when something showing it appears (`refresh()`) and after
// each toggle; a click flips the switch at once and the read-back corrects
// it. A state that cannot be read is null and its switch is hidden.
Item {
  id: root
  visible: false

  property var dnd: null
  property var nightLight: null
  property var stayAwake: null
  readonly property bool available: dnd !== null || nightLight !== null || stayAwake !== null

  property bool hyprsunset: false

  function refresh() {
    dndRead.run()
    if (hyprsunset) nightRead.run()
    awakeRead.run()
  }

  // A read that was already under way when a toggle finished may hold the
  // old state: read once more after it, and let only that one count.
  property var _reread: ({})
  function readAfterSet(probe, key) {
    if (!probe.run()) { const r = _reread; r[key] = true; _reread = r }
  }
  function settle(key, probe) {
    if (!_reread[key]) return true
    var r = _reread; delete r[key]; _reread = r
    Qt.callLater(function() { probe.run() })
    return false
  }

  // `omarchy-toggle-nightlight --status` answers even without hyprsunset.
  Probe {
    id: hasSunset
    command: ["sh", "-c", "command -v hyprsunset"]
    onFinished: function(code) { root.hyprsunset = code === 0; if (code === 0) nightRead.run() }
  }
  // `omavisor dnd` works before any panel has shown the state.
  Component.onCompleted: {
    hasSunset.run()
    dndRead.run()
  }

  function toggleDnd() {
    if (dnd === null || dndSet.running) return
    dnd = !dnd
    dndSet.run()
  }

  function toggleNightLight() {
    if (nightLight === null || nightSet.running) return
    nightLight = !nightLight
    nightSet.run()
  }

  function toggleStayAwake() {
    if (stayAwake === null || awakeSet.running) return
    stayAwake = !stayAwake
    awakeSet.run()
  }

  // Omarchy 4.5 renamed dndState to isDnd (same "on"/"off"); an older shell
  // answers isDnd with "Function not found", so read it once the old way.
  property string dndMethod: "isDnd"
  Probe {
    id: dndRead
    command: ["omarchy-shell", "notifications", root.dndMethod]
    onFinished: function(code, output) {
      if (code !== 0 && root.dndMethod === "isDnd") {
        root.dndMethod = "dndState"
        Qt.callLater(dndRead.run)
        return
      }
      if (root.settle("dnd", dndRead) && !dndSet.running) root.dnd = code === 0 ? System.dndFlag(output) : null
    }
  }
  Probe {
    id: dndSet
    command: ["omarchy-shell", "notifications", "toggleDnd"]
    onFinished: root.readAfterSet(dndRead, "dnd")
  }

  Probe {
    id: nightRead
    command: ["omarchy-toggle-nightlight", "--status"]
    onFinished: function(code, output) { if (root.settle("night", nightRead) && !nightSet.running) root.nightLight = code === 0 ? System.jsonFlag(output, "enabled") : null }
  }
  Probe {
    id: nightSet
    command: ["omarchy", "toggle", "nightlight"]
    // Starting hyprsunset and making the temperature stick takes a moment.
    timeoutMs: 10000
    onFinished: root.readAfterSet(nightRead, "night")
  }

  Probe {
    id: awakeRead
    command: ["omarchy-toggle-idle", "status"]
    onFinished: function(code, output) { if (root.settle("awake", awakeRead) && !awakeSet.running) root.stayAwake = code === 0 ? System.jsonFlag(output, "enabled") : null }
  }
  Probe {
    id: awakeSet
    command: ["omarchy", "toggle", "idle"]
    onFinished: root.readAfterSet(awakeRead, "awake")
  }
}
