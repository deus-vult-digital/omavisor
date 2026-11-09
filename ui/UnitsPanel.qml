pragma ComponentBehavior: Bound

import QtQuick
import qs.Commons
import qs.Commons as Commons

// Failed systemd units, system first, then the user's: one row each, in
// the urgent colour; a click opens the unit's journal for this boot in a
// floating terminal. The list is read again each time the panel appears.
ListView {
  id: root

  property var units: null
  property color foreground: Commons.Color.foreground
  property string fontFamily: Style.font.family

  clip: true
  spacing: Style.spacing.xs
  boundsBehavior: Flickable.StopAtBounds
  model: units ? units.system.map(function(u) { return { unit: u.unit, user: false } })
    .concat(units.user.map(function(u) { return { unit: u.unit, user: true } })) : []

  Component.onCompleted: if (units) units.refresh()
  onVisibleChanged: if (visible && units) units.refresh()

  delegate: FocusSurface {
    id: row
    required property var modelData
    required property int index
    focus: index === ListView.view.currentIndex
    onActivated: root.units.openJournal(row.modelData.unit, row.modelData.user)
    width: ListView.view.width
    height: label.implicitHeight + kind.implicitHeight + Style.spacing.sm * 2
    radius: Style.cornerRadius
    foreground: root.foreground
    hasCursor: mouse.containsMouse
    Accessible.role: Accessible.Button
    Accessible.name: "Journal of " + modelData.unit + (modelData.user ? " (user)" : "")

    MouseArea {
      id: mouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: root.units.openJournal(row.modelData.unit, row.modelData.user)
    }

    Column {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.leftMargin: Style.spacing.sm
      anchors.rightMargin: Style.spacing.sm
      anchors.verticalCenter: parent.verticalCenter

      Text {
        id: label
        width: parent.width
        textFormat: Text.PlainText
        // A .service suffix is the usual case and says nothing.
        text: "󰀦 " + row.modelData.unit.replace(/\.service$/, "")
        color: Commons.Color.urgent
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        elide: Text.ElideRight
      }

      Text {
        id: kind
        width: parent.width
        textFormat: Text.PlainText
        text: (row.modelData.user ? "User" : "System") + "  ·  journal"
        color: Qt.darker(root.foreground, 1.5)
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        elide: Text.ElideRight
      }
    }
  }
}
