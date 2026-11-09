pragma ComponentBehavior: Bound

import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Do Not Disturb, night light and stay awake: one row each, glyph and name
// with the stock switch, the whole row clickable. State is read again each
// time the panel appears; a state Omavisor cannot read hides its row.
Column {
  id: root

  property var toggles: null
  property color foreground: Commons.Color.foreground
  property string fontFamily: Style.font.family

  spacing: Style.spacing.xs

  readonly property var rows: [
    { key: "dnd", icon: "󰂛", label: "Do not disturb", on: toggles ? toggles.dnd : null },
    { key: "night", icon: "󰔎", label: "Night light", on: toggles ? toggles.nightLight : null },
    { key: "awake", icon: "󰅶", label: "Stay awake", on: toggles ? toggles.stayAwake : null }
  ]

  Component.onCompleted: if (toggles) toggles.refresh()
  onVisibleChanged: if (visible && toggles) toggles.refresh()

  function flip(key) {
    if (!toggles) return
    if (key === "dnd") toggles.toggleDnd()
    else if (key === "night") toggles.toggleNightLight()
    else toggles.toggleStayAwake()
  }

  Repeater {
    model: root.rows

    FocusSurface {
      id: row
      required property var modelData
      readonly property bool spaceToggles: true
      onActivated: root.flip(row.modelData.key)
      visible: modelData.on !== null
      width: root.width
      height: Math.max(label.implicitHeight, toggle.implicitHeight)
      radius: Style.cornerRadius
      foreground: root.foreground
      hasCursor: mouse.containsMouse
      Accessible.role: Accessible.CheckBox
      Accessible.name: modelData.label
      Accessible.checked: modelData.on === true

      MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.flip(row.modelData.key)
      }

      Text {
        id: label
        anchors.left: parent.left
        anchors.leftMargin: Style.spacing.sm
        anchors.right: toggle.left
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: row.modelData.icon + "  " + row.modelData.label
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        elide: Text.ElideRight
      }

      ToggleSwitch {
        id: toggle
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        checked: row.modelData.on === true
        interactive: false
        foreground: root.foreground
      }
    }
  }
}
