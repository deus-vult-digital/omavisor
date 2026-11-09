import QtQuick
import qs.Commons
import qs.Commons as Commons
import "../lib/Format.js" as Format
import "../lib/Media.js" as Media

// Title and artist over the scrubber and the transport row, for the Media
// tab and the Home media tile (`compact` drops the time labels and makes
// the buttons smaller).
Item {
  id: root

  property var media: null
  property QtObject bar: null
  property color foreground: Commons.Color.foreground
  property string fontFamily: Style.font.family
  property bool compact: false
  // Off where the transport sits elsewhere (under the art, MediaTab).
  property bool showTransport: true
  // For a view placing something between the titles and the scrubber.
  readonly property real infoHeight: info.height
  readonly property real controlsHeight: controls.height

  readonly property bool hasMedia: !!media && media.available
  readonly property color dim: Qt.darker(foreground, 1.4)
  readonly property real progress: hasMedia ? Media.progress(media.position, media.length) : 0

  Column {
    id: info
    width: parent.width
    spacing: Style.spacing.xs

    Text {
      width: parent.width
      textFormat: Text.PlainText
      text: root.hasMedia ? root.media.title : ""
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: root.compact ? Style.font.title : Style.font.heading
      font.bold: true
      elide: Text.ElideRight
    }

    Text {
      width: parent.width
      textFormat: Text.PlainText
      text: root.hasMedia ? root.media.artist : ""
      visible: text !== ""
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
      elide: Text.ElideRight
    }
  }

  Column {
    id: controls
    anchors.bottom: parent.bottom
    width: parent.width
    spacing: root.compact ? 0 : Style.spacing.xs

    FocusSlider {
      id: scrubber
      // Five seconds a key.
      keyStep: root.hasMedia && root.media.length > 0 ? 5 / root.media.length : step
      visible: root.hasMedia && root.media.length > 0
      width: parent.width
      bar: root.bar
      value: root.progress
      enabled: root.hasMedia && root.media.canSeek
      Accessible.role: Accessible.Slider
      Accessible.name: "Track position"
      onReleased: function(v) { root.media.seek(v) }
    }

    Item {
      visible: !root.compact && scrubber.visible
      width: parent.width
      height: elapsed.implicitHeight

      Text {
        id: elapsed
        textFormat: Text.PlainText
        text: Format.duration(scrubber.dragging ? scrubber.liveValue * root.media.length : (root.hasMedia ? root.media.position : 0))
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }

      Text {
        anchors.right: parent.right
        textFormat: Text.PlainText
        text: root.hasMedia ? "-" + Format.duration(root.media.length - (scrubber.dragging ? scrubber.liveValue * root.media.length : root.media.position)) : ""
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }
    }

    Transport {
      visible: root.showTransport
      anchors.horizontalCenter: parent.horizontalCenter
      media: root.media
      compact: root.compact
      foreground: root.foreground
      fontFamily: root.fontFamily
    }
  }
}
