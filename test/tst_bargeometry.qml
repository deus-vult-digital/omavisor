import QtQuick
import QtTest
import "../lib/BarGeometry.js" as BarGeometry

TestCase {
  name: "BarGeometry"

  function test_strip() {
    // 4.5: the window spans the screen and publishes the strip as its zone.
    compare(BarGeometry.strip(1080, 26, 26), 26)
    // A notch floor raises the zone above barSize.
    compare(BarGeometry.strip(1080, 38, 26), 38)
    // No usable zone: barSize, when it is smaller than the window.
    compare(BarGeometry.strip(1080, 0, 26), 26)
    compare(BarGeometry.strip(1080, -1, 26), 26)
    compare(BarGeometry.strip(1080, undefined, undefined), 1080)
    // 4.0: the window is the strip.
    compare(BarGeometry.strip(26, 26, 26), 26)
    compare(BarGeometry.strip(26, 0, 26), 26)
    compare(BarGeometry.strip(30, 0, 26), 26)
    compare(BarGeometry.strip(0, 0, 0), 0)
  }

  function test_innerEdge() {
    compare(BarGeometry.innerEdge(26, 0), 26)
    // 4.5 parks the whole window; 4.0 parked the strip.
    compare(BarGeometry.innerEdge(26, -1080), 0)
    compare(BarGeometry.innerEdge(26, -26), 0)
    compare(BarGeometry.innerEdge(26, undefined), 26)
  }

  function test_stripStart() {
    compare(BarGeometry.stripStart("top", 1080, 26), 0)
    compare(BarGeometry.stripStart("left", 2560, 26), 0)
    compare(BarGeometry.stripStart("bottom", 1080, 26), 1054)
    compare(BarGeometry.stripStart("right", 2560, 26), 2534)
    // 4.0: window and strip are the same size.
    compare(BarGeometry.stripStart("bottom", 26, 26), 0)
  }

  function test_hubRadius() {
    // auto follows the theme: square theme, square hub.
    compare(BarGeometry.hubRadius("auto", 0, 10), 0)
    compare(BarGeometry.hubRadius("auto", 8, 10), 8)
    // square wins over a rounded theme.
    compare(BarGeometry.hubRadius("square", 8, 10), 0)
    // round keeps the theme's rounding, else the fallback.
    compare(BarGeometry.hubRadius("round", 8, 10), 8)
    compare(BarGeometry.hubRadius("round", 0, 10), 10)
    compare(BarGeometry.hubRadius(undefined, 6, 10), 6)
  }
}
