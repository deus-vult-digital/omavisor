pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import qs.Commons
import qs.Commons as Commons

// Square album art with the theme's corner rounding, or a music glyph on
// the stock hover fill when the player gives no art (or it fails to load).
Item {
  id: root

  property string source: ""
  property color foreground: Commons.Color.foreground
  property string fontFamily: Style.font.family

  readonly property bool hasArt: art.status === Image.Ready

  Rectangle {
    anchors.fill: parent
    visible: !root.hasArt
    radius: Style.cornerRadius
    color: Style.hoverFillFor(root.foreground, Commons.Color.accent)

    Text {
      anchors.centerIn: parent
      text: "󰝚"
      color: Qt.darker(root.foreground, 1.4)
      font.family: root.fontFamily
      font.pixelSize: Math.round(parent.height * 0.4)
    }
  }

  Image {
    id: art
    anchors.fill: parent
    visible: root.hasArt
    // Only while on screen: the hub (and its Home tiles) stays loaded when
    // closed, and web art must not be fetched for nobody.
    source: root.visible ? root.source : ""
    asynchronous: true
    cache: true
    fillMode: Image.PreserveAspectCrop
    sourceSize.width: Math.ceil(width * 2)
    sourceSize.height: Math.ceil(height * 2)
    layer.enabled: Style.cornerRadius > 0
    layer.smooth: true
    layer.effect: MultiEffect {
      maskEnabled: true
      maskSource: mask
      maskThresholdMin: 0.5
      maskSpreadAtMin: 1.0
    }
  }

  Rectangle {
    id: mask
    anchors.fill: parent
    visible: false
    layer.enabled: true
    radius: Style.cornerRadius
    color: "black"
  }
}
