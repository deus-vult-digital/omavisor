import QtQuick
import qs.Commons
import qs.Commons as Commons

// A labelled progress rail, the stock calendar's year/life bar: small-caps
// label, a track filled in the selected state colour, the percentage.
Item {
  id: root

  property string label: ""
  property real value: 0
  property color foreground: Commons.Color.foreground
  property string fontFamily: Style.font.family
  property real labelWidth: labelText.implicitWidth

  implicitHeight: Math.max(labelText.implicitHeight, Style.space(10))
  Accessible.role: Accessible.ProgressBar
  Accessible.name: label + " " + percentText.text

  Text {
    id: labelText
    width: root.labelWidth
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    textFormat: Text.PlainText
    text: root.label
    color: Qt.darker(root.foreground, 1.5)
    font.family: root.fontFamily
    font.pixelSize: Style.font.bodySmall
    font.letterSpacing: 1
  }

  Text {
    id: percentText
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    textFormat: Text.PlainText
    text: Math.round(Math.max(0, Math.min(1, root.value)) * 100) + "%"
    color: root.foreground
    font.family: root.fontFamily
    font.pixelSize: Style.font.bodySmall
  }

  Rectangle {
    anchors.left: labelText.right
    anchors.right: percentText.left
    anchors.leftMargin: Style.space(12)
    anchors.rightMargin: Style.space(12)
    anchors.verticalCenter: parent.verticalCenter
    height: Style.space(6)
    radius: Style.cornerRadius > 0 ? height / 2 : 0
    color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)

    Rectangle {
      width: Math.round(parent.width * Math.max(0, Math.min(1, root.value)))
      height: parent.height
      radius: parent.radius
      color: Style.selectedStateColor(root.foreground, Commons.Color.accent)
    }
  }
}
