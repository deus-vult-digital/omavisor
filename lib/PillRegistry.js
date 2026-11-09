.pragma library

// Shared between Omavisor's per-monitor pills and its Hub panel.
//
// shell.summon/hide/toggle route a plugin that also declares a panel kind to
// the panel loader, never to its bar widget, and the scoped facades hand a
// panel no bar reference. Both live in one QML engine, where a `.pragma
// library` script is a single shared instance, so each pill registers here
// and the Hub picks the one on the focused output. Only live objects Omavisor
// itself created are stored; nothing crosses a process.

var pills = []
var hubs = []

function register(pill) {
  if (pill && pills.indexOf(pill) < 0) pills.push(pill)
  changed()
}

function unregister(pill) {
  var index = pills.indexOf(pill)
  if (index >= 0) pills.splice(index, 1)
  changed()
}

function registerHub(hub) {
  if (hub && hubs.indexOf(hub) < 0) hubs.push(hub)
  changed()
}

function unregisterHub(hub) {
  var index = hubs.indexOf(hub)
  if (index >= 0) hubs.splice(index, 1)
}


// A hub open and holding the keyboard. One the hover opened does not count:
// the shell's `toggle` then summons it (which hands it the keyboard) instead
// of hiding it.
function anyHoldingKeys() {
  for (var i = 0; i < pills.length; i++) {
    if (pills[i] && pills[i].opened === true && pills[i].holdsKeys === true) return true
  }
  return false
}

// A pill's state changed: push it to every Hub, whose `opened` the shell
// reads to decide whether `toggle` means summon or hide.
function changed() {
  var open = anyHoldingKeys()
  for (var i = 0; i < hubs.length; i++) {
    if (hubs[i]) hubs[i].opened = open
  }
}

// Every live pill.
function each(fn) {
  for (var i = 0; i < pills.length; i++) if (pills[i]) fn(pills[i])
}

// Rank like the bar's own panel routing: an open pill first, then one that
// is drawn (the bar can keep a zero-size placeholder copy of a center
// module), then any.
function rank(pill) {
  if (pill.opened === true) return 2
  return pill.width > 0 && pill.visible !== false ? 1 : 0
}

// The best pill on `screenName`, or the best live one anywhere when no pill
// sits on that output (a monitor without a bar, or one unplugged since).
function pick(screenName) {
  var name = String(screenName || "")
  var best = null
  var bestHere = null
  for (var i = 0; i < pills.length; i++) {
    var pill = pills[i]
    if (!pill || typeof pill.open !== "function") continue
    if (!best || rank(pill) > rank(best)) best = pill
    if (name !== "" && String(pill.screenName || "") === name
        && (!bestHere || rank(pill) > rank(bestHere))) bestHere = pill
  }
  return bestHere || best
}

function openOn(screenName, tab) {
  var pill = pick(screenName)
  if (!pill) return false
  pill.open(tab)
  return true
}

function closeAll() {
  for (var i = 0; i < pills.length; i++) {
    if (pills[i] && pills[i].opened === true) pills[i].close()
  }
}
