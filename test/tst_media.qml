import QtQuick
import QtTest
import "../lib/Media.js" as Media

TestCase {
  name: "Media"

  function test_artFetch() {
    var a = Media.artFileName("https://i.scdn.co/image/abc")
    verify(/^art-[0-9a-f]{8}$/.test(a))
    compare(Media.artFileName("https://i.scdn.co/image/abc"), a)
    verify(Media.artFileName("https://i.scdn.co/image/abd") !== a)
    var args = Media.artFetchArgs("https://x.test/a.jpg", "/tmp/o")
    compare(args[0], "curl")
    verify(args.indexOf("--max-filesize") !== -1)
    verify(args.indexOf("--max-time") !== -1)
    compare(args[args.indexOf("--proto") + 1], "=http,https")
    compare(args[args.indexOf("--proto-redir") + 1], "=http,https")
    compare(args.slice(-3), ["/tmp/o", "--", "https://x.test/a.jpg"])
    compare(Media.artFetchArgs("file:///a.png", "/tmp/o"), [])
    compare(Media.artFetchArgs("ftp://x/a", "/tmp/o"), [])
    compare(Media.artFetchArgs("https://x/a", ""), [])
  }

  function player(props) {
    var p = { dbusName: "", identity: "", isPlaying: false, trackTitle: "", canPlay: false }
    for (let k in props) p[k] = props[k]
    return p
  }

  function test_pickNone() {
    compare(Media.pick([], {}, ""), null)
    compare(Media.pick([player({ dbusName: "a" })], {}, ""), null)
  }

  function test_pickPlayingFirst() {
    var paused = player({ dbusName: "mpv", trackTitle: "A", canPlay: true })
    var playing = player({ dbusName: "chromium", trackTitle: "B", isPlaying: true })
    compare(Media.pick([paused, playing], {}, ""), playing)
  }

  function test_pickNewestPlaying() {
    var a = player({ dbusName: "a", trackTitle: "A", isPlaying: true })
    var b = player({ dbusName: "b", trackTitle: "B", isPlaying: true })
    compare(Media.pick([a, b], { a: 3, b: 1 }, ""), a)
    compare(Media.pick([a, b], { a: 1, b: 3 }, ""), b)
  }

  function test_pickRealOverProxy() {
    var proxy = player({ dbusName: "org.mpris.MediaPlayer2.playerctld", trackTitle: "A", isPlaying: true })
    var real = player({ dbusName: "org.mpris.MediaPlayer2.mpv", trackTitle: "A", isPlaying: true })
    compare(Media.pick([proxy, real], {}, ""), real)
  }

  function test_pickKeepsLastWhenPaused() {
    var a = player({ dbusName: "a", trackTitle: "A", canPlay: true })
    var b = player({ dbusName: "b", trackTitle: "B", canPlay: true })
    compare(Media.pick([a, b], {}, "b"), b)
  }

  function test_pickTitledOverArtOnly() {
    var brave = player({ dbusName: "brave", trackArtUrl: "file:///tmp/x", canPlay: true })
    var spotify = player({ dbusName: "spotify", trackTitle: "Song", canPlay: true })
    compare(Media.pick([brave, spotify], {}, ""), spotify)
  }

  function test_progressAndVolume() {
    compare(Media.progress(30, 120), 0.25)
    compare(Media.progress(30, 0), 0)
    compare(Media.progress(200, 120), 1)
    compare(Media.stepVolume(0.5, 1), 0.55)
    compare(Media.stepVolume(0.98, 1), 1)
    compare(Media.stepVolume(0.02, -1), 0)
    compare(Media.stepVolume(0.33, -1), 0.3)
  }

  function test_joinParts() {
    compare(Media.joinParts(["Artist", "", "Album"]), "Artist · Album")
    compare(Media.joinParts(["Same", "Same"]), "Same")
    compare(Media.joinParts([null, undefined]), "")
  }

  function test_localArtOnly() {
    compare(Media.localArt("file:///tmp/art.png"), "file:///tmp/art.png")
    compare(Media.localArt("/tmp/art.png"), "file:///tmp/art.png")
    compare(Media.localArt("data:image/png;base64,AA"), "data:image/png;base64,AA")
    compare(Media.localArt("https://i.scdn.co/image/x"), "")
    compare(Media.localArt("http://example.com/a.jpg"), "")
    compare(Media.localArt(undefined), "")
    compare(Media.localArt("https://i.scdn.co/image/x", true), "https://i.scdn.co/image/x")
    compare(Media.localArt("ftp://x/y.png", true), "")
    compare(Media.localArt("file:///tmp/a.png", true), "file:///tmp/a.png")
  }
}
