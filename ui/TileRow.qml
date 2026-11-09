import QtQuick
import qs.Commons

// Lays its Tile children side by side in equal columns, MacNotch's
// dashboard slots, with the gap the stock panels use between sections.
Row {
  id: root

  readonly property real gap: Style.spacing.panelGap * 2

  spacing: gap

  // Columns are the visible Tiles (a Repeater's delegates included; the
  // Repeater itself and hidden tiles take no slot). Imperative and
  // deferred, so a tile showing or hiding never loops through a binding.
  function relayout() {
    var cols = []
    for (let i = 0; i < children.length; i++)
      if ("divider" in children[i] && children[i].visible) cols.push(children[i])
    var w = cols.length > 0 ? (width - gap * (cols.length - 1)) / cols.length : width
    for (let i = 0; i < cols.length; i++) {
      cols[i].width = w
      cols[i].height = height
      cols[i].divider = i > 0
      cols[i].dividerGap = gap
    }
  }

  function scheduleRelayout() { Qt.callLater(relayout) }

  onWidthChanged: relayout()
  onHeightChanged: relayout()
  onChildrenChanged: scheduleRelayout()
  Component.onCompleted: relayout()
}
