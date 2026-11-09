import QtQuick
import qs.Commons
import qs.Commons as Commons
import "../lib/Power.js" as Power

// Battery level, state, time left and draw, with the power profiles as
// chips (the stock power panel's glyphs). Shown only on a machine with a
// battery (PowerModule.available); profiles are read while it is visible.
Item {
  id: root

  property var power: null
  property color foreground: Commons.Color.foreground
  property string fontFamily: Style.font.family

  readonly property bool watching: visible && !!power
  onWatchingChanged: if (power) power.watchers += watching ? 1 : -1
  Component.onDestruction: if (watching && power) power.watchers -= 1

  Readout {
    glyph: root.power ? root.power.glyph : ""
    value: root.power ? root.power.percent + "%" : ""
    detail: root.power ? root.power.detail : ""
    foreground: root.foreground
    fontFamily: root.fontFamily
  }

  ChipGrid {
    anchors.bottom: parent.bottom
    width: parent.width
    visible: !!root.power && root.power.profiles.length > 0
    cols: Math.max(1, root.power ? root.power.profiles.length : 1)
    iconOnly: true
    options: !root.power ? [] : root.power.profiles.map(function(name) {
      return {
        key: name,
        icon: Power.profileIcon(name),
        label: Power.profileLabel(name),
        tooltip: Power.profileLabel(name) + (name === root.power.activeProfile ? " (active)" : ""),
        active: name === root.power.activeProfile
      }
    })
    foreground: root.foreground
    fontFamily: root.fontFamily
    onPicked: function(key) { root.power.setProfile(key) }
  }
}
