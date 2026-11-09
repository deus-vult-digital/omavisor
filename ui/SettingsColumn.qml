pragma ComponentBehavior: Bound

import QtQuick
import qs.Commons
import qs.Commons as Commons

// One column of the Settings page: a Tile of rows, scrolling if it has to.
// The delegates stay put as rows change places (the model is a count), so the
// focus can follow a row to where it went.
Tile {
  id: root

  property var rows: []

  signal activated(string id)
  signal moved(string id, int direction)
  // A row took the keys' focus: HubContent scrolls it into view.
  signal focusMoved(Item item)

  readonly property bool hasFocus: {
    for (let i = 0; i < repeater.count; i++) {
      let item = repeater.itemAt(i)
      if (item && item.activeFocus) return true
    }
    return false
  }

  readonly property Item firstRow: repeater.count > 0 ? repeater.itemAt(0) : null

  // After a change, put the focus back on the row that was acted on.
  function focusRow(id) {
    for (let i = 0; i < repeater.count; i++) {
      let item = repeater.itemAt(i)
      if (item && item.row.id === id) {
        item.forceActiveFocus()
        focusMoved(item)
        return
      }
    }
  }

  Flickable {
    anchors.fill: parent
    clip: true
    contentWidth: width
    contentHeight: list.implicitHeight
    boundsBehavior: Flickable.StopAtBounds

    Column {
      id: list
      width: parent.width

      Repeater {
        id: repeater
        model: root.rows.length

        SettingsRow {
          required property int index
          width: list.width
          row: root.rows[index] || ({})
          foreground: root.foreground
          fontFamily: root.fontFamily
          // The last tab, or the pill's last clock or glyph, stays on.
          onActivated: if (row.canToggle !== false) root.activated(row.id)
          // A move with nowhere to go writes nothing: an edit would turn the
          // defaults into a list of your own.
          onMoved: function(direction) {
            if (direction < 0 ? row.canMoveUp === true : row.canMoveDown === true) root.moved(row.id, direction)
          }
        }
      }
    }
  }
}
