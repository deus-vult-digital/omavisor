import QtQuick
import QtTest
import "../lib/Calendar.js" as Calendar

TestCase {
  name: "Calendar"

  function test_isoWeek() {
    compare(Calendar.isoWeek(2026, 9, 29), 44)
    compare(Calendar.isoWeek(2021, 0, 1), 53)
    compare(Calendar.isoWeek(2024, 11, 30), 1)
    compare(Calendar.isoWeek(2026, 0, 1), 1)
  }

  function test_gridIsSixFullWeeks() {
    var weeks = Calendar.monthGrid(2026, 1, 1, "")
    compare(weeks.length, 6)
    for (let i = 0; i < weeks.length; i++) compare(weeks[i].days.length, 7)
  }

  function test_gridMondayStart() {
    // October 2026 starts on a Thursday.
    var weeks = Calendar.monthGrid(2026, 9, 1, "2026-10-29")
    compare(weeks[0].days[0].key, "2026-09-28")
    compare(weeks[0].days[3].key, "2026-10-01")
    verify(!weeks[0].days[0].inMonth)
    verify(weeks[0].days[3].inMonth)
    compare(weeks[0].week, 40)
    var today = []
    for (let w = 0; w < weeks.length; w++)
      for (let d = 0; d < 7; d++) if (weeks[w].days[d].today) today.push(weeks[w].days[d].key)
    compare(today, ["2026-10-29"])
  }

  function test_gridSundayStartWeekNumberFromThursday() {
    var weeks = Calendar.monthGrid(2026, 9, 0, "")
    compare(weeks[0].days[0].key, "2026-09-27")
    compare(weeks[0].days[0].weekday, 0)
    compare(weeks[0].week, 40)
    verify(weeks[0].days[0].weekend)
  }

  function test_weekStart() {
    compare(Calendar.normalizedWeekStart("sunday", 1), 0)
    compare(Calendar.normalizedWeekStart("Mon", 0), 1)
    compare(Calendar.normalizedWeekStart(null, 0), 0)
    compare(Calendar.normalizedWeekStart("bogus", "nope"), 1)
    compare(Calendar.weekdayOrder(1), [1, 2, 3, 4, 5, 6, 0])
  }

  function test_stepMonth() {
    compare(Calendar.stepMonth(2026, 11, 1), { year: 2027, month: 0 })
    compare(Calendar.stepMonth(2026, 0, -1), { year: 2025, month: 11 })
    compare(Calendar.stepMonth(2026, 5, 0), { year: 2026, month: 5 })
  }

  function test_yearProgress() {
    compare(Calendar.yearProgress(2026, 0, 1), 0)
    compare(Calendar.percent(Calendar.yearProgress(2026, 11, 31)), 100)
    compare(Calendar.percent(Calendar.yearProgress(2026, 9, 29)), 82)
    compare(Calendar.daysInYear(2024), 366)
  }

  function test_dayProgress() {
    compare(Calendar.dayProgress(new Date(2026, 9, 29, 0, 0, 0)), 0)
    compare(Calendar.dayProgress(new Date(2026, 9, 29, 12, 0, 0)), 0.5)
  }

  function test_life() {
    compare(Calendar.parseBirthYear(1983, 2026), 1983)
    compare(Calendar.parseBirthYear("1983", 2026), 1983)
    compare(Calendar.parseBirthYear(2030, 2026), 0)
    compare(Calendar.parseBirthYear("83", 2026), 0)
    compare(Calendar.parseBirthYear(undefined, 2026), 0)
    compare(Calendar.ageFromBirthYear(1983, 2026), 43)
    compare(Calendar.parseLifeExpectancy(85), 85)
    compare(Calendar.parseLifeExpectancy("x"), 90)
    compare(Calendar.parseLifeExpectancy(0), 90)
    compare(Calendar.percent(Calendar.lifeProgress(43, 85)), 51)
    compare(Calendar.lifeProgress(0, 85), 0)
    compare(Calendar.lifeProgress(200, 85), 1)
  }
}
