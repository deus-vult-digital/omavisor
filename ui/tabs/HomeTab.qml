pragma ComponentBehavior: Bound

import QtQuick
import qs.Commons
import qs.Commons as Commons
import ".."
import "../../lib/Calendar.js" as Calendar
import "../../lib/Catalog.js" as Catalog
import "../../lib/Layout.js" as Layout

// Up to four tiles, in the order `homeTiles` lists them (MacNotch's four
// dashboard slots). Media and weather show live data and step aside when
// there is none (no player, no reading yet), updates and capture when their
// module is unavailable; a Today tile fills in for one that stepped aside, and
// can be listed itself. Power shows only with a battery; hypr only under
// Hyprland. lib/Catalog.js picks them.
Item {
  id: root

  property color foreground: Commons.Color.foreground
  property string fontFamily: Style.font.family
  property date now: new Date()
  property QtObject bar: null
  property var config: ({})
  property var weather: null
  property var media: null
  property var service: null
  property real nowMs: Date.now()

  readonly property color dim: Qt.darker(foreground, 1.4)
  // Through a string, which only signals a real change: a settings write makes
  // a new config, and a new array would rebuild every tile under the pointer.
  readonly property string tileList: Catalog.homeTiles(config, service).join(" ")
  readonly property var tiles: tileList.split(" ")

  // The bar-layout card (first run, the anchor step, a failed run) takes
  // the tab's place until it is answered.
  readonly property var layout: service ? service.layout : null
  readonly property bool showCard: !!layout && Layout.showsCard(layout.stage)

  // The media tile shows the position, so it is polled while it is visible.
  readonly property bool watching: visible && !showCard && tiles.indexOf("media") !== -1
  onWatchingChanged: if (media) media.watchers += watching ? 1 : -1
  Component.onDestruction: if (watching && media) media.watchers -= 1

  OnboardingCard {
    anchors.fill: parent
    visible: root.showCard
    layout: root.layout
    foreground: root.foreground
    fontFamily: root.fontFamily
  }

  TileRow {
    anchors.fill: parent
    visible: !root.showCard

    Repeater {
      model: root.tiles

      Tile {
        id: tile
        required property string modelData
        title: modelData === "media" ? (root.media ? root.media.identity || "Media" : "Media")
          : modelData === "weather" ? (root.weather ? root.weather.location || "Weather" : "Weather")
          : Catalog.find(Catalog.TILES, modelData).label
        foreground: root.foreground
        fontFamily: root.fontFamily

        Loader {
          anchors.fill: parent
          sourceComponent: tile.modelData === "media" ? mediaTile
            : tile.modelData === "weather" ? weatherTile
            : tile.modelData === "timers" ? timersTile
            : tile.modelData === "updates" ? updatesTile
            : tile.modelData === "capture" ? captureTile
            : tile.modelData === "stats" ? statsTile
            : tile.modelData === "power" ? powerTile
            : tile.modelData === "hypr" ? hyprTile
            : tile.modelData === "actions" ? actionsTile
            : todayTile
        }
      }
    }
  }

  Component {
    id: todayTile
    Item {
      Readout {
        glyph: "\udb80\udced"
        value: Qt.formatDate(root.now, "MMM d")
        detail: Qt.locale("en_US").dayName(root.now.getDay(), Locale.LongFormat) + "  ·  Week "
          + Calendar.isoWeek(root.now.getFullYear(), root.now.getMonth(), root.now.getDate())
        foreground: root.foreground
        fontFamily: root.fontFamily
      }

      ProgressRail {
        anchors.bottom: parent.bottom
        width: parent.width
        label: "DAY"
        value: Calendar.dayProgress(root.now)
        foreground: root.foreground
        fontFamily: root.fontFamily
      }
    }
  }

  Component {
    id: mediaTile
    Row {
      spacing: Style.spacing.lg

      AlbumArt {
        id: thumb
        width: Math.round(Math.min(parent.height * 0.5, parent.width * 0.32))
        height: width
        source: root.media ? root.media.artUrl : ""
        foreground: root.foreground
        fontFamily: root.fontFamily
      }

      NowPlaying {
        width: parent.width - thumb.width - parent.spacing
        height: parent.height
        compact: true
        media: root.media
        bar: root.bar
        foreground: root.foreground
        fontFamily: root.fontFamily
      }
    }
  }

  Component {
    id: weatherTile
    Item {
      Readout {
        glyph: root.weather ? root.weather.glyph : ""
        value: root.weather ? root.weather.tempWithUnit : ""
        detail: root.weather ? [root.weather.condition, root.weather.high !== "" ? "H " + root.weather.high + "  L " + root.weather.low : ""].filter(function(s) { return s !== "" }).join("  ·  ") : ""
        foreground: root.foreground
        fontFamily: root.fontFamily
      }

      Text {
        anchors.bottom: parent.bottom
        width: parent.width
        textFormat: Text.PlainText
        text: !root.weather ? ""
          : root.weather.stale ? "Offline · updated " + root.weather.updated
          : root.weather.wind !== "" ? "Wind " + root.weather.wind : ""
        Accessible.name: root.weather ? root.weather.summary : ""
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        elide: Text.ElideRight
      }
    }
  }

  Component {
    id: timersTile
    TimersPanel {
      compact: true
      timers: root.service ? root.service.timers : null
      nowMs: root.nowMs
      foreground: root.foreground
      fontFamily: root.fontFamily
    }
  }

  Component {
    id: updatesTile
    UpdatesPanel {
      updates: root.service ? root.service.updates : null
      packages: root.service ? root.service.packages : null
      nowMs: root.nowMs
      foreground: root.foreground
      fontFamily: root.fontFamily
    }
  }

  Component {
    id: captureTile
    CapturePanel {
      capture: root.service ? root.service.capture : null
      recording: root.service ? root.service.recording : null
      foreground: root.foreground
      fontFamily: root.fontFamily
    }
  }

  Component {
    id: statsTile
    StatsPanel {
      stats: root.service ? root.service.stats : null
      foreground: root.foreground
      fontFamily: root.fontFamily
    }
  }

  Component {
    id: powerTile
    PowerPanel {
      power: root.service ? root.service.power : null
      foreground: root.foreground
      fontFamily: root.fontFamily
    }
  }

  Component {
    id: actionsTile
    ActionsPanel {
      actions: root.config.actions || []
      service: root.service
      foreground: root.foreground
      fontFamily: root.fontFamily
    }
  }

  Component {
    id: hyprTile
    HyprPanel {
      hypr: root.service ? root.service.hypr : null
      foreground: root.foreground
      fontFamily: root.fontFamily
    }
  }
}
