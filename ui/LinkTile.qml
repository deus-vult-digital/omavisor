import QtQuick
import Quickshell
import qs.Commons
import qs.Commons as Commons

// A built-in Omavisor cannot host (an overlay or panel with no bar widget):
// a chip that opens it through the shell's own route,
// `omarchy-shell shell toggle <id> '{}'`, as argv, on click only.
Item {
  id: root

  required property var tile
  property color foreground: Commons.Color.popups.text
  property string fontFamily: Style.font.family

  implicitWidth: Style.space(92)
  implicitHeight: chip.height + Style.spacing.xs + name.implicitHeight

  Accessible.role: Accessible.Button
  Accessible.name: "Open " + tile.name

  function activate() { Quickshell.execDetached(["omarchy-shell", "shell", "toggle", root.tile.id, "{}"]) }
  activeFocusOnTab: true
  Keys.onReturnPressed: root.activate()
  Keys.onEnterPressed: root.activate()

  Rectangle {
    id: chip
    width: parent.width
    height: Style.space(42)
    radius: Style.cornerRadius
    color: hover.hovered ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08) : "transparent"
    border.width: Math.max(1, Style.spacing.hairline)
    border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)
    clip: true

    HoverHandler { id: hover }

    Text {
      anchors.centerIn: parent
      text: (root.tile.glyph || "󰏌") + "  󰁔"
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
    }

    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: root.activate()
    }
  }

  Text {
    id: name
    anchors.top: chip.bottom
    anchors.topMargin: Style.spacing.xs
    width: parent.width
    horizontalAlignment: Text.AlignHCenter
    text: root.tile.name
    elide: Text.ElideRight
    maximumLineCount: 1
    color: root.foreground
    opacity: 0.7
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
  }
}
