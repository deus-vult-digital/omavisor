import QtQuick
import qs.Commons
import qs.Ui

// A qs.Ui CursorSurface the hub's keys can reach: in the focus chain, drawn
// with the theme's focus fill and border while it has the keyboard focus,
// and Enter emits activated() (wire it to the row's click).
CursorSurface {
  id: root

  signal activated()

  activeFocusOnTab: true
  color: activeFocus ? Style.focusFillFor(foreground, accent) : (hasCursor ? fill : (current ? currentFill : "transparent"))
  borderSpec: activeFocus
    ? Border.controlSpec("focus", foreground, accent)
    : (hasCursor
      ? Border.controlSpec("hover-cursor", foreground, accent)
      : (current
        ? Border.controlSpec("selected", foreground, accent)
        : (bordered ? Border.controlSpec("normal", foreground, accent) : Border.none())))

  Keys.onReturnPressed: root.activated()
  Keys.onEnterPressed: root.activated()
}
