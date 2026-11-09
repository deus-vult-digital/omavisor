import QtQuick
import Quickshell.Io

// One external command with the process guards of SPEC.md section 7:
// a run is skipped while the last one is still going, it is killed after
// `timeoutMs`, and a command that is not installed (it never starts, or
// exits 127) sets `missing`, after which `run()` does nothing, so a missing
// tool is reported once by Quickshell and never polled again.
Item {
  id: root
  visible: false

  property var command: []
  property int timeoutMs: 5000
  property bool missing: false
  readonly property bool running: proc.running

  // `code` is the exit code (-1 when killed by the timeout), `output`
  // what it printed on stdout.
  signal finished(int code, string output)

  property bool _started: false
  property bool _killed: false

  // Runs `command`, or `argv` when given. False when skipped.
  function run(argv) {
    if (missing || proc.running) return false
    var cmd = argv || command
    if (!cmd || cmd.length === 0) return false
    proc.command = cmd
    _started = false
    _killed = false
    proc.running = true
    return true
  }

  Process {
    id: proc
    stdout: StdioCollector {
      id: out
      waitForEnd: true
    }
    onStarted: root._started = true
    onExited: function(code) {
      if (code === 127) root.missing = true
      root.finished(root._killed ? -1 : code, out.text)
    }
    // A binary that is not there never starts and never exits.
    onRunningChanged: if (!running && !root._started) {
      root.missing = true
      root.finished(127, "")
    }
  }

  Timer {
    interval: root.timeoutMs
    running: proc.running
    onTriggered: { root._killed = true; proc.running = false }
  }
}
