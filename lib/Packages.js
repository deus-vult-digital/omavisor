.pragma library

// Parsing for the Pending packages module (SPEC.md section 7, v1).

// How many updates a list command printed: one per non-empty line
// (`checkupdates`: "name 1.0-1 -> 1.1-1"; `yay -Qua`: the same). Lines
// starting with "::" or "error"/"warning" are yay's messages, not packages.
function count(text) {
  var lines = String(text || "").split("\n")
  var n = 0
  for (let i = 0; i < lines.length; i++) {
    var line = lines[i].trim()
    if (line === "" || /^(::|error|warning|==>)/i.test(line)) continue
    n++
  }
  return n
}

// The repo count from checkupdates' exit code and output: exit 0 lists
// updates, exit 2 means none, anything else (1: the sync failed, offline)
// is no answer (-1), so the last count stays.
function repoCount(code, text) {
  if (code === 2) return 0
  if (code === 0) return count(text)
  return -1
}

// The AUR count from `yay -Qua`: it exits 1 both when nothing is out of
// date and when the AUR cannot be reached, so output decides: lines are
// updates; no output and exit 0 or 1 is none; killed (-1) is no answer.
function aurCount(code, text) {
  if (code < 0 || code === 127) return -1
  var n = count(text)
  if (n > 0) return n
  return code === 0 || code === 1 ? 0 : -1
}

// "12 packages", "1 package"
function label(n, noun) {
  return n + " " + noun + (n === 1 ? "" : "s")
}
