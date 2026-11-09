import QtQuick
import QtTest
import "../lib/Format.js" as Format

TestCase {
  name: "Format"

  function test_duration() {
    compare(Format.duration(0), "0:00")
    compare(Format.duration(5.9), "0:05")
    compare(Format.duration(65), "1:05")
    compare(Format.duration(3599), "59:59")
    compare(Format.duration(3600), "1:00:00")
    compare(Format.duration(3725), "1:02:05")
    compare(Format.duration(-3), "0:00")
    compare(Format.duration(NaN), "0:00")
    compare(Format.duration(undefined), "0:00")
  }

  function test_roundedTemp() {
    compare(Format.roundedTemp(21.4), "21")
    compare(Format.roundedTemp("21.5"), "22")
    compare(Format.roundedTemp(-0.4), "0")
    compare(Format.roundedTemp(-3.6), "-4")
    compare(Format.roundedTemp(null), "")
    compare(Format.roundedTemp("abc"), "")
  }

  function test_temp() {
    compare(Format.temp(21.1, false, false), "21°")
    compare(Format.temp(21.1, true, false), "70°")
    compare(Format.temp(21.1, true, true), "70°F")
    compare(Format.temp(-40, true, true), "-40°F")
    compare(Format.temp(0, false, true), "0°C")
    compare(Format.temp(null, false, true), "")
    compare(Format.temp(NaN, true, true), "")
  }

  function test_age() {
    var now = 10 * 86400000
    compare(Format.age(now, now), "now")
    compare(Format.age(now - 30000, now), "now")
    compare(Format.age(now - 5 * 60000, now), "5 min ago")
    compare(Format.age(now - 2 * 3600000, now), "2 h ago")
    compare(Format.age(now - 3 * 86400000, now), "3 d ago")
  }

  function test_shellQuote() {
    compare(Format.shellQuote("/a b/c.mp4"), "'/a b/c.mp4'")
    compare(Format.shellQuote("it's"), "'it'\\''s'")
    compare(Format.shellQuote(""), "''")
  }
}
