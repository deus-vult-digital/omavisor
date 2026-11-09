pragma ComponentBehavior: Bound

import QtQuick
import qs.Commons
import qs.Commons as Commons
import ".."

// Every live activity, most important first (ActivityStore.sorted), with
// progress, countdowns, actions and a dismiss button. Empty, it says how
// scripts push one. Beside them, the notifications glance (M3) while the
// shell keeps notification files.
Item {
  id: root

  property color foreground: Commons.Color.foreground
  property string fontFamily: Style.font.family
  property QtObject bar: null
  property var activities: null
  property bool allowActions: true
  property real nowMs: Date.now()
  property var notifications: null

  readonly property bool showNotifications: !!notifications && notifications.available
  readonly property real sideWidth: showNotifications ? Math.round((width - Style.spacing.panelGap * 2) / 3) : 0
  readonly property real mainWidth: showNotifications ? width - sideWidth - Style.spacing.panelGap * 2 : width

  readonly property var items: activities ? activities.items : []
  readonly property var byId: {
    var map = Object.create(null)
    for (let i = 0; i < items.length; i++) map[items[i].id] = items[i]
    return map
  }

  // The list holds ids and is patched in place (move, insert, remove), so
  // rows, their buttons and the scroll position survive the up to 10
  // renders a second; each row reads its activity from byId.
  ListModel { id: rows }

  onItemsChanged: sync()
  Component.onCompleted: sync()

  function sync() {
    for (let i = 0; i < items.length; i++) {
      const id = items[i].id
      if (i < rows.count && rows.get(i).aid === id) continue
      let from = -1
      for (let j = i + 1; j < rows.count; j++) if (rows.get(j).aid === id) { from = j; break }
      if (from >= 0) rows.move(from, i, 1)
      else rows.insert(i, { aid: id })
    }
    if (rows.count > items.length) rows.remove(items.length, rows.count - items.length)
  }

  TileRow {
    anchors.left: parent.left
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    width: root.mainWidth
    visible: root.items.length === 0
    Tile {
      title: "Activity"
      foreground: root.foreground
      fontFamily: root.fontFamily
      Readout { glyph: "󱐋"; value: "All quiet"; detail: "Recording, dictation, timers and agents show up here"; foreground: root.foreground; fontFamily: root.fontFamily }
    }
  }

  ListView {
    id: list
    // The hub's arrows move between the rows' buttons; the list's own key
    // navigation would take them and drop the focus on a bare row.
    keyNavigationEnabled: false
    anchors.left: parent.left
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    width: root.mainWidth
    visible: root.items.length > 0
    clip: true
    spacing: Style.spacing.lg
    boundsBehavior: Flickable.StopAtBounds
    model: rows
    Accessible.role: Accessible.List
    Accessible.name: "Live activities"

    delegate: ActivityRow {
      required property string aid
      width: list.width
      height: Math.max(implicitHeight, Style.spacing.controlHeight)
      activity: root.byId[aid] || null
      activities: root.activities
      allowActions: root.allowActions
      now: root.nowMs
      bar: root.bar
      foreground: root.foreground
      fontFamily: root.fontFamily
    }
  }

  Tile {
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    width: root.sideWidth
    visible: root.showNotifications
    divider: true
    dividerGap: Style.spacing.panelGap * 2
    title: !root.notifications ? "Notifications"
      : "Notifications" + (root.notifications.unread > 0 ? " · " + root.notifications.unread + " new" : "")
        + (root.notifications.onScreen > 0 ? " · " + root.notifications.onScreen + " on screen" : "")
    foreground: root.foreground
    fontFamily: root.fontFamily

    NotificationsPanel {
      anchors.fill: parent
      notifications: root.notifications
      nowMs: root.nowMs
      foreground: root.foreground
      fontFamily: root.fontFamily
    }
  }
}
