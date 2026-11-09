pragma ComponentBehavior: Bound

import QtQuick
import qs.Commons
import qs.Commons as Commons
import "../lib/Format.js" as Format

// The notifications glance: the newest few as app · summary (never the
// body), the DND switch and the shell's own actions (dismiss, dismiss all,
// open the last one, replay history). The caption counts what is new since
// it was last on screen; leaving marks them seen.
Item {
  id: root

  property var notifications: null
  property real nowMs: Date.now()
  property color foreground: Commons.Color.foreground
  property string fontFamily: Style.font.family
  readonly property color dim: Qt.darker(foreground, 1.4)

  readonly property var recent: notifications ? notifications.recent : []

  onVisibleChanged: {
    if (!notifications) return
    if (visible) notifications.refresh()
    else notifications.markSeen()
  }
  Component.onCompleted: if (visible && notifications) notifications.refresh()
  Component.onDestruction: if (notifications) notifications.markSeen()

  Column {
    id: list
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: actions.top
    anchors.bottomMargin: Style.spacing.lg
    spacing: Style.spacing.xs
    clip: true

    Text {
      visible: root.recent.length === 0
      width: parent.width
      textFormat: Text.PlainText
      text: "Nothing recent"
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
    }

    Repeater {
      model: root.recent

      Item {
        id: row
        required property var modelData
        width: list.width
        height: summary.implicitHeight
        Accessible.role: Accessible.StaticText
        Accessible.name: modelData.app + ": " + modelData.summary

        Text {
          id: summary
          anchors.left: parent.left
          anchors.right: age.left
          anchors.rightMargin: Style.spacing.sm
          textFormat: Text.PlainText
          text: (row.modelData.glyph !== "" ? row.modelData.glyph + "  " : "")
            + (row.modelData.app !== "" ? row.modelData.app + " · " : "") + row.modelData.summary
          color: row.modelData.urgency === "critical" ? Commons.Color.urgent : root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          font.bold: row.modelData.live === true
          elide: Text.ElideRight
        }

        Text {
          id: age
          anchors.right: parent.right
          textFormat: Text.PlainText
          text: row.modelData.live === true ? "now" : row.modelData.timestamp > 0 ? Format.age(row.modelData.timestamp, root.nowMs) : ""
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
        }
      }
    }
  }

  ChipGrid {
    id: actions
    anchors.bottom: parent.bottom
    width: parent.width
    cols: 5
    iconOnly: true
    foreground: root.foreground
    fontFamily: root.fontFamily
    options: [
      { key: "dnd", icon: root.notifications && root.notifications.dnd === true ? "󰂛" : "󰂚", tooltip: "Do not disturb", toggle: true, active: !!root.notifications && root.notifications.dnd === true },
      { key: "dismissOne", icon: "󰅖", tooltip: "Dismiss the newest on screen" },
      { key: "dismissAll", icon: "󰎟", tooltip: "Dismiss all on screen" },
      { key: "invokeLast", icon: "󰁔", tooltip: "Open the last one" },
      { key: "showHistory", icon: "󰋚", tooltip: "Show history" }
    ]
    onPicked: function(key) {
      if (!root.notifications) return
      if (key === "dnd") root.notifications.toggleDnd()
      else if (key === "dismissOne") root.notifications.dismissOne()
      else if (key === "dismissAll") root.notifications.dismissAll()
      else if (key === "invokeLast") root.notifications.invokeLast()
      else root.notifications.showHistory()
    }
  }
}
