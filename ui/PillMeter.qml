pragma ComponentBehavior: Bound

import QtQuick
import qs.Commons
import qs.Commons as Commons
import "../lib/Visualizer.js" as Visualizer

// The pill's small level meter while a player plays: four bars. With cava
// (`live`) they follow the audio, `levels` folded into four bands; without,
// a drawing with each bar at its own pace. Moves while `active`.
Row {
  id: root

  property bool active: false
  // From VisualizerModule: real levels, and whether they are.
  property bool live: false
  property var levels: []
  readonly property var shown: Visualizer.bands(levels, 4)
  property bool reduceMotion: false
  property real size: Style.font.body
  property color foreground: Commons.Color.foreground

  height: size
  spacing: Math.max(1, Math.round(size / 8))

  Repeater {
    model: 4

    Rectangle {
      id: barRect
      required property int index
      readonly property real low: 0.25
      readonly property int pace: [520, 380, 610, 450][index]
      readonly property real peak: [0.7, 1, 0.8, 0.6][index]
      property real drawnLevel: low
      readonly property real level: root.live && root.active ? Math.max(0.12, root.shown[index]) : drawnLevel
      // Sat on the row's bottom by position, not an anchor: a bar being
      // torn down has no parent to anchor to.
      y: root.size - height
      width: Math.max(2, Math.round((root.size - root.spacing * 3) / 4))
      height: Math.max(2, Math.round(root.size * level))
      radius: width / 2
      color: root.foreground

      SequentialAnimation on drawnLevel {
        running: root.active && !root.live && !root.reduceMotion
        loops: Animation.Infinite
        onRunningChanged: if (!running) barRect.drawnLevel = barRect.low
        NumberAnimation { to: barRect.peak; duration: barRect.pace; easing.type: Easing.InOutSine }
        NumberAnimation { to: barRect.low + 0.15; duration: barRect.pace * 0.8; easing.type: Easing.InOutSine }
        NumberAnimation { to: barRect.peak * 0.75; duration: barRect.pace * 0.7; easing.type: Easing.InOutSine }
        NumberAnimation { to: barRect.low; duration: barRect.pace; easing.type: Easing.InOutSine }
      }
    }
  }
}
