.pragma library

// Open-Meteo request and response handling for the Weather module. The
// glyphs and the location file format match the stock weather panel
// (panels/weather/Model.js) and `omarchy weather icon`, so Omavisor and the
// rest of Omarchy show the same conditions. Pure, so it is unit tested.

var FORECAST_URL = "https://api.open-meteo.com/v1/forecast"
var GEOCODE_URL = "https://geocoding-api.open-meteo.com/v1/search"

function trim(value) {
  return String(value === undefined || value === null ? "" : value).replace(/^\s+|\s+$/g, "")
}

function number(value) {
  if (value === undefined || value === null || value === "") return NaN
  return parseFloat(String(value))
}

// ~/.local/state/omarchy/settings/weather.json, owned by
// omarchy-weather-location: {"name", "latitude", "longitude"}.
function parseLocationFile(raw) {
  var unset = { name: "", latitude: null, longitude: null }
  try {
    var data = JSON.parse(String(raw || ""))
    if (!data || typeof data !== "object") return unset
    var lat = number(data.latitude)
    var lon = number(data.longitude)
    var ok = !isNaN(lat) && !isNaN(lon)
    return {
      name: typeof data.name === "string" ? trim(data.name) : "",
      latitude: ok ? lat : null,
      longitude: ok ? lon : null
    }
  } catch (e) {
    return unset
  }
}

function hasCoordinates(location) {
  return !!location && !isNaN(number(location.latitude)) && !isNaN(number(location.longitude))
}

// Distinct time zone names in a geocoding response.
function zones(raw) {
  var results
  try { results = JSON.parse(String(raw || "{}")).results } catch (e) { return [] }
  var out = []
  for (var i = 0; results && i < results.length; i++) {
    var tz = results[i] && typeof results[i].timezone === "string" ? results[i].timezone : ""
    if (/^[A-Za-z0-9_+\-\/]+$/.test(tz) && out.indexOf(tz) === -1) out.push(tz)
  }
  return out
}

// "-0600" (date +%z) → minutes east of UTC, NaN when malformed.
function parseOffset(text) {
  var m = /^([+-])(\d\d)(\d\d)$/.exec(trim(text))
  if (!m) return NaN
  return (m[1] === "-" ? -1 : 1) * (parseInt(m[2], 10) * 60 + parseInt(m[3], 10))
}

function forecastUrl(latitude, longitude) {
  return FORECAST_URL
    + "?latitude=" + encodeURIComponent(String(latitude))
    + "&longitude=" + encodeURIComponent(String(longitude))
    + "&current=temperature_2m,apparent_temperature,relative_humidity_2m,wind_speed_10m,wind_direction_10m,weather_code,is_day"
    + "&daily=weather_code,temperature_2m_max,temperature_2m_min"
    + "&forecast_days=1&timezone=auto"
}

function geocodeUrl(name) {
  return GEOCODE_URL + "?name=" + encodeURIComponent(trim(name)) + "&count=10&language=en&format=json"
}

function distance2(aLat, aLon, bLat, bLon) {
  var dLat = aLat - bLat
  var dLon = (aLon - bLon) * Math.cos((aLat + bLat) / 2 * Math.PI / 180)
  return dLat * dLat + dLon * dLon
}

// The geocoding result for a place name: the one nearest the stored
// coordinates when there are some (a name alone is ambiguous: Portland),
// else the first whose time zone has this machine's UTC offset (the
// IP-detected city is local; `offsets` maps zone name → minutes east of
// UTC), else the first. null when there is none.
function pickPlace(raw, latitude, longitude, offsets, localOffset) {
  var results
  try { results = JSON.parse(String(raw || "{}")).results } catch (e) { return null }
  if (!results || !results.length) return null

  var lat = number(latitude)
  var lon = number(longitude)
  if ((isNaN(lat) || isNaN(lon)) && offsets) {
    for (var z = 0; z < results.length; z++) {
      var zoneOffset = results[z] ? offsets[results[z].timezone] : undefined
      if (zoneOffset !== undefined && zoneOffset === localOffset) { results = [results[z]]; break }
    }
  }
  var best = null
  var bestDistance = Infinity
  for (var i = 0; i < results.length; i++) {
    var r = results[i]
    if (!r || isNaN(number(r.latitude)) || isNaN(number(r.longitude))) continue
    var d = isNaN(lat) || isNaN(lon) ? i : distance2(lat, lon, number(r.latitude), number(r.longitude))
    if (d < bestDistance) { best = r; bestDistance = d }
  }
  if (!best) return null
  return {
    name: String(best.name || ""),
    latitude: number(best.latitude),
    longitude: number(best.longitude),
    countryCode: String(best.country_code || "").toUpperCase()
  }
}

// An Open-Meteo forecast response → the reading Omavisor keeps (and caches),
// or null when it carries no current temperature.
function parseForecast(raw) {
  var data
  try { data = JSON.parse(String(raw || "")) } catch (e) { return null }
  var c = data && data.current
  if (!c || c.temperature_2m === undefined || c.temperature_2m === null) return null
  var daily = data.daily || {}
  function first(list) { return list && list.length ? list[0] : null }
  return {
    tempC: number(c.temperature_2m),
    feelsC: number(c.apparent_temperature),
    humidity: number(c.relative_humidity_2m),
    windKmh: number(c.wind_speed_10m),
    windDirection: number(c.wind_direction_10m),
    code: parseInt(String(c.weather_code), 10),
    isDay: Number(c.is_day) !== 0,
    maxC: number(first(daily.temperature_2m_max)),
    minC: number(first(daily.temperature_2m_min))
  }
}

// Same mapping as the stock panel: Open-Meteo WMO code → wttr code →
// the glyph `omarchy weather icon` prints.
function iconForCode(code, night) {
  var c = parseInt(String(code || "0"), 10)
  switch (c) {
    case 113: return night ? "\ue32b" : "\ue30d"
    case 116: return night ? "\ue32e" : "\ue302"
    case 119: case 122: return "\ue33d"
    case 143: case 248: case 260: return night ? "\ue346" : "\ue313"
    case 176: case 263: case 353: return night ? "\ue333" : "\ue308"
    case 179: case 227: case 230: case 323: case 326: case 368: return night ? "\ue327" : "\ue30a"
    case 182: case 185: case 281: case 284: case 311: case 314:
    case 317: case 320: case 350: case 362: case 365: case 374: case 377: return "\ue3ad"
    case 200: case 386: case 389: case 392: case 395: return "\ue31d"
    case 266: case 293: case 296: case 299: case 302: case 305: case 308: case 356: case 359: return "\ue318"
    case 329: case 332: case 335: case 338: case 371: return "\ue31a"
    default: return "\ue33d"
  }
}

function wttrCode(code) {
  var c = parseInt(String(code || "0"), 10)
  if (c === 0) return 113
  if (c === 1 || c === 2) return 116
  if (c === 3) return 119
  if (c === 45 || c === 48) return 143
  if (c === 51 || c === 53 || c === 55 || c === 56 || c === 57 || c === 61) return 266
  if (c === 63 || c === 65 || c === 66 || c === 67 || c === 80 || c === 81 || c === 82) return 308
  if (c === 71 || c === 73 || c === 75 || c === 77 || c === 85 || c === 86) return 338
  if (c === 95 || c === 96 || c === 99) return 389
  return 119
}

function glyph(code, isDay) {
  return iconForCode(wttrCode(code), isDay === false)
}

// WMO weather interpretation codes (Open-Meteo docs), in plain words.
function condition(code) {
  var c = parseInt(String(code), 10)
  if (c === 0) return "Clear"
  if (c === 1) return "Mostly clear"
  if (c === 2) return "Partly cloudy"
  if (c === 3) return "Overcast"
  if (c === 45 || c === 48) return "Fog"
  if (c >= 51 && c <= 57) return "Drizzle"
  if (c >= 61 && c <= 67) return "Rain"
  if (c >= 71 && c <= 77) return "Snow"
  if (c >= 80 && c <= 82) return "Showers"
  if (c === 85 || c === 86) return "Snow showers"
  if (c >= 95) return "Thunderstorm"
  return ""
}

// The arrow `omarchy weather status` (wttr) uses: it points where the
// wind blows to, so a wind *from* the south-west reads ↗.
function windArrow(degrees) {
  var d = number(degrees)
  if (isNaN(d)) return ""
  var arrows = ["↓", "↙", "←", "↖", "↑", "↗", "→", "↘"]
  return arrows[Math.round((((d % 360) + 360) % 360) / 45) % 8]
}

function wind(kmh, imperial) {
  var v = number(kmh)
  if (isNaN(v)) return ""
  return imperial ? Math.round(v * 0.621371) + " mph" : Math.round(v) + " km/h"
}

function localeUsesImperial(localeName) {
  var name = String(localeName || "").replace(".", "_")
  return /^en[_-]US($|[_.-])/.test(name) || /^en[_-]LR($|[_.-])/.test(name) || /^my($|[_.-])/.test(name)
}

// unit setting "metric"/"imperial" wins; then the place's country (as the
// stock panel does with wttr's country); then the locale.
function useImperial(unit, countryCode, localeName) {
  var u = trim(unit).toLowerCase()
  if (u === "imperial") return true
  if (u === "metric") return false
  var cc = trim(countryCode).toUpperCase()
  if (cc !== "") return cc === "US" || cc === "LR" || cc === "MM"
  return localeUsesImperial(localeName)
}

// Stale once a reading is older than two refresh periods (one missed
// refresh is normal; two means we are offline or the API is down).
function isStale(fetchedAtMs, nowMs, refreshMs) {
  var at = Number(fetchedAtMs)
  if (!isFinite(at) || at <= 0) return false
  return Number(nowMs) - at > 2 * Number(refreshMs)
}

// ---- `omarchy weather status` / `icon`
//
// When the CLI is there, the pill shows exactly what it prints (Open
// question 13). status prints "Place  ·  Temp 59°F  ·  Wind ↗11mph", or
// "Weather unavailable" (exit 1) when offline; icon prints one glyph.

// status's line → { summary, place, temp ("59°F"), value (59), unit ("F"
// or "C"), tempC, wind ("↗11mph") }, or null when it carries no temperature.
function parseStatus(text) {
  var line = trim(String(text || "").split("\n")[0])
  var parts = line.split(/\s+·\s+/)
  var place = ""
  var temp = ""
  var wind = ""
  for (var i = 0; i < parts.length; i++) {
    var p = trim(parts[i])
    if (/^Temp /.test(p)) temp = trim(p.slice(5))
    else if (/^Wind /.test(p)) wind = trim(p.slice(5))
    else if (i === 0) place = p
  }
  var m = /^\+?(-?\d+(?:\.\d+)?)\s*°\s*([CF])$/.exec(temp)
  if (!m) return null
  var value = parseFloat(m[1])
  return {
    summary: line,
    place: place,
    temp: temp.replace(/^\+/, ""),
    value: value,
    unit: m[2],
    tempC: m[2] === "F" ? (value - 32) * 5 / 9 : value,
    wind: wind
  }
}

// icon's output → the glyph, "" when it printed nothing usable.
function parseIcon(text) {
  var glyph = trim(String(text || "").split("\n")[0])
  return glyph.length > 0 && glyph.length <= 4 ? glyph : ""
}

// The pill's temperature from status: its own number when the unit is the
// one wanted (so it reads exactly like the CLI), else converted.
function cliTemp(status, imperial, withUnit) {
  if (!status) return ""
  var unit = imperial ? "F" : "C"
  var value = status.unit === unit ? status.value : (imperial ? status.tempC * 9 / 5 + 32 : status.tempC)
  return Math.round(value) + "°" + (withUnit ? unit : "")
}

// Do two readings describe the same place? Open-Meteo's details (condition,
// high/low, humidity) are shown next to the CLI's temperature only when its
// current temperature is within this many °C of the CLI's: the CLI asks
// wttr.in by name, which can be another town of the same name.
var AGREE_C = 3

function agrees(cliTempC, openMeteoTempC) {
  var a = number(cliTempC)
  var b = number(openMeteoTempC)
  return !isNaN(a) && !isNaN(b) && Math.abs(a - b) <= AGREE_C
}
