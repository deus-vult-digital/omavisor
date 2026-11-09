.pragma library

// Pure formatting helpers shared by the pill and the hub.

function pad2(value) {
  var n = Number(value)
  return (n < 10 ? "0" : "") + n
}

// ISO 8601 week number for a local calendar date (month is 0-based).
function isoWeek(year, month, day) {
  var date = new Date(Date.UTC(year, month, day))
  var weekday = date.getUTCDay() || 7
  date.setUTCDate(date.getUTCDate() + 4 - weekday)
  var yearStart = new Date(Date.UTC(date.getUTCFullYear(), 0, 1))
  return Math.ceil(((date - yearStart) / 86400000 + 1) / 7)
}

// Qt has no ISO week specifier, so a format's `ww` token is replaced by the
// two-digit week before Qt formats the date (digits are not Qt specifiers).
// Same convention as the stock omarchy.clock, so the same format strings
// render identically.
function clockFormat(format, date) {
  var week = pad2(isoWeek(date.getFullYear(), date.getMonth(), date.getDate()))
  return String(format || "").replace(/ww/g, week)
}

// True when the format shows seconds, so the clock must tick every second.
function needsSeconds(format) {
  return /s/.test(String(format || "").replace(/'[^']*'/g, ""))
}

// Media time: "m:ss" under an hour, "h:mm:ss" from there. Negative,
// missing or non-finite seconds read as 0:00.
function duration(seconds) {
  var total = Math.floor(Number(seconds))
  if (!isFinite(total) || total < 0) total = 0
  var h = Math.floor(total / 3600)
  var m = Math.floor((total % 3600) / 60)
  var s = total % 60
  return h > 0 ? h + ":" + pad2(m) + ":" + pad2(s) : m + ":" + pad2(s)
}

// Whole degrees as a string, "" when there is no number.
function roundedTemp(value) {
  if (value === undefined || value === null || value === "") return ""
  var n = parseFloat(String(value))
  return isNaN(n) ? "" : String(Math.round(n))
}

function celsiusToFahrenheit(value) {
  if (value === undefined || value === null || value === "") return NaN
  var n = parseFloat(String(value))
  return isNaN(n) ? NaN : n * 9 / 5 + 32
}

// A Celsius reading in the chosen unit: "21°" bare, "21°C" with the unit.
function temp(celsius, imperial, withUnit) {
  var value = roundedTemp(imperial ? celsiusToFahrenheit(celsius) : celsius)
  if (value === "") return ""
  return value + "°" + (withUnit ? (imperial ? "F" : "C") : "")
}

// "now", "5 min ago", "2 h ago", "3 d ago" for a past epoch-ms time.
function age(thenMs, nowMs) {
  var minutes = Math.floor((Number(nowMs) - Number(thenMs)) / 60000)
  if (!isFinite(minutes) || minutes < 1) return "now"
  if (minutes < 60) return minutes + " min ago"
  var hours = Math.floor(minutes / 60)
  if (hours < 24) return hours + " h ago"
  return Math.floor(hours / 24) + " d ago"
}

// One argument quoted for bash, for the Omarchy launchers that take a
// command line as one string (omarchy-launch-floating-terminal-with-presentation
// runs `bash -c "$*"`), so a path with spaces or quotes stays one word.
function shellQuote(value) {
  return "'" + String(value).replace(/'/g, "'\\''") + "'"
}
