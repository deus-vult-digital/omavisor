import QtQuick
import Quickshell
import qs.Commons as Commons
import "../lib/Theme.js" as Theme

// Theme switcher (SPEC.md section 7, v1), all through Omarchy's own
// commands: `omarchy theme list` for the cards (exactly what it prints, in
// its order), `omarchy theme current` for the marked one, and per theme
// `omarchy theme dir <slug>` for its preview image and colors.toml swatches.
// Applying runs `omarchy theme set "<name>"`; the extras are
// `omarchy theme bg next` and the built-in switcher.
//
// Nothing polls: `refresh()` runs when the Theme tab appears, and the
// current theme is read again after an apply and whenever the shell's
// colors change (a theme set from anywhere else).
Item {
  id: root
  visible: false

  // The dispatcher answers; hidden once `omarchy` turns out missing.
  readonly property bool available: !listProbe.missing
  property var names: []
  property string current: ""
  // The name being applied, until `omarchy theme set` is done.
  property string applying: ""
  property var dump: ({})
  readonly property var cards: Theme.cards(names, dump, applying !== "" ? applying : current)
  readonly property bool loading: listProbe.running || dumpProbe.running

  function refresh() {
    listProbe.run()
    currentProbe.run()
  }

  function apply(name) {
    if (!name || applying !== "" || Theme.same(name, current)) return
    // Detached, like every other user action: the theme set must finish
    // (hooks, previews) whatever happens to the shell meanwhile.
    applying = String(name)
    Quickshell.execDetached(["omarchy", "theme", "set", applying])
    applyGuard.restart()
  }

  function nextBackground() {
    Quickshell.execDetached(["omarchy", "theme", "bg", "next"])
  }

  function openSwitcher() {
    Quickshell.execDetached(["omarchy", "theme", "switcher"])
  }

  // One process for every theme's directory, preview and colors: a header
  // line per theme, then its colors.toml. The preview is found the way the
  // built-in switcher does: preview.<image ext> in any case, else the first
  // background. `omarchy theme set` lays a user copy over the official one,
  // so what a user copy lacks comes from the official theme.
  readonly property string dumpScript: "o=\"${OMARCHY_PATH:-/usr/share/omarchy}/themes\"; "
    + "for t; do d=$(omarchy theme dir \"$t\") || continue; p=''; "
    + "for dir in \"$d\" \"$o/$t\"; do [ -n \"$p\" ] || p=$(find -L \"$dir\" -maxdepth 1 -type f \\( -iname preview.png -o -iname preview.jpg -o -iname preview.jpeg -o -iname preview.webp -o -iname preview.gif -o -iname preview.bmp \\) 2>/dev/null | sort | head -n 1); done; "
    + "for dir in \"$d\" \"$o/$t\"; do [ -n \"$p\" ] || p=$(find -L \"$dir/backgrounds\" -maxdepth 1 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.gif' -o -iname '*.bmp' \\) 2>/dev/null | sort | head -n 1); done; "
    + "c=\"$d/colors.toml\"; [ -f \"$c\" ] || c=\"$o/$t/colors.toml\"; "
    + "printf '@@omavisor-theme\\t%s\\t%s\\t%s\\n' \"$t\" \"$d\" \"$p\"; cat \"$c\" 2>/dev/null; echo; done"

  Probe {
    id: listProbe
    command: ["omarchy", "theme", "list"]
    onFinished: function(code, output) {
      if (code !== 0) return
      var list = Theme.parseList(output)
      root.names = list
      var slugs = list.map(Theme.slug)
      dumpProbe.run(["sh", "-c", root.dumpScript, "sh"].concat(slugs))
    }
  }

  Probe {
    id: dumpProbe
    timeoutMs: 10000
    onFinished: function(code, output) { if (code === 0) root.dump = Theme.parseDump(output) }
  }

  Probe {
    id: currentProbe
    command: ["omarchy", "theme", "current"]
    onFinished: function(code, output) {
      if (code !== 0) return
      root.current = output.trim()
      if (root.applying !== "" && Theme.same(root.applying, root.current)) { root.applying = ""; applyGuard.stop() }
    }
  }

  // The shell's colors change when the set lands; give up the mark after
  // a minute in case it never does (an invalid theme).
  Timer {
    id: applyGuard
    interval: 60000
    onTriggered: { root.applying = ""; currentProbe.run() }
  }

  Connections {
    target: Commons.Color
    function onShellValuesChanged() { currentProbe.run() }
  }

  Component.onCompleted: currentProbe.run()
}
