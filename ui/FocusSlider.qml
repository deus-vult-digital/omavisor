import QtQuick
import qs.Ui

// A qs.Ui PanelSlider the hub's keys can reach: Left and Right step it (the
// hub's focus ring marks it); Up and Down leave it, as on any control.
PanelSlider {
  id: root

  property real keyStep: step

  activeFocusOnTab: true
  Keys.onLeftPressed: root.nudge(-1)
  Keys.onRightPressed: root.nudge(1)

  function nudge(direction) {
    var next = Math.max(minimum, Math.min(maximum, value + direction * keyStep))
    moved(next)
    released(next)
  }
}
