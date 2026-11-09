import QtQuick
import qs.Commons
import qs.Commons as Commons
import ".."

// Now playing: the art with the transport under it on the left; title and
// artist, the wave display (Visualizer, its style a click away) and the
// scrubber on the right. Volume is a scroll on the pill. With no player it
// says so instead.
Item {
  id: root

  property color foreground: Commons.Color.foreground
  property string fontFamily: Style.font.family
  property date now: new Date()
  property QtObject bar: null
  property var media: null
  // The wave's levels (VisualizerModule), and where its style is kept.
  property var visualizer: null
  property var config: ({})
  property var editor: null

  readonly property bool hasMedia: !!media && media.available

  // Position is polled only while a scrubber is on screen.
  readonly property bool watching: visible && hasMedia
  onWatchingChanged: {
    if (media) media.watchers += watching ? 1 : -1
    if (visualizer) visualizer.watchers += watching ? 1 : -1
  }
  Component.onDestruction: if (watching) {
    if (media) media.watchers -= 1
    if (visualizer) visualizer.watchers -= 1
  }

  Readout {
    visible: !root.hasMedia
    anchors.verticalCenter: parent.verticalCenter
    glyph: "󰝚"
    value: "Nothing playing"
    detail: "Play something in Spotify, a browser or mpv"
    foreground: root.foreground
    fontFamily: root.fontFamily
  }

  Row {
    visible: root.hasMedia
    anchors.fill: parent
    spacing: Style.spacing.panelGap * 2

    Column {
      id: artColumn
      readonly property real side: Math.max(0, parent.height - transport.height - spacing)
      width: side
      height: parent.height
      spacing: Style.spacing.md

      AlbumArt {
        width: artColumn.side
        height: artColumn.side
        source: root.hasMedia ? root.media.artUrl : ""
        foreground: root.foreground
        fontFamily: root.fontFamily
      }

      Transport {
        id: transport
        anchors.horizontalCenter: parent.horizontalCenter
        media: root.media
        foreground: root.foreground
        fontFamily: root.fontFamily
      }
    }

    Item {
      width: parent.width - artColumn.width - parent.spacing
      height: parent.height

      NowPlaying {
        id: nowPlaying
        anchors.fill: parent
        showTransport: false
        media: root.media
        bar: root.bar
        foreground: root.foreground
        fontFamily: root.fontFamily
      }

      Visualizer {
        readonly property real gap: Style.spacing.lg
        y: nowPlaying.infoHeight + gap
        width: parent.width
        height: Math.max(0, parent.height - nowPlaying.infoHeight - nowPlaying.controlsHeight - gap * 2)
        levels: root.visualizer ? root.visualizer.levels : []
        playing: root.hasMedia && root.media.playing
        style: root.config ? root.config.visualizerStyle : "bars"
        foreground: root.foreground
        onStylePicked: function(style) { if (root.editor) root.editor.change({ visualizerStyle: style }) }
      }
    }
  }
}
