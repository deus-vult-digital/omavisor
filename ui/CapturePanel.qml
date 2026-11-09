import QtQuick
import qs.Commons
import qs.Commons as Commons

// Capture buttons (SPEC.md section 7): screenshot region, windows,
// fullscreen (saved) and smart, OCR, QR, and screen recording. Each closes
// the hub before it runs (CaptureModule), so Omavisor is not in the shot.
// `part`: "screenshot", "text" or "all" (the Home tile, icons only).
Item {
  id: root

  property var capture: null
  property var recording: null
  property string part: "all"
  property color foreground: Commons.Color.foreground
  property string fontFamily: Style.font.family

  readonly property var screenshot: [
    { key: "region", icon: "󰩭", label: "Region", tooltip: "Screenshot a region" },
    { key: "windows", icon: "󰖯", label: "Window", tooltip: "Screenshot a window" },
    { key: "fullscreen", icon: "󰍹", label: "Screen", tooltip: "Save a screenshot of the screen" },
    { key: "smart", icon: "󰆞", label: "Smart", tooltip: "Smart screenshot" }
  ]
  readonly property var text: (capture && capture.textAvailable ? [{ key: "text", icon: "󰊄", label: "Text", tooltip: "Copy text from a region (OCR)" }] : [])
    .concat(capture && capture.qrAvailable ? [{ key: "qr", icon: "󰐲", label: "QR code", tooltip: "Read a QR code from a region" }] : [])
  readonly property bool canRecord: !!recording && recording.available
  readonly property var record: !canRecord ? []
    : recording.recording ? [{ key: "stop", icon: "󰓛", label: "Stop", tooltip: "Stop recording", active: true }]
    : [{ key: "record", icon: "󰑊", label: "Record", tooltip: "Record the screen" }]

  implicitHeight: grid.implicitHeight

  function pick(key) {
    if (key === "record") recording.start()
    else if (key === "stop") recording.stop()
    else if (capture) capture.capture(key)
  }

  ChipGrid {
    id: grid
    width: parent.width
    cols: root.part === "all" ? 4 : 2
    iconOnly: root.part === "all"
    options: root.part === "screenshot" ? root.screenshot
      : root.part === "text" ? root.text
      : root.screenshot.concat(root.text).concat(root.record)
    foreground: root.foreground
    fontFamily: root.fontFamily
    onPicked: function(key) { root.pick(key) }
  }
}
