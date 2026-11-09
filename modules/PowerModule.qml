import QtQuick
import Quickshell.Services.UPower
import "../lib/Power.js" as Power

// Power (SPEC.md section 7, v1): battery level, state, time and draw from
// Quickshell's UPower display device (event driven, no polling), and the
// power profiles through Omarchy's commands: `omarchy powerprofiles list
// --active-state` to read, `omarchy powerprofiles set ac|battery <profile>`
// to pick one (remembered per AC/battery, like the stock power panel).
//
// Shown only when `omarchy battery present` exits 0, checked once at start;
// a desktop never shows it. Profiles are read while something shows them
// and after each set; without power-profiles-daemon the list is empty and
// the chips hide.
Item {
  id: root
  visible: false

  property bool batteryPresent: false
  readonly property bool available: batteryPresent

  readonly property var device: UPower.displayDevice
  readonly property bool onBattery: UPower.onBattery
  readonly property real fraction: device && device.isPresent ? device.percentage : 0
  readonly property int percent: Power.percent(fraction)
  readonly property bool full: !!device && device.isPresent
    && (device.state === UPowerDeviceState.FullyCharged || (!onBattery && fraction >= 0.99))
  readonly property bool charging: !!device && device.isPresent && !onBattery && !full
    && device.state === UPowerDeviceState.Charging
  readonly property string glyph: Power.batteryIcon(fraction, charging, full)
  readonly property string detail: device && device.isPresent
    ? Power.detail(onBattery, full, charging, device.timeToEmpty, device.timeToFull, device.changeRate) : ""

  property var profiles: []
  property string activeProfile: ""
  // The profile being set, until the command is done.
  property string settingProfile: ""

  property int watchers: 0
  onWatchersChanged: if (watchers > 0) refresh()

  // A profile changed elsewhere (the stock power panel, a keybind,
  // powerprofilesctl) while the chips show: power-profiles-daemon's own
  // D-Bus signal, through Quickshell, so nothing polls.
  Connections {
    // Only bound while shown, so Quickshell's power-profiles client (which
    // may try to start the daemon) is never touched on a desktop or idle.
    target: root.watchers > 0 && root.available ? PowerProfiles : null
    function onProfileChanged() { if (!setProbe.running) root.refresh() }
  }

  function refresh() {
    if (available) listProbe.run()
  }

  function setProfile(name) {
    if (!available || name === activeProfile || profiles.indexOf(name) === -1) return
    if (setProbe.run(["omarchy", "powerprofiles", "set", Power.source(onBattery), name])) {
      settingProfile = name
      activeProfile = name
    }
  }

  Probe {
    id: presentProbe
    command: ["omarchy", "battery", "present"]
    onFinished: function(code) {
      root.batteryPresent = Power.present(code)
      if (!root.batteryPresent) console.info("omavisor: no battery (omarchy battery present exited " + code + "), power hidden")
      else if (root.watchers > 0) root.refresh()
    }
  }

  Probe {
    id: listProbe
    command: ["omarchy", "powerprofiles", "list", "--active-state"]
    onFinished: function(code, output) {
      if (code !== 0 || setProbe.running) return
      var p = Power.parseProfiles(output)
      root.profiles = p.profiles
      root.activeProfile = p.active
    }
  }

  Probe {
    id: setProbe
    onFinished: {
      root.settingProfile = ""
      listProbe.run()
    }
  }

  Component.onCompleted: presentProbe.run()
}
