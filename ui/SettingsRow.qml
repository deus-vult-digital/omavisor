pragma ComponentBehavior: Bound

import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// One row of the Settings page, one stop for the keys: Enter or Space runs it,
// Shift+Up and Shift+Down move it. `row` comes from lib/Customize.js: a switch
// with move buttons, or with a `level`, a button that steps through the levels.
Item {
  id: root

  property var row: ({})
  property color foreground: Commons.Color.foreground
  property string fontFamily: Style.font.family

  signal activated()
  signal moved(int direction)

  readonly property bool hasLevel: row.level !== undefined
  // Space runs this rather than playing or pausing (HubContent).
  readonly property bool spaceToggles: true

  activeFocusOnTab: true
  implicitHeight: Style.spacing.controlHeight
  Accessible.role: hasLevel ? Accessible.Button : Accessible.CheckBox
  Accessible.name: hasLevel ? row.label + ", " + row.level : String(row.label)
  Accessible.checkable: !hasLevel
  Accessible.checked: row.listed === true

  Keys.onPressed: function(event) {
    if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)) return
    if ((event.modifiers & Qt.ShiftModifier) && (event.key === Qt.Key_Up || event.key === Qt.Key_Down)) {
      if (!hasLevel) moved(event.key === Qt.Key_Up ? -1 : 1)
      event.accepted = true
    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
      activated()
      event.accepted = true
    }
  }

  ToggleSwitch {
    id: toggle
    visible: !root.hasLevel
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    trackHeight: Style.space(16)
    trackWidth: Style.space(28)
    cursorPad: 0
    checked: root.row.listed === true
    opacity: root.row.canToggle === false ? 0.45 : 1
    busy: root.row.canToggle === false
    foreground: root.foreground
    onToggled: root.activated()
  }

  Text {
    anchors.left: root.hasLevel ? parent.left : toggle.right
    anchors.leftMargin: root.hasLevel ? 0 : Style.spacing.md
    anchors.right: tail.left
    anchors.rightMargin: Style.spacing.sm
    anchors.verticalCenter: parent.verticalCenter
    textFormat: Text.PlainText
    text: root.row.label || ""
    elide: Text.ElideRight
    color: root.foreground
    opacity: root.row.available === false ? 0.5 : 1
    font.family: root.fontFamily
    font.pixelSize: Style.font.body
    renderType: Text.NativeRendering
  }

  Row {
    id: tail
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    spacing: Style.spacing.xs

    Text {
      visible: root.row.isNew === true
      anchors.verticalCenter: parent.verticalCenter
      textFormat: Text.PlainText
      text: "New"
      color: Commons.Color.accent
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      renderType: Text.NativeRendering
    }

    PanelActionButton {
      visible: !root.hasLevel && root.row.movable === true && root.row.listed === true
      size: Style.space(20)
      fontSize: Style.font.caption
      iconText: "󰁝"
      tooltipText: "Move up"
      foreground: root.foreground
      fontFamily: root.fontFamily
      enabled: root.row.canMoveUp === true
      onClicked: root.moved(-1)
    }
    PanelActionButton {
      visible: !root.hasLevel && root.row.movable === true && root.row.listed === true
      size: Style.space(20)
      fontSize: Style.font.caption
      iconText: "󰁅"
      tooltipText: "Move down"
      foreground: root.foreground
      fontFamily: root.fontFamily
      enabled: root.row.canMoveDown === true
      onClicked: root.moved(1)
    }

    Button {
      visible: root.hasLevel
      text: root.hasLevel ? root.row.level.charAt(0).toUpperCase() + root.row.level.slice(1) : ""
      bordered: true
      foreground: root.foreground
      fontFamily: root.fontFamily
      fontSize: Style.font.caption
      verticalPadding: 0
      implicitHeight: Style.space(22)
      tooltipText: "Quiet, Badge, Peek or Bloom: the most this activity may do"
      onClicked: root.activated()
    }
  }
}
