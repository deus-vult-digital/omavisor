.pragma library

// The `actions` setting (docs/macnotch-audit.md, shortlist 4): your own
// commands on a Home tile, run as argv, only on a click, never through a
// shell. Pure, so it is unit-tested.
//
// An object from label to argv, which `omarchy bar set … --json` can pass
// (an array argument cannot reach the shell, see SPEC M3 notes), with an
// optional icon:
//   { "Lock": ["omarchy-lock-screen"],
//     "btop": { "argv": ["omarchy-launch-or-focus-tui", "btop"], "icon": "󰍛" } }
// A list of { label, argv, icon } is taken too, for editing shell.json by
// hand. As text when given without --json.

// The tile shows this many; more are kept but not shown.
var SHOWN = 6
var MAX = 24
var LABEL_MAX = 24
var ARG_MAX = 1024
var ARGS_MAX = 64
var DEFAULT_ICON = "󰐊"

function codePoints(text) {
  return String(text).match(/[\uD800-\uDBFF][\uDC00-\uDFFF]|[\s\S]/g) || []
}

function cleanArgv(value) {
  if (!Array.isArray(value) || value.length === 0 || value.length > ARGS_MAX) return null
  var out = []
  for (var i = 0; i < value.length; i++) {
    var arg = value[i]
    if (typeof arg !== "string" || arg.length > ARG_MAX || arg.indexOf("\u0000") !== -1) return null
    out.push(arg)
  }
  return out[0].trim() === "" ? null : out
}

// One action, or null when it is not a usable one.
function entry(label, spec) {
  var name = typeof label === "string" ? label.replace(/\s+/g, " ").trim() : ""
  if (name === "") return null
  var cps = codePoints(name)
  if (cps.length > LABEL_MAX) name = cps.slice(0, LABEL_MAX - 1).join("") + "…"
  var argv = cleanArgv(Array.isArray(spec) ? spec : spec && typeof spec === "object" ? spec.argv : null)
  if (!argv) return null
  var icon = spec && typeof spec === "object" && !Array.isArray(spec) && typeof spec.icon === "string" ? spec.icon.trim() : ""
  if (icon === "" || codePoints(icon).length > 2) icon = DEFAULT_ICON
  return { label: name, argv: argv, icon: icon }
}

// The setting as a list of { label, argv, icon }, in order, labels unique,
// at most MAX. Anything unusable is left out.
function parse(value) {
  var data = value
  if (typeof data === "string") {
    try { data = JSON.parse(data) } catch (e) { return [] }
  }
  var raw = []
  if (Array.isArray(data)) {
    data.forEach(function(item) {
      if (item && typeof item === "object" && !Array.isArray(item)) raw.push([item.label, item])
    })
  } else if (data && typeof data === "object") {
    for (var key in data) raw.push([key, data[key]])
  }
  var out = []
  var seen = {}
  for (var i = 0; i < raw.length && out.length < MAX; i++) {
    var a = entry(raw[i][0], raw[i][1])
    if (!a || seen[a.label]) continue
    seen[a.label] = true
    out.push(a)
  }
  return out
}

// The tile's buttons (ChipGrid options): the first SHOWN, keyed by position.
function chips(actions) {
  return (actions || []).slice(0, SHOWN).map(function(a, i) {
    return { key: String(i), icon: a.icon, label: a.label, tooltip: a.label + ": " + a.argv.join(" ") }
  })
}
