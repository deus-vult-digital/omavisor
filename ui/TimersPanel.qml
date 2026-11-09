pragma ComponentBehavior: Bound

import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "../lib/Timers.js" as Timers

// Running timers with pause/resume and cancel, over chips that start a
// 5/15/25/50-minute countdown or a pomodoro (25 min focus, then a 5 min
// break). `compact` (Home tile) shows the first timer hero-sized, or only
// the chips when none runs.
Item {
  id: root

  property var timers: null
  property real nowMs: Date.now()
  property bool compact: false
  property color foreground: Commons.Color.foreground
  property string fontFamily: Style.font.family

  readonly property color dim: Qt.darker(foreground, 1.4)
  readonly property var list: timers ? timers.timers : []
  readonly property var first: list.length > 0 ? list[0] : null
  readonly property var chips: [
    { key: "5", label: "5", tooltip: "5-minute timer" },
    { key: "15", label: "15", tooltip: "15-minute timer" },
    { key: "25", label: "25", tooltip: "25-minute timer" },
    { key: "50", label: "50", tooltip: "50-minute timer" },
    { key: "pomodoro", icon: "󱎫", tooltip: "Pomodoro: 25 min focus, 5 min break" }
  ]

  function pick(key) {
    if (!timers) return
    if (key === "pomodoro") timers.startPomodoro()
    else timers.start(Number(key), "", "timer")
  }

  function timeLeft(t) {
    return Timers.clock(Timers.remaining(t, root.nowMs))
  }

  // Compact with a timer: the first one, hero-sized.
  Item {
    anchors.fill: parent
    visible: root.compact && root.first !== null

    Readout {
      glyph: root.first ? (Timers.isPaused(root.first) ? "󰏤" : Timers.glyph(root.first.kind)) : ""
      value: root.first ? root.timeLeft(root.first) : ""
      detail: root.first ? root.first.label + (root.list.length > 1 ? "  ·  " + (root.list.length - 1) + " more" : "") : ""
      foreground: root.foreground
      fontFamily: root.fontFamily
    }

    Row {
      anchors.bottom: parent.bottom
      spacing: Style.spacing.sm
      PanelActionButton {
        readonly property bool spaceToggles: true
        focusable: true
        iconText: root.first && Timers.isPaused(root.first) ? "󰐊" : "󰏤"
        tooltipText: root.first && Timers.isPaused(root.first) ? "Resume" : "Pause"
        foreground: root.foreground
        fontFamily: root.fontFamily
        fontSize: Style.font.iconLarge
        Accessible.role: Accessible.Button
        Accessible.name: tooltipText
        onClicked: if (root.first) { if (Timers.isPaused(root.first)) root.timers.resume(root.first.id); else root.timers.pause(root.first.id) }
      }
      PanelActionButton {
        focusable: true
        iconText: "󰅖"
        tooltipText: "Cancel"
        foreground: root.foreground
        hoverColor: Commons.Color.urgent
        fontFamily: root.fontFamily
        fontSize: Style.font.iconLarge
        Accessible.role: Accessible.Button
        Accessible.name: "Cancel timer"
        onClicked: if (root.first) root.timers.cancel(root.first.id)
      }
    }
  }

  // Full: every timer (as many as fit), then the chips.
  Column {
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.bottom: chipGrid.top
    anchors.bottomMargin: Style.spacing.md
    visible: !root.compact
    spacing: Style.spacing.xs
    clip: true

    Text {
      visible: root.list.length === 0
      width: parent.width
      textFormat: Text.PlainText
      text: "No timers running"
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
      elide: Text.ElideRight
    }

    Repeater {
      model: root.list

      Item {
        id: row
        required property var modelData
        readonly property bool paused: Timers.isPaused(modelData)
        width: parent.width
        height: Math.max(label.implicitHeight, pauseButton.height)

        Text {
          id: label
          anchors.left: parent.left
          anchors.right: time.left
          anchors.rightMargin: Style.spacing.md
          anchors.verticalCenter: parent.verticalCenter
          textFormat: Text.PlainText
          text: (row.paused ? "󰏤" : Timers.glyph(row.modelData.kind)) + "  " + row.modelData.label
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          elide: Text.ElideRight
        }

        Text {
          id: time
          anchors.right: pauseButton.left
          anchors.rightMargin: Style.spacing.sm
          anchors.verticalCenter: parent.verticalCenter
          textFormat: Text.PlainText
          text: root.timeLeft(row.modelData)
          color: row.paused ? root.dim : root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          font.bold: true
          font.features: { "tnum": 1 }
        }

        PanelActionButton {
          id: pauseButton
          readonly property bool spaceToggles: true
          focusable: true
          anchors.right: cancelButton.left
          anchors.verticalCenter: parent.verticalCenter
          iconText: row.paused ? "󰐊" : "󰏤"
          tooltipText: row.paused ? "Resume" : "Pause"
          foreground: root.foreground
          fontFamily: root.fontFamily
          Accessible.role: Accessible.Button
          Accessible.name: tooltipText + " " + row.modelData.label
          onClicked: if (row.paused) root.timers.resume(row.modelData.id); else root.timers.pause(row.modelData.id)
        }

        PanelActionButton {
          id: cancelButton
          focusable: true
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          iconText: "󰅖"
          tooltipText: "Cancel"
          foreground: root.foreground
          hoverColor: Commons.Color.urgent
          fontFamily: root.fontFamily
          Accessible.role: Accessible.Button
          Accessible.name: "Cancel " + row.modelData.label
          onClicked: root.timers.cancel(row.modelData.id)
        }
      }
    }
  }

  ChipGrid {
    id: chipGrid
    anchors.bottom: parent.bottom
    width: parent.width
    visible: !root.compact || root.first === null
    cols: root.compact ? 3 : 5
    options: root.chips
    foreground: root.foreground
    fontFamily: root.fontFamily
    onPicked: function(key) { root.pick(key) }
  }
}
