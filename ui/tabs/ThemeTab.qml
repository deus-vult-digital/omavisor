pragma ComponentBehavior: Bound

import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import ".."

// The theme switcher: every theme `omarchy theme list` prints, in its
// order, as a card with its preview and swatches; a click (or Enter on a
// focused card) applies it with `omarchy theme set`. The leading column
// shows the current theme with the extras: the next background and the
// full built-in switcher.
Item {
  id: root

  property color foreground: Commons.Color.foreground
  property string fontFamily: Style.font.family
  property var service: null
  // Where the hub's arrows start on this tab: the theme cards.
  readonly property Item keyFocusItem: grid

  readonly property var theme: service ? service.theme : null
  readonly property var cards: theme ? theme.cards : []
  readonly property int currentIndex: {
    for (let i = 0; i < cards.length; i++) if (cards[i].current) return i
    return -1
  }
  readonly property var currentCard: currentIndex >= 0 ? cards[currentIndex] : null
  // A fresh list (after an apply) resets the grid to its first card: keep
  // the keyboard on the theme just applied.
  onCardsChanged: refocus.restart()
  Timer {
    id: refocus
    interval: 0
    onTriggered: if (grid.activeFocus && root.currentIndex >= 0) grid.currentIndex = root.currentIndex
  }

  // Read again each time the tab appears: themes may have been installed.
  Component.onCompleted: if (theme) theme.refresh()
  onVisibleChanged: if (visible && theme) theme.refresh()

  readonly property real gap: Style.spacing.panelGap * 2

  Tile {
    id: currentTile
    width: Math.round((root.width - root.gap) * 0.26)
    height: root.height
    title: "Theme"
    foreground: root.foreground
    fontFamily: root.fontFamily

    ThemeCard {
      id: currentPreview
      width: parent.width
      height: parent.height - chips.height - Style.spacing.lg
      visible: !!root.currentCard
      card: root.currentCard || ({})
      busy: !!root.theme && root.theme.applying !== ""
      foreground: root.foreground
      fontFamily: root.fontFamily
      // Already the theme: a click opens the full switcher instead.
      onPicked: root.openSwitcher()
    }

    ChipGrid {
      id: chips
      anchors.bottom: parent.bottom
      width: parent.width
      cols: 2
      iconOnly: true
      options: [
        { key: "bg", icon: "󰸉", label: "Next background", tooltip: "Next background" },
        { key: "switcher", icon: "󰏘", label: "All themes", tooltip: "Open the theme switcher" }
      ]
      foreground: root.foreground
      fontFamily: root.fontFamily
      onPicked: function(key) {
        if (!root.theme) return
        if (key === "bg") root.theme.nextBackground()
        else root.openSwitcher()
      }
    }
  }

  function openSwitcher() {
    if (!theme) return
    // The switcher is a shell overlay of its own: get the hub out of its way.
    if (service && service.activities) service.activities.collapse()
    theme.openSwitcher()
  }

  Tile {
    id: listTile
    x: currentTile.width + root.gap
    width: root.width - x
    height: root.height
    divider: true
    dividerGap: root.gap
    title: root.cards.length > 0 ? "Themes  ·  " + root.cards.length : "Themes"
    foreground: root.foreground
    fontFamily: root.fontFamily

    Text {
      anchors.centerIn: parent
      visible: root.cards.length === 0
      textFormat: Text.PlainText
      text: root.theme && root.theme.loading ? "Loading…" : "No themes"
      color: Qt.darker(root.foreground, 1.4)
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
    }

    GridView {
      id: grid
      // Up and Down move a row, Left and Right a card; Enter applies.
      anchors.fill: parent
      clip: true
      model: root.cards
      readonly property int columns: Math.max(1, Math.floor(width / Style.space(104)))
      cellWidth: Math.floor(width / columns)
      cellHeight: Math.round((cellWidth - Style.spacing.sm) * 9 / 16) + Style.font.bodySmall + Style.spacing.lg * 2
      boundsBehavior: Flickable.StopAtBounds
      keyNavigationEnabled: true
      // The grid would wrap a row; at its edge the keys leave it instead.
      Keys.onLeftPressed: function(event) {
        if (currentIndex % columns === 0 && currentPreview.visible) currentPreview.forceActiveFocus()
        else event.accepted = false
      }
      Keys.onRightPressed: function(event) { event.accepted = currentIndex % columns === columns - 1 }
      currentIndex: root.currentIndex
      Accessible.role: Accessible.List
      Accessible.name: "Themes"

      // Bring the current theme into view when the list arrives.
      onCountChanged: if (root.currentIndex >= 0) positionViewAtIndex(root.currentIndex, GridView.Contain)
      // And keep the keyboard's card in view.
      // Arriving from elsewhere starts on the current theme.
      onActiveFocusChanged: {
        if (!activeFocus) return
        if (root.currentIndex >= 0) currentIndex = root.currentIndex
        if (currentIndex >= 0) positionViewAtIndex(currentIndex, GridView.Contain)
      }
      onCurrentIndexChanged: if (activeFocus && currentIndex >= 0) positionViewAtIndex(currentIndex, GridView.Contain)

      // A focus scope, so the grid's focus reaches the card inside.
      delegate: FocusScope {
        id: cell
        required property var modelData
        required property int index
        width: grid.cellWidth
        height: grid.cellHeight

        ThemeCard {
          anchors.fill: parent
          anchors.rightMargin: Style.spacing.sm
          anchors.bottomMargin: Style.spacing.sm
          card: cell.modelData
          busy: !!root.theme && root.theme.applying !== "" && cell.modelData.current
          focus: true
          foreground: root.foreground
          fontFamily: root.fontFamily
          onPicked: if (root.theme) root.theme.apply(cell.modelData.name)
        }
      }
    }
  }
}
