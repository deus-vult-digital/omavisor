pragma ComponentBehavior: Bound

import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import "../lib/Notifications.js" as Notifications

// Notifications glance (SPEC.md section 7, v1; Open question 4).
//
// Omarchy's notification server lives in the shell and is not reachable
// from a third-party plugin, and Omavisor never registers a second one. What
// it can see: the files the shell keeps, one JSON file per notification,
// on screen in ~/.local/state/omarchy/notifications/*.json and, once they
// leave the screen, in …/notifications/history/*.json (the newest 10).
// That format is internal and undocumented, so this is best-effort: a
// file that does not parse is skipped, and only app, summary, glyph,
// urgency and time are kept. Never the body, images or execArgv, which
// Omavisor never runs.
//
// Omarchy 4.5 keeps them in two files instead, live.json and history.json
// in the same folder, each one JSON array (Notifications.storeEntries). When
// those exist they are watched (FileView) and the folders are not read.
//
// Both folders are watched (FolderListModel, inotify, no polling) and read
// again when they change. DND comes from TogglesModule; the actions are the
// shell's `notifications` IPC calls, run as argv on a click.
Item {
  id: root
  visible: false

  property var toggles: null

  readonly property string baseDir: (Quickshell.env("HOME") + "/.local/state/omarchy/notifications").replace(/\/+/g, "/")
  readonly property string historyDir: baseDir + "/history"

  // 4.5's store files, made at shell start.
  property bool storeFiles: false
  // The history folder exists once the shell has kept one notification.
  readonly property bool available: storeFiles || historyModel.status === FolderListModel.Ready || liveModel.status === FolderListModel.Ready
  // Newest first: on screen ones, then history.
  property var recent: []
  property int onScreen: 0
  // Newest timestamp shown in the hub before it was last left (session only).
  property real seenAt: Date.now()
  readonly property int unread: Notifications.unreadCount(recent, seenAt)
  readonly property var dnd: toggles ? toggles.dnd : null

  property var _history: []
  property var _live: []

  // A path as a file URL, each part encoded (a home with a space or "#").
  function fileUrl(path) {
    return "file://" + path.split("/").map(encodeURIComponent).join("/")
  }

  function markSeen() {
    if (recent.length > 0 && recent[0].timestamp > seenAt) seenAt = recent[0].timestamp
  }

  function refresh() {
    if (storeFiles) {
      historyFile.reload()
      liveFile.reload()
    } else {
      historyRead.run()
      liveRead.run()
    }
    if (toggles) toggles.refresh()
  }

  function merge() {
    var live = _live.map(function(e) { var c = Object.assign({}, e); c.live = true; return c })
    var all = live.concat(_history)
    all.sort(function(a, b) { return b.timestamp - a.timestamp })
    recent = all.slice(0, 10)
    onScreen = _live.length
  }

  // ---- actions (the shell's notification IPC; argv, on click only)
  function call(method) { Quickshell.execDetached(["omarchy-shell", "notifications", method]) }
  function dismissOne() { call("dismissOne") }
  function dismissAll() { call("dismissAll") }
  function invokeLast() { call("invokeLast") }
  function showHistory() { call("showHistory") }
  function toggleDnd() { if (toggles) toggles.toggleDnd() }

  // One JSON object per line, one line per file.
  Probe {
    id: historyRead
    command: ["sh", "-c", "for f in \"$1\"/*.json; do [ -f \"$f\" ] && head -c 65536 -- \"$f\" && echo; done; true", "--", root.historyDir]
    onFinished: function(code, output) { if (code === 0) { root._history = Notifications.historyEntries(output, 10); root.merge() } }
  }
  Probe {
    id: liveRead
    command: ["sh", "-c", "for f in \"$1\"/*.json; do [ -f \"$f\" ] && head -c 65536 -- \"$f\" && echo; done; true", "--", root.baseDir]
    onFinished: function(code, output) { if (code === 0) { root._live = Notifications.historyEntries(output, 10); root.merge() } }
  }

  FileView {
    id: historyFile
    path: root.baseDir + "/history.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: { root.storeFiles = true; root._history = Notifications.storeEntries(text(), 10); root.merge() }
  }
  FileView {
    id: liveFile
    path: root.baseDir + "/live.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: { root.storeFiles = true; root._live = Notifications.storeEntries(text(), 10); root.merge() }
  }

  // A read already running when the folder changes again: once more after.
  Timer {
    id: settle
    interval: 150
    onTriggered: {
      if (root.storeFiles) return
      var a = historyRead.run()
      var b = liveRead.run()
      if (!a || !b) settle.restart()
    }
  }

  FolderListModel {
    id: historyModel
    folder: root.fileUrl(root.historyDir)
    nameFilters: ["*.json"]
    showDirs: false
    showDotAndDotDot: false
    showHidden: false
    onCountChanged: settle.restart()
    onStatusChanged: if (status === FolderListModel.Ready) settle.restart()
  }
  FolderListModel {
    id: liveModel
    folder: root.fileUrl(root.baseDir)
    nameFilters: ["*.json"]
    showDirs: false
    showDotAndDotDot: false
    showHidden: false
    onCountChanged: settle.restart()
  }
  // The history keeps its newest 10: a new one replaces the oldest and the
  // count stays the same.
  Connections {
    target: historyModel
    function onRowsInserted() { settle.restart() }
  }
}
