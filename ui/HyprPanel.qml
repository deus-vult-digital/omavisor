import QtQuick
import qs.Commons
import qs.Commons as Commons
import "../lib/Hypr.js" as Hypr

// The focused workspace, the active window (title, class, monitor) and the
// workspace's tiled layout with Omarchy's dwindle/scrolling toggle. The
// wheel anywhere on it steps workspaces.
Item {
  id: root

  property var hypr: null
  property color foreground: Commons.Color.foreground
  property string fontFamily: Style.font.family
  readonly property color dim: Qt.darker(foreground, 1.4)

  readonly property bool watching: visible && !!hypr
  onWatchingChanged: if (hypr) hypr.watchers += watching ? 1 : -1
  Component.onDestruction: if (watching && hypr) hypr.watchers -= 1

  WheelHandler {
    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
    onWheel: function(event) { if (root.hypr) root.hypr.scroll(event.angleDelta.y) }
  }

  Readout {
    id: readout
    glyph: "󰕰"
    value: root.hypr ? root.hypr.workspaceLabel : ""
    detail: root.hypr ? (root.hypr.windowTitle !== "" ? root.hypr.windowTitle : "No window") : ""
    foreground: root.foreground
    fontFamily: root.fontFamily
  }

  Text {
    anchors.top: readout.bottom
    anchors.topMargin: Style.spacing.xs
    width: parent.width
    textFormat: Text.PlainText
    text: !root.hypr ? "" : [root.hypr.hasWindow ? root.hypr.windowClass : "", root.hypr.monitorName].filter(function(s) { return s !== "" }).join("  ·  ")
    color: root.dim
    font.family: root.fontFamily
    font.pixelSize: Style.font.bodySmall
    elide: Text.ElideRight
  }

  ChipGrid {
    anchors.bottom: parent.bottom
    width: parent.width
    visible: !!root.hypr && root.hypr.layout !== ""
    cols: 1
    options: [{
      key: "layout",
      icon: Hypr.layoutGlyph,
      label: root.hypr ? Hypr.layoutLabel(root.hypr.layout) : "",
      tooltip: "Toggle this workspace between dwindle and scrolling",
      toggle: true
    }]
    foreground: root.foreground
    fontFamily: root.fontFamily
    onPicked: root.hypr.toggleLayout()
  }
}
