pragma ComponentBehavior: Bound

import QtQuick
import qs.Commons
import qs.Commons as Commons
import "../lib/Stats.js" as Stats

// CPU, memory, GPU and disk: a dim small-caps label and the reading on one
// line, a rail under it (the calendar's progress rail colours). Stats are
// polled only while this panel is on screen (it counts itself as one of
// the module's watchers). A click opens btop.
Item {
  id: root

  property var stats: null
  property color foreground: Commons.Color.foreground
  property string fontFamily: Style.font.family

  // The module counted, so a swapped or cleared `stats` is let go of.
  readonly property bool watching: visible && !!stats
  property var _counted: null
  function recount() {
    var want = watching ? stats : null
    if (want === _counted) return
    if (_counted) _counted.watchers -= 1
    if (want) want.watchers += 1
    _counted = want
  }
  onWatchingChanged: recount()
  onStatsChanged: recount()
  Component.onCompleted: recount()
  Component.onDestruction: if (_counted) _counted.watchers -= 1

  readonly property color dim: Qt.darker(foreground, 1.5)

  function temp(c) { return isNaN(c) ? "" : Math.round(c) + "°" }
  function joined(parts) { return parts.filter(function(s) { return s !== "" }).join("  ·  ") }

  readonly property var rows: {
    const s = stats
    if (!s) return []
    const out = [
      { label: "CPU", value: s.cpu, text: joined([Stats.percent(s.cpu), temp(s.cpuTemp)]) },
      { label: "RAM", value: s.memTotal > 0 ? s.memUsed / s.memTotal : -1, text: Stats.bytePair(s.memUsed, s.memTotal) }
    ]
    if (s.gpuAvailable) {
      const nv = s.nv
      if (nv && !s.nvAsleep) out.push({ label: "GPU", value: nv.busy, text: joined([Stats.percent(nv.busy), temp(nv.temp)]) })
      else if (!isNaN(s.amdBusy)) out.push({ label: "GPU", value: s.amdBusy, text: Stats.percent(s.amdBusy) })
      else out.push({ label: "GPU", value: 0, text: "Asleep" })
    }
    if (s.diskTotal > 0) out.push({ label: "Disk", value: s.diskUsed / s.diskTotal, text: Stats.bytePair(s.diskUsed, s.diskTotal) })
    return out
  }

  FocusSurface {
    anchors.fill: parent
    anchors.margins: -Style.spacing.xs
    radius: Style.cornerRadius
    foreground: root.foreground
    hasCursor: mouse.containsMouse
    Accessible.role: Accessible.Button
    Accessible.name: "Open btop"
    onActivated: if (root.stats) root.stats.openMonitor()
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    anchors.margins: -Style.spacing.xs
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: if (root.stats) root.stats.openMonitor()
  }

  Column {
    width: parent.width
    spacing: Style.spacing.md

    Repeater {
      model: root.rows

      Column {
        id: row
        required property var modelData
        width: parent.width
        spacing: Style.spacing.xs
        Accessible.role: Accessible.ProgressBar
        Accessible.name: modelData.label + " " + modelData.text

        Item {
          width: parent.width
          height: Math.max(name.implicitHeight, reading.implicitHeight)

          Text {
            id: name
            anchors.left: parent.left
            textFormat: Text.PlainText
            text: row.modelData.label.toUpperCase()
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            font.letterSpacing: 1
          }

          Text {
            id: reading
            anchors.right: parent.right
            width: Math.min(implicitWidth, parent.width - name.implicitWidth - Style.spacing.md)
            horizontalAlignment: Text.AlignRight
            textFormat: Text.PlainText
            text: row.modelData.text
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            elide: Text.ElideLeft
          }
        }

        Rectangle {
          width: parent.width
          height: Style.space(6)
          radius: Style.cornerRadius > 0 ? height / 2 : 0
          color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)

          Rectangle {
            width: Math.round(parent.width * Math.max(0, Math.min(1, row.modelData.value)))
            height: parent.height
            radius: parent.radius
            color: Style.selectedStateColor(root.foreground, Commons.Color.accent)
          }
        }
      }
    }
  }
}
