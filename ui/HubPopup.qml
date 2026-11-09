pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "../lib/BarGeometry.js" as BarGeometry
import "../lib/Catalog.js" as Catalog

// The expanded hub, grown out of the pill.
//
// A layer-shell window (not an xdg-popup): only a layer surface can take
// the keyboard, and a layer surface taking it dismissed an xdg-popup hub
// (SPEC M0/ON-12 notes). It asks for the keyboard only while `takeKeys`
// (opened from a keybind, IPC or a click-mode click), with qs.Ui
// KeyboardPanel's brief Exclusive prime settling on OnDemand. A hover-opened
// hub asks for none, so the window under the pointer keeps its keys, until the
// pointer is on the card: then it is OnDemand, and focus follows the pointer
// into the card as it does into any window (a surface OnDemand when it maps
// would take the keyboard at once, so it can't simply stay OnDemand).
//
// The pill paints a cap in the bar (see Pill.qml) in the same popup colours
// and border as this card, reaching to the bar's inner edge. This window sits
// flush against that edge and the card inside it grows from the cap's
// footprint to its full size, so cap and card read as one shape: the notch
// widening into the hub (MacNotch's gesture) rather than a second surface
// popping in. The window keeps its final size the whole time; only the card
// inside animates, which avoids resizing a Wayland surface every frame.
//
// It does what qs.Ui PopupCard does for coordination: bar.requestPopout on
// open (closing any other bar popup), releasePopout on close, and a Hyprland
// focus grab for click-outside dismissal while it is pinned open.
// No type info for Quickshell's PanelWindow reaches the linter (as for KeyboardPanel).
// qmllint disable uncreatable-type
PanelWindow {
  // qmllint enable uncreatable-type
  id: root

  required property Item anchorItem
  required property QtObject bar
  property var owner: null
  property bool open: false
  // Take a Hyprland focus grab while open so a click outside closes it.
  // Off for hover-opened hubs, which hold no input at all.
  property bool grabInput: false
  // Take the keyboard while open (the in-hub keys, SPEC section 10).
  property bool takeKeys: false
  // A keybind or IPC open lands on a control with the ring; a click-mode click
  // has the keys but no ring until one is pressed.
  property bool landOnOpen: false
  property bool focusPrimed: false
  // A hub without takeKeys has the keys while the pointer is on its card.
  readonly property bool pointerKeys: open && !takeKeys && !bloom && cardHover.hovered
  property bool reduceMotion: false
  // The tab showing; the first open picks one (Pill.open).
  property string currentTab: ""
  // Live activities (the service's ActivitiesModule) for the tab and bloom.
  property var activities: null
  property bool allowActions: true
  property real now: Date.now()
  // Bloom: the hub opened short, showing only `bloomActivity`.
  property bool bloom: false
  property var bloomActivity: null
  signal bloomClicked()
  // Omavisor's service (weather, media) and the resolved settings, for the tabs.
  property var service: null
  property var config: ({})
  property var settingsEditor: null
  // The tab Settings was opened from, for Esc to go back to ("" to close).
  property string settingsBack: ""

  // Narrow for the three everyday views, wide for the denser opt-in tabs
  // and Settings, which have more to lay out.
  // (Only with a short strip: a long one needs the full width for its tabs.)
  readonly property bool compactTab: ["media", "calendar", "activities"].indexOf(currentTab) !== -1 && !bloom
    && Catalog.shownTabs(config, service).length <= 4
  property int contentWidth: compactTab ? Style.space(680) : Style.space(820)
  // Settings is taller: it has a row for everything there is.
  property int contentHeight: currentTab === Catalog.SETTINGS_TAB.id && !bloom
    ? Style.space(440) : Style.space(260)

  // The cap's length along the bar; the card starts from exactly its
  // footprint.
  property real capLength: anchorItem ? (vertical ? anchorItem.height : anchorItem.width) : 0

  // The popup itself (not the pill) is the bar's popout identity, so the
  // bar's accent "panel open" line is not drawn across the cap; the cap
  // already shows the hub is open. Close requests still go to the owner.
  readonly property var coordinatorKey: root
  readonly property var anchorWindow: anchorItem ? anchorItem.QsWindow.window : null
  readonly property string edge: bar && bar.position ? String(bar.position) : "top"
  readonly property bool vertical: edge === "left" || edge === "right"
  readonly property real margin: Style.gapsOut
  readonly property real screenLength: anchorWindow
    ? (vertical ? anchorWindow.height : anchorWindow.width) : 0
  // The bar's strip across its window (the window spans its screen from
  // Omarchy 4.5, see lib/BarGeometry.js).
  readonly property real barStrip: anchorWindow
    ? BarGeometry.strip(vertical ? anchorWindow.width : anchorWindow.height, anchorWindow.exclusiveZone, bar ? bar.barSize : 0)
    : 0
  readonly property real awayRoom: anchorWindow && anchorWindow.screen
    ? (vertical ? anchorWindow.screen.width : anchorWindow.screen.height) - barStrip - margin
    : contentHeight
  // The hub stays landscape on every edge: along a top/bottom bar it spans
  // contentWidth, along a left/right bar contentHeight. Each side is capped
  // to the room the screen has.
  readonly property real hubLength: {
    var want = vertical ? contentHeight : contentWidth
    return screenLength > 0 ? Math.min(want, screenLength - margin * 2) : want
  }
  readonly property real hubDepth: Math.max(Style.space(120), Math.min(vertical ? contentWidth : contentHeight, awayRoom))
  // A bloom is the card opened short (along a left/right bar, where the
  // card's depth is its width, it keeps the full depth). The window keeps
  // the full hub's size either way; only the card's depth changes, and a
  // bloom growing into the hub deepens smoothly.
  readonly property real bloomDepth: vertical ? hubDepth : Math.min(hubDepth, Style.space(120))
  property real cardDepth: bloom ? bloomDepth : hubDepth
  Behavior on cardDepth {
    enabled: root.visible && !root.reduceMotion
    NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
  }
  readonly property bool containsMouse: cardHover.hovered

  // The card's (and the cap's) fill: the theme's popup background at
  // `surfaceOpacity` (the hubOpacity setting) times its own alpha.
  property real surfaceOpacity: 1
  readonly property color surfaceColor: {
    var c = Commons.Color.popups.background
    return Qt.rgba(c.r, c.g, c.b, c.a * Math.max(0, Math.min(1, surfaceOpacity)))
  }
  readonly property var surfaceBorder: Border.localOrSurfaceSpec("popups", "border", Commons.Color.popups.border, Commons.Color.popups.border, Math.max(1, Style.space(2)))
  // The card side that meets the bar.
  readonly property string innerSide: edge
  readonly property real innerBorderWidth: Border.uniformWidth(surfaceBorder)
  readonly property color innerBorderColor: surfaceBorder && surfaceBorder.color ? surfaceBorder.color : Commons.Color.popups.border
  // A border spec with no border on `sides` ("top", "left" …).
  function withoutSides(spec, sides) {
    if (!spec || !spec.widths) return spec
    var widths = Object.assign({}, spec.widths)
    sides.forEach(function(side) { widths[side] = 0 })
    return Object.assign({}, spec, { widths: widths })
  }

  // The hub's corners (the `corners` setting, lib/BarGeometry.js hubRadius):
  // the card's far corners and the curves where the cap meets it (ui/Fillet.qml,
  // drawn by the pill in the bar's window) share one radius. Auto follows the
  // theme, so a square theme gets a square joint. The curves never exceed the
  // room on each side of the cap or the card's depth while it grows. Top and
  // bottom bars only; along a left or right bar the joint stays square.
  property string corners: "auto"
  readonly property real cornerRadius: BarGeometry.hubRadius(corners, Style.cornerRadius, Style.space(10))
  readonly property real earRadius: cornerRadius
  readonly property real innerEar: {
    if (vertical || progress <= 0) return 0
    var before = _anchorOffset - card.along
    var after = card.along + card.length - (_anchorOffset + capLength)
    return Math.max(0, Math.min(earRadius, before, after, card.depth))
  }

  // 0 = only the cap, 1 = the full hub.
  property real progress: open ? 1 : 0
  Behavior on progress {
    NumberAnimation {
      duration: root.reduceMotion || root.progressSnap ? 0 : 240
      easing.type: root.open ? Easing.OutCubic : Easing.InCubic
    }
  }

  // Window-local start of the card along the bar, set in place().
  property real _anchorOffset: 0

  function close() {
    if (owner && "close" in owner) owner.close()
    else root.open = false
  }

  // Bar.requestPopout calls this when another bar popup takes over: drop
  // the hub at once instead of animating it shut under the newcomer.
  function closeForPopoutSwitch() {
    progressSnap = true
    close()
    Qt.callLater(function() { root.progressSnap = false })
  }
  property bool progressSnap: false

  // Hand an open hub without the keyboard the keys, as a fresh keyboard open
  // would have them: the surface is mapped again with no animation. Taking the
  // keyboard and the focus grab on the mapped surface loses one or the other
  // (Hyprland cleared the grab, closing the hub, or kept the keys elsewhere).
  // A keybind or IPC again on a hub that has the keys: back to the ring.
  function landAgain() { content.landFocus() }

  // Settings holds the keyboard and the hub, so a hub without the keys takes them
  // on the way in (Pill.open).
  function openSettings() {
    if (currentTab !== Catalog.SETTINGS_TAB.id) settingsBack = currentTab
    if (takeKeys) currentTab = Catalog.SETTINGS_TAB.id
    else if (owner && "open" in owner) owner.open(Catalog.SETTINGS_TAB.id, "keyboard")
  }

  onCurrentTabChanged: if (currentTab !== Catalog.SETTINGS_TAB.id) settingsBack = ""

  function leaveSettings() {
    if (settingsBack === "") { close(); return }
    currentTab = Catalog.startTab(settingsBack, Catalog.shownTabs(config, service), "keyboard")
    content.landFocus()
  }

  function remapForKeys() {
    progressSnap = true
    open = false
    remapTimer.restart()
  }
  Timer {
    id: remapTimer
    interval: 30
    onTriggered: {
      // Unless it was closed in the meantime.
      if (root.takeKeys) root.open = true
      Qt.callLater(function() { root.progressSnap = false })
    }
  }

  visible: open || progress > 0
  color: "transparent"
  // Only the card takes pointer input, so the window's transparent area
  // never blocks clicks while the card grows or shrinks.
  mask: Region { item: card }
  implicitWidth: vertical ? hubDepth : hubLength
  implicitHeight: vertical ? hubLength : hubDepth

  // Keep the card on the cap if the pill changes size while open (the clock
  // label grows at 9:59 → 10:00, or the day name changes).
  onCapLengthChanged: if (visible) place()

  onOpenChanged: {
    if (open) {
      place()
      focusPrimed = false
      beginFocusPrime()
      if (takeKeys) enterKeys()
    } else {
      focusPrimeTimer.stop()
      focusPrimed = false
    }
    if (!bar) return
    if (open) bar.requestPopout(coordinatorKey)
    else if (bar.activePopout === coordinatorKey) bar.releasePopout(coordinatorKey)
  }

  HyprlandFocusGrab {
    active: root.open && root.grabInput
    windows: root.anchorWindow ? [root, root.anchorWindow] : [root]
    onCleared: root.close()
  }

  // Where the window starts along the bar, worked out in place().
  property real _along: 0
  // The bar's inner edge from the screen edge. A hidden bar is parked past
  // the edge with a negative margin (Bar.qml), so the hub then starts at the
  // screen edge, as the xdg-popup did.
  readonly property real barThickness: {
    if (!anchorWindow) return 0
    var m = anchorWindow.margins
    var parked = !m ? 0 : edge === "top" ? m.top : edge === "bottom" ? m.bottom : edge === "left" ? m.left : m.right
    return BarGeometry.innerEdge(barStrip, parked)
  }

  function place() {
    var window = root.anchorWindow
    if (!root.anchorItem || !window) return
    var origin = window.contentItem.mapFromItem(root.anchorItem, 0, 0)
    var start = root.vertical ? origin.y : origin.x
    // Centre the hub on the cap, then keep it on screen.
    var pos = start + root.capLength / 2 - root.hubLength / 2
    pos = Math.round(Math.max(root.margin, Math.min(pos, root.screenLength - root.hubLength - root.margin)))
    root._anchorOffset = start - pos
    root._along = pos
  }
  onScreenLengthChanged: if (visible) place()
  // The pill can still move after the open (the bar re-centres its section
  // as widths settle). A mapping is no binding, so while the hub shows, its
  // place is checked again; unchanged values change nothing.
  Timer {
    interval: 100
    repeat: true
    running: root.visible
    onTriggered: root.place()
  }
  // Settings is taller, which along a left or right bar is its length.
  onHubLengthChanged: if (visible) place()

  // Flush against the bar's inner edge (the bar spans its whole screen
  // edge, so a position in its window is a position on screen).
  screen: anchorWindow ? anchorWindow.screen : null
  exclusionMode: ExclusionMode.Ignore
  // Omarchy's own keyboard panels' namespace: its layer rule
  // (default/hypr/apps/omarchy-shell.lua) turns off Hyprland's layer fade
  // for it, which would otherwise fade the whole card in over the grow-out
  // while the cap in the bar appears at once. Omavisor can't add a rule of its
  // own without editing the user's Hyprland config. A hub with the keyboard
  // is on Overlay, like KeyboardPanel, so a keybind open over a fullscreen
  // window is seen; otherwise Top, under fullscreen windows like the bar, so
  // a bloom never covers a fullscreen video or game.
  WlrLayershell.namespace: "omarchy-keyboard-panel"
  WlrLayershell.layer: takeKeys ? WlrLayer.Overlay : WlrLayer.Top
  WlrLayershell.keyboardFocus: open && takeKeys
    ? (focusPrimed ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.Exclusive)
    : pointerKeys ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
  anchors.top: edge !== "bottom"
  anchors.bottom: edge === "bottom"
  anchors.left: edge !== "right"
  anchors.right: edge === "right"
  // qmllint disable unqualified unresolved-type
  margins.top: edge === "top" ? barThickness : (vertical ? _along : 0)
  margins.bottom: edge === "bottom" ? barThickness : 0
  margins.left: edge === "left" ? barThickness : (vertical ? 0 : _along)
  margins.right: edge === "right" ? barThickness : 0
  // qmllint enable unqualified unresolved-type

  // As qs.Ui KeyboardPanel: Exclusive gets the keyboard when the surface
  // maps (or reopens during its close animation); OnDemand then stops
  // Hyprland sending every pointer event to this surface.
  function beginFocusPrime() {
    if (open && takeKeys && visible) focusPrimeTimer.restart()
  }
  onVisibleChanged: beginFocusPrime()
  onTakeKeysChanged: if (takeKeys) { focusPrimed = false; beginFocusPrime(); enterKeys() }
  function enterKeys() {
    if (landOnOpen) content.landOnOpen()
    else content.takeFocus()
  }
  Timer {
    id: focusPrimeTimer
    interval: 75
    onTriggered: if (root.open) root.focusPrimed = true
  }

  Item {
    id: card

    readonly property real along: root._anchorOffset * (1 - root.progress)
    readonly property real length: root.capLength + (root.hubLength - root.capLength) * root.progress
    readonly property real depth: root.cardDepth * root.progress
    readonly property real contentLeftInset: surface.contentLeftInset
    readonly property real contentTopInset: surface.contentTopInset
    readonly property real contentRightInset: surface.contentRightInset
    readonly property real contentBottomInset: surface.contentBottomInset

    x: root.edge === "left" ? 0 : root.edge === "right" ? root.hubDepth - depth : along
    y: root.edge === "top" ? 0 : root.edge === "bottom" ? root.hubDepth - depth : along
    width: root.vertical ? depth : length
    height: root.vertical ? length : depth
    clip: true

    // Square where it meets the bar, rounded (cornerRadius) on the far side,
    // so cap and card form one outline at any rounding. The shell's border
    // overlay rounds all four corners alike, so the surface runs on past the
    // bar side by the radius and the card clips that end off: the corners
    // left there are square, fill and border alike.
    BorderSurface {
      id: surface
      readonly property real over: root.cornerRadius
      x: root.edge === "left" ? -over : 0
      y: root.edge === "top" ? -over : 0
      width: card.width + (root.vertical ? over : 0)
      height: card.height + (root.vertical ? 0 : over)
      color: root.surfaceColor
      borderSpec: root.withoutSides(root.surfaceBorder, [root.innerSide])
      radius: root.cornerRadius
    }

    HoverHandler { id: cardHover }

    // The card's border along the bar side, drawn here rather than by the
    // surface, so it can stop where the cap (and its curves) take over: no
    // seam is painted over, which a see-through card couldn't hide.
    Repeater {
      model: root.progress > 0 ? 2 : 0
      Rectangle {
        required property int index
        readonly property real w: root.innerBorderWidth
        // Where the cap meets the card, along it, in the card.
        readonly property real capStart: root._anchorOffset - card.along
        readonly property real capEnd: capStart + root.capLength
        // With the curves, from where each meets the card's edge; without,
        // under the cap's own side border, so the corner is closed.
        readonly property real from: index === 0 ? 0 : (root.innerEar > 0 ? capEnd + root.innerEar : capEnd - w)
        readonly property real to: index === 0 ? (root.innerEar > 0 ? capStart - root.innerEar : capStart + w) : card.length
        readonly property real span: Math.max(0, to - from)
        color: root.innerBorderColor
        x: root.vertical ? (root.edge === "left" ? 0 : card.width - w) : from
        y: root.vertical ? from : (root.edge === "top" ? 0 : card.height - w)
        width: root.vertical ? w : span
        height: root.vertical ? span : w
      }
    }

    // The curves' outline once more, in this window: the pill draws them in
    // the bar's window, which shows nothing past the bar's inner edge, and
    // the stroke dips just past it where it turns into the card's border.
    // The card clips to itself, so only that sliver shows from here.
    Repeater {
      model: root.innerEar > 0 && !root.vertical ? 2 : 0
      Fillet {
        required property int index
        readonly property bool onTop: root.edge === "top"
        r: root.innerEar
        x: index === 0 ? root._anchorOffset - card.along - r : root._anchorOffset - card.along + root.capLength
        y: onTop ? -r : card.height
        corner: onTop ? (index === 0 ? "bottomRight" : "bottomLeft") : (index === 0 ? "topRight" : "topLeft")
        fill: "transparent"
        strokeColor: root.innerBorderColor
        strokeWidth: root.innerBorderWidth
      }
    }

    HubContent {
      id: content
      keyboard: root.open && (root.takeKeys || root.pointerKeys)
      onKeyboardChanged: if (keyboard && !root.takeKeys) takeFocus()
      onCloseRequested: root.close()
      onSettingsBackRequested: root.leaveSettings()
      x: card.contentLeftInset + Style.spacing.popupPadding
      y: card.contentTopInset + Style.spacing.popupPadding
      width: (root.vertical ? root.hubDepth : root.hubLength) - x - card.contentRightInset - Style.spacing.popupPadding
      height: (root.vertical ? root.hubLength : root.hubDepth) - y - card.contentBottomInset - Style.spacing.popupPadding
      opacity: root.bloom ? 0 : Math.max(0, (root.progress - 0.55) / 0.45)
      visible: opacity > 0
      bar: root.bar
      service: root.service
      config: root.config
      settingsEditor: root.settingsEditor
      currentTab: root.currentTab
      activities: root.activities
      allowActions: root.allowActions
      now: root.now
      onTabRequested: function(tab) {
        if (tab === Catalog.SETTINGS_TAB.id) root.openSettings()
        else root.currentTab = tab
      }
    }

    Bloom {
      x: card.contentLeftInset + Style.spacing.popupPadding
      y: card.contentTopInset + Style.spacing.popupPadding
      width: (root.vertical ? root.bloomDepth : root.hubLength) - x - card.contentRightInset - Style.spacing.popupPadding
      height: (root.vertical ? root.hubLength : root.bloomDepth) - y - card.contentBottomInset - Style.spacing.popupPadding
      opacity: root.bloom ? Math.max(0, (root.progress - 0.55) / 0.45) : 0
      visible: opacity > 0 && root.bloomActivity !== null
      bar: root.bar
      activity: root.bloomActivity
      activities: root.activities
      allowActions: root.allowActions
      now: root.now
      onClicked: root.bloomClicked()
    }
  }
}
