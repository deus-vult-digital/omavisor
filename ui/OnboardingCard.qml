import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// The bar-layout card (SPEC.md section 9): on first run it offers to
// replace the stock clock and weather (or keep them, wrap mode); when the
// bar's center widget is not the one the last replace or restore set (a
// failed edit, no jq, or changed since) it offers to set it (Set it) or
// shows the edit to make by hand; and it says when a run failed. Nothing
// changes without a click.
// Two tiles: what and why on the left, the buttons on the right.
TileRow {
  id: root

  property var layout: null
  property color foreground: Commons.Color.foreground
  property string fontFamily: Style.font.family

  readonly property string stage: layout ? layout.stage : ""
  // The widget the one-liner centers the bar on.
  readonly property string anchorName: !layout || layout.anchorTarget === undefined ? ""
    : layout.anchorTarget === null ? ""
    : layout.anchorTarget === "omarchy.clock" ? "the clock"
    : layout.anchorTarget === layout.pluginId ? "Omavisor" : layout.anchorTarget

  Tile {
    title: root.stage === "onboarding" ? "Welcome to Omavisor" : "Bar layout"
    foreground: root.foreground
    fontFamily: root.fontFamily

    Readout {
      glyph: root.stage === "failed" ? "󰀦" : root.stage === "anchor" ? "󰁔" : root.stage === "busy" ? "󰔟" : "󰕮"
      value: root.stage === "onboarding" ? "Omavisor as your clock?"
        : root.stage === "busy" ? (root.layout.busy === "restore" ? "Restoring…" : root.layout.busy === "keep" ? "Saving…" : root.layout.busy === "anchor" ? "Centering…" : "Moving widgets…")
        : root.stage === "failed" ? "Did not finish"
        : "One step left"
      detail: root.stage === "onboarding"
        ? "Omavisor can take the place of the clock and weather in the bar's center. Your layout is saved first; Restore puts it back exactly."
        : root.stage === "failed" ? root.layout.message
        : root.stage === "anchor"
          ? (root.anchorName !== "" ? "The bar is not centered on " + root.anchorName + "." : "The bar still has a center widget.")
            + (root.layout.hasJq
              ? " Set it backs up shell.json and edits it for you, or run this yourself."
              : " Omavisor needs jq to edit shell.json; make this change by hand.")
        : ""
      foreground: root.foreground
      fontFamily: root.fontFamily
    }
  }

  Tile {
    title: root.stage !== "anchor" ? "" : root.layout.hasJq ? "Or in a terminal" : "By hand"
    foreground: root.foreground
    fontFamily: root.fontFamily

    Text {
      id: command
      visible: root.stage === "anchor"
      width: parent.width
      textFormat: Text.PlainText
      text: root.layout ? root.layout.anchorCommand : ""
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      wrapMode: Text.WrapAnywhere
      maximumLineCount: 5
      elide: Text.ElideRight
      Accessible.name: "Command: " + text
    }

    // One column of wide buttons for the first-run choice, side by side
    // under the command for the anchor step.
    ChipGrid {
      anchors.bottom: parent.bottom
      width: parent.width
      cols: root.stage === "onboarding" ? 1 : Math.max(1, options.length)
      foreground: root.foreground
      fontFamily: root.fontFamily
      options: root.stage === "onboarding" ? [
          { key: "replace", icon: "󰁯", label: "Replace clock & weather" },
          { key: "keep", icon: "󰄬", label: "Keep them", tooltip: "Keep the clock and weather; Omavisor shows only activities" }
        ]
        : root.stage === "anchor" ? (root.layout.hasJq ? [{ key: "set", icon: "󰁔", label: "Set it", tooltip: "Back up shell.json and set the bar's center widget" }] : [])
          .concat(root.layout.canCopy ? [{ key: "copy", icon: "󰆏", label: "Copy" }] : [])
          .concat([{ key: "skip", icon: "󰅖", label: "Leave it", tooltip: "Keep the center widget as it is; don't ask again" }])
        : root.stage === "failed" ? (root.layout.replaced ? [{ key: "restore", icon: "󰦛", label: "Restore" }] : [])
          .concat([{ key: "dismiss", icon: "󰅖", label: "Dismiss" }])
        : []
      onPicked: function(key) {
        if (!root.layout) return
        if (key === "replace") root.layout.replace()
        else if (key === "keep") root.layout.keep()
        else if (key === "restore") root.layout.restore()
        else if (key === "copy") root.layout.copyAnchorCommand()
        else if (key === "set") root.layout.applyAnchor()
        else if (key === "skip") root.layout.skipAnchor()
        else root.layout.dismiss()
      }
    }
  }
}
