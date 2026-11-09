pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Hyprland
import "../lib/Notices.js" as Notices

// Short notices (lib/Notices.js): power plugged in or out, a monitor
// connected or removed, a Bluetooth device connected, disconnected or low.
// Each peeks for a moment as a normal activity and goes on its own; they are
// the "notices" group in `activityRules`, so Settings can make them quiet.
//
// All event driven, nothing polled and no process started: PowerModule's
// UPower state (only with a battery), Hyprland's monitor events (only under
// Hyprland), Quickshell's BlueZ devices (none without bluetoothd). Nothing is
// announced for `settleMs` after the shell starts, when devices reconnect and
// monitors come up on their own.
Item {
  id: root
  visible: false

  property var activities: null
  property var power: null
  property bool hyprland: !!Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")

  property int settleMs: 8000
  property bool settled: false
  Timer {
    interval: root.settleMs
    running: true
    onTriggered: root.settled = true
  }

  function announce(activity) {
    if (!settled || !activities || !activity) return
    activities.push(activity, { own: true })
  }

  // ---- Power: the AC adapter, on machines with a battery.
  Connections {
    target: root.power && root.power.available ? root.power : null
    function onOnBatteryChanged() {
      root.announce(Notices.power(root.power.onBattery, root.power.fraction))
    }
  }

  // ---- Monitors.
  Connections {
    target: root.hyprland ? Hyprland : null
    function onRawEvent(event) {
      if (!event) return
      root.announce(Notices.monitor(String(event.name), String(event.data)))
    }
  }

  // ---- Bluetooth: one watcher per known device.
  Instantiator {
    model: Bluetooth.devices
    delegate: QtObject {
      id: watcher
      required property var modelData
      property bool lowWarned: false

      readonly property bool connected: !!modelData && modelData.connected
      readonly property var battery: modelData && modelData.batteryAvailable ? modelData.battery : null
      readonly property string label: modelData ? String(modelData.name || modelData.deviceName || "") : ""
      readonly property string address: modelData ? String(modelData.address || "") : ""

      onConnectedChanged: {
        root.announce(Notices.bluetooth(label, address, connected, battery))
        if (!connected) lowWarned = false
      }
      onBatteryChanged: {
        if (!connected) return
        var r = Notices.lowBattery(battery, lowWarned)
        lowWarned = r.warned
        if (r.warn) root.announce(Notices.bluetoothLow(label, address, battery))
      }
    }
  }
}
