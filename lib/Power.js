.pragma library

// Power module logic (SPEC.md section 7, v1): power profiles from
// `omarchy powerprofiles list --active-state` and the battery readout from
// UPower's display device. Pure, so it is unit-tested without a battery.

// `omarchy battery present` exits 0 only when a battery is there; anything
// else (no battery, the command missing, killed) hides the module.
function present(exitCode) {
  return exitCode === 0
}

// "power-saver\t0\nbalanced\t0\nperformance\t1" → { profiles, active }.
function parseProfiles(text) {
  var profiles = []
  var active = ""
  var lines = String(text || "").split("\n")
  for (let i = 0; i < lines.length; i++) {
    var line = lines[i].trim()
    if (line === "") continue
    var parts = line.split("\t")
    var name = parts[0].trim()
    if (!/^[A-Za-z0-9-]+$/.test(name) || profiles.indexOf(name) !== -1) continue
    profiles.push(name)
    if ((parts[1] || "").trim() === "1") active = name
  }
  return { profiles: profiles, active: active }
}

// The glyphs the stock power panel uses.
function profileIcon(name) {
  if (name === "power-saver") return "󰌪"
  if (name === "balanced") return "󰊚"
  if (name === "performance") return "󰓅"
  return "󰂄"
}

function profileLabel(name) {
  if (name === "power-saver") return "Saver"
  if (name === "balanced") return "Balanced"
  if (name === "performance") return "Performance"
  var s = String(name || "")
  return s.charAt(0).toUpperCase() + s.slice(1)
}

// Which remembered profile `omarchy powerprofiles set` writes: the shell
// keys it by UPower.onBattery.
function source(onBattery) {
  return onBattery ? "battery" : "ac"
}

// UPower's percentage is 0..1 in Quickshell; clamp and round for display.
function percent(fraction) {
  var f = Number(fraction)
  if (!isFinite(f)) return 0
  return Math.round(Math.max(0, Math.min(1, f)) * 100)
}

// The stock panel's battery glyphs: ten levels, a charging set, and full.
function batteryIcon(fraction, charging, full) {
  if (full) return "󰂅"
  var index = Math.max(0, Math.min(9, Math.floor(Math.max(0, Math.min(1, Number(fraction) || 0)) * 10)))
  var chargingIcons = ["󰢜", "󰂆", "󰂇", "󰂈", "󰢝", "󰂉", "󰢞", "󰂊", "󰂋", "󰂅"]
  var defaultIcons = ["󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"]
  return charging ? chargingIcons[index] : defaultIcons[index]
}

// Seconds → "2h 15m", "45m", "" when unknown (0, negative or over a week,
// which UPower reports while it is still estimating).
function timeLeft(seconds) {
  var s = Math.floor(Number(seconds))
  if (!isFinite(s) || s <= 0 || s > 7 * 86400) return ""
  var h = Math.floor(s / 3600)
  var m = Math.floor((s % 3600) / 60)
  if (h === 0) return Math.max(1, m) + "m"
  return m > 0 ? h + "h " + m + "m" : h + "h"
}

// Watts with one decimal, "" when not flowing.
function rate(watts) {
  var w = Math.abs(Number(watts))
  if (!isFinite(w) || w < 0.05) return ""
  return (Math.round(w * 10) / 10).toFixed(1) + " W"
}

// The state word under the percentage.
function stateLabel(onBattery, full, charging) {
  if (full) return "Fully charged"
  if (onBattery) return "On battery"
  if (charging) return "Charging"
  return "Plugged in"
}

// "On battery · 2h 15m left · 8.4 W": state, time, then rate, each only
// when known.
function detail(onBattery, full, charging, timeToEmpty, timeToFull, watts) {
  var parts = [stateLabel(onBattery, full, charging)]
  var t = onBattery ? timeLeft(timeToEmpty) : (charging && !full ? timeLeft(timeToFull) : "")
  if (t !== "") parts.push(onBattery ? t + " left" : t + " to full")
  var r = rate(watts)
  if (r !== "" && !full) parts.push(r)
  return parts.join("  ·  ")
}
