import QtQuick
import Quickshell
import Quickshell.Io
import "../lib/Stats.js" as Stats

// System stats (SPEC.md section 7, v1). Nothing runs unless something
// showing them is on screen (`watchers` > 0: the System tab or the stats
// Home tile), so a collapsed hub starts no process and reads no file.
//
// - CPU and RAM: /proc/stat (two samples, diffed) and /proc/meminfo through
//   FileView, every `intervalMs` (statsWhileOpenMs).
// - CPU temperature: `sensors -j` (lm_sensors), every `slowMs`.
// - GPU: NVIDIA through `nvidia-smi --query-gpu`, every `slowMs`, but only
//   while the card is awake: on a hybrid laptop the query would wake a
//   runtime-suspended card (half a second of work, and its idle power for
//   as long as the tab is open), so a suspended card reads "asleep" (an
//   awake one is asked every `slowMs` and so stays awake while shown). AMD
//   through gpu_busy_percent in sysfs when a card has it, every `slowMs`,
//   and not while that card is runtime-suspended either.
// - Disk: `btrfs filesystem usage -b /`, else `df -B1 /`, every 30 s.
//
// Which tools and files exist is looked up once, the first time stats are
// shown. A missing tool hides its row and is never asked again.
Item {
  id: root
  visible: false

  property int watchers: 0
  property int intervalMs: 1000
  readonly property int slowMs: Math.max(5000, intervalMs)
  readonly property bool active: watchers > 0
  // CPU and RAM come from /proc, which every Linux has.
  readonly property bool available: true

  property real cpu: -1
  property real cpuTemp: NaN
  property real memUsed: 0
  property real memTotal: 0

  property bool hasSensors: false
  property bool hasNvidia: false
  property bool hasBtrfs: false
  property string busyPath: ""
  property string nvidiaPmPath: ""
  property string busyPmPath: ""
  property bool _looked: false
  property bool _ready: false

  property var nv: null
  property bool nvAsleep: false
  property real amdBusy: NaN
  readonly property bool gpuAvailable: (hasNvidia && !nvProbe.missing && (nv !== null || nvAsleep)) || !isNaN(amdBusy)

  property real diskUsed: 0
  property real diskTotal: 0

  property var _prevCpu: null

  onActiveChanged: {
    if (!active) { _prevCpu = null; return }
    if (!_looked) { _looked = true; tools.run() }
  }

  function tick() {
    statFile.reload()
    memFile.reload()
  }

  function slowTick() {
    if (hasSensors) sensorsProbe.run()
    if (busyPath !== "") {
      if (busyPmPath !== "") busyPmFile.reload()
      else busyFile.reload()
    }
    if (hasNvidia) {
      if (nvidiaPmPath !== "") pmFile.reload()
      else nvProbe.run()
    }
  }

  function readBusy() {
    if (busyFile.path === "") busyFile.path = busyPath
    else busyFile.reload()
  }

  function diskTick() {
    if (hasBtrfs && !btrfsProbe.missing) btrfsProbe.run()
    else dfProbe.run()
  }

  // Opens btop (click only), focusing it when it already runs.
  function openMonitor() {
    Quickshell.execDetached(["omarchy-launch-or-focus-tui", "btop"])
  }

  Probe {
    id: tools
    command: ["sh", "-c",
      "command -v sensors >/dev/null && echo sensors; "
      + "command -v nvidia-smi >/dev/null && echo nvidia; "
      + "[ \"$(stat -f -c %T / 2>/dev/null)\" = btrfs ] && command -v btrfs >/dev/null && echo btrfs; "
      + "for f in /sys/class/drm/card*/device/gpu_busy_percent; do [ -r \"$f\" ] && { echo \"busy $f\"; p=\"${f%/gpu_busy_percent}/power/runtime_status\"; [ -r \"$p\" ] && echo \"busypm $p\"; break; }; done; "
      + "for d in /sys/bus/pci/devices/*; do [ \"$(cat \"$d/vendor\" 2>/dev/null)\" = 0x10de ] || continue; "
      + "case \"$(cat \"$d/class\" 2>/dev/null)\" in 0x03*) [ -r \"$d/power/runtime_status\" ] && echo \"pm $d/power/runtime_status\"; break;; esac; done; true"]
    onFinished: function(code, output) {
      var lines = output.split("\n")
      for (let i = 0; i < lines.length; i++) {
        const line = lines[i].trim()
        if (line === "sensors") root.hasSensors = true
        else if (line === "nvidia") root.hasNvidia = true
        else if (line === "btrfs") root.hasBtrfs = true
        else if (line.indexOf("busy ") === 0) root.busyPath = line.slice(5)
        else if (line.indexOf("busypm ") === 0) root.busyPmPath = line.slice(7)
        else if (line.indexOf("pm ") === 0) root.nvidiaPmPath = line.slice(3)
      }
      root._ready = true
      if (!root.hasSensors) console.info("omavisor: sensors (lm_sensors) not found, no CPU temperature")
    }
  }

  FileView {
    id: statFile
    path: root.active ? "/proc/stat" : ""
    printErrors: false
    onLoaded: {
      var sample = Stats.cpuSample(text())
      var usage = Stats.cpuUsage(root._prevCpu, sample)
      if (usage >= 0) root.cpu = usage
      root._prevCpu = sample
    }
  }

  FileView {
    id: memFile
    path: root.active ? "/proc/meminfo" : ""
    printErrors: false
    onLoaded: {
      var m = Stats.memory(text())
      if (!m) return
      root.memUsed = m.used
      root.memTotal = m.total
    }
  }

  FileView {
    id: busyFile
    // Without a power state to check it is read at once; with one, only
    // after busyPmFile found the card awake.
    path: root.busyPmPath === "" ? root.busyPath : ""
    printErrors: false
    onLoaded: root.amdBusy = Stats.busyPercent(text())
    onLoadFailed: root.amdBusy = NaN
  }

  // The amdgpu card's runtime power state: a suspended card is not read
  // (sysfs reads can wake it).
  FileView {
    id: busyPmFile
    path: root.busyPmPath
    printErrors: false
    onLoaded: {
      if (text().trim() === "suspended") root.amdBusy = 0
      else root.readBusy()
    }
    onLoadFailed: root.readBusy()
  }

  // The NVIDIA card's runtime power state: asked before every query.
  FileView {
    id: pmFile
    path: root.nvidiaPmPath
    printErrors: false
    onLoaded: {
      root.nvAsleep = text().trim() === "suspended"
      if (!root.nvAsleep) nvProbe.run()
    }
    onLoadFailed: nvProbe.run()
  }

  Probe {
    id: sensorsProbe
    command: ["sensors", "-j"]
    onFinished: function(code, output) {
      if (code < 0 || code === 127) return
      root.cpuTemp = Stats.cpuTemp(output)
    }
  }

  Probe {
    id: nvProbe
    command: ["nvidia-smi", "--query-gpu=utilization.gpu,temperature.gpu,memory.used,memory.total", "--format=csv,noheader,nounits"]
    onFinished: function(code, output) {
      if (code < 0 || code === 127) return
      root.nv = code === 0 ? Stats.nvidia(output) : null
      // Installed without a working card (no driver loaded, no device):
      // not asked again.
      if (code !== 0 && root.nvidiaPmPath === "") root.hasNvidia = false
    }
  }

  Probe {
    id: btrfsProbe
    command: ["btrfs", "filesystem", "usage", "-b", "/"]
    onFinished: function(code, output) {
      var u = code === 0 ? Stats.btrfsUsage(output) : null
      if (u) { root.diskUsed = u.used; root.diskTotal = u.total }
      else { root.hasBtrfs = false; dfProbe.run() }
    }
  }

  Probe {
    id: dfProbe
    command: ["df", "-B1", "/"]
    onFinished: function(code, output) {
      var u = code === 0 ? Stats.dfUsage(output) : null
      if (u) { root.diskUsed = u.used; root.diskTotal = u.total }
    }
  }

  Timer {
    interval: root.intervalMs
    running: root.active
    repeat: true
    triggeredOnStart: true
    onTriggered: root.tick()
  }

  Timer {
    interval: root.slowMs
    running: root.active && root._ready
    repeat: true
    triggeredOnStart: true
    onTriggered: root.slowTick()
  }

  Timer {
    interval: 30000
    running: root.active && root._ready
    repeat: true
    triggeredOnStart: true
    onTriggered: root.diskTick()
  }
}
