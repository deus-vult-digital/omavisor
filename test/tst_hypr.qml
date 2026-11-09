import QtQuick
import QtTest
import "../lib/Hypr.js" as Hypr

TestCase {
  name: "Hypr"

  function test_workspaceLabel() {
    compare(Hypr.workspaceLabel(4, "4"), "4")
    compare(Hypr.workspaceLabel(-98, "special:magic"), "magic")
    compare(Hypr.workspaceLabel(7, "code"), "code")
    compare(Hypr.workspaceLabel(3, ""), "3")
    compare(Hypr.workspaceLabel(undefined, ""), "")
  }

  function test_scroll() {
    compare(Hypr.scrollTarget(1), "e-1")
    compare(Hypr.scrollTarget(-1), "e+1")
    compare(Hypr.focusDispatch("e+1"), 'hl.dsp.focus({ workspace = "e+1" })')
    compare(Hypr.focusDispatch('4"x'), 'hl.dsp.focus({ workspace = "4x" })')
  }

  function test_wheel() {
    var w = Hypr.wheel(0, 60)
    compare(w.notches, 0); compare(w.accum, 60)
    w = Hypr.wheel(w.accum, 60)
    compare(w.notches, 1); compare(w.accum, 0)
    // A reversal drops what was carried.
    w = Hypr.wheel(100, -120)
    compare(w.notches, -1)
    compare(Hypr.wheel(5, 0).notches, 0)
  }

  function test_window_and_layout() {
    compare(Hypr.windowTitle("  ", "kitty"), "kitty")
    compare(Hypr.windowTitle("Doc", "kitty"), "Doc")
    compare(Hypr.layoutLabel("dwindle"), "Dwindle")
    compare(Hypr.layoutLabel(""), "")
  }
}
