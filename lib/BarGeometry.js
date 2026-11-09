.pragma library

// Where the bar's strip is inside the bar's window.
//
// Up to Omarchy 4.0 the bar window was exactly as thick as its strip. From
// 4.5 it spans its whole screen, transparent past the strip, and publishes
// the strip's thickness (a notch floor included) as its exclusive zone
// (Bar.qml: "the reserved area stays the strip's thickness though the window
// spans its screen"). Both cases go through here.

// The strip's thickness in window coordinates: the exclusive zone when the
// window publishes one smaller than itself, else the bar's own barSize when
// that is smaller, else the window's size (the 4.0 window).
function strip(windowSize, exclusiveZone, barSize) {
  var size = Number(windowSize) || 0
  var zone = Number(exclusiveZone) || 0
  var bar = Number(barSize) || 0
  if (zone > 0 && (size <= 0 || zone <= size)) return zone
  if (bar > 0 && (size <= 0 || bar < size)) return bar
  return Math.max(0, size)
}

// How far the bar's inner edge is from the screen edge. A hidden bar is
// parked past the edge with a negative margin (by its strip in 4.0, by the
// whole window in 4.5), so this is then 0 and the hub starts at the screen
// edge.
function innerEdge(stripSize, parkedMargin) {
  return Math.max(0, (Number(stripSize) || 0) + (Number(parkedMargin) || 0))
}

// Where the strip starts across the window, from the window's top or left:
// a bottom or right bar's strip sits at the far side of a window that spans
// its screen.
function stripStart(edge, windowSize, stripSize) {
  if (edge !== "bottom" && edge !== "right") return 0
  return Math.max(0, (Number(windowSize) || 0) - (Number(stripSize) || 0))
}

// The hub's corner radius for the `corners` setting: "square" none, "round"
// the theme's rounding or `roundRadius` on a square theme, "auto" (anything
// else) the theme's rounding, so a square theme gets a square hub.
function hubRadius(corners, themeRadius, roundRadius) {
  var theme = Math.max(0, Number(themeRadius) || 0)
  if (corners === "square") return 0
  if (corners === "round") return theme > 0 ? theme : Math.max(0, Number(roundRadius) || 0)
  return theme
}
