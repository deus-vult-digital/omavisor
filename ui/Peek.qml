import QtQuick
import qs.Commons
import qs.Commons as Commons
import "../lib/ActivityStore.js" as Store

// The top live activity on both sides of the pill's clock, the Dynamic
// Island's compact leading/trailing: collapsed it is only the leading glyph
// (the priority badge); peeking adds the title after it and the trailing
// text (progress, countdown, `compact.trailing`) on the far side.
//
// Both sides take the same width so the clock stays centred on the pill,
// and grow in step with the pill's width, clipped, so text never runs over
// the clock while it animates. Each side's content hugs the clock; the
// shorter side's slack becomes padding at the pill's outer edge.
//
// When the pill shares the bar's centre with other widgets, the bar keeps
// one edge of it in place (`edge`, the bar's fixedEdge: "start" or "end").
// Then everything goes on the side that grows, one wing of twice `side`
// (glyph, title, trailing), so the clock doesn't move when it peeks.
Item {
  id: root

  property var activity: null
  property bool peeking: false
  property real now: Date.now()
  property bool reduceMotion: false
  property color foreground: Commons.Color.foreground
  property color urgentColor: Commons.Color.urgent
  property string fontFamily: Style.font.family
  property real fontSize: Style.font.body
  // Gap between a side and the clock.
  property real gap: Style.spacing.xxl
  // At most this per side, so a peeking pill stays within ~480 px.
  property real maxSide: Style.space(150)
  // The pill's edge that stays put: "center" (both wings), "start" or "end".
  property string edge: "center"
  readonly property bool oneSided: edge === "start" || edge === "end"
  // The wings' widths: the leading one (glyph, title) is on the left unless
  // the left edge is the fixed one.
  readonly property real leadWidth: oneSided ? side * 2 : side
  readonly property real trailWidth: oneSided ? 0 : side

  // A count-up (a recording) shows its time even collapsed.
  readonly property bool live: !!activity && activity.since > 0 && Store.isCounting(activity)

  readonly property string glyph: Store.leadingGlyph(activity)
  readonly property string trailing: peeking || live ? Store.trailingText(activity, now) : ""
  readonly property color tint: !activity ? foreground
    : (activity.priority === "urgent" || activity.state === "error") ? urgentColor
    : activity.state === "waiting" ? Commons.Color.accent : foreground

  readonly property real wantSide: !activity ? 0
    : oneSided ? (Math.min(maxSide * 2, leadRow.implicitWidth) + gap) / 2
    : Math.min(maxSide, Math.max(leadRow.implicitWidth, trailText.visible ? trailText.implicitWidth : 0)) + gap
  // What the pill adds on each side of the clock.
  property real side: wantSide
  Behavior on side {
    NumberAnimation { duration: root.reduceMotion ? 0 : 240; easing.type: Easing.OutCubic }
  }

  // Where a point (in this item) falls in the leading wing.
  function inLead(px) {
    return edge === "start" ? px >= width - leadWidth && px <= width : px >= 0 && px <= leadWidth
  }

  Item {
    id: leadWing
    x: root.edge === "start" ? root.width - width : 0
    width: root.leadWidth
    height: parent.height
    clip: true

    Row {
      id: leadRow
      // Hugs the clock: the wing's inner side.
      x: root.edge === "start" ? root.gap : parent.width - root.gap - width
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.spacing.sm

      Text {
        id: glyphText
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: root.glyph
        color: root.tint
        font.family: root.fontFamily
        font.pixelSize: root.fontSize
        renderType: Text.NativeRendering

        // Something waits for you (an agent's permission prompt): the badge
        // pulses until it goes on or ends.
        SequentialAnimation on opacity {
          running: Store.isPulsing(root.activity) && !root.reduceMotion
          loops: Animation.Infinite
          onRunningChanged: if (!running) glyphText.opacity = 1
          NumberAnimation { to: 0.25; duration: 700; easing.type: Easing.InOutSine }
          NumberAnimation { to: 1; duration: 700; easing.type: Easing.InOutSine }
        }
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        visible: root.peeking && text !== ""
        textFormat: Text.PlainText
        text: root.activity ? root.activity.title : ""
        width: Math.min(implicitWidth, root.maxSide - glyphText.implicitWidth - leadRow.spacing)
        elide: Text.ElideRight
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: root.fontSize
        renderType: Text.NativeRendering
      }

      // One-sided: the trailing text follows the title in the same wing.
      Text {
        anchors.verticalCenter: parent.verticalCenter
        visible: root.oneSided && text !== ""
        textFormat: Text.PlainText
        text: root.trailing
        color: root.tint
        font.family: root.fontFamily
        font.pixelSize: root.fontSize
        font.features: { "tnum": 1 }
        renderType: Text.NativeRendering
      }
    }
  }

  Item {
    anchors.right: parent.right
    width: root.trailWidth
    height: parent.height
    clip: true

    Text {
      id: trailText
      anchors.left: parent.left
      anchors.leftMargin: root.gap
      anchors.verticalCenter: parent.verticalCenter
      visible: !root.oneSided && text !== ""
      width: Math.min(implicitWidth, root.maxSide)
      elide: Text.ElideRight
      textFormat: Text.PlainText
      text: root.trailing
      color: root.tint
      font.family: root.fontFamily
      font.pixelSize: root.fontSize
      font.features: { "tnum": 1 }
      renderType: Text.NativeRendering
    }
  }
}
