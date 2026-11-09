.pragma library

// Hyprland strip logic (SPEC.md section 7, v1). Pure, so it is unit-tested
// without a compositor.

// What a workspace is called: its name when it has one of its own
// ("special:magic" → "magic"), else its number.
function workspaceLabel(id, name) {
  var n = String(name || "")
  if (n.indexOf("special:") === 0) n = n.slice(8)
  if (n !== "" && n !== String(id)) return n
  return id === undefined || id === null || id === "" ? "" : String(id)
}

// Hyprland 0.56 with the Lua config takes Lua dispatchers: the stock
// Workspaces widget focuses with hl.dsp.focus({ workspace = "<id>" }).
// A wheel notch up (positive delta) goes to the previous workspace, like
// the pill's scroll.
function scrollTarget(notches) {
  return notches > 0 ? "e-1" : "e+1"
}

function focusDispatch(target) {
  return "hl.dsp.focus({ workspace = \"" + String(target).replace(/["\\]/g, "") + "\" })"
}

// Wheel deltas add up to whole notches (120 each). Returns
// { notches, accum }: notches is -1, 0 or 1, accum what is carried over.
function wheel(accum, delta) {
  var a = Number(accum) || 0
  var d = Number(delta) || 0
  if (d === 0) return { notches: 0, accum: a }
  if (a !== 0 && (a > 0) !== (d > 0)) a = 0
  a += d
  if (Math.abs(a) < 120) return { notches: 0, accum: a }
  return { notches: a > 0 ? 1 : -1, accum: 0 }
}

// The window line: its title, else its class; the class as the dim detail
// when there is a title.
function windowTitle(title, appClass) {
  var t = String(title || "").trim()
  return t !== "" ? t : String(appClass || "").trim()
}

// Tiled layout of a workspace (`tiledLayout` in hyprctl's JSON; Omarchy
// toggles it between dwindle and scrolling).
function layoutLabel(layout) {
  var l = String(layout || "")
  if (l === "") return ""
  return l.charAt(0).toUpperCase() + l.slice(1)
}

// The glyph Omarchy's own layout toggle notifies with.
var layoutGlyph = "󱂬"
