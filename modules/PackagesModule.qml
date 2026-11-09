import QtQuick
import Quickshell
import "../lib/Packages.js" as Packages

// Pending packages (SPEC.md section 7, v1): repo updates from
// `checkupdates` (pacman-contrib; it syncs a private copy of the database,
// so it never touches pacman's) and AUR updates from `yay -Qua`. Each tool
// is optional and looked up once at start; with neither the module hides.
// Checked 90 s after start and every `pollMinutes`. Both fetch, so they get a
// minute before they are killed. Omavisor never updates anything itself:
// the actions open Omarchy's updaters in a floating terminal, on click.
Item {
  id: root
  visible: false

  property int pollMinutes: 60
  // The Omarchy update check runs checkupdates too, and two at once share
  // one database lock: the second fails (and the first loses its lock).
  // So the first count waits a while after start, and a count due while
  // that check runs waits for it.
  property var updates: null
  property bool _due: false

  property bool hasRepo: false
  property bool hasAur: false
  readonly property bool repoAvailable: hasRepo && !repoProbe.missing
  readonly property bool aurAvailable: hasAur && !aurProbe.missing
  readonly property bool available: repoAvailable || aurAvailable

  // -1 until the first answer.
  property int repo: -1
  property int aur: -1
  readonly property int total: Math.max(0, repo) + Math.max(0, aur)
  property real checkedAt: 0
  readonly property bool checking: repoProbe.running || aurProbe.running

  function refresh() {
    if (updates && updates.checking) { _due = true; return }
    _due = false
    if (repoAvailable) repoProbe.run()
    if (aurAvailable) aurProbe.run()
  }

  Connections {
    target: root.updates
    function onCheckingChanged() { if (root._due && !root.updates.checking) root.refresh() }
  }

  // `omarchy update`: snapshot, system packages, AUR and the rest.
  function runUpdate() {
    Quickshell.execDetached(["omarchy-launch-floating-terminal-with-presentation", "omarchy-update"])
  }
  // `omarchy update aur pkgs`: only the AUR packages.
  function runAurUpdate() {
    Quickshell.execDetached(["omarchy-launch-floating-terminal-with-presentation", "omarchy-update-aur-pkgs"])
  }

  Probe {
    id: tools
    command: ["sh", "-c", "command -v checkupdates >/dev/null && echo repo; command -v yay >/dev/null && echo aur; true"]
    onFinished: function(code, output) {
      root.hasRepo = /\brepo\b/.test(output)
      root.hasAur = /\baur\b/.test(output)
      if (!root.available) console.info("omavisor: neither checkupdates nor yay found, pending packages hidden")
    }
  }
  Component.onCompleted: tools.run()

  Probe {
    id: repoProbe
    command: ["checkupdates"]
    timeoutMs: 60000
    onFinished: function(code, output) {
      var n = Packages.repoCount(code, output)
      if (n < 0) return
      root.repo = n
      root.checkedAt = Date.now()
    }
  }

  Probe {
    id: aurProbe
    command: ["yay", "-Qua"]
    timeoutMs: 60000
    onFinished: function(code, output) {
      var n = Packages.aurCount(code, output)
      if (n < 0) return
      root.aur = n
      root.checkedAt = Date.now()
    }
  }

  Timer {
    id: firstCount
    interval: 90000
    running: root.available
    onTriggered: { root.refresh(); poll.start() }
  }

  Timer {
    id: poll
    interval: Math.max(15, root.pollMinutes) * 60000
    repeat: true
    onTriggered: root.refresh()
  }
}
