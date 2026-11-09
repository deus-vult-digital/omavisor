.pragma library

// Timers and pomodoro (SPEC.md section 7): pure logic over plain timer
// objects, so the TimerModule only schedules, persists and shows them.
//
// A timer is { id, label, kind, minutes, startedAt, deadline, left }:
// kind "timer" (a plain countdown), "focus" (a pomodoro's work block, which
// starts a break when it ends) or "break". Running: `deadline` is when it
// ends. Paused: `deadline` is 0 and `left` holds the milliseconds that were
// left. `startedAt` is when the current run began, so a restored timer's
// activity keeps its age. Times are epoch ms passed in by the caller.

var PRESETS = [5, 15, 25, 50]
var POMODORO = { focus: 25, rest: 5 }
var MAX_MINUTES = 1440
var KINDS = ["timer", "focus", "break"]
var LABEL_MAX = 40
var ID_PATTERN = /^timer:[A-Za-z0-9._-]{1,48}$/

// A label never starts with a dash, so it is never read as an option by the
// notification command it ends up in.
function cleanLabel(label, kind) {
  var text = String(label === undefined || label === null ? "" : label).replace(/[\r\n\t]+/g, " ").replace(/^[\s-]+/, "").trim()
  if (text.length > LABEL_MAX) text = text.slice(0, LABEL_MAX)
  if (text !== "") return text
  return kind === "focus" ? "Focus" : kind === "break" ? "Break" : "Timer"
}

// Returns { timer } or { error }.
function create(id, minutes, label, kind, now) {
  var m = Number(minutes)
  if (!isFinite(m) || m <= 0 || m > MAX_MINUTES) return { error: "minutes must be more than 0 and at most " + MAX_MINUTES }
  var k = KINDS.indexOf(kind) >= 0 ? kind : "timer"
  if (!ID_PATTERN.test(String(id))) return { error: "bad timer id" }
  return { timer: { id: String(id), label: cleanLabel(label, k), kind: k, minutes: m, startedAt: now,
    deadline: now + Math.round(m * 60000), left: 0 } }
}

function isPaused(t) {
  return !!t && !(t.deadline > 0)
}

// Milliseconds left (0 once due).
function remaining(t, now) {
  if (!t) return 0
  return Math.max(0, isPaused(t) ? t.left : t.deadline - now)
}

function copy(t) {
  var out = {}
  for (let k in t) out[k] = t[k]
  return out
}

function pause(t, now) {
  if (isPaused(t)) return t
  var out = copy(t)
  out.left = remaining(t, now)
  out.deadline = 0
  out.pausedAt = now
  return out
}

function resume(t, now) {
  if (!isPaused(t)) return t
  var out = copy(t)
  out.deadline = now + Math.max(0, t.left)
  out.left = 0
  out.startedAt = now
  return out
}

// "12:34" / "1:02:03" for milliseconds left (rounded up, like a countdown).
function clock(ms) {
  var left = Math.max(0, Math.ceil(ms / 1000))
  var h = Math.floor(left / 3600)
  var m = Math.floor((left % 3600) / 60)
  var s = left % 60
  return (h > 0 ? h + ":" + (m < 10 ? "0" : "") : "") + m + ":" + (s < 10 ? "0" : "") + s
}

function glyph(kind) {
  return kind === "focus" ? "󱎫" : kind === "break" ? "󰾨" : "󱎫"
}

// The live activity that shows a timer: { data, extra, at }, ready for
// ActivitiesModule.push(data, extra, at). Running, the store counts down to
// `deadline` and finishes it there; paused, it shows the frozen time left.
// `at` backdates the push to the run's start (or to `before`, when given
// and earlier), so its ttl covers the run from there.
function activity(t, now, before) {
  var paused = isPaused(t)
  var at = paused ? now : Math.min(now, t.startedAt > 0 ? t.startedAt : now)
  if (before > 0 && before < at) at = before
  var span = paused ? Math.ceil((now - at) / 1000) + 86400 : Math.ceil((t.deadline - at) / 1000) + 60
  return {
    data: {
      id: t.id,
      source: "omavisor",
      title: t.label,
      subtitle: paused ? "Paused" : (t.kind === "focus" ? "Pomodoro" : t.kind === "break" ? "Pomodoro break" : ""),
      glyph: glyph(t.kind),
      state: "running",
      ttl: Math.max(60, Math.min(86400, span)),
      compact: paused ? { leading: "󰏤", trailing: clock(t.left) } : { leading: glyph(t.kind), trailing: "" }
    },
    extra: paused ? { own: true } : { deadline: t.deadline, own: true },
    at: at
  }
}

// What comes after a timer ends: a pomodoro focus block is followed by a
// break (returned as a new timer), anything else by nothing.
function next(t, id, now) {
  if (!t || t.kind !== "focus") return null
  var made = create(id, POMODORO.rest, "Break", "break", now)
  return made.timer || null
}

// [headline, body] for `omarchy notification send`.
function notice(t) {
  if (t.kind === "focus") return ["Focus done", "Time for a " + POMODORO.rest + "-minute break"]
  if (t.kind === "break") return ["Break over", "Ready for the next focus block"]
  return ["Timer done", t.label]
}

// timers.json: { "version": 1, "timers": [...] }.
function serialize(timers) {
  return JSON.stringify({ version: 1, timers: timers }, null, 2) + "\n"
}

// The valid timers in a timers.json text; anything malformed is dropped.
function parse(text) {
  var data
  try { data = JSON.parse(String(text || "")) } catch (e) { return [] }
  var list = data && Array.isArray(data.timers) ? data.timers : []
  var out = []
  var seen = Object.create(null)
  for (let i = 0; i < list.length; i++) {
    var t = list[i]
    if (!t || typeof t !== "object") continue
    if (!ID_PATTERN.test(String(t.id)) || seen[t.id]) continue
    if (KINDS.indexOf(t.kind) < 0) continue
    var m = Number(t.minutes)
    if (!isFinite(m) || m <= 0 || m > MAX_MINUTES) continue
    var deadline = Number(t.deadline) || 0
    var left = Number(t.left) || 0
    if (deadline <= 0 && left <= 0) continue
    seen[t.id] = true
    out.push({ id: String(t.id), label: cleanLabel(t.label, t.kind), kind: t.kind, minutes: m,
      startedAt: Number(t.startedAt) || 0, deadline: deadline > 0 ? deadline : 0,
      left: deadline > 0 ? 0 : Math.min(left, MAX_MINUTES * 60000), pausedAt: Number(t.pausedAt) || 0 })
  }
  return out
}
