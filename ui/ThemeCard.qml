pragma ComponentBehavior: Bound

import QtQuick
import qs.Commons
import qs.Commons as Commons

// One theme in the Theme tab: its preview image (or its own background
// color when it ships none), a strip of its colors.toml swatches and its
// name, on the stock cursor surface (hover fill, selected border for the
// current theme). A click applies it.
FocusSurface {
  id: root

  property var card: ({})
  property string fontFamily: Style.font.family
  property bool busy: false

  signal picked()

  readonly property real inset: Style.spacing.xs + Math.max(1, Style.spacing.hairline)
  readonly property var swatches: card && card.swatches ? card.swatches : []

  hasCursor: hover.hovered
  current: !!card && card.current === true
  bordered: true

  Accessible.role: Accessible.Button
  Accessible.name: (card ? card.name : "") + (current ? ", current theme" : "")

  Item {
    id: thumb
    x: root.inset
    y: root.inset
    width: root.width - root.inset * 2
    height: root.height - root.inset * 2 - label.height - Style.spacing.xs

    Rectangle {
      anchors.fill: parent
      visible: preview.status !== Image.Ready
      color: root.swatches.length > 0 ? root.swatches[0] : Style.hoverFillFor(root.foreground, Commons.Color.accent)
    }

    Image {
      id: preview
      anchors.fill: parent
      // Only while on screen; previews can be large files.
      source: root.visible && root.card && root.card.preview ? root.card.preview : ""
      asynchronous: true
      cache: true
      fillMode: Image.PreserveAspectCrop
      sourceSize.width: Math.ceil(width * 2)
      sourceSize.height: Math.ceil(height * 2)
    }

    // The theme's palette along the bottom of the preview.
    Row {
      id: strip
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      height: Math.max(Style.spacing.xs, Math.round(parent.height * 0.12))
      Repeater {
        model: root.swatches
        Rectangle {
          required property string modelData
          width: strip.width / Math.max(1, root.swatches.length)
          height: strip.height
          color: modelData
        }
      }
    }

    Text {
      anchors.centerIn: parent
      visible: root.busy
      text: "󰔟"
      color: root.swatches.length > 1 ? root.swatches[1] : root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.title
    }
  }

  Text {
    id: label
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    anchors.leftMargin: root.inset
    anchors.rightMargin: root.inset
    anchors.bottomMargin: root.inset
    textFormat: Text.PlainText
    text: (root.current ? "󰄬 " : "") + (root.card ? root.card.name : "")
    color: root.foreground
    font.family: root.fontFamily
    font.pixelSize: Style.font.bodySmall
    font.bold: root.current
    elide: Text.ElideRight
    horizontalAlignment: Text.AlignHCenter
  }

  HoverHandler {
    id: hover
    cursorShape: Qt.PointingHandCursor
  }

  TapHandler {
    onTapped: root.picked()
  }

  onActivated: root.picked()
}
