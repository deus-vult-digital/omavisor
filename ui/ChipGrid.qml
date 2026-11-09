pragma ComponentBehavior: Bound

import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// A grid of bordered qs.Ui Buttons (the power panel's profile chips):
// `options` is [{ key, icon, label, tooltip }]; a click emits picked(key).
// `iconOnly` drops the labels (Home tiles). `toggle: true` on an option makes
// Space flip it as well as Enter.
Grid {
  id: root

  property var options: []
  property int cols: 2
  property bool iconOnly: false
  property color foreground: Commons.Color.foreground
  property string fontFamily: Style.font.family

  signal picked(string key)

  columns: Math.max(1, cols)
  spacing: Style.space(6)

  readonly property real cellWidth: (width - spacing * (columns - 1)) / columns
  // Every chip as tall as the tallest (an icon chip is taller than a
  // text one).
  property real cellHeight: 0

  Repeater {
    model: root.options

    Button {
      required property var modelData
      readonly property bool spaceToggles: modelData.toggle === true
      focusable: true
      width: root.cellWidth
      height: Math.max(implicitHeight, root.cellHeight)
      onImplicitHeightChanged: root.cellHeight = Math.max(root.cellHeight, implicitHeight)
      Component.onCompleted: root.cellHeight = Math.max(root.cellHeight, implicitHeight)
      iconText: modelData.icon || ""
      iconSize: Style.font.title
      text: root.iconOnly ? "" : (modelData.label || "")
      tooltipText: root.iconOnly ? (modelData.tooltip || modelData.label || "") : (modelData.tooltip || "")
      fontSize: Style.font.bodySmall
      foreground: root.foreground
      fontFamily: root.fontFamily
      verticalPadding: Style.spacing.controlPaddingY + Style.space(2)
      bordered: true
      active: modelData.active === true
      Accessible.role: Accessible.Button
      Accessible.name: modelData.tooltip || modelData.label || ""
      onClicked: root.picked(modelData.key)
    }
  }
}
