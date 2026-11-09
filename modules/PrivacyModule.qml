import QtQuick
import Quickshell.Services.Pipewire
import "../lib/Privacy.js" as Privacy

// Microphone and camera in use (SPEC.md section 7, v1; Open question 5).
//
// Pipewire: every link from an audio source node (the mic) or a video
// source node (a camera) into a stream is a reader; the stream's
// application.name (else its node name) names it. Quickshell's own peak
// meters, "Peak detect" monitors and the dictation backend (when DictationModule shows it)
// are left out. Apps that open /dev/video* themselves (not through
// Pipewire) are invisible there, so with `fuser` (psmisc) present Omavisor
// also asks which processes hold a /dev/video* device: every 30 s, every
// 5 s while it finds one held (to see it end).
//
// Each kind in use is a normal-priority own activity ("Microphone in use",
// "Camera in use" with the apps), so it peeks when it starts and shows in
// the pill's badge and the Activities tab; it goes when the last reader
// does.
Item {
  id: root
  visible: false

  property var activities: null
  // With the dictation module on, its backend's capture is shown as
  // dictation (DictationModule.captureNames).
  property var skipCapture: []

  readonly property bool available: Pipewire.ready || fuserPresent
  property bool fuserPresent: false

  readonly property var links: Pipewire.links ? Pipewire.links.values : []
  // Properties (application.name) are only filled in for tracked nodes.
  PwObjectTracker {
    objects: {
      var nodes = []
      for (let i = 0; i < root.links.length; i++) if (root.links[i] && root.links[i].target) nodes.push(root.links[i].target)
      return nodes
    }
  }

  function flat(link) {
    var s = link.source, t = link.target
    var props = t && t.properties ? t.properties : {}
    return {
      sourceType: s ? PwNodeType.toString(s.type) : "",
      targetType: t ? PwNodeType.toString(t.type) : "",
      sourceStream: !!(s && s.isStream),
      targetStream: !!(t && t.isStream),
      app: String(props["application.name"] || ""),
      name: t ? String(t.name || "") : "",
      binary: String(props["application.process.binary"] || "")
    }
  }

  readonly property var pipewireApps: {
    var flatLinks = []
    for (let i = 0; i < links.length; i++) if (links[i] && links[i].source && links[i].target) flatLinks.push(flat(links[i]))
    return Privacy.captureApps(flatLinks, skipCapture || [])
  }
  property var deviceApps: []

  readonly property var micApps: pipewireApps.mic
  readonly property var cameraApps: {
    var all = pipewireApps.camera.slice()
    for (let i = 0; i < deviceApps.length; i++) if (all.indexOf(deviceApps[i]) === -1) all.push(deviceApps[i])
    return all.sort()
  }
  readonly property bool micInUse: micApps.length > 0
  readonly property bool cameraInUse: cameraApps.length > 0

  onMicAppsChanged: publish("mic", micApps)
  onCameraAppsChanged: publish("camera", cameraApps)
  onActivitiesChanged: { publish("mic", micApps); publish("camera", cameraApps) }

  property var _shown: ({})
  function publish(kind, apps) {
    if (!activities) return
    var activity = Privacy.privacyActivity(kind, apps)
    var id = kind === "mic" ? "omavisor:mic" : "omavisor:camera"
    var key = apps.join("\n")
    // Unchanged and still shown (one dismissed or expired is pushed again).
    if (_shown[kind] === key && (key === "" || activities.store.items[id])) return
    var shown = _shown; shown[kind] = key; _shown = shown
    if (activity) activities.push(activity, { own: true })
    else if (activities.store.items[id]) activities.dismiss(id)
  }

  // ---- /dev/video* fallback
  Probe {
    id: hasFuser
    command: ["sh", "-c", "command -v fuser"]
    onFinished: function(code) {
      root.fuserPresent = code === 0
      if (code === 0) holders.run()
      else console.info("omavisor: fuser (psmisc) not installed, camera use seen through Pipewire only")
    }
  }
  Component.onCompleted: hasFuser.run()

  // Pipewire is live; ask fuser again now.
  function refresh() { if (fuserPresent) holders.run() }

  // fuser exits 1 when nobody holds a device; ps names the holders.
  Probe {
    id: holders
    command: ["sh", "-c", "set -- /dev/video*; [ -e \"$1\" ] || exit 1; p=$(fuser \"$@\" 2>/dev/null | tr -cs 0-9 ,) || exit 1; p=${p#,}; p=${p%,}; [ -n \"$p\" ] || exit 1; ps -o pid=,comm= -p \"$p\""]
    onFinished: function(code, output) { root.deviceApps = code === 0 ? Privacy.videoHolders(output) : [] }
  }
  Timer {
    interval: root.deviceApps.length > 0 ? 5000 : 30000
    running: root.fuserPresent
    repeat: true
    onTriggered: holders.run()
  }
}
