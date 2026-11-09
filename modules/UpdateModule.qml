import QtQuick
import Quickshell
import "../lib/System.js" as System

// Omarchy update available (SPEC.md section 7): `omarchy-update-available`
// exits 0 when there is an update (and prints it), non-zero when Omarchy is
// up to date. Checked at start and every `pollMinutes` (the stock
// SystemUpdate widget's cadence by default). While one is pending it is a
// low-priority live activity, so the pill shows its glyph as the badge when
// nothing outranks it and the Activities tab lists it with an Update action.
//
// The check fetches (checkupdates, git for a dev checkout), so it gets a
// minute before it is killed.
Item {
  id: root
  visible: false

  property var activities: null
  property int pollMinutes: 360

  readonly property string activityId: "omavisor:update"
  // Without checkupdates (pacman-contrib) the stock check answers "up to
  // date" without looking, so the module hides rather than claim that. A
  // dev checkout (OMARCHY_PATH elsewhere) with a git upstream is checked
  // with git instead. Probed once at start.
  property bool checkerInstalled: false
  readonly property bool available: checkerInstalled && !probe.missing
  property bool updateAvailable: false
  property string label: ""
  property real checkedAt: 0
  readonly property bool checking: probe.running

  function refresh() { probe.run() }

  // Opens Omarchy's own updater in a floating terminal (click only).
  function runUpdate() {
    Quickshell.execDetached(["omarchy-launch-floating-terminal-with-presentation", "omarchy-update"])
  }

  function publish() {
    if (!activities) return
    if (!updateAvailable) {
      if (activities.store.items[activityId]) activities.dismiss(activityId)
      return
    }
    // Pushed again only when it changed or would lapse before the next
    // check: a re-push counts as news and would outrank older activities.
    var known = activities.store.items[activityId]
    if (known && known.endsAt === 0 && known.subtitle === label
        && known.updatedAt + known.ttl * 1000 - Date.now() > pollMinutes * 90000) return
    activities.push({
      id: activityId,
      source: "omarchy",
      title: "Omarchy update",
      subtitle: label,
      glyph: "󰚰",
      // Running and low: below anything live (a timer, a recording).
      state: "running",
      priority: "low",
      // Renewed by every check, so it never lapses while the update waits.
      ttl: 86400,
      compact: { leading: "󰚰", trailing: label },
      actions: [{ label: "Update", exec: ["omarchy-launch-floating-terminal-with-presentation", "omarchy-update"] }]
    }, { own: true })
  }

  onActivitiesChanged: publish()

  Probe {
    id: probe
    command: ["omarchy-update-available"]
    timeoutMs: 60000
    onFinished: function(code, output) {
      // A killed or failed check keeps the last answer.
      if (code < 0 || code === 127) return
      root.checkedAt = Date.now()
      root.updateAvailable = code === 0
      root.label = code === 0 ? System.updateLabel(output) : ""
      root.publish()
    }
  }

  Probe {
    id: checker
    command: ["sh", "-c", "command -v checkupdates || { [ \"$OMARCHY_PATH\" != /usr/share/omarchy ] && git -C \"$OMARCHY_PATH\" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}'; }"]
    onFinished: function(code) { root.checkerInstalled = code === 0 }
  }

  Component.onCompleted: checker.run()

  Timer {
    interval: Math.max(30, root.pollMinutes) * 60000
    running: root.available
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }
}
