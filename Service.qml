import QtQuick
import Quickshell.Io
import "modules"
import "lib/PillRegistry.js" as PillRegistry
import "lib/Hypr.js" as Hypr

// Omavisor's headless root of state (keepLoaded: hot reload keeps this instance,
// so changes here need `omarchy restart shell`).
//
// Pills and tabs reach it through `bar.shell.serviceFor(<plugin id>)`.
Item {
  id: root

  property var shell: null
  property var manifest: null

  readonly property string version: manifest && manifest.version ? String(manifest.version) : "0.1.0"

  readonly property alias activities: activities

  ActivitiesModule {
    id: activities
    shell: root.shell
    pluginId: root.manifest && root.manifest.id ? String(root.manifest.id) : "dev.deusvult.omavisor"
  }

  // Quickshell IPC calls need exactly as many arguments as the function
  // takes, so calls with optional parts take them as one space-separated
  // argument: `end "build:api error"`, `timer "25 Focus"`, `expand ""`.
  // bin/omavisor joins its arguments that way.
  function words(line) {
    return String(line || "").trim().split(/\s+/).filter(function(w) { return w !== "" })
  }
  // 1 for the word that means a wheel notch up, -1 for the other, else 0.
  function notches(word, up, down) {
    var w = String(word || "").trim()
    return w === up ? 1 : w === down ? -1 : 0
  }
  // Shared data sources (SPEC section 7): one of each for every pill and
  // hub, so the weather is fetched once however many monitors there are.
  readonly property alias weather: weatherModule
  readonly property alias media: mediaModule

  WeatherModule { id: weatherModule }
  MediaModule { id: mediaModule }

  // The Now playing view's wave display (cava while watched, else drawn).
  readonly property alias visualizer: visualizerModule
  VisualizerModule { id: visualizerModule; media: mediaModule }

  // System modules (SPEC section 7, M1): updates, recording, capture,
  // toggles and timers. Badges and blooms go through the activity store.
  readonly property alias updates: updateModule
  readonly property alias recording: recordingModule
  readonly property alias capture: captureModule
  readonly property alias toggles: togglesModule
  readonly property alias timers: timerModule

  UpdateModule { id: updateModule; activities: root.activities }
  CaptureModule { id: captureModule; activities: root.activities }
  RecordingModule { id: recordingModule; activities: root.activities; capture: captureModule }
  TogglesModule { id: togglesModule }
  TimerModule { id: timerModule; activities: root.activities }

  // Pending packages, failed units and system stats (SPEC section 7, v1).
  readonly property alias packages: packagesModule
  readonly property alias units: unitsModule
  readonly property alias stats: statsModule

  PackagesModule { id: packagesModule; updates: updateModule }
  UnitsModule { id: unitsModule; activities: root.activities }
  StatsModule { id: statsModule }

  // v1 glance modules (SPEC section 7, M3, ON-12): notifications, dictation,
  // mic/camera in use and the keybinding cheatsheet.
  readonly property alias notifications: notificationsModule
  readonly property alias dictation: dictationModule
  readonly property alias privacy: privacyModule
  readonly property alias keybindings: keybindingsModule

  NotificationsModule { id: notificationsModule; toggles: togglesModule }
  DictationModule { id: dictationModule; activities: root.activities }
  PrivacyModule { id: privacyModule; activities: root.activities; skipCapture: dictationModule.available ? dictationModule.captureNames : [] }
  KeybindingsModule { id: keybindingsModule }

  // v1 (SPEC section 7, M3): theme switcher, Hyprland strip, power.
  readonly property alias theme: themeModule
  readonly property alias hypr: hyprModule
  readonly property alias power: powerModule

  ThemeModule { id: themeModule }
  HyprModule { id: hyprModule; notifications: notificationsModule }
  PowerModule { id: powerModule }

  // Power, monitor and Bluetooth notices (docs/macnotch-audit.md, shortlist 3).
  NoticesModule { activities: root.activities; power: powerModule }

  // Onboarding and restore of the bar's center (SPEC section 9, M1).
  readonly property alias layout: layoutModule
  LayoutModule { id: layoutModule; shell: root.shell; pluginId: activities.pluginId }

  IpcHandler {
    target: "dev.deusvult.omavisor"

    function version(): string { return root.version }

    // Live activities (SPEC.md section 8).
    function push(json: string): string { return activities.push(json) }
    function update(id: string, patch: string): string { return activities.update(id, patch) }
    // "<id|top> [success|error]"
    function end(args: string): string {
      var w = root.words(args)
      if (w.length < 1 || w.length > 2) return "error: usage: end '<id|top> [success|error]'"
      return activities.end(w[0], w[1] || "")
    }
    function list(): string { return activities.list() }
    // "<minutes> [label]"
    function timer(args: string): string {
      var w = root.words(args)
      if (w.length < 1) return "error: usage: timer '<minutes> [label]'"
      return timerModule.start(w[0], w.slice(1).join(" "))
    }
    // "[tab]"
    function expand(tab: string): string { return activities.expand(String(tab || "").trim()) }
    function collapse(): string { return activities.collapse() }

    // What the pill does with the mouse, for keybinds (README, Keybindings).
    // Right click: the clock's alternate format.
    function format(): string {
      PillRegistry.each(function(pill) { pill.cycleFormat() })
      return "ok"
    }
    function dnd(): string {
      if (togglesModule.dnd === null) return "error: do not disturb unavailable"
      togglesModule.toggleDnd()
      return "ok"
    }
    // One wheel notch, as `scrollAction` says: "up" or "down".
    function scroll(direction: string): string {
      var notches = root.notches(direction, "up", "down")
      if (notches === 0) return "error: usage: scroll up|down"
      var pill = PillRegistry.pick(activities.focusedScreen)
      if (!pill) return "error: no pill"
      pill.step(notches)
      return "ok"
    }
    function workspace(direction: string): string {
      var notches = root.notches(direction, "prev", "next")
      if (notches === 0) return "error: usage: workspace next|prev"
      if (!hyprModule.available) return "error: not under Hyprland"
      hyprModule.focusWorkspace(Hypr.scrollTarget(notches))
      return "ok"
    }
    function volume(direction: string): string {
      var notches = root.notches(direction, "up", "down")
      if (notches === 0) return "error: usage: volume up|down"
      return mediaModule.stepVolume(notches) ? "ok" : "error: no player playing"
    }
    // The click on the pill's REC side.
    function stopRecording(): string {
      if (!recordingModule.recording) return "error: not recording"
      recordingModule.stop()
      return "ok"
    }

    // Puts back the center saved by onboarding (layout-backup.json). It
    // answers at once; `layout` has the outcome and the anchor one-liner.
    function restore(): string { return layoutModule.restore() }
    function layout(): string { return layoutModule.status() }
  }
}
