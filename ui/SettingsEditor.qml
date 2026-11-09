import QtQuick
import "../lib/Customize.js" as Customize

// What the Settings page has changed, ahead of shell.json: `current` shows a
// change at once, and it is written after a short quiet, so a burst of moves is
// one write. It outlives the page (each pill has one), so leaving Settings or
// closing the hub loses nothing.
//
// The write is the raw entry with the changes laid over it. `settings` is the
// entry as it is now, so an `omarchy bar set` in the meantime is kept. A change
// stays laid over until the entry has it, which also keeps it showing if the
// write doesn't land.
Item {
  id: root
  visible: false

  // The pill's inline settings and the shell facade that writes them.
  property var settings: ({})
  property var shell: null
  property string pluginId: ""

  property var pending: ({})
  readonly property var current: Customize.applyChanges(settings, pending)
  readonly property bool canSave: !!shell && typeof shell.updateEntryInline === "function"

  function change(changes) {
    // Keeps a null, which removes the key when it is written.
    pending = Object.assign({}, pending, changes)
    writeTimer.restart()
  }

  function flush() {
    writeTimer.stop()
    if (Object.keys(pending).length === 0 || !canSave) return
    shell.updateEntryInline(pluginId, current)
    settle()
  }

  function settle() {
    if (Object.keys(pending).length > 0) pending = Customize.unsaved(settings, pending)
  }

  onSettingsChanged: settle()

  Timer {
    id: writeTimer
    interval: 300
    onTriggered: root.flush()
  }
}
