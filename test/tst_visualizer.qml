import QtQuick
import QtTest
import "../lib/Visualizer.js" as Visualizer
import "../lib/Settings.js" as Settings

TestCase {
  name: "Visualizer"

  function test_styles() {
    compare(Visualizer.nextStyle("bars"), "mirror")
    compare(Visualizer.nextStyle("dots"), "bars")
    compare(Visualizer.nextStyle("nope"), "mirror")
    compare(Visualizer.normalizeStyle("wave"), "wave")
    compare(Visualizer.normalizeStyle(undefined), "bars")
  }

  function test_setting() {
    compare(Settings.resolve({}).visualizerStyle, "bars")
    compare(Settings.resolve({ visualizerStyle: "dots" }).visualizerStyle, "dots")
    compare(Settings.resolve({ visualizerStyle: "laser" }).visualizerStyle, "bars")
  }

  function test_hubOpacity() {
    compare(Settings.resolve({}).hubOpacity, 85)
    compare(Settings.resolve({ hubOpacity: 20 }).hubOpacity, 40)
    compare(Settings.resolve({ hubOpacity: "70" }).hubOpacity, 70)
  }

  function test_config() {
    var c = Visualizer.cavaConfig(16, 25)
    verify(c.indexOf("bars = 16") !== -1)
    verify(c.indexOf("framerate = 25") !== -1)
    verify(c.indexOf("method = raw") !== -1)
    verify(c.indexOf("data_format = ascii") !== -1)
    verify(c.indexOf("bar_delimiter = 59") !== -1)
    // No input device named: cava's default, the default output's monitor.
    verify(c.indexOf("[input]") === -1)
    verify(Visualizer.cavaConfig(0, 0).indexOf("bars = " + Visualizer.BARS) !== -1)
  }

  function test_parseFrame() {
    compare(Visualizer.parseFrame("0;50;100;", 3), [0, 0.5, 1])
    compare(Visualizer.parseFrame("50;", 3), [0.5, 0, 0])
    compare(Visualizer.parseFrame("200;-5;x;7", 4), [1, 0, 0, 0.07])
    compare(Visualizer.parseFrame("", 2), [0, 0])
    compare(Visualizer.parseFrame(null, 2), [0, 0])
    compare(Visualizer.parseFrame("1;2;3;4;5", 2).length, 2)
  }

  function test_drawn() {
    var a = Visualizer.drawn(1.5, 8)
    compare(a.length, 8)
    compare(Visualizer.drawn(1.5, 8), a)
    verify(a.every(function(v) { return v >= 0.04 && v <= 1 }))
    verify(Visualizer.drawn(2.5, 8).some(function(v, i) { return v !== a[i] }))
  }

  function test_bands() {
    compare(Visualizer.bands([], 4), [0, 0, 0, 0])
    var b = Visualizer.bands([0, 0, 1, 0, 0.5, 0.5, 0, 0], 4)
    compare(b.length, 4)
    compare(b[0], 0)
    fuzzyCompare(b[1], 0.7, 1e-9)
    fuzzyCompare(b[2], 0.5, 1e-9)
    compare(Visualizer.bands([0.2, 0.4], 4).length, 4)
  }

  function test_smooth() {
    var up = Visualizer.smooth([0, 1], [1, 0])
    fuzzyCompare(up[0], 0.6, 1e-9)
    fuzzyCompare(up[1], 0.75, 1e-9)
    compare(Visualizer.smooth(null, [0.5]).length, 1)
  }
}
