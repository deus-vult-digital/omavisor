.pragma library

// Parsing for the system modules' command output (SPEC.md section 7), kept
// pure so it is unit-tested without the commands.

// `omarchy-update-available` prints one line per update when it exits 0:
// "omarchy 4.0.6-1 -> 4.0.7-1", or for a dev checkout
// "omarchy-dev-checkout 3 new commits on origin/dev". A short label for the
// tile: the new version, else the commit count, else "Available".
function updateLabel(output) {
  var lines = String(output || "").split("\n")
  for (let i = 0; i < lines.length; i++) {
    var line = lines[i].trim()
    var arrow = line.match(/->\s*(\S+)\s*$/)
    if (arrow) return arrow[1]
  }
  for (let j = 0; j < lines.length; j++) {
    var commits = lines[j].match(/(\d+) new commits?/)
    if (commits) return commits[1] + (commits[1] === "1" ? " commit" : " commits")
  }
  return "Available"
}

// A boolean field of a JSON status line (`omarchy-toggle-nightlight
// --status`, `omarchy-toggle-idle status`), or null when it is not there.
function jsonFlag(text, key) {
  var data
  try { data = JSON.parse(String(text || "").trim()) } catch (e) { return null }
  if (!data || typeof data !== "object") return null
  return typeof data[key] === "boolean" ? data[key] : null
}

// `omarchy-shell notifications dndState` answers "on" or "off".
function dndFlag(text) {
  var value = String(text || "").trim()
  return value === "on" ? true : value === "off" ? false : null
}

// The first line of a file holding a path (Omarchy's screen recording
// writes the file it records to), or "" when it holds none.
function pathLine(text) {
  var line = String(text || "").split("\n")[0].trim()
  return line.charAt(0) === "/" ? line : ""
}
