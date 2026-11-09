.pragma library

// Live activities: validation, upsert, expiry and ordering (SPEC.md section 8).
//
// Pure functions over a plain store object, so the service owns the only
// instance and every rule here is unit-tested without a shell. Times are
// milliseconds passed in by the caller (`now`), never read from the clock.
//
// Validation is strict on what a field means and lenient on how long it is:
// a wrong type, an unknown state/priority or a bad id rejects the activity
// with an error string; over-long text is clamped. Keys outside the schema
// are dropped, so a newer sender's extra fields never break an older Omavisor.

var MAX_ACTIVITIES = 20
var END_SHOW_MS = 3000
var DEFAULT_TTL = 3600
var MAX_TTL = 86400
var MIN_RENDER_MS = 100 // at most 10 renders per second

var LIMITS = { id: 64, source: 32, title: 80, subtitle: 120, glyph: 4, compact: 24, label: 24, argv: 64, arg: 4096 }
var STATES = ["running", "waiting", "success", "error"]
var PRIORITIES = ["low", "normal", "urgent"]
var ID_PATTERN = /^[A-Za-z0-9:._-]+$/

// `items` has no prototype, so ids like "__proto__" or "toString" are
// plain keys.
function create() {
  return { items: Object.create(null), seq: 0 }
}

function isObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value)
}

// Clamp by code points, so a Nerd Font glyph (outside the BMP) is never cut
// in half.
// (QML's Array.from splits strings by UTF-16 unit, so walk them by hand.)
function clampText(value, max) {
  var text = String(value)
  var end = 0
  for (let n = 0; n < max && end < text.length; n++) {
    var c = text.charCodeAt(end)
    end += c >= 0xD800 && c <= 0xDBFF && end + 1 < text.length ? 2 : 1
  }
  return text.slice(0, end)
}

// Rich text is never wanted from a sender: drop what Qt's AutoText would
// read as markup in short fields that end up in glyph-style labels.
function plain(text) {
  return String(text).replace(/[<>&]/g, "")
}

function validId(id) {
  return typeof id === "string" && id.length > 0 && id.length <= LIMITS.id && ID_PATTERN.test(id)
}

// Parse a JSON string (or take an object) into a validated activity.
// Returns { activity } or { error }.
function parse(input) {
  var data = input
  if (typeof input === "string") {
    try { data = JSON.parse(input) } catch (e) { return { error: "invalid JSON" } }
  }
  return validate(data)
}

function validate(data) {
  if (!isObject(data)) return { error: "activity must be a JSON object" }
  var out = {}

  if (!validId(data.id)) return { error: "id must be 1-" + LIMITS.id + " characters of A-Z a-z 0-9 : . _ -" }
  out.id = data.id

  if (typeof data.title !== "string" || data.title.trim() === "") return { error: "title is required" }
  out.title = clampText(data.title, LIMITS.title)

  var texts = ["source", "subtitle", "glyph"]
  for (let i = 0; i < texts.length; i++) {
    var key = texts[i]
    var value = data[key]
    if (value === undefined || value === null) { out[key] = ""; continue }
    if (typeof value !== "string") return { error: key + " must be a string" }
    out[key] = clampText(key === "glyph" ? plain(value) : value, LIMITS[key])
  }

  var state = data.state === undefined || data.state === null ? "running" : data.state
  if (STATES.indexOf(state) < 0) return { error: "state must be one of " + STATES.join(", ") }
  out.state = state

  var priority = data.priority === undefined || data.priority === null ? "normal" : data.priority
  if (PRIORITIES.indexOf(priority) < 0) return { error: "priority must be one of " + PRIORITIES.join(", ") }
  out.priority = priority

  if (data.progress === undefined || data.progress === null) out.progress = null
  else if (typeof data.progress !== "number" || !isFinite(data.progress)) return { error: "progress must be a number from 0 to 1 or null" }
  else out.progress = Math.max(0, Math.min(1, data.progress))

  if (data.ttl === undefined || data.ttl === null) out.ttl = DEFAULT_TTL
  else if (typeof data.ttl !== "number" || !isFinite(data.ttl)) return { error: "ttl must be a number of seconds" }
  else out.ttl = Math.max(1, Math.min(MAX_TTL, Math.round(data.ttl)))

  out.compact = { leading: "", trailing: "" }
  if (data.compact !== undefined && data.compact !== null) {
    if (!isObject(data.compact)) return { error: "compact must be an object" }
    var sides = ["leading", "trailing"]
    for (let s = 0; s < sides.length; s++) {
      var side = data.compact[sides[s]]
      if (side === undefined || side === null) continue
      if (typeof side !== "string") return { error: "compact." + sides[s] + " must be a string" }
      out.compact[sides[s]] = clampText(plain(side), LIMITS.compact)
    }
  }

  out.actions = []
  if (data.actions !== undefined && data.actions !== null) {
    if (!Array.isArray(data.actions)) return { error: "actions must be an array" }
    for (let a = 0; a < data.actions.length && out.actions.length < 3; a++) {
      var action = data.actions[a]
      if (!isObject(action) || typeof action.label !== "string" || action.label.trim() === "")
        return { error: "each action needs a label" }
      // argv only: a shell string is refused, never split or interpreted.
      if (!Array.isArray(action.exec) || action.exec.length === 0 || action.exec.length > LIMITS.argv)
        return { error: "action exec must be a non-empty argv array" }
      var argv = []
      for (let x = 0; x < action.exec.length; x++) {
        if (typeof action.exec[x] !== "string" || action.exec[x].length > LIMITS.arg)
          return { error: "action exec items must be strings" }
        argv.push(action.exec[x])
      }
      if (argv[0] === "") return { error: "action exec needs a program" }
      out.actions.push({ label: clampText(plain(action.label), LIMITS.label), exec: argv })
    }
  }

  return { activity: out }
}

// Fields only Omavisor itself sets (through push's `extra`), never a sender:
// `deadline` (a countdown's end), `since` (a count-up's start, as
// recording), `own` (Omavisor's own activity: its actions run even with
// allowActions off), `quiet` (urgent, but never blooms). They survive
// updates.
var SERVICE_FIELDS = ["deadline", "since", "own", "quiet"]

// Create or replace by id. `extra` holds service-only fields that callers
// cannot send. Returns { id } or { error }.
function push(store, input, now, extra) {
  var result = parse(input)
  if (result.error) return result
  var existing = store.items[result.activity.id]
  if (existing && existing.own === true && !(extra && extra.own === true))
    return { error: result.activity.id + " belongs to Omavisor" }
  var item = result.activity
  item.createdAt = now
  item.updatedAt = now
  item.seq = ++store.seq
  item.endsAt = 0
  if (extra) for (let k in extra) item[k] = extra[k]
  store.items[item.id] = item
  evict(store, item.id)
  return { id: item.id }
}

// Shallow-merge `patch` into a live activity and validate the result.
// Returns "ok", "unknown" or an error string.
function update(store, id, patch, now) {
  var item = store.items[id]
  // An ending activity is already gone for its sender: a late update does
  // not bring it back.
  if (!item || item.endsAt > 0) return "unknown"
  // Omavisor's own activities (recording, update, timers) are Omavisor's to
  // change: an update could otherwise swap in actions that run as Omavisor's.
  if (item.own === true) return "error: " + id + " belongs to Omavisor"
  var data = patch
  if (typeof patch === "string") {
    try { data = JSON.parse(patch) } catch (e) { return "error: invalid JSON" }
  }
  if (!isObject(data)) return "error: patch must be a JSON object"
  if (data.id !== undefined && data.id !== id) return "error: id cannot change"

  var merged = {}
  for (let k in item) merged[k] = item[k]
  for (let p in data) merged[p] = data[p]
  var result = validate(merged)
  if (result.error) return "error: " + result.error

  var next = result.activity
  next.createdAt = item.createdAt
  next.updatedAt = now
  next.seq = ++store.seq
  next.endsAt = 0
  for (let f = 0; f < SERVICE_FIELDS.length; f++)
    if (item[SERVICE_FIELDS[f]] !== undefined) next[SERVICE_FIELDS[f]] = item[SERVICE_FIELDS[f]]
  store.items[id] = next
  return "ok"
}

function rank(item) {
  if (item.endsAt > 0) return 0
  if (item.priority === "urgent") return 4
  if (item.state === "waiting") return 3
  if (item.state === "running") return 2
  return 1
}

// urgent > waiting > running > others (ended last), then most recent.
function sorted(store) {
  var list = []
  for (let id in store.items) list.push(store.items[id])
  list.sort(function(a, b) {
    var r = rank(b) - rank(a)
    if (r !== 0) return r
    if (b.updatedAt !== a.updatedAt) return b.updatedAt - a.updatedAt
    return b.seq - a.seq
  })
  return list
}

// The activity `end top` refers to: the first live one that is not
// Omavisor's own (the pill's peek uses the first of `sorted`, own included).
function top(store) {
  var list = sorted(store)
  // Omavisor's own (REC, timers, update) are not a sender's to end.
  for (let i = 0; i < list.length; i++) if (list[i].endsAt === 0 && list[i].own !== true) return list[i]
  return null
}

// Show the result state for END_SHOW_MS, then expire() removes it.
// `result` is "success", "error" or empty (error stays error, else success).
// Returns "ok", "unknown" or an error string.
function end(store, id, result, now) {
  var item = id === "top" ? top(store) : store.items[id]
  if (!item) return "unknown"
  var state = result ? String(result) : (item.state === "error" ? "error" : "success")
  if (state !== "success" && state !== "error") return "error: result must be success or error"
  if (item.endsAt > 0) return "ok"
  item.state = state
  if (state === "success" && item.progress !== null) item.progress = 1
  item.endsAt = now + END_SHOW_MS
  item.updatedAt = now
  item.seq = ++store.seq
  return "ok"
}

// Remove at once, without the result state (the UI's dismiss).
function remove(store, id) {
  if (!store.items[id]) return "unknown"
  delete store.items[id]
  return "ok"
}

// Remove ended and timed-out activities and finish due countdowns.
// Returns { removed: [ids], finished: [ids] }.
function expire(store, now) {
  var removed = []
  var finished = []
  for (let id in store.items) {
    var item = store.items[id]
    // A due countdown finishes before its ttl is checked, so a timer as
    // long as the ttl allows still ends with "Done".
    if (item.deadline > 0 && item.deadline <= now && item.endsAt === 0 && item.state === "running") {
      item.state = "success"
      item.progress = 1
      item.compact = { leading: item.compact.leading, trailing: "Done" }
      // A finished timer stays a minute as "Done", then times out.
      item.ttl = 60
      item.updatedAt = now
      item.seq = ++store.seq
      finished.push(id)
    } else if (item.endsAt > 0 ? item.endsAt <= now : item.updatedAt + item.ttl * 1000 <= now) {
      delete store.items[id]
      removed.push(id)
    }
  }
  return { removed: removed, finished: finished }
}

// When expire() next has work, or 0 when nothing is pending.
function nextDeadline(store) {
  var next = 0
  for (let id in store.items) {
    var item = store.items[id]
    var due = item.endsAt > 0 ? item.endsAt : item.updatedAt + item.ttl * 1000
    if (item.deadline > 0 && item.endsAt === 0 && item.state === "running") due = Math.min(due, item.deadline)
    if (next === 0 || due < next) next = due
  }
  return next
}

function count(store) {
  return Object.keys(store.items).length
}

// Over MAX_ACTIVITIES: drop the lowest-priority, longest-untouched ones.
// Ended ones go first, urgent last; the one just pushed (`keep`) goes only
// when everything else outranks it.
function evict(store, keep) {
  var weight = { low: 0, normal: 1, urgent: 2 }
  // Omavisor's own (timers, REC, update) go only when nothing else is left:
  // dropping a timer's activity would cancel the timer.
  function w(item) { return item.endsAt > 0 ? -1 : item.own === true ? 3 : weight[item.priority] }
  // Whether `a` should go before `b`.
  function first(a, b) {
    if (w(a) !== w(b)) return w(a) < w(b)
    if ((a.id === keep) !== (b.id === keep)) return b.id === keep
    if (a.updatedAt !== b.updatedAt) return a.updatedAt < b.updatedAt
    return a.seq < b.seq
  }
  while (count(store) > MAX_ACTIVITIES) {
    var victim = null
    for (let id in store.items)
      if (!victim || first(store.items[id], victim)) victim = store.items[id]
    delete store.items[victim.id]
  }
}

// Plain copies for `list` and for the UI, so bindings never hold the
// store's own objects.
function snapshot(store) {
  return JSON.parse(JSON.stringify(sorted(store)))
}

// Render coalescing: how long to wait before the next render, given when
// the last one ran. 0 means render now.
function renderDelay(lastRenderAt, now) {
  var since = now - lastRenderAt
  return since >= MIN_RENDER_MS ? 0 : MIN_RENDER_MS - since
}

// "12:34" / "1:02:03" left until a countdown deadline.
function countdownText(deadline, now) {
  return clockText(Math.ceil((deadline - now) / 1000))
}

// "3:12" / "1:02:03" since a count-up started (whole seconds passed).
function elapsedText(since, now) {
  return clockText(Math.floor((now - since) / 1000))
}

function clockText(seconds) {
  var left = Math.max(0, seconds)
  var h = Math.floor(left / 3600)
  var m = Math.floor((left % 3600) / 60)
  var s = left % 60
  var mm = (h > 0 && m < 10 ? "0" : "") + m
  return (h > 0 ? h + ":" : "") + mm + ":" + (s < 10 ? "0" : "") + s
}

// The short text on an activity's trailing side: its own compact.trailing,
// else a countdown or count-up, else its progress as a percentage.
function trailingText(item, now) {
  if (!item) return ""
  if (item.compact && item.compact.trailing) return item.compact.trailing
  if (item.deadline > 0 && item.endsAt === 0 && item.state === "running") return countdownText(item.deadline, now)
  if (item.since > 0 && item.endsAt === 0 && item.state === "running") return elapsedText(item.since, now)
  if (item.progress !== null && item.progress !== undefined) return Math.round(item.progress * 100) + "%"
  return ""
}

// The leading glyph: compact.leading, else glyph, else one for the state.
function leadingGlyph(item) {
  if (!item) return ""
  if (item.compact && item.compact.leading) return item.compact.leading
  if (item.glyph) return item.glyph
  return stateGlyph(item.state)
}

function stateGlyph(state) {
  switch (state) {
  case "waiting": return "󰔟"
  case "success": return "󰄬"
  case "error": return "󰅖"
  }
  return "󰐊"
}

// Whether the activity's trailing text is a live counter (down or up).
function isCounting(item) {
  return !!item && (item.deadline > 0 || item.since > 0) && item.endsAt === 0 && item.state === "running"
    && !(item.compact && item.compact.trailing)
}

// Whether the UI needs a once-a-second tick to keep countdowns current.
function hasCountdown(items) {
  for (let i = 0; i < items.length; i++) if (isCounting(items[i])) return true
  return false
}

// Whether the pill's badge pulses: something urgent waits for the user (a
// coding agent's permission prompt) and has not ended.
function isPulsing(item) {
  return !!item && item.state === "waiting" && item.priority === "urgent" && item.endsAt === 0
}
