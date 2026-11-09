import QtQuick
import QtTest
import "../lib/Notices.js" as Notices
import "../lib/ActivityStore.js" as Store
import "../lib/Catalog.js" as Catalog

TestCase {
  name: "Notices"

  // Every notice is a valid activity the store takes, in the notices group.
  function valid(a) {
    var store = Store.create()
    var r = Store.push(store, a, 1000, { own: true })
    verify(!r.error, r.error)
    compare(Catalog.activityCategory(a.id), "notices")
    compare(a.priority, "normal")
    compare(a.ttl, Notices.TTL)
  }

  function test_power() {
    var on = Notices.power(false, 57)
    compare(on.title, "Plugged in")
    compare(on.subtitle, "57%, charging")
    valid(on)
    var off = Notices.power(true, 0.42)
    compare(off.title, "On battery")
    compare(off.subtitle, "42%")
    compare(off.id, on.id)
    compare(Notices.power(false, NaN).subtitle, "")
    valid(off)
  }

  function test_monitor() {
    var a = Notices.monitor("monitoraddedv2", "2,DP-2,Dell Inc. DELL U2723QE, 4K")
    compare(a.title, "Monitor connected")
    compare(a.subtitle, "DP-2 · Dell Inc. DELL U2723QE, 4K")
    compare(a.id, "omavisor:notice-monitor-dp-2")
    valid(a)
    var r = Notices.monitor("monitorremovedv2", "2,DP-2,Dell Inc. DELL U2723QE")
    compare(r.title, "Monitor removed")
    compare(r.id, a.id)
    compare(Notices.monitor("monitoradded", "HDMI-A-1").subtitle, "HDMI-A-1")
    compare(Notices.monitor("monitoraddedv2", "3,HEADLESS-2,").subtitle, "HEADLESS-2")
    compare(Notices.monitor("workspace", "2"), null)
    compare(Notices.monitor("monitoraddedv2", ""), null)
    compare(Notices.monitor("monitoradded", "  "), null)
  }

  function test_bluetooth() {
    var c = Notices.bluetooth("AirPods Pro", "AA:BB:CC:DD:EE:FF", true, 0.8)
    compare(c.title, "Connected")
    compare(c.subtitle, "AirPods Pro · 80%")
    compare(c.id, "omavisor:notice-bt-aa-bb-cc-dd-ee-ff")
    valid(c)
    compare(Notices.bluetooth("Mouse", "11:22", true, null).subtitle, "Mouse")
    var d = Notices.bluetooth("", "11:22", false, null)
    compare(d.title, "Disconnected")
    compare(d.subtitle, "11:22")
    valid(d)
  }

  function test_lowBattery() {
    compare(Notices.lowBattery(0.5, false), { warn: false, warned: false })
    compare(Notices.lowBattery(0.2, false), { warn: true, warned: true })
    // Once per discharge, also through a wobble at the line.
    compare(Notices.lowBattery(0.15, true), { warn: false, warned: true })
    compare(Notices.lowBattery(0.25, true), { warn: false, warned: true })
    compare(Notices.lowBattery(0.19, true), { warn: false, warned: true })
    // Charged past the recover line: armed again.
    compare(Notices.lowBattery(0.31, true), { warn: false, warned: false })
    compare(Notices.lowBattery(null, true), { warn: false, warned: true })
    compare(Notices.lowBattery(NaN, false), { warn: false, warned: false })
    var a = Notices.bluetoothLow("Keyboard", "AA:BB", 0.12)
    compare(a.subtitle, "Keyboard · 12%")
    compare(a.state, "error")
    valid(a)
  }
}
