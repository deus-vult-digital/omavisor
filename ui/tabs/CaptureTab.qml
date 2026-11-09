import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import ".."
import "../../lib/ActivityStore.js" as Store

// Screenshots, screen recording, and text/QR from a region. Every button
// closes the hub before it captures, so Omavisor is not in the shot.
Item {
  id: root

  property color foreground: Commons.Color.foreground
  property string fontFamily: Style.font.family
  property var service: null
  property real nowMs: Date.now()

  readonly property var capture: service ? service.capture : null
  readonly property var recording: service ? service.recording : null
  readonly property color dim: Qt.darker(foreground, 1.4)

  TileRow {
    anchors.fill: parent

    Tile {
      title: "Screenshot"
      foreground: root.foreground
      fontFamily: root.fontFamily
      CapturePanel {
        width: parent.width
        part: "screenshot"
        capture: root.capture
        foreground: root.foreground
        fontFamily: root.fontFamily
      }
    }

    Tile {
      title: "Record"
      visible: !!root.recording && root.recording.available
      foreground: root.foreground
      fontFamily: root.fontFamily

      Readout {
        glyph: root.recording && root.recording.recording ? "󰑊" : "󰕧"
        value: root.recording && root.recording.recording
          ? "REC " + (root.recording.since > 0 ? Store.elapsedText(root.recording.since, root.nowMs) : "")
          : "Screen"
        detail: root.recording && root.recording.recording ? "Recording · click Stop to save" : "Region or screen, with audio or webcam"
        foreground: root.foreground
        fontFamily: root.fontFamily
      }

      Button {
        focusable: true
        anchors.bottom: parent.bottom
        width: parent.width
        iconText: root.recording && root.recording.recording ? "󰓛" : "󰑊"
        iconSize: Style.font.title
        text: root.recording && root.recording.recording ? "Stop" : "Record"
        fontSize: Style.font.bodySmall
        foreground: root.foreground
        fontFamily: root.fontFamily
        verticalPadding: Style.spacing.controlPaddingY + Style.space(2)
        bordered: true
        active: !!root.recording && root.recording.recording
        Accessible.role: Accessible.Button
        Accessible.name: text === "Stop" ? "Stop recording" : "Record the screen"
        onClicked: if (root.recording.recording) root.recording.stop(); else root.recording.start()
      }
    }

    Tile {
      title: "Text & QR"
      visible: !!root.capture && (root.capture.textAvailable || root.capture.qrAvailable)
      foreground: root.foreground
      fontFamily: root.fontFamily
      CapturePanel {
        width: parent.width
        part: "text"
        capture: root.capture
        foreground: root.foreground
        fontFamily: root.fontFamily
      }
    }
  }
}
