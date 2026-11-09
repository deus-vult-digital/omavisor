.pragma library

// Parsing for NotificationsModule (SPEC.md section 7, v1): the shell's
// notification history files. Pure, so it is unit-tested.

// The shell's notification history (~/.local/state/omarchy/notifications/
// history/*.json, one file per notification that has left the screen) read
// as text, one JSON object per line. Internal to Omarchy and undocumented,
// so every field is optional. Only app, summary, glyph, urgency and time are
// kept: never the body, images or execArgv. Newest first, at most `limit`.
function historyEntries(text, limit) {
  var out = []
  var lines = String(text || "").split("\n")
  for (let i = 0; i < lines.length; i++) {
    var line = lines[i].trim()
    if (line === "") continue
    var data
    try { data = JSON.parse(line) } catch (e) { continue }
    if (!data || typeof data !== "object" || Array.isArray(data)) continue
    var summary = clampText(data.summary, 120)
    var app = clampText(data.app, 40)
    if (summary === "" && app === "") continue
    var ts = Number(data.timestamp)
    out.push({
      key: String(isFinite(ts) ? ts : 0) + "-" + String(data.id === undefined ? i : data.id),
      app: app,
      summary: summary,
      glyph: clampText(data.glyph, 4),
      urgency: Number(data.urgency) === 2 ? "critical" : Number(data.urgency) === 0 ? "low" : "normal",
      timestamp: isFinite(ts) && ts > 0 ? ts : 0
    })
  }
  out.sort(function(a, b) { return b.timestamp - a.timestamp })
  var max = limit > 0 ? limit : 10
  return out.length > max ? out.slice(0, max) : out
}

// Omarchy 4.5's store: live.json and history.json each hold one JSON array
// of entries with `ts` in seconds (plugins/notifications/Store.js). Same
// rules as historyEntries: optional fields, only app, summary, glyph, urgency
// and time kept, newest first, at most `limit`.
function storeEntries(text, limit) {
  var data
  try { data = JSON.parse(String(text || "")) } catch (e) { return [] }
  if (!Array.isArray(data)) return []
  var lines = []
  for (let i = 0; i < data.length; i++) {
    var e = data[i]
    if (!e || typeof e !== "object" || Array.isArray(e)) continue
    var ts = Number(e.ts)
    lines.push(JSON.stringify({
      id: typeof e.key === "string" ? e.key : i,
      app: e.app, summary: e.summary, glyph: e.glyph, urgency: e.urgency,
      timestamp: isFinite(ts) && ts > 0 ? Math.round(ts * 1000) : 0
    }))
  }
  return historyEntries(lines.join("\n"), limit)
}

// How many entries are newer than `seenAt` (ms).
function unreadCount(entries, seenAt) {
  var n = 0
  for (let i = 0; i < (entries || []).length; i++) if (entries[i].timestamp > seenAt) n++
  return n
}

function clampText(value, max) {
  if (typeof value !== "string") return ""
  var s = value.replace(/[\r\n\t]+/g, " ").trim()
  var cps = Array.from(s)
  return cps.length > max ? cps.slice(0, max - 1).join("") + "…" : s
}
