import QtQuick
import Quickshell
import "../lib/Units.js" as Units
import "../lib/Format.js" as Format

// Failed systemd units (SPEC.md section 7, v1): `systemctl --failed` for
// the system and the user manager. Read every minute (two cheap calls, the
// collapsed budget allows one every 30 s) and whenever the System tab
// appears. While any unit has failed it is an activity (state error,
// urgent and quiet like REC: the badge, a peek when it first appears, no
// bloom), and a tap on a unit opens its journal for this boot in a
// floating terminal. No systemctl (another init): hidden.
Item {
  id: root
  visible: false

  property var activities: null

  readonly property string activityId: "omavisor:units"
  readonly property bool available: !systemProbe.missing
  property var system: []
  property var user: []
  readonly property int count: system.length + user.length
  property string _key: ""

  function refresh() {
    if (_pending > 0) return
    if (systemProbe.run()) _pending++
    if (userProbe.run()) _pending++
  }

  // The old list when nothing changed, so views keep their rows.
  function same(old, next) {
    return JSON.stringify(old) === JSON.stringify(next) ? old : next
  }

  function journalArgv(unit, isUser) {
    return ["omarchy-launch-floating-terminal-with-presentation", Units.journalCommand(unit, isUser, Format.shellQuote)]
  }
  function openJournal(unit, isUser) {
    Quickshell.execDetached(journalArgv(unit, isUser))
  }

  function publish() {
    if (!activities) return
    var key = Units.key(system, user)
    if (count === 0) {
      _key = key
      if (activities.store.items[activityId]) activities.dismiss(activityId)
      return
    }
    var known = activities.store.items[activityId]
    // Gone with the same set: the user dismissed it. It comes back only
    // when the set of failed units changes.
    if (!known && key === _key) return
    if (known && known.endsAt === 0 && key === _key
        && known.updatedAt + known.ttl * 1000 - Date.now() > 3600000) return
    _key = key
    var first = system.length > 0 ? { unit: system[0].unit, user: false } : { unit: user[0].unit, user: true }
    var names = system.concat(user).map(function(u) { return u.unit })
    activities.push({
      id: activityId,
      source: "systemd",
      title: count === 1 ? "Failed unit" : count + " failed units",
      subtitle: names.join(", "),
      glyph: "󰀦",
      state: "error",
      // Urgent so it is the badge over passive notices (a pending update
      // ranks above any non-urgent error), quiet so it never blooms; a
      // dismissal holds until the set of failed units changes.
      priority: "urgent",
      ttl: 86400,
      compact: { leading: "󰀦", trailing: String(count) },
      actions: [{ label: "Journal", exec: journalArgv(first.unit, first.user) }]
    }, { own: true, quiet: true })
  }

  onActivitiesChanged: publish()

  // Each list is kept until the other answers, so the badge is pushed
  // once per change, not once per list.
  property int _pending: 0
  function answered() { _pending = Math.max(0, _pending - 1); if (_pending === 0) publish() }

  Probe {
    id: systemProbe
    command: ["systemctl", "--failed", "--no-legend", "--plain"]
    onFinished: function(code, output) {
      if (code === 127) console.info("omavisor: systemctl not found, failed units hidden")
      if (code === 0) root.system = root.same(root.system, Units.parse(output))
      root.answered()
    }
  }

  Probe {
    id: userProbe
    command: ["systemctl", "--user", "--failed", "--no-legend", "--plain"]
    onFinished: function(code, output) {
      if (code === 0) root.user = root.same(root.user, Units.parse(output))
      root.answered()
    }
  }

  Timer {
    interval: 60000
    running: root.available
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }
}
