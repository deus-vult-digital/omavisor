import QtQuick
import Quickshell
import Quickshell.Io
import "../lib/Visualizer.js" as Visualizer

// The levels the Now playing view's wave display draws (lib/Visualizer.js).
//
// With cava installed, cava reads the default output's monitor and prints the
// bar heights; it runs only while something is watching (`watchers` > 0:
// the Now playing view, or the pill's Audio levels) and the player plays,
// and stops the moment either ends. Nothing is recorded.
// Without cava, a drawing that moves while the player plays. cava is
// optional: detected once, never an error.
Item {
  id: root
  visible: false

  property var media: null
  property int watchers: 0

  // cava found (it ran, rather than failing to start).
  property bool available: false
  // Levels from cava right now, rather than the drawing.
  readonly property bool live: cava.running && _gotFrame
  property var levels: []

  readonly property bool wanted: watchers > 0 && !!media && media.playing === true
  readonly property string stateDir: ((Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/omavisor").replace(/\/+/g, "/")
  readonly property string configPath: stateDir + "/cava.conf"

  property bool _configReady: false
  property bool _gotFrame: false

  onWantedChanged: {
    if (!wanted) {
      _gotFrame = false
      levels = []
    }
  }

  Probe {
    id: detect
    command: ["cava", "-v"]
    onFinished: function(code) { if (code === 0 && !detect.missing) root.writeConfig() }
  }
  Component.onCompleted: detect.run()

  function writeConfig() {
    mkdir.running = true
  }
  Process {
    id: mkdir
    command: ["mkdir", "-p", "--", root.stateDir]
    onExited: function(code) {
      if (code !== 0) return
      configFile.setText(Visualizer.cavaConfig(Visualizer.BARS, Visualizer.FRAMERATE))
      root._configReady = true
      root.available = true
    }
  }
  FileView {
    id: configFile
    path: root.configPath
    printErrors: false
  }

  Process {
    id: cava
    command: ["cava", "-p", root.configPath]
    running: root.wanted && root.available && root._configReady
    stdout: SplitParser {
      onRead: function(line) {
        root._gotFrame = true
        root.levels = Visualizer.smooth(root.levels, Visualizer.parseFrame(line, Visualizer.BARS))
      }
    }
    onExited: function(code) {
      root._gotFrame = false
      // It stopped by itself (no audio server, a bad config): drawn from now on.
      if (root.wanted && code !== 0) {
        console.info("omavisor: cava exited " + code + ", drawing the wave instead")
        root.available = false
      }
    }
  }

  // The drawing, while watched and playing without cava's levels.
  Timer {
    interval: Math.round(1000 / Visualizer.FRAMERATE)
    repeat: true
    running: root.wanted && !root.live
    onTriggered: root.levels = Visualizer.drawn(Date.now() / 1000, Visualizer.BARS)
  }
}
