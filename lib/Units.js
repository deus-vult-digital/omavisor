.pragma library

// Parsing for the Failed units module (SPEC.md section 7, v1).

// `systemctl [--user] --failed --no-legend --plain` lines, "unit load
// active sub description…", as [{ unit, description }]. An older systemctl
// without --plain prints a "●" first; it is skipped.
function parse(text) {
  var out = []
  var lines = String(text || "").split("\n")
  for (let i = 0; i < lines.length; i++) {
    var f = lines[i].trim().replace(/^[●*×]\s*/, "").split(/\s+/)
    if (f.length < 1 || f[0] === "" || f[0].indexOf(".") < 1) continue
    out.push({ unit: f[0], description: f.slice(4).join(" ") })
  }
  return out
}

// The command line (for the floating terminal's `bash -c`) that shows a
// unit's journal for this boot, at its end. `quote` is Format.shellQuote.
function journalCommand(unit, user, quote) {
  return "journalctl -b -e " + (user ? "--user-unit " : "-u ") + quote(unit)
}

// A stable key for a failed set, so the badge is pushed again only when
// it changes.
function key(system, user) {
  return system.map(function(u) { return u.unit }).join(",") + "|" + user.map(function(u) { return u.unit }).join(",")
}
