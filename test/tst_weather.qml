import QtQuick
import QtTest
import "../lib/Weather.js" as Weather

TestCase {
  name: "Weather"

  function test_locationFile() {
    var loc = Weather.parseLocationFile('{"name":" Portland ","latitude":45.52,"longitude":-122.68}')
    compare(loc.name, "Portland")
    compare(loc.latitude, 45.52)
    verify(Weather.hasCoordinates(loc))
    var nameOnly = Weather.parseLocationFile('{"name":"Malibu"}')
    compare(nameOnly.latitude, null)
    verify(!Weather.hasCoordinates(nameOnly))
    compare(Weather.parseLocationFile("not json").name, "")
    compare(Weather.parseLocationFile("").name, "")
  }

  function test_forecastUrl() {
    var url = Weather.forecastUrl(45.52, -122.68)
    verify(url.indexOf("https://api.open-meteo.com/v1/forecast?") === 0)
    verify(url.indexOf("latitude=45.52") !== -1)
    verify(url.indexOf("longitude=-122.68") !== -1)
    verify(url.indexOf("weather_code") !== -1)
  }

  function test_pickPlaceNearest() {
    var raw = JSON.stringify({ results: [
      { name: "Portland", latitude: -38.34, longitude: 141.6, country_code: "AU" },
      { name: "Portland", latitude: 45.52, longitude: -122.68, country_code: "us" }
    ] })
    var near = Weather.pickPlace(raw, 45.5, -122.7)
    compare(near.countryCode, "US")
    compare(Weather.pickPlace(raw, null, null).countryCode, "AU")
    var zoned = JSON.stringify({ results: [
      { name: "Portland", latitude: -38.34, longitude: 141.6, country_code: "AU", timezone: "Australia/Melbourne" },
      { name: "Portland", latitude: 45.52, longitude: -122.68, country_code: "US", timezone: "America/Los_Angeles" }
    ] })
    var offsets = { "Australia/Melbourne": 660, "America/Los_Angeles": -480 }
    compare(Weather.pickPlace(zoned, null, null, offsets, -480).countryCode, "US")
    compare(Weather.pickPlace(zoned, null, null, offsets, 660).countryCode, "AU")
    compare(Weather.pickPlace(zoned, null, null, offsets, 60).countryCode, "AU")
    compare(Weather.pickPlace(zoned, null, null, null, -480).countryCode, "AU")
    compare(Weather.zones(zoned), ["Australia/Melbourne", "America/Los_Angeles"])
    compare(Weather.zones('{"results":[{"timezone":"x;rm"}]}'), [])
    compare(Weather.parseOffset("-0600"), -360)
    compare(Weather.parseOffset("+0530"), 330)
    verify(isNaN(Weather.parseOffset("bogus")))
    compare(Weather.pickPlace("{}", 1, 1), null)
    compare(Weather.pickPlace("oops", 1, 1), null)
  }

  function test_parseForecast() {
    var raw = JSON.stringify({
      current: { temperature_2m: 21.2, apparent_temperature: 19.5, relative_humidity_2m: 40,
        wind_speed_10m: 27.4, wind_direction_10m: 225, weather_code: 2, is_day: 0 },
      daily: { temperature_2m_max: [24], temperature_2m_min: [8] }
    })
    var r = Weather.parseForecast(raw)
    compare(r.tempC, 21.2)
    compare(r.code, 2)
    compare(r.isDay, false)
    compare(r.maxC, 24)
    compare(Weather.parseForecast('{"current":{}}'), null)
    compare(Weather.parseForecast("<html>"), null)
  }

  function test_glyphMatchesStockMapping() {
    compare(Weather.glyph(0, true), "")
    compare(Weather.glyph(0, false), "")
    compare(Weather.wttrCode(2), 116)
    compare(Weather.wttrCode(63), 308)
    compare(Weather.wttrCode(1234), 119)
    compare(Weather.glyph(95, true), Weather.iconForCode(389, false))
  }

  function test_condition() {
    compare(Weather.condition(0), "Clear")
    compare(Weather.condition(3), "Overcast")
    compare(Weather.condition(61), "Rain")
    compare(Weather.condition(99), "Thunderstorm")
  }

  function test_wind() {
    compare(Weather.windArrow(225), "↗")
    compare(Weather.windArrow(0), "↓")
    compare(Weather.windArrow(-90), "→")
    compare(Weather.wind(27.4, true), "17 mph")
    compare(Weather.wind(27.4, false), "27 km/h")
    compare(Weather.wind(null, false), "")
  }

  function test_units() {
    verify(Weather.useImperial("imperial", "DE", "de_DE"))
    verify(!Weather.useImperial("metric", "US", "en_US"))
    verify(Weather.useImperial("auto", "US", "de_DE"))
    verify(!Weather.useImperial("", "GB", "en_US"))
    verify(Weather.useImperial("", "", "en_US"))
    verify(!Weather.useImperial("", "", "en_GB"))
  }

  function test_stale() {
    var period = 15 * 60000
    verify(!Weather.isStale(0, 1e12, period))
    verify(!Weather.isStale(1e12 - period, 1e12, period))
    verify(Weather.isStale(1e12 - 3 * period, 1e12, period))
  }

  function test_parseStatus() {
    var s = Weather.parseStatus("Portland  ·  Temp 59°F  ·  Wind ↗11mph\n")
    compare(s.place, "Portland")
    compare(s.temp, "59°F")
    compare(s.value, 59)
    compare(s.unit, "F")
    compare(s.wind, "↗11mph")
    compare(s.summary, "Portland  ·  Temp 59°F  ·  Wind ↗11mph")
    verify(Math.abs(s.tempC - 15) < 0.01)
    var c = Weather.parseStatus("Malibu, CA  ·  Temp +7°C  ·  Wind ←9km/h")
    compare(c.place, "Malibu, CA")
    compare(c.temp, "7°C")
    compare(c.tempC, 7)
    compare(Weather.parseStatus("Oslo  ·  Temp -3°C  ·  Wind ↓2km/h").value, -3)
    compare(Weather.parseStatus("Weather unavailable"), null)
    compare(Weather.parseStatus(""), null)
    compare(Weather.parseStatus("Unknown location; please try ~45,-122  ·  Temp   ·  Wind "), null)
  }

  function test_parseIcon() {
    compare(Weather.parseIcon("\ue30d\n"), "\ue30d")
    compare(Weather.parseIcon(""), "")
    compare(Weather.parseIcon("Weather unavailable"), "")
  }

  function test_cliTemp() {
    var f = Weather.parseStatus("X  ·  Temp 59°F  ·  Wind ↗11mph")
    compare(Weather.cliTemp(f, true, false), "59°")
    compare(Weather.cliTemp(f, true, true), "59°F")
    compare(Weather.cliTemp(f, false, true), "15°C")
    var c = Weather.parseStatus("X  ·  Temp 7°C  ·  Wind ←9km/h")
    compare(Weather.cliTemp(c, false, false), "7°")
    compare(Weather.cliTemp(c, true, true), "45°F")
    compare(Weather.cliTemp(null, true, true), "")
  }

  function test_agrees() {
    verify(Weather.agrees(6.7, 5.9))
    verify(Weather.agrees(-1, 2))
    verify(!Weather.agrees(15, 5.9))
    verify(!Weather.agrees(NaN, 5))
    verify(!Weather.agrees(5, null))
  }
}
