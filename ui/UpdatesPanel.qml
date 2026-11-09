import QtQuick
import Quickshell
import qs.Commons
import qs.Commons as Commons
import "../lib/Format.js" as Format
import "../lib/Packages.js" as Packages

// Omarchy update state and pending packages: up to date, the new version,
// or how many packages wait, with an Update button that opens Omarchy's
// updater in a floating terminal (and an AUR one for AUR-only updates).
// Either module may be missing; the panel shows what the other knows.
Item {
  id: root

  property var updates: null
  property var packages: null
  property real nowMs: Date.now()
  property color foreground: Commons.Color.foreground
  property string fontFamily: Style.font.family

  readonly property bool omarchy: !!updates && updates.available
  readonly property bool pending: omarchy && updates.updateAvailable
  readonly property bool pkgs: !!packages && packages.available
  readonly property int repo: pkgs ? Math.max(0, packages.repo) : 0
  readonly property int aur: pkgs ? Math.max(0, packages.aur) : 0
  readonly property bool checked: (omarchy && updates.checkedAt > 0) || (pkgs && packages.checkedAt > 0)
  readonly property bool checking: (omarchy && updates.checking) || (pkgs && packages.checking)
  readonly property real checkedAt: Math.max(omarchy ? updates.checkedAt : 0, pkgs ? packages.checkedAt : 0)
  // nowMs only ticks while a countdown shows; the age needs minutes.
  SystemClock { id: minute; precision: SystemClock.Minutes }
  readonly property real ageNow: Math.max(nowMs, minute.date.getTime())

  readonly property string pkgLine: {
    if (!pkgs) return ""
    var parts = []
    if (packages.repoAvailable && packages.repo >= 0) parts.push(Packages.label(packages.repo, "package"))
    if (packages.aurAvailable && packages.aur >= 0) parts.push(packages.aur + " AUR")
    return parts.join("  ·  ")
  }

  Readout {
    glyph: root.pending || root.repo + root.aur > 0 ? "󰚰" : "󰄬"
    value: root.pending ? root.updates.label
      : root.repo + root.aur > 0 ? Packages.label(root.repo + root.aur, "package")
      : root.checked ? "Up to date" : root.checking ? "Checking…" : "Not checked yet"
    detail: [
      (root.pending ? "Omarchy update" : root.omarchy ? "Omarchy" : "Packages")
        + (root.checked ? "  ·  checked " + Format.age(root.checkedAt, root.ageNow) : ""),
      root.repo + root.aur > 0 ? root.pkgLine : ""
    ].filter(function(s) { return s !== "" }).join("\n")
    foreground: root.foreground
    fontFamily: root.fontFamily
  }

  ChipGrid {
    anchors.bottom: parent.bottom
    width: parent.width
    readonly property bool update: root.pending || root.repo > 0
    visible: update || root.aur > 0
    cols: options.length
    // `omarchy update` updates the AUR too, so the AUR button shows only
    // when nothing else waits.
    options: update
      ? [{ key: "update", icon: "󰚰", label: "Update", tooltip: root.pending ? "Update Omarchy" : "Update packages" }]
      : [{ key: "aur", icon: "󰚰", label: "Update AUR", tooltip: "Update AUR packages" }]
    foreground: root.foreground
    fontFamily: root.fontFamily
    onPicked: function(key) {
      if (key === "aur") root.packages.runAurUpdate()
      else if (root.omarchy) root.updates.runUpdate()
      else root.packages.runUpdate()
    }
  }
}
