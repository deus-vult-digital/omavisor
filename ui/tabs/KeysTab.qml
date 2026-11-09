pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import ".."

// The keybinding cheatsheet (M3): every line of `omarchy menu keybindings
// --print` in columns. Typing filters them (the hub's keys bring any letter to
// the search field), Down or Enter goes on to the list, Esc clears the field
// first. The button beside it opens Omarchy's own keybindings menu after the
// hub closes, like the capture buttons.
Item {
  id: root

  property color foreground: Commons.Color.foreground
  property string fontFamily: Style.font.family
  property var keybindings: null
  // Omavisor's service: closes the hub before the menu opens.
  property var service: null

  readonly property color dim: Qt.darker(foreground, 1.4)
  // A digit in the empty field is still a tab key.
  signal tabDigit(string text)

  readonly property var shown: keybindings ? keybindings.filtered(search.text) : []
  // Where the hub's keys land on this tab.
  readonly property Item keyFocusItem: search

  Component.onCompleted: if (keybindings) keybindings.refresh()
  onVisibleChanged: {
    if (visible && keybindings) keybindings.refresh()
    if (!visible) search.text = ""
  }

  // The hub hands over what is typed anywhere on the tab.
  function typeText(text) {
    search.forceActiveFocus()
    search.insert(search.length, text)
  }

  function openMenu() {
    var argv = ["omarchy", "menu", "keybindings"]
    if (service && service.capture) service.capture.runAfterClose(argv)
    else Quickshell.execDetached(argv)
  }

  TextField {
    id: search
    anchors.top: parent.top
    anchors.left: parent.left
    width: Math.min(parent.width, Style.space(260))
    placeholderText: "󰍉  Search keybindings"
    foreground: root.foreground
    font.family: root.fontFamily
    activeFocusOnTab: true
    Keys.onPressed: function(event) {
      if (text === "" && /^[1-9]$/.test(event.text)) {
        root.tabDigit(event.text)
        event.accepted = true
      }
    }
    Keys.onEscapePressed: function(event) {
      event.accepted = text !== ""
      text = ""
    }
    Keys.onReturnPressed: if (grid.count > 0) grid.forceActiveFocus()
    Keys.onEnterPressed: if (grid.count > 0) grid.forceActiveFocus()
    Accessible.role: Accessible.EditableText
    Accessible.name: "Search keybindings"
  }

  Button {
    anchors.verticalCenter: search.verticalCenter
    anchors.left: search.right
    anchors.leftMargin: Style.spacing.md
    focusable: true
    bordered: true
    iconText: "󰌌"
    tooltipText: "Open Omarchy's keybindings menu"
    foreground: root.foreground
    fontFamily: root.fontFamily
    Accessible.role: Accessible.Button
    Accessible.name: tooltipText
    onClicked: root.openMenu()
  }

  Text {
    anchors.verticalCenter: search.verticalCenter
    anchors.right: parent.right
    textFormat: Text.PlainText
    text: !root.keybindings ? "" : !root.keybindings.available ? "omarchy menu keybindings is not available"
      : search.text !== "" && root.keybindings.bindings.length > 0 ? root.shown.length + " of " + root.keybindings.bindings.length
      : root.shown.length + " bindings"
    color: root.dim
    font.family: root.fontFamily
    font.pixelSize: Style.font.bodySmall
  }

  GridView {
    id: grid
    anchors.top: search.bottom
    anchors.topMargin: Style.spacing.lg
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    cellWidth: Math.floor(width / 3)
    cellHeight: Math.ceil(Style.font.body * 1.7)
    model: root.shown
    Accessible.role: Accessible.List
    Accessible.name: "Keybindings"
    onCurrentIndexChanged: if (activeFocus && currentIndex >= 0) positionViewAtIndex(currentIndex, GridView.Contain)

    delegate: FocusScope {
      id: cell
      required property var modelData
      width: grid.cellWidth
      height: grid.cellHeight
      Accessible.role: Accessible.ListItem
      Accessible.name: modelData.keys + ": " + modelData.action

      // Only for the keys' ring: a binding is read, not run.
      FocusSurface {
        anchors.fill: parent
        focus: true
        foreground: root.foreground
      }

      Text {
        id: keys
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: Math.round(parent.width * 0.5)
        textFormat: Text.PlainText
        text: cell.modelData.keys
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        font.bold: true
        elide: Text.ElideRight
      }
      Text {
        anchors.left: keys.right
        anchors.leftMargin: Style.spacing.sm
        anchors.right: parent.right
        anchors.rightMargin: Style.spacing.lg
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: cell.modelData.action
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        elide: Text.ElideRight
      }
    }
  }
}
