.pragma library

// Parsing for DictationModule (SPEC.md section 7, v1): which dictation
// backend to follow, its status lines and the activity they become. Pure, so
// it is unit-tested.

// The backends Omavisor can follow. Omarchy 4.5 picks one with
// `omarchy default dictation` (voxtype or superwhisper); both print one
// waybar-style JSON line per state change.
var BACKENDS = {
  voxtype: {
    label: "Voxtype",
    // `omarchy voxtype status` ran this until Omarchy 4.5 removed it.
    follow: ["voxtype", "status", "--follow", "--extended", "--format", "json"],
    stop: ["voxtype", "record", "stop"],
    cancel: ["voxtype", "record", "cancel"],
    // How its microphone reader is named in PipeWire ("alsa_capture.voxtype-avx2").
    capture: ["voxtype"]
  },
  superwhisper: {
    label: "Superwhisper",
    // Reports a stopped service as "stopped" rather than starting it.
    follow: ["superwhisper", "status", "--bar", "--follow", "--extended"],
    stop: ["superwhisper", "stop"],
    cancel: ["superwhisper", "cancel"],
    // "superwhisper-capture", and "superwhisper-prewarm" while it keeps the
    // microphone ready.
    capture: ["superwhisper"]
  }
}

function backend(name) {
  return BACKENDS.hasOwnProperty(name) ? BACKENDS[name] : null
}

// The detect probe's output: "default=<name>" (from `omarchy default
// dictation`, empty before 4.5 or when none is set), then one line per
// installed backend. The configured default when it is installed, else
// superwhisper, else voxtype, else "".
function pickBackend(text) {
  var lines = String(text || "").split("\n")
  var wanted = ""
  var installed = {}
  for (let i = 0; i < lines.length; i++) {
    var line = lines[i].trim()
    if (line.indexOf("default=") === 0) wanted = line.slice(8)
    else if (BACKENDS.hasOwnProperty(line)) installed[line] = true
  }
  if (installed[wanted]) return wanted
  if (installed.superwhisper) return "superwhisper"
  if (installed.voxtype) return "voxtype"
  return ""
}

// One status line, e.g. voxtype 1.1.1's
//   {"text":"🎤","alt":"recording","class":"recording","tooltip":"Recording...\nModel: base.en…",
//    "model":"base.en","device":"default","backend":"CPU (AVX2)"}
// or Superwhisper's
//   {"text":"󰍬","alt":"idle","class":"idle","tooltip":"…","model":"Offline","device":"System default"}
// `alt` and `class` carry the state: idle, recording, transcribing, stopped,
// and loading/warming/meeting/paused/error. Null for a line that is not such
// an object.
function barStatus(line) {
  var data
  try { data = JSON.parse(String(line || "").trim()) } catch (e) { return null }
  if (!data || typeof data !== "object" || Array.isArray(data)) return null
  var state = String(data.alt || data["class"] || "idle").toLowerCase()
  if (!/^[a-z_-]{1,24}$/.test(state)) state = "idle"
  return {
    state: state,
    model: typeof data.model === "string" ? data.model : "",
    device: typeof data.device === "string" ? data.device : ""
  }
}

// The name before Superwhisper support.
function voxtypeStatus(line) { return barStatus(line) }

// The activity Omavisor shows for a dictation state, or null when nothing
// should show (idle, stopped, unknown). `status.backend` defaults to voxtype.
function dictationActivity(status) {
  if (!status) return null
  var b = backend(status.backend || "voxtype")
  if (!b) return null
  var detail = status.model ? b.label + " · " + status.model : b.label
  if (status.state === "recording") {
    return {
      id: "omavisor:dictation", source: "omavisor", title: "Listening", subtitle: detail,
      glyph: "󰍬", state: "running", priority: "urgent", ttl: 3600,
      compact: { leading: "󰍬", trailing: "" },
      actions: [
        { label: "Stop", exec: b.stop.slice() },
        { label: "Cancel", exec: b.cancel.slice() }
      ]
    }
  }
  if (status.state === "transcribing") {
    return {
      id: "omavisor:dictation", source: "omavisor", title: "Transcribing", subtitle: detail,
      glyph: "󰔟", state: "running", progress: null, priority: "urgent", ttl: 600,
      compact: { leading: "󰔟", trailing: "" },
      actions: [{ label: "Cancel", exec: b.cancel.slice() }]
    }
  }
  return null
}
