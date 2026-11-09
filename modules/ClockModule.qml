import QtQuick
import Quickshell
import "../lib/Format.js" as Format

// The clock text for one format, rendered exactly as omarchy.clock renders
// it (Qt date format, plus `ww` for the ISO week). It ticks on the minute,
// or on the second only while the format shows seconds, so a collapsed pill
// wakes once a minute.
Item {
  id: root

  property string format: "dddd h:mm AP"

  readonly property bool available: true
  readonly property bool needsSeconds: Format.needsSeconds(format)
  readonly property date now: clock.date
  readonly property string text: Qt.formatDateTime(now, Format.clockFormat(format, now))

  // Re-read the time now (after resume, say) instead of at the next tick.
  function refresh() {
    clock.enabled = false
    clock.enabled = true
  }

  SystemClock {
    id: clock
    precision: root.needsSeconds ? SystemClock.Seconds : SystemClock.Minutes
  }
}
