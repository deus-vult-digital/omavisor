import QtQuick
import "../lib/Keybindings.js" as Keybindings

// Keybinding cheatsheet (SPEC.md section 7, v1): `omarchy menu keybindings
// --print` (lines like "SUPER + K → Keybindings"), read when the Keys tab
// opens, at most once a minute, so a binding added since shows next time.
// Without the command the tab says so.
Item {
  id: root
  visible: false

  property var bindings: []
  property bool loaded: false
  readonly property bool available: !probe.missing
  property real _readAt: 0

  function refresh() {
    if (loaded && Date.now() - _readAt < 60000) return
    if (probe.run()) _readAt = Date.now()
  }

  function filtered(query) { return Keybindings.filterBindings(bindings, query) }

  Probe {
    id: probe
    command: ["omarchy", "menu", "keybindings", "--print"]
    timeoutMs: 10000
    onFinished: function(code, output) {
      if (code === 0) root.bindings = Keybindings.keybindings(output)
      root.loaded = true
    }
  }
}
