import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "../lib/Hypr.js" as Hypr

// Hyprland strip (SPEC.md section 7, v1): the focused workspace and
// monitor and the active window, straight from Quickshell.Hyprland's event
// stream (no polling), the focused workspace's tiled layout, scroll to step
// workspaces and Omarchy's layout toggle.
//
// Quickshell 0.3.2 names (checked against its qmltypes and the stock
// Workspaces widget): Hyprland.focusedWorkspace {id, name, toplevels},
// Hyprland.focusedMonitor {name}, Hyprland.activeToplevel {title,
// workspace}, HyprlandWorkspace.lastIpcObject {tiledLayout},
// refreshWorkspaces(), dispatch(); the window's title and class come from
// Quickshell.Wayland's ToplevelManager.activeToplevel {title, appId}. The
// layout is only in lastIpcObject, refreshed while something shows it.
Item {
  id: root
  visible: false

  // Quickshell.Hyprland connects only under Hyprland.
  readonly property bool available: !!Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")

  readonly property var workspace: Hyprland.focusedWorkspace
  readonly property var monitor: Hyprland.focusedMonitor
  // The active window from the Wayland toplevel list, like the stock
  // ActiveWindow widget: Hyprland.activeToplevel only fills in on the first
  // focus change after the shell starts.
  readonly property var toplevel: ToplevelManager.activeToplevel
  readonly property var hyprToplevel: Hyprland.activeToplevel

  readonly property string workspaceLabel: workspace ? Hypr.workspaceLabel(workspace.id, workspace.name) : ""
  readonly property string monitorName: monitor ? String(monitor.name || "") : ""
  readonly property string windowClass: toplevel && toplevel.appId ? String(toplevel.appId) : ""
  // No window on an empty workspace, where the last focused window stays
  // the active toplevel; nor one Hyprland places on another workspace.
  readonly property bool hasWindow: !!toplevel
    && !(workspace && workspace.toplevels && workspace.toplevels.values.length === 0)
    && !(hyprToplevel && hyprToplevel.workspace && workspace && hyprToplevel.workspace !== workspace)
  // toplevel checked again: a closing window can re-evaluate this before
  // hasWindow catches up.
  readonly property string windowTitle: hasWindow && toplevel ? Hypr.windowTitle(toplevel.title, windowClass) : ""
  readonly property string layout: workspace && workspace.lastIpcObject ? String(workspace.lastIpcObject.tiledLayout || "") : ""

  // Things on screen that show the layout; refreshed while above zero.
  property int watchers: 0
  onWatchersChanged: if (watchers > 0) refresh()

  function refresh() {
    if (available) Hyprland.refreshWorkspaces()
  }

  Connections {
    target: Hyprland
    enabled: root.watchers > 0
    function onFocusedWorkspaceChanged() { root.refresh() }
  }

  // A layout rule sends no Hyprland event (checked on the event socket), so
  // a toggle from a keybind or the menu while the chip shows is caught by
  // what Omarchy's toggle does next: it announces the new layout with a
  // notification, which lands in the folder Omavisor already watches. Wired
  // in Service.qml.
  property var notifications: null
  Connections {
    target: root.notifications
    enabled: root.watchers > 0
    function onRecentChanged() { root.refresh() }
  }

  property real _wheel: 0
  // A wheel delta from a tile; whole notches step one workspace.
  function scroll(delta) {
    var w = Hypr.wheel(_wheel, delta)
    _wheel = w.accum
    if (w.notches !== 0) focusWorkspace(Hypr.scrollTarget(w.notches))
  }

  function focusWorkspace(target) {
    if (available) Hyprland.dispatch(Hypr.focusDispatch(target))
  }

  function toggleLayout() {
    toggleProbe.run()
  }

  Probe {
    id: toggleProbe
    command: ["omarchy", "hyprland", "workspace", "layout", "toggle"]
    onFinished: root.refresh()
  }
}
