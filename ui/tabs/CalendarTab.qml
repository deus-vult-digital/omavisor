pragma ComponentBehavior: Bound

import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import ".."
import "../../lib/Calendar.js" as Calendar

// Today on the left (date, ISO week, day and year progress, and life
// progress when `birthYear` is set, as on the stock clock), the month grid
// with ISO week numbers on the right. Chevrons or the wheel step months;
// the calendar button between them comes back to today. Grid and numbering are the
// stock clock's (lib/Calendar.js); `weekStartDay` works the same way.
Item {
  id: root

  property color foreground: Commons.Color.foreground
  property string fontFamily: Style.font.family
  property date now: new Date()
  property var config: ({})

  readonly property color dim: Qt.darker(foreground, 1.4)
  readonly property int todayYear: now.getFullYear()
  readonly property string todayKey: Calendar.keyForDate(now)

  property int viewYear: todayYear
  property int viewMonth: now.getMonth()
  readonly property bool viewingToday: viewYear === todayYear && viewMonth === now.getMonth()

  readonly property int weekStart: Calendar.normalizedWeekStart(config ? config.weekStartDay : null, Qt.locale().firstDayOfWeek)
  readonly property var weekdays: Calendar.weekdayOrder(weekStart)
  readonly property var weeks: Calendar.monthGrid(viewYear, viewMonth, weekStart, todayKey)
  readonly property int birthYear: Calendar.parseBirthYear(config ? config.birthYear : 0, todayYear)
  readonly property real lifeDone: Calendar.lifeProgress(Calendar.ageFromBirthYear(birthYear, todayYear), config ? config.lifeExpectancy : 0)
  // English labels, like the stock clock; only the week start is regional.
  readonly property var labelLocale: Qt.locale("en_US")

  function moveMonth(delta) {
    var next = Calendar.stepMonth(viewYear, viewMonth, delta)
    viewYear = next.year
    viewMonth = next.month
  }

  function goToToday() {
    viewYear = todayYear
    viewMonth = now.getMonth()
  }

  // Each time the tab opens it starts on this month.
  Component.onCompleted: goToToday()
  onVisibleChanged: if (visible) goToToday()

  Row {
    anchors.fill: parent
    spacing: Style.spacing.panelGap * 2

    Tile {
      id: today
      width: Math.round((parent.width - parent.spacing) * 0.38)
      height: parent.height
      title: "Today"
      foreground: root.foreground
      fontFamily: root.fontFamily

      Column {
        width: parent.width
        spacing: Style.spacing.sm

        Text {
          width: parent.width
          textFormat: Text.PlainText
          text: Qt.formatDate(root.now, "MMMM d")
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.display
          font.bold: true
          elide: Text.ElideRight
        }

        Text {
          width: parent.width
          textFormat: Text.PlainText
          text: root.labelLocale.dayName(root.now.getDay(), Locale.LongFormat) + "  ·  Week "
            + Calendar.isoWeek(root.todayYear, root.now.getMonth(), root.now.getDate())
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          elide: Text.ElideRight
        }
      }

      // The rails' labels share one width so the tracks line up.
      TextMetrics {
        id: railLabel
        text: "0000"
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        font.letterSpacing: 1
      }

      Column {
        anchors.bottom: parent.bottom
        width: parent.width
        spacing: Style.spacing.md

        ProgressRail {
          width: parent.width
          label: "DAY"
          labelWidth: railLabel.advanceWidth
          value: Calendar.dayProgress(root.now)
          foreground: root.foreground
          fontFamily: root.fontFamily
        }

        ProgressRail {
          width: parent.width
          label: String(root.todayYear)
          labelWidth: railLabel.advanceWidth
          value: Calendar.yearProgress(root.todayYear, root.now.getMonth(), root.now.getDate())
          foreground: root.foreground
          fontFamily: root.fontFamily
        }

        ProgressRail {
          visible: root.birthYear > 0
          width: parent.width
          label: "LIFE"
          labelWidth: railLabel.advanceWidth
          value: root.lifeDone
          foreground: root.foreground
          fontFamily: root.fontFamily
        }
      }
    }

    Tile {
      id: month
      width: parent.width - today.width - parent.spacing
      height: parent.height
      title: Qt.formatDate(new Date(root.viewYear, root.viewMonth, 1, 12), "MMMM yyyy")
      foreground: root.foreground
      fontFamily: root.fontFamily
      divider: true
      dividerGap: parent.spacing

      trailing: [
        PanelActionButton {
          focusable: true
          iconText: "󰅁"
          tooltipText: "Previous month"
          foreground: root.foreground
          fontFamily: root.fontFamily
          size: Style.font.icon + Style.spacing.sm
          Accessible.role: Accessible.Button
          Accessible.name: tooltipText
          onClicked: root.moveMonth(-1)
        },
        PanelActionButton {
          focusable: true
          iconText: "󰃭"
          tooltipText: "Today"
          visible: !root.viewingToday
          foreground: root.foreground
          fontFamily: root.fontFamily
          size: Style.font.icon + Style.spacing.sm
          Accessible.role: Accessible.Button
          Accessible.name: "Back to today"
          onClicked: root.goToToday()
        },
        PanelActionButton {
          focusable: true
          iconText: "󰅂"
          tooltipText: "Next month"
          foreground: root.foreground
          fontFamily: root.fontFamily
          size: Style.font.icon + Style.spacing.sm
          Accessible.role: Accessible.Button
          Accessible.name: tooltipText
          onClicked: root.moveMonth(1)
        }
      ]

      Item {
        id: grid
        anchors.fill: parent

        readonly property real weekWidth: Style.space(26)
        readonly property real cellWidth: (width - weekWidth) / 7
        readonly property real cellHeight: Math.floor(height / 7)

        WheelHandler {
          onWheel: function(event) {
            if (event.angleDelta.y === 0) return
            root.moveMonth(event.angleDelta.y > 0 ? -1 : 1)
          }
        }

        Column {
          Row {
            Text {
              width: grid.weekWidth
              height: grid.cellHeight
              horizontalAlignment: Text.AlignLeft
              verticalAlignment: Text.AlignVCenter
              text: "W"
              color: Qt.darker(root.foreground, 1.9)
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.letterSpacing: 1
              font.bold: true
            }

            Repeater {
              model: root.weekdays

              Text {
                required property var modelData
                width: grid.cellWidth
                height: grid.cellHeight
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                textFormat: Text.PlainText
                text: root.labelLocale.dayName(modelData, Locale.ShortFormat).substr(0, 2).toUpperCase()
                color: Qt.darker(root.foreground, 1.5)
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.letterSpacing: 1
                font.bold: true
              }
            }
          }

          Repeater {
            model: root.weeks

            Row {
              id: weekRow
              required property var modelData

              Text {
                width: grid.weekWidth
                height: grid.cellHeight
                verticalAlignment: Text.AlignVCenter
                textFormat: Text.PlainText
                text: weekRow.modelData.week
                color: Qt.darker(root.foreground, 1.9)
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }

              Repeater {
                model: weekRow.modelData.days

                Item {
                  id: cell
                  required property var modelData
                  width: grid.cellWidth
                  height: grid.cellHeight

                  // Today is outlined, not filled, as on the stock clock.
                  Rectangle {
                    anchors.centerIn: parent
                    width: Math.min(parent.width, parent.height * 1.6)
                    height: parent.height
                    radius: Style.cornerRadius
                    color: "transparent"
                    border.width: cell.modelData.today ? Math.max(1, Style.spacing.hairline) : 0
                    border.color: Style.normalBorderFor(root.foreground, Commons.Color.accent)
                  }

                  Text {
                    anchors.centerIn: parent
                    textFormat: Text.PlainText
                    text: cell.modelData.day
                    color: cell.modelData.inMonth
                      ? (cell.modelData.weekend ? Qt.darker(root.foreground, 1.45) : root.foreground)
                      : Qt.darker(root.foreground, 2.2)
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.bodySmall
                    font.bold: cell.modelData.today
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
