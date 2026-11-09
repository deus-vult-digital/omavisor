import QtQuick
import qs.Commons
import qs.Commons as Commons

// The bloom: one urgent activity, hero-sized, in the hub's card opened
// short (expanded width × 120). A click on it (outside its buttons) grows it
// into the full hub on the Activities tab.
Item {
  id: root

  property QtObject bar: null
  property var activity: null
  property var activities: null
  property bool allowActions: true
  property real now: Date.now()

  signal clicked()

  readonly property color foreground: bar && bar.foreground ? bar.foreground : Commons.Color.popups.text
  readonly property string fontFamily: bar && bar.fontFamily ? bar.fontFamily : Style.font.family

  Accessible.role: Accessible.AlertMessage
  Accessible.name: activity ? activity.title : ""

  // Under the row, so the row's buttons get their clicks first.
  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: root.clicked()
  }

  ActivityRow {
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    large: true
    bar: root.bar
    activity: root.activity
    activities: root.activities
    allowActions: root.allowActions
    now: root.now
    foreground: root.foreground
    fontFamily: root.fontFamily
  }
}
