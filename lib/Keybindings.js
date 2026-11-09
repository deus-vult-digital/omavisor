.pragma library

// Parsing for the Keys tab (SPEC.md section 7, v1): `omarchy menu
// keybindings --print` and its search. Pure, so it is unit-tested.

// `omarchy menu keybindings --print`: lines like
//   "SUPER SHIFT + RETURN                → Browser"
// Each becomes { keys, action } (keys with single spaces). Lines without the
// arrow are skipped.
function keybindings(text) {
  var out = []
  var lines = String(text || "").split("\n")
  for (let i = 0; i < lines.length; i++) {
    var line = lines[i]
    var at = line.indexOf("→")
    if (at < 0) continue
    var keys = line.slice(0, at).replace(/\s+/g, " ").trim()
    var action = line.slice(at + 1).trim()
    if (keys === "" || action === "") continue
    out.push({ keys: keys, action: action })
  }
  return out
}

// Bindings whose keys or action contain every word of `query`
// (case-insensitive); all of them for an empty query.
function filterBindings(list, query) {
  var words = String(query || "").toLowerCase().split(/\s+/).filter(function(w) { return w !== "" })
  if (words.length === 0) return list || []
  return (list || []).filter(function(b) {
    var hay = (b.keys + " " + b.action).toLowerCase()
    for (let i = 0; i < words.length; i++) if (hay.indexOf(words[i]) === -1) return false
    return true
  })
}
