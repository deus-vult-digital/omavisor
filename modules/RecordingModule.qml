import QtQuick
import Quickshell
import Quickshell.Io
import "../lib/System.js" as System
import "../lib/Format.js" as Format

// Screen recording (SPEC.md section 7): `pgrep -f ^gpu-screen-recorder`
// says whether one runs (the stock indicator's check). While it does, a
// "REC" live activity counts up from when the recorder started (its age
// from `ps`), ranks first (urgent, but it never blooms) and carries a Stop
// action; a click on the pill's REC side stops it too
// (`omarchy-capture-screenrecording --stop-recording`). Once the recording
// has been saved, a bloom offers Open, Share (LocalSend, when installed)
// and Transcode.
//
// Omarchy's recorder writes the file it records to into
// /tmp/omarchy-screenrecord-filename when it starts and removes that file
// once the stopped recording is saved (after its clean-up pass), so
// watching it notices a start or a finished save at once. Polling backs it
// up: every 5 s while recording, every 30 s otherwise.
Item {
  id: root
  visible: false

  property var activities: null
  // To start one: close the hub first (CaptureModule.runAfterClose).
  property var capture: null

  readonly property string activityId: "omavisor:recording"
  readonly property string savedId: "omavisor:recording-saved"
  // Fixed by omarchy-capture-screenrecording (not $TMPDIR).
  readonly property string filenameFile: "/tmp/omarchy-screenrecord-filename"

  // The recorder is installed and pgrep works.
  property bool recorderInstalled: false
  readonly property bool available: recorderInstalled && !probe.missing
  property bool recording: false
  property real since: 0
  // The file being recorded, from the filename file.
  property string file: ""
  property bool stopping: false
  // Stopped, waiting for the save to finish.
  property bool finishing: false
  property string finishingFile: ""
  property bool shareAvailable: false

  function refresh() { probe.run() }

  // Omarchy's own picker (region or screen, audio, webcam).
  function start() {
    if (!available || recording) return
    if (capture) capture.runAfterClose(["omarchy-menu", "toggle", "trigger.capture.screenrecord"])
  }

  function stop() {
    if (!recording || stopping) return
    stopping = true
    Quickshell.execDetached(["omarchy-capture-screenrecording", "--stop-recording"])
    refreshSoon.restart()
  }

  function setRecording(value, pid) {
    if (value === recording) {
      if (value && since === 0 && pid !== "") age.run(["ps", "-o", "etimes=", "-p", pid])
      // Ended from outside (`omavisor end omavisor:recording`): still recording.
      const shown = activities ? activities.store.items[activityId] : null
      if (value && (!shown || shown.endsAt > 0)) publish()
      return
    }
    recording = value
    if (value) {
      since = 0
      finishing = false
      if (pid !== "") age.run(["ps", "-o", "etimes=", "-p", pid])
      publish()
    } else {
      stopping = false
      since = 0
      if (activities && activities.store.items[activityId]) activities.dismiss(activityId)
      finishingFile = file
      finishing = finishingFile !== ""
      // The filename file goes once the save is done; if it is gone
      // already (or never existed), finish now.
      if (finishing) {
        filenameView.reload()
        saveWait.restart()
      }
    }
  }

  function publish() {
    if (!activities || !recording) return
    activities.push({
      id: activityId,
      source: "omavisor",
      title: "Recording",
      subtitle: file !== "" ? file.slice(file.lastIndexOf("/") + 1) : "",
      glyph: "󰑊",
      state: "running",
      priority: "urgent",
      ttl: 86400,
      compact: { leading: "󰑊", trailing: "" },
      actions: [{ label: "Stop", exec: ["omarchy-capture-screenrecording", "--stop-recording"] }]
    }, { since: since > 0 ? since : Date.now(), own: true, quiet: true })
  }

  // The save is done: check the file is there, then bloom it.
  function finish() {
    saveWait.stop()
    if (!finishing) return
    finishing = false
    if (finishingFile !== "") exists.run(["test", "-f", finishingFile])
  }

  function saved(path) {
    if (!activities) return
    var actions = [{ label: "Open", exec: ["xdg-open", path] }]
    if (shareAvailable) actions.push({ label: "Share", exec: ["omarchy", "share", "file", path] })
    // The transcoder asks for format and size in a terminal.
    actions.push({ label: "Transcode", exec: ["omarchy-launch-floating-terminal-with-presentation", "omarchy-transcode " + Format.shellQuote(path)] })
    activities.push({
      id: savedId,
      source: "omavisor",
      title: "Recording saved",
      subtitle: path.slice(path.lastIndexOf("/") + 1),
      glyph: "󰕧",
      state: "success",
      priority: "urgent",
      ttl: 300,
      actions: actions
    }, { own: true })
  }

  onActivitiesChanged: publish()

  Probe {
    id: installed
    command: ["sh", "-c", "command -v gpu-screen-recorder"]
    onFinished: function(code) {
      root.recorderInstalled = code === 0
      if (code === 0) root.refresh()
    }
  }

  Probe {
    id: share
    command: ["sh", "-c", "command -v localsend"]
    onFinished: function(code) { root.shareAvailable = code === 0 }
  }

  Component.onCompleted: { installed.run(); share.run() }

  Probe {
    id: probe
    // The oldest match, so its pid is the recorder that has run longest.
    command: ["pgrep", "-o", "-f", "^gpu-screen-recorder"]
    onFinished: function(code, output) {
      if (code < 0 || code === 127) return
      root.setRecording(code === 0, code === 0 ? String(output).trim().split("\n")[0] : "")
    }
  }

  Probe {
    id: age
    onFinished: function(code, output) {
      var seconds = parseInt(String(output).trim(), 10)
      if (code !== 0 || !isFinite(seconds) || !root.recording) return
      root.since = Date.now() - seconds * 1000
      root.publish()
    }
  }

  Probe {
    id: exists
    onFinished: function(code) { if (code === 0) root.saved(root.finishingFile) }
  }

  FileView {
    id: filenameView
    path: root.filenameFile
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      var path = System.pathLine(text())
      if (path !== "" && path !== root.file) {
        root.file = path
        if (root.recording) root.publish()
      }
      root.refresh()
    }
    onLoadFailed: {
      if (root.finishing) root.finish()
      else if (root.recording) root.refresh()
      // Gone with no recording running: the next one names its own file.
      if (!root.recording) root.file = ""
    }
  }

  // A stop takes a moment (the recorder gets up to 5 s to write its file).
  Timer {
    id: refreshSoon
    interval: 1500
    repeat: true
    property int tries: 0
    onRunningChanged: if (running) tries = 0
    onTriggered: {
      root.refresh()
      if (!root.recording || ++tries >= 8) stop()
    }
  }

  // Omarchy's clean-up pass may re-encode a long recording; whatever
  // happens to the filename file, a stopped recording blooms within 5 min.
  Timer {
    id: saveWait
    interval: 300000
    onTriggered: root.finish()
  }

  Timer {
    interval: root.recording ? 5000 : 30000
    running: root.available
    repeat: true
    onTriggered: root.refresh()
  }
}
