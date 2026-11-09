pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "tabs"
import "../lib/Catalog.js" as Catalog
import "../lib/HubKeys.js" as HubKeys
import "../lib/Layout.js" as Layout

// Header (tab strip and the Settings gear) over the current tab's body.
//
// Tabs are the shell's own qs.Ui Buttons in the ButtonGroup chrome, so
// hover, selected and focus states come from the theme's control tokens.
// Every tab comes from `tabs` (the `tabs` setting, lib/Catalog.js) and one
// delegate: hovering any of them switches to it after a short pause, so sweeping
// the pointer across the strip does not flick through every tab on the way. A
// tab left out of the setting still opens when asked for by name (`omavisor expand
// media`): it shows with no tab selected.
//
// While the hub has the keyboard (`keyboard`) the in-hub keys of SPEC section
// 10 work. A keybind or IPC open lands on the tab's first useful control
// (landFocus). Arrows move between its controls (a list or grid keeps its own
// arrows until its edge, a slider its Left and Right), Up off the top reaches
// the tab strip, where Left and Right switch tabs and Down comes back. Tab and
// Shift+Tab step through the tabs, 1-9 jump to one, Enter runs the focused
// control, Space flips a focused toggle or else plays or pauses the media
// player, Esc closes. The gear after the tabs opens Settings by click, by key
// on the strip or with Tab, never by hover, and hovering a tab won't leave it;
// Esc there goes back to where it was opened from. A ring in the theme's focus colour marks the focused
// control; a mouse click leaves none behind.
FocusScope {
  id: root

  property QtObject bar: null
  property string currentTab: "home"
  property var activities: null
  property bool allowActions: true
  property real now: Date.now()
  // Omavisor's service (weather, media) and resolved settings, for the tabs.
  property var service: null
  property var config: ({})
  // Holds what the Settings page changes (Pill).
  property var settingsEditor: null

  property bool keyboard: false

  signal tabRequested(string tab)
  signal closeRequested()
  signal settingsBackRequested()

  // Through a string, which only signals a real change: a settings write makes
  // a new config, and a new array would rebuild the strip under the pointer and
  // the focus.
  readonly property string tabList: Catalog.shownTabs(config, service).join(" ")
  readonly property var tabValues: tabList.split(" ")
  // What Left, Right and Tab step through: the tabs, then the gear.
  readonly property var stripValues: tabValues.concat([Catalog.SETTINGS_TAB.id])
  readonly property bool onSettings: currentTab === Catalog.SETTINGS_TAB.id
  readonly property int currentIndex: tabValues.indexOf(currentTab)
  readonly property Item activeItem: root.Window.activeFocusItem
  readonly property Item currentTabButton: onSettings ? gear
    : tabButtons.count > 0 && currentIndex >= 0 ? tabButtons.itemAt(currentIndex) : null
  readonly property bool onTabStrip: !!activeItem && activeItem === currentTabButton

  // Put the focus on the current tab's first useful control, once it is laid
  // out: what a keybind or IPC open and a tab switch by key do.
  // A hover hub with the keys starts with no control focused.
  function takeFocus() {
    Qt.callLater(function() { if (root.keyboard) keyCatcher.forceActiveFocus() })
  }
  onKeyboardChanged: if (!keyboard) {
    landTimer.stop()
    lastRect = null
    keyCatcher.forceActiveFocus()
  }

  // Where typing goes, a plugin's plain text input included.
  function isTextField(item) { return "cursorPosition" in item }

  // A keybind or IPC open.
  function landOnOpen() {
    openedAt = Date.now()
    landFocus()
  }

  function landFocus() {
    hoverSwitch.stop()
    pendingTab = ""
    landTries = 0
    forgetPress()
    landTimer.restart()
  }
  property int landTries: 0
  property real openedAt: 0
  Timer {
    id: landTimer
    interval: 30
    onTriggered: {
      if (!root.keyboard) return
      // Hidden until the grow-out is far enough along; nothing to focus yet.
      if (!root.visible) { restart(); return }
      let item = root.startItem()
      if (item) { root.focusItem(item); return }
      // The tab is still loading its controls (the theme list reads files):
      // on the strip meanwhile, and not for ever.
      if (root.currentTabButton && !root.onTabStrip) root.currentTabButton.forceActiveFocus()
      if (++root.landTries < 40) restart()
    }
  }

  // Where a tab starts: the control it names, one marked keyStart (play or
  // pause), else its first control that is not a slider.
  function startItem() {
    let items = focusables()
    if (body.item && body.item.keyFocusItem) {
      if (items.indexOf(body.item.keyFocusItem) !== -1) return body.item.keyFocusItem
      if (landTries < 39) return null
    }
    for (let i = 0; i < items.length; i++) if (items[i].keyStart === true) return items[i]
    let controls = items.filter(function(it) { return !("liveValue" in it) })
    let from = controls.length > 0 ? controls : items
    let to = HubKeys.move(from.map(rectOf), -1, 0, 1)
    return to >= 0 ? from[to] : null
  }

  function rectOf(item) {
    let p = item.mapToItem(root, 0, 0)
    return { x: p.x, y: p.y, w: item.width, h: item.height }
  }

  function focusItem(item) {
    item.forceActiveFocus()
    reveal(item)
  }

  // Scroll a list to show the control the keys moved to.
  function reveal(item) {
    for (let f = item.parent; f && f !== root; f = f.parent) {
      if (!("contentY" in f) || !f.contentItem) continue
      let y = item.mapToItem(f.contentItem, 0, 0).y
      if (y < f.contentY) f.contentY = y
      else if (y + item.height > f.contentY + f.height) f.contentY = y + item.height - f.height
      return
    }
  }

  // The one way to another tab, for pointer and keys alike.
  function selectTab(tab) {
    hoverSwitch.stop()
    pendingTab = ""
    if (tab !== "" && tab !== currentTab) tabRequested(tab)
  }

  // By key: the new tab's first control.
  function showTab(tab) {
    if (tab === "" || tab === currentTab) return
    forgetPress()
    selectTab(tab)
    landFocus()
  }

  // Left and Right on the strip: switch, and stay on the strip.
  function stepTabOnStrip(direction) {
    selectTab(HubKeys.stepTab(stripValues, currentTab, direction))
    if (currentTabButton) currentTabButton.forceActiveFocus()
  }

  // Every control the current tab offers to the keyboard (activeFocusOnTab,
  // shown, enabled). A key-navigable list or grid counts as one control and
  // is not searched, since its own arrows move within it.
  function focusables() {
    const out = []
    function walk(item) {
      let kids = item.children
      for (let i = 0; i < kids.length; i++) {
        let c = kids[i]
        if (!c.visible || !c.enabled || c.opacity === 0 || c.width <= 0 || c.height <= 0) continue
        // Clipped away, like timers past what fits.
        if (item.clip && c.y >= item.height) continue
        if (isKeyList(c)) { out.push(c); continue }
        if (c.activeFocusOnTab) { out.push(c); continue }
        walk(c)
      }
    }
    if (body.item) walk(body.item)
    return out
  }

  // A ListView or GridView whose current delegate takes the focus.
  function isKeyList(item) {
    if (!("keyNavigationEnabled" in item) || !item.keyNavigationEnabled || !item.currentItem) return false
    let cur = item.currentItem
    if (cur.activeFocusOnTab) return true
    for (let i = 0; i < cur.children.length; i++) if (cur.children[i].activeFocusOnTab) return true
    return false
  }

  function toStrip() {
    if (!currentTabButton) selectTab(tabValues[0])
    if (currentTabButton) currentTabButton.forceActiveFocus()
  }

  function moveFocus(dx, dy) {
    landTimer.stop()
    forgetPress()
    if (onTabStrip) {
      if (dx !== 0) stepTabOnStrip(dx)
      else if (dy > 0) landFocus()
      return
    }
    let items = focusables()
    let from = -1
    for (let i = 0; i < items.length; i++) {
      if (items[i].activeFocus) { from = i; break }
    }
    // A hidden tab with nothing to focus has only the way out.
    if (from < 0 && items.length === 0 && dy < 0 && !currentTabButton) { toStrip(); return }
    if (from < 0) { landFocus(); return }
    let to = HubKeys.move(items.map(rectOf), from, dx, dy)
    if (to !== from) focusItem(items[to])
    // Nothing above the top row but the strip. A hidden tab has no place on
    // it, so that is the way back to the first one (toStrip).
    else if (dy < 0) toStrip()
  }

  // ---- The focus ring, and what happens to the focus when something else
  //      moves it: a mouse click takes the ring off, and a control that goes
  //      away (a cancelled timer) hands it to the nearest one left.
  readonly property Item ringTarget: keyboard && !!activeItem && activeItem.activeFocusOnTab === true ? activeItem : null
  property real pressedAt: 0
  function pressedLately() { return Date.now() - pressedAt < 1500 }
  function forgetPress() { pressedAt = 0 }
  property var lastRect: null
  property string lastTab: ""

  onActiveItemChanged: {
    if (!keyboard) return
    // activeItem itself: ringTarget may not have caught up yet.
    if (activeItem && activeItem.activeFocusOnTab === true) {
      if (pressedLately() && !(isTextField(activeItem))) {
        lastRect = null
        Qt.callLater(function() { keyCatcher.forceActiveFocus() })
        return
      }
      lastRect = rectOf(activeItem)
      lastTab = currentTab
    } else if (lastRect !== null) {
      settleTimer.restart()
    }
  }
  onRingTargetChanged: placeRing()
  // On the strip, stay on the strip when the tab changes some other way.
  onCurrentTabChanged: {
    if (activeItem && (activeItem.parent === tabStrip || activeItem === gear) && currentTabButton) currentTabButton.forceActiveFocus()
  }

  // After the layout: the rows that replace a removed one aren't placed yet.
  Timer {
    id: settleTimer
    interval: 30
    onTriggered: root.settleFocus()
  }
  // A hidden control keeps Qt's focus, and Enter would still run it.
  Connections {
    target: root.ringTarget
    function onVisibleChanged() { if (!root.ringTarget.visible) settleTimer.restart() }
  }
  function settleFocus() {
    if (!keyboard || lastRect === null || (ringTarget && ringTarget.visible)) return
    if (lastTab !== currentTab) { landFocus(); return }
    let items = focusables()
    let to = HubKeys.nearest(items.map(rectOf), lastRect)
    if (to >= 0) focusItem(items[to])
    else landFocus()
  }

  function placeRing() {
    if (!ringTarget) return
    let p = ringTarget.mapToItem(root, 0, 0)
    ring.x = p.x
    ring.y = p.y
  }

  // Follows a scrolling list and rows moving under it, only while it shows.
  Timer {
    interval: 50
    repeat: true
    running: root.ringTarget !== null
    onTriggered: root.placeRing()
  }

  Shortcut {
    enabled: root.keyboard && root.visible
    sequences: ["Tab"]
    onActivated: root.showTab(HubKeys.stepTab(root.stripValues, root.currentTab, 1))
  }
  Shortcut {
    enabled: root.keyboard && root.visible
    sequences: ["Backtab", "Shift+Tab"]
    onActivated: root.showTab(HubKeys.stepTab(root.stripValues, root.currentTab, -1))
  }
  // Space flips a focused toggle, else plays or pauses, even on a focused
  // button (which would click it). In a text field it is a space, and on the
  // Settings page it only ever runs a row.
  Shortcut {
    enabled: root.keyboard && root.visible && !(root.activeItem && root.isTextField(root.activeItem))
    sequences: ["Space"]
    onActivated: {
      let item = root.activeItem
      if (item && item.spaceToggles === true) {
        if (typeof item.activated === "function") item.activated()
        else item.clicked()
      } else if (!root.onSettings && root.service && root.service.media) root.service.media.playPause()
    }
  }

  // Holds Qt's focus when no control does.
  Item {
    id: keyCatcher
    focus: true
  }

  // Keys a focused control leaves alone come up to here.
  Keys.onPressed: function(event) {
    // Chords belong to the compositor or the control.
    if (!keyboard || (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) return
    let tab = HubKeys.digitTab(tabValues, event.text)
    if (event.key === Qt.Key_Escape) {
      if (onSettings) settingsBackRequested()
      else closeRequested()
    }
    else if (tab !== "") showTab(tab)
    else if (event.key === Qt.Key_Left) moveFocus(-1, 0)
    else if (event.key === Qt.Key_Right) moveFocus(1, 0)
    else if (event.key === Qt.Key_Up) moveFocus(0, -1)
    else if (event.key === Qt.Key_Down) moveFocus(0, 1)
    // Enter with nothing focused goes to the first control.
    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { if (!ringTarget) landFocus() }
    // Typing on a tab that takes text (the cheatsheet's search).
    else if (event.text !== "" && event.text.trim() !== "" && event.text.charCodeAt(0) >= 32
      && body.item && typeof body.item.typeText === "function") body.item.typeText(event.text)
    else return
    event.accepted = true
  }

  readonly property color foreground: bar && bar.foreground ? bar.foreground : Commons.Color.popups.text
  readonly property string fontFamily: bar && bar.fontFamily ? bar.fontFamily : Style.font.family
  readonly property color dim: Qt.darker(foreground, 1.4)
  readonly property bool themeEnabled: !!service && !!service.theme && service.theme.available
  readonly property var tabs: Catalog.tabEntries(tabValues)
  // With Home hidden, its bar-layout card shows on the first tab instead.
  readonly property bool cardHere: currentTab === tabValues[0] && tabValues.indexOf("home") === -1
    && !!service && !!service.layout && Layout.showsCard(service.layout.stage)

  property string pendingTab: ""

  onVisibleChanged: {
    if (!visible) { hoverSwitch.stop(); pendingTab = ""; return }
    // The bar layout may have changed since (the anchor one-liner, a CLI move).
    if (service && service.layout) service.layout.refresh()
  }

  Timer {
    id: hoverSwitch
    interval: 120
    // The pointer has taken over: the keys' ring doesn't follow it.
    onTriggered: {
      root.lastRect = null
      if (root.ringTarget) keyCatcher.forceActiveFocus()
      root.selectTab(root.pendingTab)
    }
  }

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
  }

  Item {
    id: header
    width: parent.width
    height: tabStrip.implicitHeight

    Row {
      id: tabStrip
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.spacing.md
      Accessible.role: Accessible.PageTabList
      Accessible.name: "Omavisor hub tabs"

      Repeater {
        id: tabButtons
        model: root.tabs

        Button {
          required property var modelData
          // With every tab on, only the selected one has room for its name.
          text: root.tabValues.length <= 8 || selected ? modelData.label : ""
          tooltipText: text === "" ? modelData.label : ""
          iconText: modelData.icon
          selected: modelData.id === root.currentTab
          focusable: true
          // Quiet chrome: only the selected tab has a fill (the theme's
          // selected state), the rest are bare labels.
          bordered: false
          foreground: selected ? root.foreground : root.dim
          fontFamily: root.fontFamily
          Accessible.role: Accessible.PageTab
          Accessible.name: modelData.label
          onClicked: {
            // Enter on the tab already showing goes into it; a click is just a click.
            if (selected && activeFocus && !root.pressedLately()) root.landFocus()
            else root.selectTab(modelData.id)
          }
          onHovered: function(isHovered) {
            // Hyprland hands the pointer back just after a keyboard open.
            // On the way across Settings, the pointer shouldn't leave it.
            if (Date.now() - root.openedAt < 500 || root.onSettings) return
            if (isHovered) {
              root.pendingTab = modelData.id
              hoverSwitch.restart()
            } else if (root.pendingTab === modelData.id) {
              hoverSwitch.stop()
              root.pendingTab = ""
            }
          }
        }
      }
    }

    Button {
      id: gear
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      iconText: Catalog.SETTINGS_TAB.icon
      selected: root.onSettings
      focusable: true
      bordered: false
      foreground: selected ? root.foreground : root.dim
      fontFamily: root.fontFamily
      Accessible.role: Accessible.PageTab
      Accessible.name: Catalog.SETTINGS_TAB.label
      onClicked: {
        if (selected && activeFocus && !root.pressedLately()) root.landFocus()
        else {
          root.selectTab(Catalog.SETTINGS_TAB.id)
          root.landFocus()
        }
      }
    }

  }

  Loader {
    id: body
    anchors.top: header.bottom
    anchors.topMargin: Style.spacing.panelGap * 1.5
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    sourceComponent: {
      if (root.cardHere) return layoutCard
      switch (root.currentTab) {
      case "media": return mediaTab
      case "calendar": return calendarTab
      case "capture": return captureTab
      case "system": return systemTab
      case "theme": if (root.themeEnabled) return themeTab; break
      case "activities": return activitiesTab
      case "keys": return keysTab
      case "settings": return settingsTab
      }
      return homeTab
    }
  }

  Component {
    id: layoutCard
    OnboardingCard {
      foreground: root.foreground; fontFamily: root.fontFamily
      layout: root.service ? root.service.layout : null
    }
  }
  Component {
    id: homeTab
    HomeTab {
      foreground: root.foreground; fontFamily: root.fontFamily; now: clock.date; bar: root.bar; config: root.config
      weather: root.service ? root.service.weather : null
      media: root.service ? root.service.media : null
      service: root.service; nowMs: root.now
    }
  }
  Component {
    id: mediaTab
    MediaTab {
      foreground: root.foreground; fontFamily: root.fontFamily; bar: root.bar
      media: root.service ? root.service.media : null
      visualizer: root.service ? root.service.visualizer : null
      config: root.config; editor: root.settingsEditor
    }
  }
  Component { id: calendarTab; CalendarTab { foreground: root.foreground; fontFamily: root.fontFamily; now: clock.date; config: root.config } }
  Component { id: captureTab; CaptureTab { foreground: root.foreground; fontFamily: root.fontFamily; service: root.service; nowMs: root.now } }
  Component { id: themeTab; ThemeTab { foreground: root.foreground; fontFamily: root.fontFamily; service: root.service } }
  Component { id: systemTab; SystemTab { foreground: root.foreground; fontFamily: root.fontFamily; service: root.service; config: root.config; nowMs: root.now } }
  Component { id: keysTab; KeysTab { foreground: root.foreground; fontFamily: root.fontFamily; keybindings: root.service ? root.service.keybindings : null; service: root.service
    onTabDigit: function(text) { root.showTab(HubKeys.digitTab(root.tabValues, text)) } } }
  Component { id: settingsTab; SettingsTab { foreground: root.foreground; fontFamily: root.fontFamily; service: root.service; config: root.config; editor: root.settingsEditor
    onFocusMoved: function(item) { root.reveal(item) } } }
  Component { id: activitiesTab; ActivitiesTab { foreground: root.foreground; fontFamily: root.fontFamily; bar: root.bar; activities: root.activities; allowActions: root.allowActions; nowMs: root.now
    notifications: root.service ? root.service.notifications : null } }

  // Notes each press, then lets it through, so the focus a click moves can be
  // told from the focus a key moves.
  MouseArea {
    anchors.fill: parent
    z: 100
    onPressed: function(mouse) {
      root.pressedAt = Date.now()
      if (root.ringTarget && !(root.isTextField(root.ringTarget))) {
        root.lastRect = null
        keyCatcher.forceActiveFocus()
      }
      mouse.accepted = false
    }
  }

  Rectangle {
    id: ring
    z: 101
    visible: root.ringTarget !== null && root.ringTarget.visible
    width: root.ringTarget ? root.ringTarget.width : 0
    height: root.ringTarget ? root.ringTarget.height : 0
    radius: Style.cornerRadius
    color: "transparent"
    border.width: Math.max(1, Style.space(2))
    border.color: Style.focusStateColor(root.foreground, Commons.Color.accent)
  }
}
