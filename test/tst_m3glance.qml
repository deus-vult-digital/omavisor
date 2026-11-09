import QtQuick
import QtTest
import "../lib/Dictation.js" as Dictation
import "../lib/Notifications.js" as Notifications
import "../lib/Privacy.js" as Privacy
import "../lib/Keybindings.js" as Keybindings

TestCase {
  name: "M3Glance"

  // Lines as voxtype 1.1.1 printed them (idle, then a recording started
  // with `voxtype record start` and cancelled).
  function test_voxtypeStatus() {
    var idle = Dictation.voxtypeStatus('{"text": "🎙️", "alt": "idle", "class": "idle", "tooltip": "Voxtype ready - hold hotkey to record\\nModel: base.en", "model": "base.en", "device": "default", "backend": "CPU (AVX2)"}')
    compare(idle.state, "idle")
    compare(idle.model, "base.en")
    compare(Dictation.dictationActivity(idle), null)
    var rec = Dictation.voxtypeStatus('{"text":"🎤","alt":"recording","class":"recording","tooltip":"Recording...","model":"base.en"}\n')
    compare(rec.state, "recording")
    var a = Dictation.dictationActivity(rec)
    compare(a.title, "Listening")
    compare(a.priority, "urgent")
    compare(a.actions[0].exec, ["voxtype", "record", "stop"])
    compare(a.subtitle, "Voxtype · base.en")
    compare(Dictation.dictationActivity(Dictation.voxtypeStatus('{"class":"transcribing"}')).title, "Transcribing")
    // Without voxtype, omarchy-voxtype-status prints this.
    compare(Dictation.voxtypeStatus('{"alt": "", "class": "idle", "tooltip": ""}').state, "idle")
    compare(Dictation.voxtypeStatus("garbage"), null)
    compare(Dictation.voxtypeStatus("[1]"), null)
    compare(Dictation.voxtypeStatus('{"alt":"rm -rf /"}').state, "idle")
  }

  // Superwhisper's `status --bar --follow --extended` lines (Omarchy 4.5).
  function test_superwhisperStatus() {
    var idle = Dictation.barStatus('{"text": "󰍬", "alt": "idle", "class": "idle", "tooltip": "Superwhisper ready — hold the dictation key to record\\nMode: Offline", "model": "Offline", "device": "System default", "backend": "Automatic"}')
    compare(idle.state, "idle")
    compare(idle.model, "Offline")
    compare(Dictation.dictationActivity({ state: "idle", backend: "superwhisper" }), null)
    var a = Dictation.dictationActivity({ state: "recording", model: "Offline", backend: "superwhisper" })
    compare(a.title, "Listening")
    compare(a.subtitle, "Superwhisper · Offline")
    compare(a.actions[0].exec, ["superwhisper", "stop"])
    compare(a.actions[1].exec, ["superwhisper", "cancel"])
    var t = Dictation.dictationActivity({ state: "transcribing", backend: "superwhisper" })
    compare(t.subtitle, "Superwhisper")
    compare(t.actions[0].exec, ["superwhisper", "cancel"])
    compare(Dictation.dictationActivity({ state: "recording", backend: "nope" }), null)
    compare(Dictation.dictationActivity({ state: "stopped", backend: "superwhisper" }), null)
  }

  function test_pickBackend() {
    compare(Dictation.pickBackend("default=superwhisper\nvoxtype\nsuperwhisper\n"), "superwhisper")
    compare(Dictation.pickBackend("default=voxtype\nvoxtype\nsuperwhisper\n"), "voxtype")
    // The default is not installed: what is.
    compare(Dictation.pickBackend("default=voxtype\nsuperwhisper\n"), "superwhisper")
    // Before 4.5, or none chosen: Superwhisper first.
    compare(Dictation.pickBackend("default=\nvoxtype\nsuperwhisper\n"), "superwhisper")
    compare(Dictation.pickBackend("default=\nvoxtype\n"), "voxtype")
    compare(Dictation.pickBackend("default=\n"), "")
    compare(Dictation.pickBackend("default=evil\nevil\n"), "")
    compare(Dictation.pickBackend(""), "")
    compare(Dictation.backend("superwhisper").follow, ["superwhisper", "status", "--bar", "--follow", "--extended"])
    compare(Dictation.backend("voxtype").follow, ["voxtype", "status", "--follow", "--extended", "--format", "json"])
    compare(Dictation.backend("x"), null)
  }

  function test_history() {
    var text = [
      '{"id":3,"originalId":3,"app":"kitty","summary":"Claude Code","body":"secret body","execArgv":"rm -rf /","glyph":"","urgency":1,"timestamp":1793327909247}',
      '{"id":1,"app":"Spotify","summary":"Song\\nTitle","urgency":0,"timestamp":1793316739179}',
      'not json',
      '{"id":2,"app":"","summary":"","timestamp":5}',
      '{"id":9,"app":"x","summary":"crit","urgency":2,"timestamp":1793327909999}',
      ''
    ].join("\n")
    var list = Notifications.historyEntries(text, 10)
    compare(list.length, 3)
    compare(list[0].summary, "crit")
    compare(list[0].urgency, "critical")
    compare(list[1].app, "kitty")
    compare(list[1].body, undefined)
    compare(list[1].execArgv, undefined)
    compare(list[2].summary, "Song Title")
    compare(list[2].urgency, "low")
    compare(Notifications.historyEntries(text, 1).length, 1)
    compare(Notifications.unreadCount(list, 1793327909247), 1)
    compare(Notifications.unreadCount(list, 0), 3)
    compare(Notifications.historyEntries("", 5), [])
  }

  // Omarchy 4.5: one JSON array per file, `ts` in seconds.
  function test_store() {
    var text = JSON.stringify([
      { key: "a1", app: "Hermes", summary: "Hermes finished", body: "secret", execArgv: "rm -rf /", glyph: "", urgency: 1, ts: 1794107990.367 },
      { key: "b2", app: "kitty", summary: "Older", urgency: 0, ts: 1794093044.918 },
      { key: "c3", app: "", summary: "", ts: 1794107999 },
      "junk",
      { key: "d4", app: "x", summary: "crit", urgency: 2, ts: 1794107995 }
    ])
    var list = Notifications.storeEntries(text, 10)
    compare(list.length, 3)
    compare(list[0].summary, "crit")
    compare(list[0].urgency, "critical")
    compare(list[1].app, "Hermes")
    compare(list[1].timestamp, 1794107990367)
    compare(list[1].key, "1794107990367-a1")
    compare(list[1].body, undefined)
    compare(list[1].execArgv, undefined)
    compare(list[2].urgency, "low")
    compare(Notifications.storeEntries(text, 1).length, 1)
    compare(Notifications.storeEntries("[]\n", 5), [])
    compare(Notifications.storeEntries("", 5), [])
    compare(Notifications.storeEntries("{}", 5), [])
  }

  function test_capture() {
    var mic = { sourceType: "AudioSource", targetType: "AudioInStream", sourceStream: false, targetStream: true, app: "Firefox", name: "Firefox", binary: "firefox" }
    var cam = { sourceType: "VideoSource", targetType: "VideoSink", sourceStream: false, targetStream: true, app: "", name: "obs", binary: "obs" }
    var meter = { sourceType: "AudioSource", targetStream: true, app: "Quickshell", name: "quickshell" }
    var peak = { sourceType: "AudioSource", targetStream: true, app: "PulseAudio Volume Control", name: "Peak detect" }
    var playback = { sourceType: "AudioOutStream", sourceStream: true, targetStream: false, app: "Spotify" }
    var vox = { sourceType: "AudioSource", targetStream: true, name: "voxtype", binary: "voxtype" }
    compare(Privacy.captureKind(mic), "mic")
    compare(Privacy.captureKind(cam), "camera")
    compare(Privacy.captureKind(meter), "")
    compare(Privacy.captureKind(peak), "")
    compare(Privacy.captureKind(playback), "")
    compare(Privacy.captureKind(vox, ["voxtype"]), "")
    compare(Privacy.captureKind(vox, []), "mic")
    var alsaVox = { sourceType: "AudioSource", targetStream: true, app: "PipeWire ALSA [voxtype-avx2]", name: "alsa_capture.voxtype-avx2" }
    compare(Privacy.captureKind(alsaVox, ["voxtype"]), "")
    compare(Privacy.captureApps([{ sourceType: "AudioSource", targetStream: true, app: "PipeWire ALSA [arecord]", name: "alsa_capture.arecord" }]).mic, ["arecord"])
    var apps = Privacy.captureApps([mic, mic, cam, meter, { sourceType: "AudioSource", targetStream: true, name: "pw-record" }])
    compare(apps.mic, ["Firefox", "pw-record"])
    compare(apps.camera, ["obs"])
    compare(Privacy.privacyActivity("mic", []), null)
    var a = Privacy.privacyActivity("camera", ["obs", "ffmpeg"])
    compare(a.id, "omavisor:camera")
    compare(a.subtitle, "obs, ffmpeg")
  }

  function test_videoHolders() {
    compare(Privacy.videoHolders("  4242 ffmpeg\n 812 wireplumber\n 900 pipewire\n4243 ffmpeg\nbad line\n"), ["ffmpeg"])
    compare(Privacy.videoHolders(""), [])
  }

  function test_keybindings() {
    var text = "SUPER + K                           → Keybindings\nSUPER SHIFT + RETURN                → Browser\n\nno arrow here\n →\nCTRL ALT + DELETE                   → Close all windows\n"
    var list = Keybindings.keybindings(text)
    compare(list.length, 3)
    compare(list[1].keys, "SUPER SHIFT + RETURN")
    compare(list[1].action, "Browser")
    compare(Keybindings.filterBindings(list, "").length, 3)
    compare(Keybindings.filterBindings(list, "  ").length, 3)
    compare(Keybindings.filterBindings(list, "browser").length, 1)
    compare(Keybindings.filterBindings(list, "super k")[0].action, "Keybindings")
    compare(Keybindings.filterBindings(list, "delete close").length, 1)
    compare(Keybindings.filterBindings(list, "zzz").length, 0)
  }
}
