import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import ".."
import "../../lib/Catalog.js" as Catalog
import "../../lib/Customize.js" as Customize
import "../../lib/Settings.js" as Settings

// The Settings page, off the gear in the hub's header: which tabs, Home tiles
// and pill items show and in what order, and how far each kind of activity may
// interrupt. Every change shows at once and is written by the SettingsEditor,
// which holds it past this page. docs/customization-plan.md has the rules.
Item {
  id: root

  property color foreground: Commons.Color.foreground
  property string fontFamily: Style.font.family
  property var service: null
  property var config: ({})
  property var editor: null

  signal focusMoved(Item item)

  // Where the keys start (HubContent.startItem).
  readonly property Item keyFocusItem: tabsColumn.firstRow
  readonly property var layout: service ? service.layout : null

  // Run a change, and bring the focus along if it was on this column.
  function apply(column, id, changes) {
    if (!editor) return
    let keep = column && column.hasFocus
    editor.change(changes)
    if (keep) Qt.callLater(function() { column.focusRow(id) })
  }

  TileRow {
    id: columns
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: footer.top
    anchors.bottomMargin: Style.spacing.md

    SettingsColumn {
      id: tabsColumn
      title: "Tabs"
      rows: Customize.tabRows(root.config, root.service)
      foreground: root.foreground
      fontFamily: root.fontFamily
      onFocusMoved: function(item) { root.focusMoved(item) }
      onActivated: function(id) { root.apply(tabsColumn, id, Customize.toggleTab(root.config, id)) }
      onMoved: function(id, direction) { root.apply(tabsColumn, id, Customize.moveTab(root.config, id, direction)) }
    }

    SettingsColumn {
      id: tilesColumn
      title: "Home tiles (first " + Catalog.HOME_SLOTS + ")"
      rows: Customize.tileRows(root.config, root.service)
      foreground: root.foreground
      fontFamily: root.fontFamily
      onFocusMoved: function(item) { root.focusMoved(item) }
      onActivated: function(id) { root.apply(tilesColumn, id, { homeTiles: Customize.toggled(root.config.homeTiles, id) }) }
      onMoved: function(id, direction) { root.apply(tilesColumn, id, { homeTiles: Customize.moved(root.config.homeTiles, id, direction, []) }) }
    }

    SettingsColumn {
      id: pillColumn
      title: "Pill"
      rows: Customize.pillRows(root.config, root.service)
      foreground: root.foreground
      fontFamily: root.fontFamily
      onFocusMoved: function(item) { root.focusMoved(item) }
      onActivated: function(id) { root.apply(pillColumn, id, { pillItems: Customize.togglePillItem(root.config, id) }) }
      onMoved: function(id, direction) { root.apply(pillColumn, id, { pillItems: Customize.moved(root.config.pillItems, id, direction, ["badge"]) }) }
    }

    SettingsColumn {
      id: activitiesColumn
      title: "Activities"
      rows: Customize.activityRows(root.config)
      foreground: root.foreground
      fontFamily: root.fontFamily
      onFocusMoved: function(item) { root.focusMoved(item) }
      onActivated: function(id) { root.apply(activitiesColumn, id, Customize.nextLevelChanges(root.config, id)) }
    }
  }

  Item {
    id: footer
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    height: Math.max(buttons.implicitHeight, hint.implicitHeight)

    Text {
      id: hint
      anchors.left: parent.left
      anchors.right: buttons.left
      anchors.rightMargin: Style.spacing.lg
      anchors.verticalCenter: parent.verticalCenter
      textFormat: Text.PlainText
      text: root.editor && !root.editor.canSave ? "This shell can't save settings; changes last until it restarts."
        : Customize.timersUnseen(root.config, root.service) ? "Timers show nowhere now; omavisor timer still runs them."
        : "Space shows or hides  ·  Shift+↑↓ moves  ·  Esc back"
      elide: Text.ElideRight
      color: root.foreground
      opacity: 0.7
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      renderType: Text.NativeRendering
    }

    Row {
      id: buttons
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.spacing.md

      // The System tab's Restore or Replace, for when that tab is hidden.
      Button {
        readonly property bool spaceToggles: true
        visible: !!root.layout && (root.layout.replaced || root.layout.canReplace)
        enabled: !!root.layout && root.layout.busy === ""
        text: !root.layout ? ""
          : root.layout.busy === "restore" ? "Restoring…"
          : root.layout.busy === "replace" ? "Replacing…"
          : root.layout.replaced ? "Restore stock clock" : "Replace stock clock"
        focusable: true
        bordered: true
        foreground: root.foreground
        fontFamily: root.fontFamily
        onClicked: {
          if (root.layout.replaced) root.layout.restore()
          else root.layout.replace()
        }
      }

      // Twice, since it can't be undone.
      Button {
        id: reset
        readonly property bool spaceToggles: true
        property bool armed: false
        text: armed ? "Reset all four?" : "Reset to defaults"
        focusable: true
        bordered: true
        selected: armed
        foreground: root.foreground
        fontFamily: root.fontFamily
        onClicked: {
          if (!armed) { armed = true; disarm.restart(); return }
          armed = false
          if (root.editor) root.editor.change(Customize.resetChanges(Settings.CUSTOMIZATION_KEYS))
        }
        Timer {
          id: disarm
          interval: 4000
          onTriggered: reset.armed = false
        }
      }
    }
  }
}
