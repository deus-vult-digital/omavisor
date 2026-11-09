import QtQuick
import Quickshell

// The Capture row (SPEC.md section 7): screenshots, OCR and QR through
// `omarchy capture …`. The hub is closed first and the command runs once
// its close animation is over, so Omavisor is never in the shot.
Item {
  id: root
  visible: false

  // Closes the hub on every monitor (ActivitiesModule.collapse).
  property var activities: null

  readonly property var commands: ({
    region: ["omarchy", "capture", "screenshot", "region"],
    windows: ["omarchy", "capture", "screenshot", "windows"],
    fullscreen: ["omarchy", "capture", "screenshot", "fullscreen", "save"],
    smart: ["omarchy", "capture", "screenshot", "smart"],
    text: ["omarchy", "capture", "text"],
    qr: ["omarchy", "capture", "qr"]
  })

  // OCR needs tesseract and QR zbarimg (Omarchy's scripts exit quietly
  // without them), so their buttons show only when installed.
  property bool textAvailable: false
  property bool qrAvailable: false

  Probe {
    id: hasTesseract
    command: ["sh", "-c", "command -v tesseract"]
    onFinished: function(code) { root.textAvailable = code === 0 }
  }
  Probe {
    id: hasZbar
    command: ["sh", "-c", "command -v zbarimg"]
    onFinished: function(code) { root.qrAvailable = code === 0 }
  }
  Component.onCompleted: { hasTesseract.run(); hasZbar.run() }

  property var _pending: null

  // `what` is a key of `commands`; false for anything else.
  function capture(what) {
    var argv = commands[what]
    if (!argv) return false
    runAfterClose(argv)
    return true
  }

  // Close the hub, then run `argv` (also used to start a recording).
  function runAfterClose(argv) {
    _pending = argv
    if (activities) activities.collapse()
    delay.restart()
  }

  // The card shrinks in 240 ms; a little more lets the last frame go.
  Timer {
    id: delay
    interval: 400
    onTriggered: {
      var argv = root._pending
      root._pending = null
      if (argv) Quickshell.execDetached(argv)
    }
  }
}
