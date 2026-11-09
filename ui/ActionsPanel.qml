import QtQuick
import Quickshell
import qs.Commons
import qs.Commons as Commons
import "../lib/Actions.js" as Actions

// The Actions tile: your own commands (`actions`, lib/Actions.js) as
// buttons. A click closes the hub and runs the command as argv, never through
// a shell; nothing runs any other way.
Item {
  id: root

  property var actions: []
  property var service: null
  property color foreground: Commons.Color.foreground
  property string fontFamily: Style.font.family

  implicitHeight: grid.implicitHeight

  function run(key) {
    var action = root.actions[Number(key)]
    if (!action) return
    var activities = service ? service.activities : null
    if (activities) activities.collapse()
    Quickshell.execDetached(action.argv)
  }

  ChipGrid {
    id: grid
    width: parent.width
    cols: 2
    options: Actions.chips(root.actions)
    foreground: root.foreground
    fontFamily: root.fontFamily
    onPicked: function(key) { root.run(key) }
  }
}
