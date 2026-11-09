import QtQuick
import qs.Commons
import qs.Commons as Commons
import ".."
import "../../lib/Catalog.js" as Catalog
import "../../lib/Format.js" as Format
import "../../lib/Layout.js" as Layout

// System stats, Omarchy updates and pending packages, failed units (only
// while any), the quick toggles (DND, night light, stay awake) and timers
// (only when the Home tab does not already show them, to leave the stats
// room). A module whose tool is missing takes no column. While Omavisor has
// replaced the clock and weather, a Bar layout tile offers Restore.
Item {
  id: root

  property color foreground: Commons.Color.foreground
  property string fontFamily: Style.font.family
  property var service: null
  property var config: ({})
  property real nowMs: Date.now()

  readonly property var updates: service ? service.updates : null
  readonly property var toggles: service ? service.toggles : null
  readonly property var layout: service ? service.layout : null
  readonly property var packages: service ? service.packages : null
  readonly property var units: service ? service.units : null
  // Home decides with the same function, unless the bar-layout card has
  // taken its place.
  readonly property bool timersOnHome: Catalog.timersOnHome(config, service)
    && !(layout && Layout.showsCard(layout.stage))

  // A unit that failed since the last minute's check shows at once.
  onVisibleChanged: if (visible && units) units.refresh()
  Component.onCompleted: if (units) units.refresh()

  TileRow {
    anchors.fill: parent

    Tile {
      title: "Stats"
      visible: !!root.service && !!root.service.stats
      foreground: root.foreground
      fontFamily: root.fontFamily
      StatsPanel {
        anchors.fill: parent
        stats: root.service ? root.service.stats : null
        foreground: root.foreground
        fontFamily: root.fontFamily
      }
    }

    Tile {
      title: "Timers"
      visible: !root.timersOnHome
      foreground: root.foreground
      fontFamily: root.fontFamily
      TimersPanel {
        anchors.fill: parent
        timers: root.service ? root.service.timers : null
        nowMs: root.nowMs
        foreground: root.foreground
        fontFamily: root.fontFamily
      }
    }

    Tile {
      title: "Updates"
      visible: (!!root.updates && root.updates.available) || (!!root.packages && root.packages.available)
      foreground: root.foreground
      fontFamily: root.fontFamily
      UpdatesPanel {
        anchors.fill: parent
        updates: root.updates
        packages: root.packages
        nowMs: root.nowMs
        foreground: root.foreground
        fontFamily: root.fontFamily
      }
    }

    Tile {
      title: "Failed units"
      visible: !!root.units && root.units.available && root.units.count > 0
      foreground: root.foreground
      fontFamily: root.fontFamily
      UnitsPanel {
        anchors.fill: parent
        units: root.units
        foreground: root.foreground
        fontFamily: root.fontFamily
      }
    }

    // Restore while Omavisor has the clock's place; Replace again after a
    // restore or in wrap mode.
    Tile {
      title: "Bar layout"
      visible: !!root.layout && (root.layout.replaced || root.layout.canReplace || root.layout.busy !== "")
      foreground: root.foreground
      fontFamily: root.fontFamily

      Readout {
        glyph: "󰕮"
        value: !root.layout ? ""
          : root.layout.busy === "restore" ? "Restoring…"
          : root.layout.busy === "replace" ? "Replacing…"
          : root.layout.replaced ? "Replaced" : "Stock"
        detail: !root.layout || !root.layout.backup ? "Clock & weather"
          : root.layout.replaced ? "Clock & weather  ·  saved " + Format.age(Date.parse(root.layout.backup.savedAt), root.nowMs)
          : "Clock & weather  ·  restored " + Format.age(Date.parse(root.layout.backup.restoredAt), root.nowMs)
        foreground: root.foreground
        fontFamily: root.fontFamily
      }

      ChipGrid {
        anchors.bottom: parent.bottom
        width: parent.width
        cols: 1
        visible: !!root.layout && root.layout.busy === ""
        options: root.layout && root.layout.replaced
          ? [{ key: "restore", icon: "󰦛", label: "Restore", tooltip: "Restore the stock clock and weather" }]
          : [{ key: "replace", icon: "󰁯", label: "Replace", tooltip: "Replace the clock and weather with Omavisor" }]
        foreground: root.foreground
        fontFamily: root.fontFamily
        onPicked: function(key) {
          if (key === "restore") root.layout.restore()
          else root.layout.replace()
        }
      }
    }

    Tile {
      title: "Quick toggles"
      visible: !!root.toggles && root.toggles.available
      foreground: root.foreground
      fontFamily: root.fontFamily
      TogglesPanel {
        width: parent.width
        toggles: root.toggles
        foreground: root.foreground
        fontFamily: root.fontFamily
      }
    }
  }
}
