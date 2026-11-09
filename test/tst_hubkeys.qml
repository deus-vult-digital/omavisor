import QtQuick
import QtTest
import "../lib/HubKeys.js" as HubKeys

TestCase {
  name: "HubKeys"

  readonly property var tabs: ["home", "media", "calendar", "capture", "system", "theme", "activities", "keys"]

  function test_stepTabWraps() {
    compare(HubKeys.stepTab(tabs, "home", 1), "media")
    compare(HubKeys.stepTab(tabs, "keys", 1), "home")
    compare(HubKeys.stepTab(tabs, "home", -1), "keys")
    compare(HubKeys.stepTab(tabs, "gone", 1), "home")
    compare(HubKeys.stepTab([], "home", 1), "")
  }

  function test_digitTab() {
    compare(HubKeys.digitTab(tabs, "1"), "home")
    compare(HubKeys.digitTab(tabs, "6"), "theme")
    compare(HubKeys.digitTab(tabs, "8"), "keys")
    compare(HubKeys.digitTab(tabs, "9"), "")
    compare(HubKeys.digitTab(tabs, "0"), "")
    compare(HubKeys.digitTab(tabs, "a"), "")
    compare(HubKeys.digitTab(tabs, ""), "")
  }

  // Two columns: a column of three chips on the left, two chips on the right.
  readonly property var rects: [
    { x: 0, y: 0, w: 100, h: 20 },    // 0
    { x: 0, y: 30, w: 100, h: 20 },   // 1
    { x: 0, y: 60, w: 100, h: 20 },   // 2
    { x: 200, y: 10, w: 80, h: 20 },  // 3
    { x: 200, y: 55, w: 80, h: 20 }   // 4
  ]

  // The home tab's shape: a scrubber over a transport in one column, timer
  // chips higher up in the next.
  readonly property var home: [
    { x: 0, y: 100, w: 100, h: 10 },   // 0: scrubber
    { x: 40, y: 120, w: 20, h: 20 },   // 1: play
    { x: 200, y: 50, w: 40, h: 40 },   // 2: chip
    { x: 200, y: 110, w: 40, h: 40 }   // 3: chip level with play
  ]

  function test_moveStaysInColumnGoingUp() {
    compare(HubKeys.move(home, 1, 0, -1), 0)
    compare(HubKeys.move(home, 0, 0, -1), 0)  // the hub goes to the tab strip
    compare(HubKeys.move(home, 1, 1, 0), 3)
    compare(HubKeys.move(home, 3, -1, 0), 1)
  }

  function test_moveDownFallsBackAcrossColumns() {
    var media = [{ x: 300, y: 40, w: 80, h: 10 }, { x: 100, y: 120, w: 20, h: 20 }]
    compare(HubKeys.move(media, 0, 0, 1), 1)
    compare(HubKeys.move(media, 1, 0, -1), 1)
  }

  function test_nearest() {
    compare(HubKeys.nearest(rects, { x: 0, y: 28, w: 100, h: 20 }), 1)
    compare(HubKeys.nearest(rects, { x: 210, y: 60, w: 80, h: 20 }), 4)
    compare(HubKeys.nearest([], { x: 0, y: 0, w: 1, h: 1 }), -1)
    compare(HubKeys.nearest(rects, null), -1)
  }

  function test_moveStartsTopLeft() {
    compare(HubKeys.move(rects, -1, 0, 1), 0)
    compare(HubKeys.move([{ x: 50, y: 0, w: 10, h: 10 }, { x: 0, y: 0, w: 10, h: 10 }], -1, 1, 0), 1)
    compare(HubKeys.move([], -1, 0, 1), -1)
  }

  function test_moveWalksColumnsAndRows() {
    compare(HubKeys.move(rects, 0, 0, 1), 1)
    compare(HubKeys.move(rects, 1, 0, 1), 2)
    compare(HubKeys.move(rects, 2, 0, 1), 2)  // nothing below: stays
    compare(HubKeys.move(rects, 2, 0, -1), 1)
    compare(HubKeys.move(rects, 0, 1, 0), 3)  // nearest on the right
    compare(HubKeys.move(rects, 2, 1, 0), 4)
    compare(HubKeys.move(rects, 4, -1, 0), 2)
    compare(HubKeys.move(rects, 3, -1, 0), 0)
    compare(HubKeys.move(rects, 3, 1, 0), 3)  // nothing further right
    compare(HubKeys.move(rects, 3, 0, 1), 4)
  }
}
