import QtQuick
import qs.Commons
import qs.Commons as Commons

// Placeholder body for a tile: a glyph, a large value and a dim detail line,
// in the stock panels' hero typography (bold display value, dimmed body).
Column {
  id: root

  property string glyph: ""
  property string value: ""
  property string detail: ""
  property color foreground: Commons.Color.foreground
  property string fontFamily: Style.font.family
  readonly property color dim: Qt.darker(foreground, 1.4)

  width: parent ? parent.width : implicitWidth
  spacing: Style.spacing.sm

  Row {
    spacing: Style.spacing.lg
    width: parent.width

    Text {
      id: glyphText
      visible: root.glyph !== ""
      anchors.verticalCenter: parent.verticalCenter
      text: root.glyph
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.display
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      textFormat: Text.PlainText
      text: root.value
      width: Math.min(implicitWidth, parent.width - (glyphText.visible ? glyphText.width + parent.spacing : 0))
      elide: Text.ElideRight
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.display
      font.bold: true
    }
  }

  Text {
    width: parent.width
    visible: root.detail !== ""
    textFormat: Text.PlainText
    text: root.detail
    color: root.dim
    font.family: root.fontFamily
    font.pixelSize: Style.font.body
    wrapMode: Text.Wrap
    maximumLineCount: 3
    elide: Text.ElideRight
  }
}
