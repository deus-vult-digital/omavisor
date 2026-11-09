import QtQuick
import Quickshell.Hyprland
import "lib/PillRegistry.js" as PillRegistry

// Panel route for Omavisor, so `omarchy-shell shell toggle
// dev.deusvult.omavisor '{}'` works from a keybind.
//
// The shell sends summon/hide/toggle for a plugin with a panel kind here, not
// to its bar widget. This item draws nothing: it forwards to the pill on the
// focused monitor, which owns the popup. `opened` mirrors the pills (pushed by
// PillRegistry) because the shell reads it to choose between summon and hide:
// it is true only for a hub holding the keyboard, so the toggle keybind on a
// hub the hover opened gives it the keyboard, and the next press closes it.
Item {
  id: root

  property var shell: null
  property var manifest: null
  property bool opened: false

  readonly property string focusedScreen: Hyprland.focusedMonitor ? String(Hyprland.focusedMonitor.name || "") : ""

  // payload: the summon JSON already parsed by the shell, or a string.
  // `{"tab":"media"}` opens on that tab.
  function open(payload) {
    var data = payload
    if (typeof data === "string" && data !== "") {
      try { data = JSON.parse(data) } catch (e) { data = null }
    }
    var tab = data && typeof data === "object" ? data.tab : ""
    PillRegistry.openOn(root.focusedScreen, tab)
  }

  function close() {
    PillRegistry.closeAll()
  }

  function toggle(payload) {
    if (PillRegistry.anyHoldingKeys()) close()
    else open(payload)
  }

  Component.onCompleted: PillRegistry.registerHub(root)
  Component.onDestruction: PillRegistry.unregisterHub(root)
}
