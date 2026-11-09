import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Previous, play or pause, next: under the art in the Now playing view, at
// the foot of the Home media tile (`compact`: smaller).
Row {
  id: root

  property var media: null
  property bool compact: false
  property color foreground: Commons.Color.foreground
  property string fontFamily: Style.font.family
  readonly property bool hasMedia: !!media && media.available

  spacing: root.compact ? Style.spacing.sm : Style.spacing.lg

  PanelActionButton {
    focusable: true
    anchors.verticalCenter: parent.verticalCenter
    iconText: "󰒮"
    tooltipText: "Previous"
    foreground: root.foreground
    fontFamily: root.fontFamily
    fontSize: root.compact ? Style.font.icon : Style.font.iconLarge
    enabled: root.hasMedia && root.media.canPrevious
    Accessible.role: Accessible.Button
    Accessible.name: "Previous track"
    onClicked: root.media.previous()
  }

  PanelActionButton {
    // Where the hub's keys land on this tab.
    readonly property bool keyStart: true
    focusable: true
    anchors.verticalCenter: parent.verticalCenter
    iconText: root.hasMedia && root.media.playing ? "󰏤" : "󰐊"
    tooltipText: root.hasMedia && root.media.playing ? "Pause" : "Play"
    foreground: root.foreground
    fontFamily: root.fontFamily
    fontSize: root.compact ? Style.font.iconLarge : Style.font.display
    enabled: root.hasMedia && root.media.canPlayPause
    Accessible.role: Accessible.Button
    Accessible.name: tooltipText
    onClicked: root.media.playPause()
  }

  PanelActionButton {
    focusable: true
    anchors.verticalCenter: parent.verticalCenter
    iconText: "󰒭"
    tooltipText: "Next"
    foreground: root.foreground
    fontFamily: root.fontFamily
    fontSize: root.compact ? Style.font.icon : Style.font.iconLarge
    enabled: root.hasMedia && root.media.canNext
    Accessible.role: Accessible.Button
    Accessible.name: "Next track"
    onClicked: root.media.next()
  }
}
