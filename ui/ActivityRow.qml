pragma ComponentBehavior: Bound

import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "../lib/ActivityStore.js" as Store

// One live activity: glyph, title, source and subtitle, a progress line,
// the trailing text and its action buttons. `large` is the bloom's hero
// size; the Activities tab uses the list size.
//
// Action buttons are shown only when allowActions is on (or the activity is
// Omavisor's own: recording, update, timers), and run only on
// click, through the service (argv arrays, never a shell string).
Item {
  id: root

  property var activity: null
  property var activities: null
  property bool allowActions: true
  property bool large: false
  property bool dismissable: !large
  property real now: Date.now()
  property QtObject bar: null
  property color foreground: Commons.Color.foreground
  property string fontFamily: Style.font.family

  readonly property color dim: Qt.darker(foreground, 1.4)
  readonly property bool ended: !!activity && activity.endsAt > 0
  readonly property color tint: !activity ? foreground
    : (activity.priority === "urgent" || activity.state === "error") ? Commons.Color.urgent
    : activity.state === "waiting" ? Commons.Color.accent : foreground
  readonly property string trailing: Store.trailingText(activity, now)
  readonly property string detail: {
    if (!activity) return ""
    var parts = []
    if (activity.source) parts.push(activity.source)
    if (activity.subtitle) parts.push(activity.subtitle)
    if (parts.length === 0 && (ended || activity.state !== "running"))
      parts.push(activity.state === "waiting" ? "Waiting" : activity.state === "error" ? "Failed" : activity.state === "success" ? "Done" : "")
    return parts.join(" · ")
  }

  implicitHeight: Math.max(glyphText.implicitHeight, texts.implicitHeight)
  opacity: ended ? 0.6 : 1
  Behavior on opacity { NumberAnimation { duration: 160 } }

  Accessible.role: Accessible.ListItem
  Accessible.name: activity ? activity.title + (detail ? ", " + detail : "") + (trailing ? ", " + trailing : "") : ""

  Text {
    id: glyphText
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    width: root.large ? Style.font.displayLarge * 1.4 : Style.font.iconLarge * 1.6
    horizontalAlignment: Text.AlignHCenter
    textFormat: Text.PlainText
    text: Store.leadingGlyph(root.activity)
    color: root.tint
    font.family: root.fontFamily
    font.pixelSize: root.large ? Style.font.displayLarge : Style.font.iconLarge
  }

  Column {
    id: texts
    anchors.left: glyphText.right
    anchors.leftMargin: Style.spacing.lg
    anchors.right: side.left
    anchors.rightMargin: Style.spacing.lg
    anchors.verticalCenter: parent.verticalCenter
    spacing: root.large ? Style.spacing.sm : Style.spacing.xxs

    Text {
      width: parent.width
      textFormat: Text.PlainText
      text: root.activity ? root.activity.title : ""
      elide: Text.ElideRight
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: root.large ? Style.font.heading : Style.font.body
      font.bold: true
    }

    Text {
      width: parent.width
      visible: text !== ""
      textFormat: Text.PlainText
      text: root.detail
      elide: Text.ElideRight
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: root.large ? Style.font.body : Style.font.bodySmall
    }

    // Progress: a hairline track in the separators' strength, filled with
    // the activity's tint. Hidden while indeterminate.
    Item {
      width: parent.width
      height: Math.max(2, Style.space(3))
      visible: root.activity !== null && root.activity.progress !== null && root.activity.progress !== undefined

      Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)
      }

      Rectangle {
        height: parent.height
        radius: height / 2
        width: parent.width * (root.activity && root.activity.progress ? root.activity.progress : 0)
        color: root.tint === root.foreground ? Commons.Color.accent : root.tint
        Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
      }
    }
  }

  Row {
    id: side
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    spacing: Style.spacing.md

    Text {
      anchors.verticalCenter: parent.verticalCenter
      visible: text !== ""
      textFormat: Text.PlainText
      text: root.trailing
      color: root.tint
      font.family: root.fontFamily
      font.pixelSize: root.large ? Style.font.heading : Style.font.body
      font.features: { "tnum": 1 }
    }

    // A count, not the array: renders hand over fresh arrays, and an
    // unchanged count keeps the buttons (and a press in progress) alive.
    Repeater {
      model: (root.allowActions || (root.activity && root.activity.own === true)) && root.activity && !root.ended ? root.activity.actions.length : 0

      Button {
        required property int index
        readonly property var action: root.activity && root.activity.actions[index] ? root.activity.actions[index] : null
        focusable: true
        anchors.verticalCenter: parent.verticalCenter
        text: action ? action.label : ""
        bordered: true
        foreground: root.foreground
        fontFamily: root.fontFamily
        Accessible.name: text
        onClicked: if (root.activities) root.activities.runAction(root.activity.id, index, root.allowActions)
      }
    }

    Button {
      focusable: true
      anchors.verticalCenter: parent.verticalCenter
      visible: root.dismissable && !root.ended
      iconText: "󰅖"
      tooltipText: "Dismiss"
      foreground: root.dim
      fontFamily: root.fontFamily
      Accessible.name: "Dismiss " + (root.activity ? root.activity.title : "")
      onClicked: if (root.activities && root.activity) root.activities.dismiss(root.activity.id)
    }
  }
}
