.pragma library

// Parsing for PrivacyModule (SPEC.md section 7, v1): which apps read the
// microphone or a camera. Pure, so it is unit-tested without Pipewire.

// One Pipewire link, flattened by the module to plain values:
//   { sourceType, targetType, sourceStream, targetStream, app, name, binary }
// where the types are PwNodeType flag strings ("AudioSource",
// "AudioInStream", "VideoSource", …) and app/name/binary are the target
// stream's application.name, node.name and application.process.binary.
// What it captures: "mic", "camera" or "" (not a capture link, or one of
// the excluded readers: Quickshell's own peak meters, pavucontrol-style
// "Peak detect" monitors, and any reader whose names contain a word in
// `skip`: voxtype reads through ALSA as "alsa_capture.voxtype-avx2",
// "PipeWire ALSA [voxtype-avx2]").
function captureKind(link, skip) {
  if (!link || !link.targetStream || link.sourceStream) return ""
  var src = String(link.sourceType || "")
  var kind = src.indexOf("AudioSource") !== -1 || src.indexOf("AudioDuplex") !== -1 ? "mic"
    : src.indexOf("VideoSource") !== -1 ? "camera" : ""
  if (kind === "") return ""
  var who = (String(link.app || "") + " " + String(link.name || "") + " " + String(link.binary || "")).toLowerCase()
  if (/quickshell|peak detect/.test(who)) return ""
  for (let i = 0; i < (skip || []).length; i++) if (who.indexOf(String(skip[i]).toLowerCase()) !== -1) return ""
  return kind
}

// The readers of each kind, by display name, deduplicated and sorted.
function captureApps(links, skip) {
  var mic = {}, camera = {}
  for (let i = 0; i < (links || []).length; i++) {
    var l = links[i]
    var kind = captureKind(l, skip)
    if (kind === "") continue
    var label = appLabel(l)
    if (kind === "mic") mic[label] = true
    else camera[label] = true
  }
  return { mic: Object.keys(mic).sort(), camera: Object.keys(camera).sort() }
}

// An app reading through the ALSA plugin is "PipeWire ALSA [<binary>]".
function appLabel(link) {
  var label = String(link.app || link.binary || link.name || "").trim()
  var alsa = label.match(/^PipeWire ALSA \[(.+)\]$/)
  if (alsa) label = alsa[1]
  return label === "" ? "An app" : clampText(label, 32)
}

// `fuser` on the video devices, piped through `ps -o pid=,comm=`: one
// "<pid> <comm>" per line. The processes holding a camera, minus Pipewire's
// own (their readers show up as links instead).
function videoHolders(text) {
  var names = {}
  var lines = String(text || "").split("\n")
  for (let i = 0; i < lines.length; i++) {
    var m = lines[i].trim().match(/^(\d+)\s+(.+)$/)
    if (!m) continue
    var comm = m[2].trim()
    if (/^(pipewire|wireplumber|pipewire-pulse)$/.test(comm)) continue
    names[clampText(comm, 32)] = true
  }
  return Object.keys(names).sort()
}

// The activity for one capture kind and its readers, or null when unused.
function privacyActivity(kind, apps) {
  if (!apps || apps.length === 0) return null
  var mic = kind === "mic"
  return {
    id: mic ? "omavisor:mic" : "omavisor:camera",
    source: "omavisor",
    title: mic ? "Microphone in use" : "Camera in use",
    subtitle: apps.join(", "),
    glyph: mic ? "󰍬" : "󰄀",
    state: "running",
    priority: "normal",
    ttl: 86400,
    compact: { leading: mic ? "󰍬" : "󰄀", trailing: "" }
  }
}

function clampText(value, max) {
  if (typeof value !== "string") return ""
  var s = value.replace(/[\r\n\t]+/g, " ").trim()
  var cps = Array.from(s)
  return cps.length > max ? cps.slice(0, max - 1).join("") + "…" : s
}
