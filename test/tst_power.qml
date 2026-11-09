import QtQuick
import QtTest
import "../lib/Power.js" as Power

TestCase {
  name: "Power"

  function test_present() {
    verify(Power.present(0))
    // No battery, the command missing, or killed: hidden.
    verify(!Power.present(1))
    verify(!Power.present(127))
    verify(!Power.present(-1))
  }

  function test_parseProfiles() {
    var p = Power.parseProfiles("power-saver\t0\nbalanced\t0\nperformance\t1\n")
    compare(p.profiles, ["power-saver", "balanced", "performance"])
    compare(p.active, "performance")
    compare(Power.parseProfiles("").profiles, [])
    compare(Power.parseProfiles("").active, "")
    compare(Power.parseProfiles("balanced\t1\nbad name\t0\nbalanced\t0").profiles, ["balanced"])
  }

  function test_labels() {
    compare(Power.profileLabel("power-saver"), "Saver")
    compare(Power.profileLabel("custom"), "Custom")
    compare(Power.profileIcon("balanced"), "󰊚")
    compare(Power.source(true), "battery")
    compare(Power.source(false), "ac")
  }

  function test_percent_and_icon() {
    compare(Power.percent(0.456), 46)
    compare(Power.percent(1.2), 100)
    compare(Power.percent(NaN), 0)
    compare(Power.batteryIcon(1, false, true), "󰂅")
    compare(Power.batteryIcon(0.05, false, false), "󰁺")
    compare(Power.batteryIcon(0.55, true, false), "󰂉")
    compare(Power.batteryIcon(1, false, false), "󰁹")
  }

  function test_timeLeft_and_rate() {
    compare(Power.timeLeft(8100), "2h 15m")
    compare(Power.timeLeft(7200), "2h")
    compare(Power.timeLeft(2700), "45m")
    compare(Power.timeLeft(20), "1m")
    compare(Power.timeLeft(0), "")
    compare(Power.timeLeft(8 * 86400), "")
    compare(Power.rate(8.44), "8.4 W")
    compare(Power.rate(-12), "12.0 W")
    compare(Power.rate(0), "")
  }

  function test_detail() {
    compare(Power.detail(true, false, false, 8100, 0, 8.44), "On battery  ·  2h 15m left  ·  8.4 W")
    compare(Power.detail(false, false, true, 0, 2700, 30), "Charging  ·  45m to full  ·  30.0 W")
    compare(Power.detail(false, true, false, 0, 0, 0), "Fully charged")
    compare(Power.detail(false, false, false, 0, 0, 0), "Plugged in")
  }
}
