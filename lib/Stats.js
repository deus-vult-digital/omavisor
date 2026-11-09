.pragma library

// Parsing for the System stats module (SPEC.md section 7, v1), kept pure so
// it is unit-tested without /proc, sensors, nvidia-smi or btrfs.

// The aggregate "cpu" line of /proc/stat as { busy, total } jiffies, or
// null. Idle is idle + iowait; guest time is already in user/nice.
function cpuSample(text) {
  var lines = String(text || "").split("\n")
  for (let i = 0; i < lines.length; i++) {
    var f = lines[i].trim().split(/\s+/)
    if (f[0] !== "cpu") continue
    var n = []
    for (let j = 1; j <= 8 && j < f.length; j++) n.push(Number(f[j]) || 0)
    while (n.length < 8) n.push(0)
    var total = 0
    for (let k = 0; k < n.length; k++) total += n[k]
    var idle = n[3] + n[4]
    return { busy: total - idle, total: total }
  }
  return null
}

// CPU use between two samples, 0..1, or -1 when it cannot be told (no
// earlier sample, or no time passed).
function cpuUsage(prev, cur) {
  if (!prev || !cur) return -1
  var total = cur.total - prev.total
  if (total <= 0) return -1
  return clamp01((cur.busy - prev.busy) / total)
}

// /proc/meminfo as { total, used } bytes (used = total - available, what
// btop and free's "used" column show), or null.
function memory(text) {
  var values = {}
  var lines = String(text || "").split("\n")
  for (let i = 0; i < lines.length; i++) {
    var m = lines[i].match(/^(\w+):\s+(\d+)/)
    if (m) values[m[1]] = Number(m[2]) * 1024
  }
  if (!values.MemTotal) return null
  var available = values.MemAvailable !== undefined ? values.MemAvailable
    : (values.MemFree || 0) + (values.Buffers || 0) + (values.Cached || 0)
  return { total: values.MemTotal, used: Math.max(0, values.MemTotal - available) }
}

// The CPU temperature in °C from `sensors -j`, or NaN. The package sensor
// of the CPU's own driver first (Intel coretemp, AMD k10temp/zenpower,
// ARM cpu_thermal), then ACPI's thermal zone.
var CPU_CHIPS = [
  { chip: /^coretemp-/, labels: [/^Package id \d+$/, /^Core \d+$/] },
  { chip: /^k10temp-/, labels: [/^Tctl$/, /^Tdie$/, /^Tccd\d+$/] },
  { chip: /^zenpower-/, labels: [/^Tdie$/, /^Tctl$/] },
  { chip: /^cpu_thermal-/, labels: [/./] },
  { chip: /^acpitz-/, labels: [/./] }
]

function firstInput(feature) {
  if (!feature || typeof feature !== "object") return NaN
  for (let key in feature) {
    if (/^temp\d+_input$/.test(key)) {
      var v = Number(feature[key])
      if (isFinite(v) && v > -50 && v < 200) return v
    }
  }
  return NaN
}

function cpuTemp(text) {
  var data
  try { data = JSON.parse(String(text || "")) } catch (e) { return NaN }
  if (!data || typeof data !== "object") return NaN
  for (let c = 0; c < CPU_CHIPS.length; c++) {
    for (let chip in data) {
      if (!CPU_CHIPS[c].chip.test(chip)) continue
      var features = data[chip]
      for (let l = 0; l < CPU_CHIPS[c].labels.length; l++) {
        for (let name in features) {
          if (!CPU_CHIPS[c].labels[l].test(name)) continue
          var v = firstInput(features[name])
          if (!isNaN(v)) return v
        }
      }
    }
  }
  return NaN
}

// The first GPU of `nvidia-smi --query-gpu=utilization.gpu,temperature.gpu,
// memory.used,memory.total --format=csv,noheader,nounits` as { busy (0..1),
// temp (°C), memUsed, memTotal (bytes) }, or null. "[N/A]" fields are NaN.
function nvidia(text) {
  var line = String(text || "").split("\n")[0].trim()
  if (line === "") return null
  var f = line.split(",").map(function(s) { return parseFloat(s.trim()) })
  if (f.length < 4 || f.every(function(v) { return isNaN(v) })) return null
  return {
    busy: isNaN(f[0]) ? NaN : clamp01(f[0] / 100),
    temp: f[1],
    memUsed: f[2] * 1048576,
    memTotal: f[3] * 1048576
  }
}

// gpu_busy_percent (amdgpu sysfs) as 0..1, or NaN.
function busyPercent(text) {
  var v = parseFloat(String(text || "").trim())
  return isNaN(v) ? NaN : clamp01(v / 100)
}

// `btrfs filesystem usage -b /` as { used, total } bytes: Used, and Used
// plus "Free (estimated)" as the size (what df's Use% measures), or null.
function btrfsUsage(text) {
  var s = String(text || "")
  var used = s.match(/^\s*Used:\s+(\d+)/m)
  var free = s.match(/^\s*Free \(estimated\):\s+(\d+)/m)
  if (!used || !free) return null
  var u = Number(used[1])
  return { used: u, total: u + Number(free[1]) }
}

// `df -B1 /` as { used, total } bytes (used plus available, like Use%), or
// null.
function dfUsage(text) {
  var lines = String(text || "").trim().split("\n")
  if (lines.length < 2) return null
  var f = lines[lines.length - 1].trim().split(/\s+/)
  if (f.length < 4) return null
  var used = Number(f[2]), avail = Number(f[3])
  if (!isFinite(used) || !isFinite(avail) || used + avail <= 0) return null
  return { used: used, total: used + avail }
}

// "18.2 GB", "512 MB": binary units with the familiar names, as btop and
// the GNOME tools print them.
function bytes(value) {
  var n = Number(value)
  if (!isFinite(n) || n < 0) return ""
  var units = ["B", "KB", "MB", "GB", "TB", "PB"]
  var i = 0
  while (n >= 1024 && i < units.length - 1) { n /= 1024; i++ }
  return (i === 0 || n >= 100 ? Math.round(n) : n.toFixed(1)) + " " + units[i]
}

// "12.4 / 62.5 GB": both in the total's unit.
function bytePair(used, total) {
  var t = Number(total), u = Number(used)
  if (!isFinite(t) || t <= 0 || !isFinite(u)) return ""
  var units = ["B", "KB", "MB", "GB", "TB", "PB"]
  var i = 0
  while (t >= 1024 && i < units.length - 1) { t /= 1024; u /= 1024; i++ }
  var fmt = function(v) { return i === 0 || v >= 100 ? String(Math.round(v)) : v.toFixed(1) }
  return fmt(u) + " / " + fmt(t) + " " + units[i]
}

function percent(fraction) {
  return isNaN(fraction) || fraction < 0 ? "" : Math.round(clamp01(fraction) * 100) + "%"
}

function clamp01(v) {
  return Math.max(0, Math.min(1, v))
}
