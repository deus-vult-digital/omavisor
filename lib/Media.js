.pragma library

// Which MPRIS player the Media module shows, and how its state reads.
// The helpers are the stock media service's (services/media/MediaModel.js);
// the pick is a smaller version of its selectActivePlayer: Omavisor has no
// Pipewire stream matching and no source cycling. Pure, so it is unit tested
// with plain objects standing in for MprisPlayer.

// playerctld re-exports another player; prefer the real one.
function isProxyPlayer(player) {
  var dbusName = String(player && player.dbusName || "").toLowerCase()
  var desktopEntry = String(player && player.desktopEntry || "").toLowerCase()
  return dbusName.indexOf("playerctld") !== -1 || desktopEntry === "playerctld"
}

function hasTrackMetadata(player) {
  return !!(player && (player.trackTitle || player.trackArtist || player.trackAlbum || player.trackArtUrl))
}

function playerCanControl(player) {
  return !!(player && (player.canTogglePlaying || player.canPlay || player.canPause || player.canGoNext || player.canGoPrevious))
}

function playerKey(player) {
  if (!player) return ""
  return String(player.dbusName || player.desktopEntry || player.identity || "")
}

// The player to show: the playing one (the one that started playing most
// recently when several do), then the last one shown, then any with a
// title or artist (a paused Spotify beats a stopped browser tab that only
// left an art file behind), then any with other track data, then any that
// can be controlled. Proxies lose ties.
// `order` maps playerKey → a serial that grows each time a player starts
// playing; `lastKey` is the player shown before.
function pick(players, order, lastKey) {
  var list = players || []
  var map = order || {}
  var best = null
  var bestRank = -1
  var bestSerial = -1

  for (var i = 0; i < list.length; i++) {
    var p = list[i]
    if (!p) continue
    var key = playerKey(p)
    var rank = 0
    if (p.isPlaying) rank = 5
    else if (key !== "" && key === lastKey && (hasTrackMetadata(p) || playerCanControl(p))) rank = 4
    else if (p.trackTitle || p.trackArtist) rank = 3
    else if (hasTrackMetadata(p)) rank = 2
    else if (playerCanControl(p)) rank = 1
    else continue
    rank = rank * 2 + (isProxyPlayer(p) ? 0 : 1)
    var serial = map[key] === undefined ? -1 : map[key]
    if (rank > bestRank || (rank === bestRank && serial > bestSerial)) {
      best = p
      bestRank = rank
      bestSerial = serial
    }
  }
  return best
}

// Fraction of the track played, 0 when the length is unknown.
function progress(position, length) {
  var len = Number(length)
  var pos = Number(position)
  if (!isFinite(len) || len <= 0 || !isFinite(pos)) return 0
  return Math.max(0, Math.min(1, pos / len))
}

// One wheel notch of volume, clamped to 0..1 and snapped to 5% steps.
function stepVolume(volume, notches) {
  var v = Number(volume)
  if (!isFinite(v)) v = 0
  var next = Math.round((v + 0.05 * Number(notches || 0)) * 20) / 20
  return Math.max(0, Math.min(1, next))
}

// "Artist · Album" style detail line from the parts present.
function joinParts(parts) {
  var out = []
  for (var i = 0; i < parts.length; i++) {
    var s = String(parts[i] === undefined || parts[i] === null ? "" : parts[i]).replace(/^\s+|\s+$/g, "")
    if (s !== "" && out.indexOf(s) === -1) out.push(s)
  }
  return out.join(" · ")
}

// Web art goes through a bounded download (artFetchArgs) into a local file,
// and only that file reaches an Image: the marketplace review asks for no
// remote URL in Image.source. The file is named from the URL, so a new track
// gets a new file and a cached one is never shown for the wrong track.
var ART_MAX_BYTES = 5 * 1024 * 1024
var ART_MAX_SECONDS = 8

function artFileName(url) {
  // FNV-1a, 32 bit: a name, not a security boundary.
  var h = 0x811c9dc5
  var u = String(url)
  for (var i = 0; i < u.length; i++) {
    h ^= u.charCodeAt(i)
    h = Math.imul(h, 0x01000193) >>> 0
  }
  return "art-" + ("0000000" + h.toString(16)).slice(-8)
}

// curl's argv for one web art URL into `out`: http(s) only, also after
// redirects (at most 3), at most ART_MAX_BYTES and ART_MAX_SECONDS, failing
// on an HTTP error. "" when the URL is not http(s).
function artFetchArgs(url, out) {
  var u = String(url === undefined || url === null ? "" : url).trim()
  if (!/^https?:\/\//i.test(u) || !out) return []
  return ["curl", "-sSfL", "--proto", "=http,https", "--proto-redir", "=http,https",
    "--max-redirs", "3", "--max-time", String(ART_MAX_SECONDS),
    "--max-filesize", String(ART_MAX_BYTES), "-o", out, "--", u]
}

// The art URL when it points at this machine (file:, data:, a bare path).
// A web (http/https) URL only with allowRemote (`remoteArt` setting): that
// is the only network request Omavisor makes besides Open-Meteo. Anything
// else gives "", so nothing is fetched.
function localArt(url, allowRemote) {
  var u = String(url === undefined || url === null ? "" : url).replace(/^\s+|\s+$/g, "")
  if (/^file:\/\//i.test(u) || /^data:image\//i.test(u)) return u
  if (u.charAt(0) === "/") return "file://" + u
  if (allowRemote && /^https?:\/\//i.test(u)) return u
  return ""
}
