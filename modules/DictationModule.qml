import QtQuick
import Quickshell.Io
import "../lib/Dictation.js" as Dictation

// Dictation (SPEC.md section 7, v1): the dictation backend streams one JSON
// line per state change; Omavisor reads it with a SplitParser and shows
// listening/transcribing as its own activity, urgent and quiet like REC
// (first in the pill, never blooms), with Stop and Cancel.
//
// The backend is the one `omarchy default dictation` names (Omarchy 4.5),
// else Superwhisper, else voxtype, whichever is installed
// (Dictation.pickBackend). Voxtype is followed directly (`voxtype status
// --follow`, which `omarchy voxtype status` ran before 4.5), Superwhisper
// with `superwhisper status --bar --follow`.
//
// It streams, so idle it costs nothing and runs no polls. With neither
// installed (checked at start) nothing runs and `available` stays false. A
// follower that exits (daemon restarted) is started again after 30 s, then
// less often (up to every 5 min) while it keeps stopping; each restart checks
// the default backend again.
Item {
  id: root
  visible: false

  property var activities: null
  readonly property string activityId: "omavisor:dictation"

  property bool available: false
  // "voxtype" or "superwhisper" (Dictation.BACKENDS), "" when neither.
  property string backend: ""
  // Names its microphone reader has in PipeWire, for PrivacyModule to leave out.
  readonly property var captureNames: backend !== "" ? Dictation.backend(backend).capture : []
  // idle, recording, transcribing, stopped, … (as the backend names them).
  property string status: "idle"
  property string model: ""
  readonly property bool active: status === "recording" || status === "transcribing"

  Probe {
    id: detect
    command: ["sh", "-c", "printf 'default=%s\\n' \"$(omarchy-default-dictation 2>/dev/null)\"; for b in voxtype superwhisper; do command -v \"$b\" >/dev/null && echo \"$b\"; done; true"]
    onFinished: function(code, output) {
      var picked = Dictation.pickBackend(output)
      if (picked !== root.backend && root.activities && root.activities.store.items[root.activityId]) root.activities.dismiss(root.activityId)
      root.backend = picked
      root.available = picked !== ""
      if (picked !== "") {
        root._started = false
        follow.command = Dictation.backend(picked).follow
        follow.running = true
      } else if (!root._logged) {
        console.info("omavisor: no dictation backend installed, dictation hidden")
        root._logged = true
      }
    }
  }
  Component.onCompleted: detect.run()

  // It streams; nothing to read again.
  function refresh() {}

  function apply(line) {
    var parsed = Dictation.barStatus(line)
    if (!parsed) return
    var was = root.status
    root.status = parsed.state
    model = parsed.model
    publish(was)
  }

  function publish(was) {
    if (!activities) return
    var activity = Dictation.dictationActivity({ state: root.status, model: model, backend: root.backend })
    if (activity) {
      activities.push(activity, { own: true, quiet: true })
      return
    }
    if (!activities.store.items[activityId]) return
    // A finished transcription shows Done for a moment; a cancel just goes.
    if (was === "transcribing") activities.end(activityId, "success")
    else activities.dismiss(activityId)
  }

  Process {
    id: follow
    stdout: SplitParser {
      onRead: function(data) { restart.interval = 15000; root.apply(data) }
    }
    onStarted: root._started = true
    onExited: function(code) {
      if (code === 127) { root.available = false; root.backend = ""; return }
      // It stopped, not finished: no "Done".
      root.status = "stopped"
      if (root.activities && root.activities.store.items[root.activityId]) root.activities.dismiss(root.activityId)
      if (!root._logged) { console.info("omavisor: " + root.backend + " status stopped (exit " + code + "), retrying"); root._logged = true }
      restart.interval = Math.min(restart.interval * 2, 300000)
      restart.start()
    }
    // The backend's command missing: it never starts.
    onRunningChanged: if (!running && !root._started) root.available = false
  }
  property bool _started: false
  property bool _logged: false

  // 30 s, doubling up to 5 min while it keeps stopping.
  Timer {
    id: restart
    interval: 15000
    // Detect again: the default backend may have changed meanwhile.
    onTriggered: detect.run()
  }
}
