import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// One column of the hub: a small-caps caption over its body, with an
// optional hairline rule on its leading side. Captions and rules are the
// stock panels' PanelSectionHeader and separator strength.
Item {
  id: root

  property string title: ""
  property color foreground: Commons.Color.foreground
  property string fontFamily: Style.font.family
  property bool divider: false
  property real dividerGap: Style.spacing.panelGap

  default property alias content: body.data
  // Optional controls on the caption line's trailing side.
  property alias trailing: trailingSlot.data

  // A TileRow lays out only visible tiles; tell it when that changes.
  onVisibleChanged: if (parent && typeof parent.scheduleRelayout === "function") parent.scheduleRelayout()

  Rectangle {
    visible: root.divider
    x: -Math.round(root.dividerGap / 2)
    width: Math.max(1, Style.spacing.hairline)
    height: parent.height
    color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)
  }

  Row {
    id: trailingSlot
    anchors.right: parent.right
    anchors.verticalCenter: caption.verticalCenter
    spacing: Style.spacing.xs
  }

  PanelSectionHeader {
    id: caption
    width: parent.width - (trailingSlot.width > 0 ? trailingSlot.width + Style.spacing.lg : 0)
    visible: root.title !== ""
    text: root.title.toUpperCase()
    foreground: root.foreground
    fontFamily: root.fontFamily
    font.letterSpacing: 1.2
    elide: Text.ElideRight
  }

  Item {
    id: body
    anchors.top: caption.visible ? caption.bottom : parent.top
    anchors.topMargin: caption.visible ? Style.spacing.lg : 0
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
  }
}
