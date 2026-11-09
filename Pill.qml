pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "ui"
import "modules"
import "lib/BarGeometry.js" as BarGeometry
import "lib/Catalog.js" as Catalog
import "lib/Customize.js" as Customize
import "lib/Settings.js" as Settings
import "lib/PillRegistry.js" as PillRegistry
import "lib/ActivityStore.js" as ActivityStore

// Omavisor's pill in the bar: what `pillItems` lists, and live activities.
//
// With `openOn: "hover"` (the default) resting the pointer on the pill for
// `peekDelayMs` opens the hub (a click opens it at once), and it collapses
// shortly after the pointer has left both pill and hub. Nothing holds input
// while it is open that way: no focus grab, and no keyboard focus unless the
// pointer is on the card, so the window under the pointer keeps getting clicks
// and keys. With `openOn: "click"`
// only clicks open it, and a click outside closes it (the stock popups'
// behaviour). A hub opened from a keybind or IPC closes on a click outside,
// Esc, the same keybind again, or once the pointer has been in and left.
// Keybind, IPC and click-mode opens take the keyboard for the in-hub keys,
// and so does the same keybind or IPC on a hub the hover opened. A hover hub
// also has the keys while the pointer is on its card (see HubPopup).
// Right click swaps `format` and `formatAlt` (the stock clock's gesture). On a
// left/right bar it shows the compact `verticalFormat` stack instead. After
// the clock come the weather glyph and temperature, as `omarchy weather
// icon` / `status` print them (a leading "~" while the reading is stale).
// Scrolling sets the playing player's volume, else switches workspace
// (`scrollAction`). One
// pill exists per monitor; the Hub panel reaches them through PillRegistry.
BarWidget {
  id: root
  moduleName: "dev.deusvult.omavisor"

  // Through the editor, so a change on the Settings page shows before it is
  // written.
  readonly property var config: Settings.resolve(editor.current)
  // `reduceMotion`: "on" stops Omavisor's animations, "off" keeps them, and
  // "auto" follows the shell's own switch (omarchy toggle animations).
  readonly property bool motionOff: config.reduceMotion === "on" || (config.reduceMotion === "auto" && Style.reduceMotion)

  SettingsEditor {
    id: editor
    settings: root.settings
    shell: root.bar ? root.bar.shell : null
    pluginId: root.moduleName
  }

  // Session-only: the alternate format is a glance, not a setting change, so
  // Omavisor never writes shell.json from a click.
  property bool showAlt: false

  readonly property string activeFormat: vertical
    ? (showAlt ? config.verticalFormatAlt : config.verticalFormat)
    : (showAlt ? config.formatAlt : config.format)
  // What `pillItems` puts on the pill. In wrap mode the stock clock and weather
  // stay on the bar, so by default it is only the activities glyph (and the
  // activity around it, the badge).
  readonly property var pillParts: Catalog.pillParts(config, service, vertical)
  readonly property bool showClock: pillParts.indexOf("clock") !== -1
  readonly property bool showBadge: config.pillItems.indexOf("badge") !== -1
  readonly property var verticalLines: pillParts.map(function(part) { return part === "glyph" ? "󱐋" : clock.text }).join("\n").split("\n")

  // Omavisor's service (weather, media), shared by every pill. The shell may
  // load it after the bar, so look it up again until it is there.
  property var service: null
  readonly property var weather: service ? service.weather : null
  readonly property var media: service ? service.media : null
  readonly property bool showWeather: pillParts.indexOf("weather") !== -1 && !!weather
  readonly property string weatherText: showWeather
    ? (weather.glyph !== "" ? weather.glyph + " " : "") + (weather.stale ? "~" : "") + weather.temp : ""
  // Now playing: while a player plays, one spot left of the clock shows the
  // album art or a small level meter (pill items `media` and `meter`, which
  // share it: Catalog.pillSpot). The spot keeps its room while either is
  // listed, so the pill never changes width for music and a track change
  // shows nothing. The title is in the Now playing view.
  readonly property bool playing: !!media && media.playing === true
  readonly property string spot: vertical ? "" : Catalog.pillSpot(config)
  readonly property real artSize: Math.round(button.fontSize * 1.25)

  // ---- What the pill draws along a top or bottom bar, in order
  //      (Catalog.pillRow): `dragOrder` while a part is being dragged.
  property var dragOrder: []
  property string dragId: ""
  readonly property bool dragging: dragId !== ""
  readonly property var rowIds: vertical ? [] : (dragOrder.length > 0 ? dragOrder : Catalog.pillRow(config, service))
  // The row's entries: the parts, with a separator between two text parts.
  readonly property var rowEntries: {
    let out = []
    for (let i = 0; i < rowIds.length; i++) {
      let id = rowIds[i]
      let text = Catalog.MEDIA_SPOT.indexOf(id) === -1
      let prevText = i > 0 && Catalog.MEDIA_SPOT.indexOf(rowIds[i - 1]) === -1
      if (i > 0 && text && prevText) out.push({ kind: "sep", id: "sep" + i })
      out.push({ kind: "part", id: id })
    }
    return out
  }
  function partText(id) {
    return id === "glyph" ? "󱐋" : id === "weather" ? weatherText : id === "clock" ? clock.text : ""
  }
  // The part under x (in the pill), or "".
  function partAt(x) {
    let kids = pillRow.children
    let px = x - pillRow.x
    let half = pillRow.spacing / 2
    for (let i = 0; i < kids.length; i++) {
      let k = kids[i]
      if (!("partId" in k) || k.isSep) continue
      if (px >= k.x - half && px <= k.x + k.width + half) return k.partId
    }
    return ""
  }
  // Moves the dragged part to where x is among the others.
  function dragTo(x) {
    let px = x - pillRow.x
    let kids = pillRow.children
    let index = 0
    for (let i = 0; i < kids.length; i++) {
      let k = kids[i]
      if (!("partId" in k) || k.isSep || k.partId === dragId) continue
      if (px > k.x + k.width / 2) index++
    }
    let next = dragOrder.filter(function(id) { return id !== dragId })
    next.splice(index, 0, dragId)
    if (next.join(" ") !== dragOrder.join(" ")) dragOrder = next
  }
  function endDrag(save) {
    if (dragId === "") return
    if (save) {
      let list = Customize.movePillItem(config.pillItems, Catalog.pillRow(config, service), dragId, dragOrder.indexOf(dragId))
      if (list.join(" ") !== config.pillItems.join(" ")) editor.change({ pillItems: list })
    }
    dragId = ""
    dragOrder = []
  }
  // Shown while a player plays and no activity holds the sides.
  readonly property bool spotLive: spot !== "" && playing && !peek.activity
  readonly property bool showArt: spotLive && spot === "media"
  readonly property bool showMeter: spotLive && spot === "meter"
  // The meter asks for real levels (cava, VisualizerModule) while it shows.
  readonly property var visualizer: service ? service.visualizer : null
  onShowMeterChanged: if (visualizer) visualizer.watchers += showMeter ? 1 : -1
  // Playback starting or a new track: the next open lands on Now playing,
  // whatever was viewed last. A tab picked after that stays until the next
  // one. Nothing opens, and an open hub is never switched under you.
  Connections {
    target: root.media
    function onTitleChanged() { root.followTrack() }
    function onPlayingChanged() { root.followTrack() }
  }
  function followTrack() {
    if (!media || !media.playing || opened) return
    if (Catalog.shownTabs(config, service).indexOf("media") !== -1) hub.currentTab = "media"
  }
  readonly property string labelText: pillParts.map(function(part) {
    return part === "glyph" ? "󱐋" : part === "weather" ? root.weatherText : part === "media" ? "" : clock.text
  }).filter(function(text) { return text !== "" }).join("  ·  ")

  function findService() {
    if (service) return
    var api = bar ? bar.shell : null
    if (api && typeof api.serviceFor === "function") service = api.serviceFor(moduleName) || null
  }

  onBarChanged: findService()

  // Every second for the first minute, then every 30 s, so a service that
  // loads late (enabled later, or reloaded after a failure) is still found.
  // The third-party shell facade has no signal for a service registering.
  property int serviceLookups: 0
  Timer {
    interval: root.serviceLookups < 60 ? 1000 : 30000
    repeat: true
    running: !root.service
    onTriggered: { root.serviceLookups++; root.findService() }
  }

  Binding {
    when: !!root.activities
    target: root.activities
    property: "rules"
    value: root.config.activityRules
    restoreMode: Binding.RestoreNone
  }

  Binding {
    when: !!root.weather
    target: root.weather
    property: "unit"
    value: root.config.unit
    // Every pill writes the same shared value; a pill going away (monitor
    // unplugged) must not put back what it found.
    restoreMode: Binding.RestoreNone
  }

  Binding {
    when: !!root.service
    target: root.service ? root.service.updates : null
    property: "pollMinutes"
    value: root.config.updatePollMinutes
    restoreMode: Binding.RestoreNone
  }

  Binding {
    when: !!root.service && !!root.service.packages
    target: root.service ? root.service.packages : null
    property: "pollMinutes"
    value: root.config.pkgPollMinutes
    restoreMode: Binding.RestoreNone
  }

  Binding {
    when: !!root.service && !!root.service.stats
    target: root.service ? root.service.stats : null
    property: "intervalMs"
    value: root.config.statsWhileOpenMs
    restoreMode: Binding.RestoreNone
  }

  Binding {
    when: !!root.media
    target: root.media
    property: "remoteArt"
    value: root.config.remoteArt
    restoreMode: Binding.RestoreNone
  }

  // auto: the playing player's volume, else workspaces.
  // Wheel deltas add up to whole notches (120 each), so a touchpad or a
  // high-resolution wheel steps once per notch, not once per event.
  property real wheelAccum: 0

  function scroll(delta) {
    if (delta === 0) return
    if (wheelAccum !== 0 && (wheelAccum > 0) !== (delta > 0)) wheelAccum = 0
    wheelAccum += delta
    if (Math.abs(wheelAccum) < 120) return
    var notches = wheelAccum > 0 ? 1 : -1
    wheelAccum = 0
    step(notches)
  }

  // One wheel notch (`omavisor scroll` too): up is positive.
  function step(notches) {
    var action = config.scrollAction
    if ((action === "auto" || action === "volume") && media && media.stepVolume(notches)) return
    if (action === "auto" || action === "workspace") {
      let target = notches > 0 ? "e-1" : "e+1"
      Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.focus({ workspace = \"" + target + "\" })"])
    }
  }

  // The output this bar instance draws on, so a keybind toggle can pick the
  // pill on the focused monitor.
  readonly property string screenName: root.QsWindow.window && root.QsWindow.window.screen
    ? String(root.QsWindow.window.screen.name || "") : ""

  readonly property bool hoverMode: config.openOn === "hover"
  readonly property bool pointerInside: pillHover.hovered || capHover.hovered || hub.containsMouse

  // How the open hub was opened: "hover", "click" or "keyboard".
  property string openedBy: ""
  // The pointer has been over pill or hub since it opened.
  property bool pointerVisited: false
  // Hyprland drops the pointer from under the bar while the hub primes the
  // keyboard and gives it back: that coming back is not a visit.
  property real keysTakenAt: 0
  // A popout a hosted widget opened (Widgets tab) holds the hub open, and so
  // does the Settings page: on it a click outside or Esc closes the hub.
  readonly property bool onSettings: hub.currentTab === Catalog.SETTINGS_TAB.id
  // Leaving it is no reason to close: with the pointer long gone only a new visit
  // counts, and the same if the card shrinks out from under it (settingsLeftAt).
  // A pointer still on the card closes the hub when it goes, as on any tab.
  property real settingsLeftAt: 0
  onOnSettingsChanged: if (!onSettings && opened) {
    settingsLeftAt = Date.now()
    pointerVisited = pointerInside
  }
  readonly property bool closesOnLeave: opened && (!onSettings || blooming)
    && (openedBy === "keyboard" || openedBy === "bloom" ? pointerVisited : hoverMode)
  onClosesOnLeaveChanged: if (closesOnLeave && !pointerInside) closeTimer.restart()

  // ---- Live activities (Service.qml): the badge, peek and bloom.
  //      (`service` is looked up above.)
  readonly property var activities: service ? service.activities : null
  readonly property var topActivity: activities ? activities.first : null
  // What the collapsed pill shows of it, without taking away the peek.
  readonly property var badgeActivity: showBadge ? topActivity : null
  // Peek for 4 s on a new activity; with openOn "click" also while hovered
  // (in hover mode hovering opens the hub instead).
  property bool peekHeld: false
  readonly property bool peeking: !opened && !vertical && topActivity !== null
    && (peekHeld || (!hoverMode && pointerInside))
  // A bloom is the hub opened short, showing one urgent activity.
  property string bloomId: ""
  readonly property bool blooming: opened && openedBy === "bloom"
  // The card keeps the bloom's look until it has fully closed, so a closing
  // bloom never flashes the full hub.
  property bool bloomLook: false
  readonly property var bloomActivity: {
    var list = activities ? activities.items : []
    for (let i = 0; i < list.length; i++) if (list[i].id === bloomId) return list[i]
    return null
  }
  // The 4 s peek is about the activity that just arrived, not the top one.
  readonly property var peekActivity: {
    if (!peekHeld || !activities) return topActivity
    var list = activities.items
    for (let i = 0; i < list.length; i++) if (list[i].id === activities.peekId) return list[i]
    return topActivity
  }
  property real nowMs: Date.now()

  // ---- Open state for the Hub route and PillRegistry (open/close/opened).
  //      The bar's popout identity is the HubPopup itself.
  readonly property bool opened: hub.open
  readonly property bool holdsKeys: hub.takeKeys
  onHoldsKeysChanged: PillRegistry.changed()
  property bool popoutSwitchClosing: false

  onOpenedChanged: {
    if (opened) cap.sync()
    // Like the stock clock: while the hub is open, hovering the center must
    // not reveal the hidden indicators, which would shift the pill (and the
    // cap with it) away from the card.
    // Deferred like the stock clock: opening hands the popout over, and the
    // panel being closed clears this shared flag on its way out.
    if (opened) Qt.callLater(function() { if (root.opened) root.setRevealSuppressed(true) })
    else setRevealSuppressed(false)
    PillRegistry.changed()
  }
  onWidthChanged: cap.sync()
  onHeightChanged: cap.sync()

  // `open(tab)` is the shell's route (keybind, IPC); the bar's own gestures
  // pass how they opened it.
  function open(tab, by) {
    var name = Settings.normalizeTab(tab)
    if (name !== "" && !Catalog.tabAvailable(name, service, config)) name = ""
    // By name, a tab opens even if it is hidden from the strip.
    // A plain open after closing on Settings goes on from where that came from.
    if (name !== "") hub.currentTab = name
    else if (!opened) hub.currentTab = Catalog.startTab(onSettings ? hub.settingsBack : hub.currentTab, Catalog.shownTabs(config, service), by)
    if (!opened) hub.settingsBack = ""
    // A bloom grows into the full hub.
    if (opened && openedBy === "bloom") {
      bloomTimer.stop()
      bloomLook = false
      openedBy = by || "keyboard"
      if (name === "") hub.currentTab = "activities"
      if (holdsKeys) {
        pointerVisited = false
        keysTakenAt = Date.now()
        hub.remapForKeys()
      }
      return
    }
    // A keybind or IPC open on a hub without the keyboard takes it. The
    // pointer is likely on it, and moving it out of the way must not close
    // what the user just reached for: only a new visit counts.
    if (opened) {
      if ((by || "keyboard") === "keyboard" && !holdsKeys) {
        openedBy = "keyboard"
        pointerVisited = false
        keysTakenAt = Date.now()
        hub.remapForKeys()
      } else if ((by || "keyboard") === "keyboard") hub.landAgain()
      return
    }
    bloomLook = false
    openedBy = by || "keyboard"
    pointerVisited = openedBy !== "keyboard" && pointerInside
    keysTakenAt = Date.now()
    hub.open = true
  }

  function close() {
    openTimer.stop()
    closeTimer.stop()
    bloomTimer.stop()
    editor.flush()
    hub.open = false
    openedBy = ""
    pointerVisited = false
  }

  function togglePanel() {
    if (opened) close()
    else open("", "keyboard")
  }

  function closeForPopoutSwitch() {
    popoutSwitchClosing = true
    close()
    Qt.callLater(function() { root.popoutSwitchClosing = false })
  }

  function cycleFormat() {
    showAlt = !showAlt
  }

  function setRevealSuppressed(value) {
    if (bar && typeof bar.setCenterHoverRevealSuppressed === "function")
      bar.setCenterHoverRevealSuppressed(value)
  }

  // A click on a hub the hover just opened keeps it open (the user was
  // reaching for it); otherwise a click toggles.
  function leftClick() {
    openTimer.stop()
    if (stopRecordingAt()) return
    if (blooming) open("", "click")
    else if (opened && openedBy === "hover") openedBy = "click"
    else if (opened) close()
    else open("", "click")
  }

  // While recording, a click on the pill's REC side (left of the clock)
  // stops it. The button's MouseArea takes every press (a child MouseArea
  // in the peek never got one, tested), so the side is found from where
  // the pointer is.
  function stopRecordingAt() {
    var rec = service ? service.recording : null
    var shown = peek.activity
    if (!rec || !rec.recording || vertical || !shown || shown.id !== rec.activityId || !pillHover.hovered) return false
    var p = peek.mapFromItem(root, pillHover.point.position.x, pillHover.point.position.y)
    if (!peek.inLead(p.x)) return false
    rec.stop()
    return true
  }

  // Bloom an urgent activity (called by the service on the focused
  // monitor's pill). It never takes over another open bar popup (then it
  // peeks) or the open hub (where the Activities tab already lists it).
  function bloom(id) {
    // A newer one replaces the bloom on screen.
    if (blooming) {
      bloomId = id
      bloomTimer.restart()
      return
    }
    var other = bar ? bar.activePopout : null
    if (opened || (other && other !== hub)) {
      // Peek this one (the peek shows the last announced activity).
      if (activities) activities.announce(id)
      return
    }
    bloomId = id
    bloomLook = true
    openedBy = "bloom"
    pointerVisited = pointerInside
    hub.open = true
    bloomTimer.restart()
  }

  // The bloomed activity ended and left: nothing to show any more.
  onBloomActivityChanged: if (blooming && bloomActivity === null) close()

  function showPeek() {
    peekHeld = true
    peekTimer.restart()
  }

  Connections {
    target: root.activities
    function onPeekSerialChanged() { if (!root.opened) root.showPeek() }
    // Only the pill the Hub route would pick (the focused monitor's) blooms.
    function onBloomRequested(id) {
      if (PillRegistry.pick(root.activities.focusedScreen) === root) root.bloom(id)
    }
  }

  Timer {
    id: peekTimer
    interval: 4000
    onTriggered: root.peekHeld = false
  }

  // A bloom shows for 6 s, longer while the pointer is on it.
  Timer {
    id: bloomTimer
    interval: 6000
    onTriggered: {
      if (!root.blooming) return
      if (root.pointerInside) restart()
      else root.close()
    }
  }

  // Countdowns tick once a second, only while one is on screen (a
  // recording's time is on the collapsed pill too).
  readonly property bool recordingShown: !vertical && !!badgeActivity && badgeActivity.since > 0
    && ActivityStore.isCounting(badgeActivity)
  Timer {
    running: (root.peeking || root.opened || root.recordingShown) && root.activities !== null
      && ActivityStore.hasCountdown(root.activities.items)
    repeat: true
    interval: 1000
    triggeredOnStart: true
    onTriggered: root.nowMs = Date.now()
  }

  onPointerInsideChanged: {
    if (pointerInside) {
      closeTimer.stop()
      if (opened && Date.now() - keysTakenAt > 500) pointerVisited = true
      else if (hoverMode) openTimer.restart()
    } else {
      openTimer.stop()
      if (Date.now() - settingsLeftAt < 500) pointerVisited = false
      if (closesOnLeave) closeTimer.restart()
    }
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Component.onCompleted: PillRegistry.register(root)
  Component.onDestruction: {
    if (showMeter && visualizer) visualizer.watchers -= 1
    editor.flush()
    if (opened) setRevealSuppressed(false)
    hub.open = false
    PillRegistry.unregister(root)
  }

  ClockModule {
    id: clock
    format: root.activeFormat
  }

  Timer {
    id: openTimer
    interval: root.config.peekDelayMs
    // Hovering never takes over a popup the user opened elsewhere on the
    // bar (the clock's calendar, say); a click still does.
    onTriggered: {
      var other = root.bar ? root.bar.activePopout : null
      if (root.pointerInside && !root.opened && !other && !root.dragging) root.open("", "hover")
    }
  }

  Timer {
    id: closeTimer
    interval: 300
    onTriggered: if (!root.pointerInside && root.closesOnLeave) root.close()
  }

  HoverHandler { id: pillHover }

  // The cap: the hub's surface reaching into the bar behind the label, from
  // the screen edge to the bar's inner edge, so the expanded card continues
  // it as one shape. Shown while the hub is open.
  BorderSurface {
    id: cap

    readonly property var window: root.QsWindow.window
    // Where the pill sits in the bar window. A mapping is not a live
    // binding, so it is refreshed whenever the hub starts to open.
    property point origin: Qt.point(0, 0)

    function sync() {
      if (window && window.contentItem) origin = window.contentItem.mapFromItem(root, 0, 0)
    }
    readonly property string edge: root.bar && root.bar.position ? String(root.bar.position) : "top"

    z: -1
    visible: opacity > 0
    opacity: hub.progress > 0 ? 1 : 0
    // The bar's strip across its window: from Omarchy 4.5 the window spans
    // its screen and the strip is only its edge (lib/BarGeometry.js).
    readonly property real windowDepth: window ? (root.vertical ? window.width : window.height) : 0
    readonly property real strip: window
      ? BarGeometry.strip(windowDepth, window.exclusiveZone, root.bar ? root.bar.barSize : 0)
      : (root.vertical ? root.width : root.height)
    readonly property real stripStart: BarGeometry.stripStart(edge, windowDepth, strip)

    // Across the bar, from the screen edge to exactly where the card starts
    // (the hub's barThickness, which can sit a little past the strip): so
    // the cap, its curves and the card meet on one line.
    readonly property bool farSide: edge === "bottom" || edge === "right"
    readonly property real cardEdge: hub.barThickness > 0 ? (farSide ? windowDepth - hub.barThickness : hub.barThickness) : (farSide ? stripStart : stripStart + strip)
    readonly property real spanFrom: farSide ? Math.min(stripStart, cardEdge) : stripStart
    readonly property real spanTo: farSide ? stripStart + strip : Math.max(stripStart + strip, cardEdge)

    x: root.vertical ? spanFrom - origin.x : 0
    y: root.vertical ? 0 : spanFrom - origin.y
    width: root.vertical ? spanTo - spanFrom : root.width
    height: root.vertical ? root.height : spanTo - spanFrom
    color: hub.surfaceColor
    // No border on the side that meets the card, and along a top or bottom
    // bar none on its sides either: those are drawn below, stopping where the
    // curves take over, so nothing is painted over (the fill may be see-through).
    readonly property string innerSide: edge === "top" ? "bottom" : edge === "bottom" ? "top" : edge === "left" ? "right" : "left"
    borderSpec: hub.withoutSides(hub.surfaceBorder, root.vertical ? [innerSide] : [innerSide, "left", "right"])
    // Square: it runs from the screen edge into the card's square side.
    radius: 0

    HoverHandler { id: capHover }

    // The side borders along a top or bottom bar, down to where the curves
    // take over.
    Repeater {
      model: root.vertical ? 0 : 2
      Rectangle {
        required property int index
        readonly property real w: hub.innerBorderWidth
        color: hub.innerBorderColor
        x: index === 0 ? 0 : cap.width - w
        y: root.capOnTop ? 0 : root.ear
        width: w
        height: Math.max(0, cap.height - root.ear)
      }
    }
  }

  // The curves joining the cap to the card (top and bottom bars), and the
  // stretch of the cap's side borders they take over.
  readonly property real ear: cap.visible ? hub.innerEar : 0
  readonly property bool capOnTop: cap.edge === "top"
  Fillet {
    z: -1
    r: root.ear
    x: cap.x - r
    y: root.capOnTop ? cap.y + cap.height - r : cap.y
    corner: root.capOnTop ? "bottomRight" : "topRight"
    fill: hub.surfaceColor
    strokeColor: hub.innerBorderColor
    strokeWidth: hub.innerBorderWidth
  }
  Fillet {
    z: -1
    r: root.ear
    x: cap.x + cap.width
    y: root.capOnTop ? cap.y + cap.height - r : cap.y
    corner: root.capOnTop ? "bottomLeft" : "topLeft"
    fill: hub.surfaceColor
    strokeColor: hub.innerBorderColor
    strokeWidth: hub.innerBorderWidth
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    // The pill draws its own parts (pillRow), so the art or levels spot can
    // sit anywhere among them and each part can be dragged.
    text: ""
    labelVisible: false
    hasVisualContent: root.vertical ? root.verticalLines.length > 0 : root.labelText !== ""
    // On a left/right bar the activity badge sits above the clock lines.
    fixedHeight: root.vertical ? (root.verticalLines.length + (root.badgeActivity ? 1 : 0)) * Style.bar.iconSlot : -1
    // Room for the activity on both sides of the clock.
    fixedWidth: root.vertical ? -1
      : pillRow.implicitWidth + button.scaledHorizontalMargin * 2 + peek.side * 2
    horizontalMargin: 8.75
    verticalPadding: 8.75
    // On the cap the label takes the hub's text colour, for as long as the
    // cap is shown (including the close animation).
    foreground: cap.visible
      ? (root.bar && root.bar.foreground ? root.bar.foreground : Commons.Color.popups.text)
      : (root.bar ? root.bar.barForeground : Commons.Color.foreground)
    Accessible.name: "Omavisor " + (root.showClock ? clock.text.replace(/\n/g, " ") : "")
      + (root.topActivity ? ", " + root.topActivity.title : "")
      + (root.playing ? ", playing " + root.media.title + (root.media.artist !== "" ? " by " + root.media.artist : "") : "")
      + (root.showWeather ? ", " + root.weather.tempWithUnit + (root.weather.condition !== "" ? " " + root.weather.condition : "") + (root.weather.stale ? ", not updated " + root.weather.updated : "") : "")
    Accessible.role: Accessible.Button

    // A left click comes from dragArea (it tells a click from a drag).
    onPressed: function(b) {
      if (b === Qt.RightButton) root.cycleFormat()
      else if (b === Qt.LeftButton && root.vertical) root.leftClick()
    }
    onWheelMoved: function(delta) { root.scroll(delta) }

    Peek {
      id: peek
      visible: !root.vertical
      anchors.fill: parent
      anchors.leftMargin: button.scaledHorizontalMargin
      anchors.rightMargin: button.scaledHorizontalMargin
      activity: root.vertical ? null : root.peeking ? root.peekActivity : root.badgeActivity
      edge: root.fixedEdge
      peeking: root.peeking
      now: root.nowMs
      reduceMotion: root.motionOff
      foreground: button.foreground
      urgentColor: button.activeColor
      fontFamily: button.fontFamily
      fontSize: button.fontSize
    }

    FontMetrics {
      id: pillMetrics
      font.family: button.fontFamily
      font.pixelSize: button.fontSize
    }

    // The parts, in a row (Catalog.pillRow): text figures on the bar's
    // middle as WidgetButton centres its own label, " · " between two text
    // parts, the art or levels spot as itself.
    Row {
      id: pillRow
      visible: !root.vertical
      anchors.centerIn: parent
      // Off centre by a wing when the pill grows one way (fixedEdge).
      anchors.horizontalCenterOffset: root.fixedEdge === "end" ? peek.side : root.fixedEdge === "start" ? -peek.side : 0
      height: parent.height
      spacing: Math.round(pillMetrics.advanceWidth("  "))

      Repeater {
        model: root.rowEntries

        Item {
          id: part
          required property var modelData
          readonly property string partId: modelData.id
          readonly property bool isSep: modelData.kind === "sep"
          readonly property bool isSpot: Catalog.MEDIA_SPOT.indexOf(partId) !== -1
          width: isSpot ? root.artSize : partLabel.implicitWidth
          height: pillRow.height
          opacity: root.dragId !== "" && partId === root.dragId ? 0.5 : 1

          Text {
            id: partLabel
            visible: !part.isSpot
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: (pillMetrics.descent - pillMetrics.ascent + pillMetrics.tightBoundingRect("0").height) / 2
            textFormat: Text.PlainText
            text: part.isSep ? "·" : root.partText(part.partId)
            color: button.foreground
            font.family: button.fontFamily
            font.pixelSize: button.fontSize
            renderType: Text.NativeRendering
            scale: button.pressScale
          }

          AlbumArt {
            visible: part.partId === "media"
            opacity: root.showArt ? 1 : 0
            Behavior on opacity {
              NumberAnimation { duration: root.motionOff ? 0 : 180 }
            }
            anchors.centerIn: parent
            width: root.artSize
            height: root.artSize
            // Only while shown: no art is fetched for a pill that doesn't show it.
            source: root.showArt && root.media ? root.media.artUrl : ""
            foreground: button.foreground
            fontFamily: button.fontFamily
          }

          PillMeter {
            visible: part.partId === "meter"
            opacity: root.showMeter ? 1 : 0
            Behavior on opacity {
              NumberAnimation { duration: root.motionOff ? 0 : 180 }
            }
            anchors.centerIn: parent
            size: root.artSize
            active: root.showMeter
            live: !!root.visualizer && root.visualizer.live
            levels: root.visualizer ? root.visualizer.levels : []
            reduceMotion: root.motionOff
            foreground: button.foreground
          }
        }
      }
    }

    // Press and hold a part, then drag it along the pill: the order is saved
    // (pillItems). Only the left button; a plain click is the pill's click,
    // and right and middle clicks go on to the button.
    MouseArea {
      id: dragArea
      anchors.fill: parent
      enabled: !root.vertical
      acceptedButtons: Qt.LeftButton
      pressAndHoldInterval: 450
      property bool held: false
      onPressed: held = false
      onPressAndHold: function(mouse) {
        var id = root.partAt(mouse.x)
        if (id === "") return
        held = true
        openTimer.stop()
        if (root.opened) root.close()
        root.dragOrder = root.rowIds.slice()
        root.dragId = id
      }
      onPositionChanged: function(mouse) { if (root.dragId !== "") root.dragTo(mouse.x) }
      onReleased: root.endDrag(true)
      onCanceled: root.endDrag(false)
      onClicked: if (!held) root.leftClick()
    }

    Column {
      visible: root.vertical
      anchors.fill: parent

      OpticalGlyph {
        id: badgeGlyph
        visible: root.badgeActivity !== null
        width: button.width
        height: visible ? Style.bar.iconSlot : 0
        text: ActivityStore.leadingGlyph(root.badgeActivity)
        fontFamily: button.fontFamily
        fontSize: button.fontSize
        color: root.badgeActivity && (root.badgeActivity.priority === "urgent" || root.badgeActivity.state === "error")
          ? button.activeColor : button.foreground

        // As in Peek: an urgent activity waiting for the user pulses.
        SequentialAnimation on opacity {
          running: ActivityStore.isPulsing(root.badgeActivity) && !root.motionOff
          loops: Animation.Infinite
          onRunningChanged: if (!running) badgeGlyph.opacity = 1
          NumberAnimation { to: 0.25; duration: 700; easing.type: Easing.InOutSine }
          NumberAnimation { to: 1; duration: 700; easing.type: Easing.InOutSine }
        }
      }

      Repeater {
        model: root.verticalLines

        OpticalGlyph {
          required property string modelData
          width: button.width
          height: Style.bar.iconSlot
          text: modelData
          fontFamily: button.fontFamily
          fontSize: modelData.length > 3 ? button.fontSize * 0.9 : button.fontSize
          color: button.foreground
        }
      }
    }
  }

  HubPopup {
    id: hub
    surfaceOpacity: root.config.hubOpacity / 100
    corners: root.config.corners
    anchorItem: root
    bar: root.bar
    owner: root
    service: root.service
    config: root.config
    settingsEditor: editor
    // Only a click-mode click or a keyboard open grabs input; a hover-mode
    // hub never does, so leaving it hands everything straight back.
    grabInput: root.openedBy === "keyboard" || (root.openedBy === "click" && !root.hoverMode)
    // The same opens take the keyboard (in-hub keys); a hover hub has it only
    // while the pointer is on its card (HubPopup.pointerKeys).
    takeKeys: grabInput
    landOnOpen: root.openedBy === "keyboard"
    reduceMotion: root.motionOff
    activities: root.activities
    allowActions: root.config.allowActions
    now: root.nowMs
    bloom: root.bloomLook
    onVisibleChanged: if (!visible) root.bloomLook = false
    bloomActivity: root.bloomActivity
    onBloomClicked: root.open("activities", "click")
  }
}
