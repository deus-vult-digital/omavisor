pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import "../lib/Media.js" as Media

// Now playing, straight from MPRIS (Quickshell.Services.Mpris; no
// playerctl). Shows the playing player, or the one that last played, with
// its track, art, position and transport. `available` is false with no
// player to show, which hides the Media tile and tab body.
//
// MPRIS does not push position updates, so `position` is re-read once a
// second, and only while something that shows it is on screen
// (`watchers` > 0) and the player is playing.
Item {
  id: root

  readonly property var players: Mpris.players ? Mpris.players.values : []
  // playerKey → serial, bumped each time a player starts playing, so the
  // newest playing player wins.
  property var playOrder: ({})
  property int playSerial: 0
  property string lastKey: ""
  property int watchers: 0

  readonly property var player: Media.pick(players, playOrder, lastKey)
  readonly property bool available: player !== null
  readonly property bool playing: !!player && player.isPlaying
  readonly property string title: player ? (player.trackTitle || player.identity || "") : ""
  readonly property string artist: player ? (player.trackArtist || "") : ""
  readonly property string album: player ? (player.trackAlbum || "") : ""
  // Local art (file:, data:) whenever the player gives it. A player with no
  // local art (Spotify and browsers hand out http(s) links) gets its web
  // art loaded with the `remoteArt` setting (on by default): only the
  // current track's, and only while that player is there, since `player`
  // is the current one and `artUrl` is empty without it. Off, those tracks
  // show the music glyph.
  property bool remoteArt: true
  // What the player gives (local, or web with remoteArt), and what reaches
  // an Image: local as it is, web only once fetched to a file (artFetch).
  readonly property string sourceArt: player ? Media.localArt(player.trackArtUrl, remoteArt) : ""
  readonly property bool sourceIsWeb: /^https?:\/\//i.test(sourceArt)
  readonly property string artUrl: !sourceIsWeb ? sourceArt
    : (fetchedFor === sourceArt && fetchedPath !== "" ? "file://" + fetchedPath : "")

  // ---- Web art: one bounded download per track (Media.artFetchArgs) into
  //      $XDG_STATE_HOME/omavisor/art/, the previous file removed. Emptied
  //      at start. A failed or missing curl leaves the music glyph.
  readonly property string artDir: ((Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/omavisor/art").replace(/\/+/g, "/")
  property string fetchedFor: ""
  property string fetchedPath: ""
  property bool _artDirReady: false
  property string _fetching: ""

  onSourceArtChanged: fetchArt()
  function fetchArt() {
    if (!sourceIsWeb || !_artDirReady || fetchedFor === sourceArt) return
    if (artFetch.running) { artFetch.running = false }
    var out = artDir + "/" + Media.artFileName(sourceArt)
    _fetching = sourceArt
    artFetch.target = out
    artFetch.command = Media.artFetchArgs(sourceArt, out)
    artFetch.running = true
  }
  Process {
    id: artDirSetup
    command: ["sh", "-c", "rm -rf -- \"$1\" && mkdir -p -- \"$1\"", "sh", root.artDir]
    running: true
    onExited: function(code) {
      root._artDirReady = code === 0
      root.fetchArt()
    }
  }
  Process {
    id: artFetch
    property string target: ""
    onExited: function(code) {
      if (code !== 0 || root._fetching !== root.sourceArt) return
      var old = root.fetchedPath
      root.fetchedFor = root._fetching
      root.fetchedPath = artFetch.target
      if (old !== "" && old !== artFetch.target) {
        artCleanup.command = ["rm", "-f", "--", old]
        artCleanup.running = true
      }
    }
  }
  Process { id: artCleanup }
  readonly property string identity: player ? (player.identity || player.desktopEntry || "") : ""
  readonly property real length: player && player.lengthSupported ? Math.max(0, player.length) : 0
  readonly property bool canSeek: !!player && player.canSeek && player.positionSupported && length > 0
  readonly property bool canPlayPause: !!player && (player.canTogglePlaying || player.canPlay || player.canPause)
  readonly property bool canNext: !!player && player.canGoNext
  readonly property bool canPrevious: !!player && player.canGoPrevious
  readonly property bool volumeSupported: !!player && player.volumeSupported
  readonly property real volume: volumeSupported ? player.volume : 0
  property real position: 0

  onPlayerChanged: {
    // Deferred: `player` itself reads lastKey. One named function, so
    // Qt.callLater runs it once with the player current by then: a closure
    // per change queued a stale key behind the current one, and two
    // players (a paused Spotify, a stopped browser tab) took turns forever.
    Qt.callLater(rememberPlayer)
    syncPosition()
  }

  function rememberPlayer() {
    var key = Media.playerKey(player)
    if (key !== "") lastKey = key
  }

  function syncPosition() {
    position = player && player.positionSupported ? Math.max(0, player.position) : 0
  }

  function syncOrder() {
    var next = {}
    var serial = playSerial
    for (let i = 0; i < players.length; i++) {
      let p = players[i]
      let key = Media.playerKey(p)
      if (!key || !p.isPlaying) continue
      if (playOrder[key] === undefined) next[key] = ++serial
      else next[key] = playOrder[key]
    }
    playSerial = serial
    playOrder = next
  }

  function playPause() {
    if (!player) return
    if (player.canTogglePlaying) player.togglePlaying()
    else if (player.isPlaying && player.canPause) player.pause()
    else if (player.canPlay) player.play()
  }

  function next() { if (canNext) player.next() }
  function previous() { if (canPrevious) player.previous() }

  function seek(fraction) {
    if (!canSeek) return
    player.position = Math.max(0, Math.min(1, fraction)) * length
    syncPosition()
  }

  function setVolume(value) {
    if (volumeSupported) player.volume = Math.max(0, Math.min(1, value))
  }

  // One wheel notch up (+1) or down (-1); false when there is nothing
  // playing whose volume can be set, so the caller can do something else.
  function stepVolume(notches) {
    if (!playing || !volumeSupported) return false
    player.volume = Media.stepVolume(player.volume, notches)
    return true
  }

  // Playing state changes re-rank players; Instantiator gives one listener
  // per player without polling.
  Instantiator {
    model: root.players
    delegate: Connections {
      required property var modelData
      target: modelData
      function onIsPlayingChanged() { root.syncOrder(); root.syncPosition() }
      function onPostTrackChanged() { root.syncPosition() }
    }
  }

  onPlayersChanged: syncOrder()

  Connections {
    target: root.player
    function onPositionChanged() { root.syncPosition() }
  }

  Timer {
    interval: 1000
    repeat: true
    running: root.watchers > 0 && root.playing
    triggeredOnStart: true
    onTriggered: root.syncPosition()
  }
}
