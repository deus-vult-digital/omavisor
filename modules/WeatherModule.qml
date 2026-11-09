import QtQuick
import Quickshell
import Quickshell.Io
import "../lib/Weather.js" as Weather
import "../lib/Format.js" as Format

// Current weather, every 15 minutes, in two parts:
//
// - What the pill shows (temperature, glyph, summary line, wind) is what
//   `omarchy weather status` and `omarchy weather icon` print: Omavisor runs
//   the CLI itself, so the pill and the CLI always agree (Open question 13).
//   The CLI asks wttr.in; Omavisor makes no request of its own for this.
// - The details (condition, high/low, humidity) come from Open-Meteo, the
//   endpoint the stock weather panel uses, for Omarchy's place: the name
//   `omarchy weather location` prints, with the coordinates
//   omarchy-weather-location stores next to it (a name alone is looked up
//   with Open-Meteo's geocoder). They are shown only while Open-Meteo's
//   temperature agrees with the CLI's (Weather.agrees): wttr.in looks the
//   place up by name and can land on another town of the same name.
//
// Without the CLI (or before its first answer) everything comes from
// Open-Meteo, glyphs following the same table as `omarchy weather icon`.
//
// Offline, the last reading stays (also across restarts, from
// $XDG_STATE_HOME/omavisor/weather.json) and `stale` is set; nothing is ever
// reported as an error. Without a place or a first reading, `available`
// stays false and the weather simply isn't shown.
Item {
  id: root

  // "auto" | "metric" | "imperial", from the pill's settings.
  property string unit: "auto"
  property int refreshMinutes: 15

  // Place: name from the CLI, coordinates from the location file or the
  // geocoder, country for the unit choice.
  property string placeName: ""
  property var place: null
  property var reading: null
  property real fetchedAt: 0
  // "lat,lon" of the place the reading is for.
  property string fetchedFor: ""
  property bool failing: false
  property real now: Date.now()

  // The CLI's last answer: Weather.parseStatus plus `glyph` (from icon)
  // and `fetchedAt`. Kept (and cached) while the CLI fails, like `reading`.
  property var cli: null
  property bool cliFailing: false
  readonly property bool cliMissing: statusProbe.missing
  // A CLI reading past two refreshes (wttr.in down while Open-Meteo is up)
  // gives way to a newer Open-Meteo one: the CLI prints nothing then either.
  readonly property bool cliExpired: cli !== null && cliFailing && Weather.isStale(cli.fetchedAt, now, refreshMinutes * 60000)
    && reading !== null && !failing && fetchedAt > cli.fetchedAt
  readonly property bool useCli: cli !== null && !cliMissing && !cliExpired
  // Open-Meteo's reading is for the same place as the CLI's (or there is
  // no CLI reading): its details may be shown.
  readonly property bool detailsAgree: !!reading && (!useCli || Weather.agrees(cli.tempC, reading.tempC))
  readonly property var details: detailsAgree ? reading : null

  readonly property bool available: useCli || reading !== null
  readonly property real shownAt: useCli ? cli.fetchedAt : fetchedAt
  readonly property bool stale: available && ((useCli ? cliFailing : failing) || Weather.isStale(shownAt, now, refreshMinutes * 60000))
  // With the unit on "auto" the CLI's own unit (wttr.in picks it by place).
  readonly property bool imperial: useCli && String(unit).toLowerCase() !== "metric" && String(unit).toLowerCase() !== "imperial"
    ? cli.unit === "F"
    : Weather.useImperial(unit, place ? place.countryCode : "", Qt.locale().name)
  readonly property string glyph: useCli ? (cli.glyph || (details ? Weather.glyph(details.code, details.isDay) : ""))
    : reading ? Weather.glyph(reading.code, reading.isDay) : ""
  readonly property string temp: useCli ? Weather.cliTemp(cli, imperial, false) : reading ? Format.temp(reading.tempC, imperial, false) : ""
  readonly property string tempWithUnit: useCli ? Weather.cliTemp(cli, imperial, true) : reading ? Format.temp(reading.tempC, imperial, true) : ""
  readonly property string high: details ? Format.temp(details.maxC, imperial, false) : ""
  readonly property string low: details ? Format.temp(details.minC, imperial, false) : ""
  readonly property string condition: details ? Weather.condition(details.code) : ""
  readonly property string wind: useCli ? cli.wind
    : reading ? Weather.windArrow(reading.windDirection) + Weather.wind(reading.windKmh, imperial) : ""
  readonly property string humidity: details && !isNaN(details.humidity) ? Math.round(details.humidity) + "%" : ""
  readonly property string location: useCli && cli.place !== "" ? cli.place
    : placeName !== "" ? placeName : (place ? place.name : "")
  // The line `omarchy weather status` prints (its own, when it ran).
  readonly property string summary: useCli ? cli.summary : available
    ? [location.charAt(0).toUpperCase() + location.slice(1), "Temp " + tempWithUnit, wind !== "" ? "Wind " + wind.replace(" ", "") : ""].filter(function(s) { return s !== "" }).join("  ·  ")
    : ""
  readonly property string updated: shownAt > 0 ? Format.age(shownAt, now) : ""

  readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/omavisor"

  property var _request: null
  property bool _refetch: false
  property int retries: 0
  property string _locationRaw: ""
  property string _geocodedFor: ""

  // The place is re-read at start and when Omarchy's location file
  // changes, not on every refresh: with no stored name,
  // `omarchy weather location` asks wttr.in for the IP-detected city.
  function refresh() {
    now = Date.now()
    runCli()
    if (place && Weather.hasCoordinates(place)) fetchForecast()
  }

  // ---- CLI: `omarchy weather status` and `icon`, run together. status
  //      prints "Weather unavailable" and exits 1 offline: the last answer
  //      stays, marked stale. Not installed (exit 127): Open-Meteo alone.

  // A run asked for while one is going (the place changed mid-run) runs
  // again when it ends, so the old town's answer doesn't stay 15 minutes.
  function runCli() {
    if (statusProbe.missing) return
    if (!statusProbe.run()) _cliAgain = true
    if (!iconProbe.run()) _iconAgain = true
  }

  property string _icon: ""
  property bool _cliAgain: false
  property bool _iconAgain: false

  Probe {
    id: statusProbe
    command: ["omarchy", "weather", "status"]
    timeoutMs: 15000
    onFinished: function(code, output) {
      if (root._cliAgain) {
        root._cliAgain = false
        Qt.callLater(statusProbe.run)
        return
      }
      if (code === 127) return
      var parsed = code === 0 ? Weather.parseStatus(output) : null
      root.now = Date.now()
      if (!parsed) {
        root.cliFailing = true
        if (!retry.running) root.scheduleRetry()
        return
      }
      parsed.glyph = root._icon !== "" ? root._icon : (root.cli ? root.cli.glyph : "")
      parsed.fetchedAt = root.now
      root.cli = parsed
      root.cliFailing = false
      root.saveCache()
      if (!root.failing && root.reading) {
        root.retries = 0
        retry.stop()
      }
    }
  }

  Probe {
    id: iconProbe
    command: ["omarchy", "weather", "icon"]
    timeoutMs: 15000
    onFinished: function(code, output) {
      if (root._iconAgain) {
        root._iconAgain = false
        Qt.callLater(iconProbe.run)
        return
      }
      var glyph = code === 0 ? Weather.parseIcon(output) : ""
      if (glyph === "") return
      root._icon = glyph
      // status may have answered first.
      if (root.cli && root.cli.glyph !== glyph) {
        root.cli = Object.assign({}, root.cli, { glyph: glyph })
        root.saveCache()
      }
    }
  }

  function reloadPlace() {
    if (!locationProc.running) locationProc.running = true
  }

  // ---- Place

  property FileView locationFile: FileView {
    path: Quickshell.env("HOME") + "/.local/state/omarchy/settings/weather.json"
    watchChanges: true
    printErrors: false
    onFileChanged: {
      reload()
      root.reloadPlace()
      // Until status answers for the new place, the shown one is elsewhere.
      if (root.cli) root.cliFailing = true
      root.runCli()
    }
    onLoaded: { root._locationRaw = text(); root.resolvePlace() }
    onLoadFailed: { root._locationRaw = ""; root.resolvePlace() }
  }

  Process {
    id: locationProc
    command: ["omarchy", "weather", "location"]
    stdout: StdioCollector {
      onStreamFinished: {
        var name = String(text || "").split("\n")[0].replace(/^\s+|\s+$/g, "")
        if (name !== "") root.placeName = name
        root.resolvePlace()
      }
    }
    onExited: function(code) { if (code !== 0) root.resolvePlace() }
  }

  // The stock panel re-reads the file once shortly after start: the first
  // read can race shell startup. A no-op when the first read was fine.
  Timer {
    interval: 1500
    running: true
    onTriggered: root.locationFile.reload()
  }

  Timer {
    id: locationKill
    interval: 5000
    running: locationProc.running
    onTriggered: locationProc.running = false
  }

  onPlaceNameChanged: resolvePlace()

  // Coordinates stored with the name win; a bare name is geocoded. `query`
  // remembers which name a place was resolved for, so a new name (the
  // laptop moved, or `omarchy weather location --set Paris`) is looked up
  // afresh instead of keeping the old coordinates.
  function resolvePlace() {
    var file = Weather.parseLocationFile(_locationRaw)
    var name = placeName !== "" ? placeName : file.name
    if (Weather.hasCoordinates(file) && (file.name === "" || file.name === name)) {
      let known = place && place.latitude === file.latitude && place.longitude === file.longitude
      place = { name: file.name || name, query: name, latitude: file.latitude, longitude: file.longitude,
        countryCode: known ? place.countryCode : "" }
      if (place.countryCode === "" && name !== "") geocode(name, true)
    } else if (name !== "") {
      if (!(place && place.query === name && Weather.hasCoordinates(place))) {
        // Until the new name resolves, whatever is shown is somewhere else.
        if (reading) failing = true
        geocode(name, false)
        return
      }
    } else {
      // The name lookup failed (offline, wttr.in slow): ask again later,
      // and meanwhile keep using a place restored from the cache.
      if (!locationProc.running) scheduleRetry()
      if (!(place && Weather.hasCoordinates(place))) return
    }
    // A new place, or one restored from the cache, needs a fresh reading.
    if (!reading || failing || fetchedFor !== place.latitude + "," + place.longitude) fetchForecast()
  }

  // countryOnly: the coordinates are known (stored with the name); only the
  // country is wanted, from the result nearest them.
  function geocode(name, countryOnly) {
    var key = name + "|" + countryOnly
    if (key === _geocodedFor) return
    _geocodedFor = key
    get(Weather.geocodeUrl(name), function(ok, body) {
      if (!ok) {
        root._geocodedFor = ""
        root.scheduleRetry()
        return
      }
      if (!countryOnly) {
        root.pickLocal(name, body)
        return
      }
      if (!root.place) return
      var found = Weather.pickPlace(body, root.place.latitude, root.place.longitude)
      if (!found) return
      root.place = { name: root.place.name, query: root.place.query, latitude: root.place.latitude,
        longitude: root.place.longitude, countryCode: found.countryCode }
      root.saveCache()
    })
  }

  // A bare name is ambiguous. For the IP-detected city take the first match
  // whose time zone has this machine's UTC offset now, so "Portland" on a
  // Pacific-time machine is Portland, Oregon. Each zone's offset comes
  // from `date +%z` run with TZ set to it; local, no network.
  property var _zoneQueue: []
  property var _zoneOffsets: ({})
  property string _zoneName: ""
  property string _zoneBody: ""

  function pickLocal(name, body) {
    _zoneName = name
    _zoneBody = body
    _zoneOffsets = ({})
    // Only for the IP-detected city: a name the user stored may be anywhere.
    _zoneQueue = Weather.parseLocationFile(_locationRaw).name === "" ? Weather.zones(body) : []
    nextZone()
  }

  function nextZone() {
    if (_zoneQueue.length === 0) {
      let found = Weather.pickPlace(_zoneBody, null, null, _zoneOffsets, -new Date().getTimezoneOffset())
      if (!found) return
      found.query = _zoneName
      place = found
      fetchForecast()
      saveCache()
      return
    }
    var zone = _zoneQueue[0]
    _zoneQueue = _zoneQueue.slice(1)
    zoneProc.zone = zone
    zoneProc.environment = { TZ: zone }
    zoneProc.running = true
  }

  Process {
    id: zoneProc
    property string zone: ""
    command: ["date", "+%z"]
    stdout: StdioCollector {
      onStreamFinished: {
        var minutes = Weather.parseOffset(text)
        if (!isNaN(minutes)) {
          let map = root._zoneOffsets
          map[zoneProc.zone] = minutes
          root._zoneOffsets = map
        }
      }
    }
    onExited: Qt.callLater(root.nextZone)
  }

  // ---- Forecast

  function fetchForecast() {
    if (!place || !Weather.hasCoordinates(place)) return
    // One at a time; a place that changed meanwhile is fetched right after.
    if (_request) { _refetch = true; return }
    var lat = place.latitude
    var lon = place.longitude
    get(Weather.forecastUrl(lat, lon), function(ok, body) {
      var parsed = ok ? Weather.parseForecast(body) : null
      root.now = Date.now()
      if (parsed) {
        root.reading = parsed
        root.fetchedFor = lat + "," + lon
        root.fetchedAt = root.now
        root.failing = false
        root.saveCache()
        // Back to the plain 15-minute refresh once the place is known too.
        if (!root.cliFailing && (root.placeName !== "" || Weather.parseLocationFile(root._locationRaw).name !== "")) {
          root.retries = 0
          retry.stop()
        }
      } else {
        root.failing = true
        root.scheduleRetry()
      }
      if (root._refetch) {
        root._refetch = false
        if (root.place && root.fetchedFor !== root.place.latitude + "," + root.place.longitude) root.fetchForecast()
      }
    }, true)
  }

  // Offline or the API erroring: retry after 2, 4, 8 … minutes, never more
  // often than the normal refresh once that is reached.
  function scheduleRetry() {
    retry.interval = Math.min(refreshMinutes, 2 * Math.pow(2, retries)) * 60000
    retries = Math.min(retries + 1, 8)
    retry.restart()
  }

  // One request at a time per kind, aborted after 10 s; failures are
  // swallowed (stale data and a retry, never an error).
  function get(url, done, isForecast) {
    var xhr = new XMLHttpRequest()
    var finished = false
    var finish = function(ok, body) {
      if (finished) return
      finished = true
      if (isForecast) root._request = null
      done(ok, body)
    }
    if (isForecast) root._request = xhr
    xhr.onreadystatechange = function() {
      if (xhr.readyState === XMLHttpRequest.DONE) finish(xhr.status === 200, xhr.responseText)
    }
    try {
      xhr.open("GET", url)
      xhr.send()
    } catch (e) {
      finish(false, "")
      return
    }
    var guard = guardComponent.createObject(root, { request: xhr, onTimeout: function() { finish(false, "") } })
    guard.start()
  }

  Component {
    id: guardComponent
    Timer {
      property var request: null
      property var onTimeout: null
      interval: 10000
      onTriggered: {
        if (request && request.readyState !== XMLHttpRequest.DONE) request.abort()
        if (onTimeout) onTimeout()
        destroy()
      }
    }
  }

  Timer {
    interval: root.refreshMinutes * 60000
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  Timer {
    id: retry
    interval: 120000
    onTriggered: {
      if (root.placeName === "" && Weather.parseLocationFile(root._locationRaw).name === "") root.reloadPlace()
      else root.resolvePlace()
      if (root.failing || !root.reading) root.fetchForecast()
      if (root.cliFailing || !root.cli) root.runCli()
    }
  }

  // `stale` and "updated … ago" age with the clock, once a minute.
  Timer {
    interval: 60000
    running: root.available
    repeat: true
    onTriggered: root.now = Date.now()
  }

  // ---- Cache: the last reading and place, so a restart while offline
  //      still shows the weather (marked stale).

  Process {
    id: mkdir
    command: ["mkdir", "-p", root.stateDir]
  }

  FileView {
    id: cache
    path: root.stateDir + "/weather.json"
    printErrors: false
    atomicWrites: true
    onLoaded: {
      try {
        let data = JSON.parse(text())
        if (!root.reading && data.reading && typeof data.reading.tempC === "number") {
          root.reading = data.reading
          root.fetchedAt = Number(data.fetchedAt) || 0
          root.fetchedFor = String(data.fetchedFor || "")
          root.failing = true
        }
        // Same place already read from Omarchy's file: keep its country.
        if (root.place && data.place && !root.place.countryCode && data.place.countryCode
            && root.place.latitude === data.place.latitude && root.place.longitude === data.place.longitude) {
          root.place = Object.assign({}, root.place, { countryCode: data.place.countryCode })
        }
        if (!root.cli && data.cli && typeof data.cli.tempC === "number") {
          root.cli = data.cli
          root.cliFailing = true
        }
        if (!root.place && data.place && Weather.hasCoordinates(data.place)) {
          root.place = data.place
          root.resolvePlace()
        }
      } catch (e) {}
    }
  }

  function saveCache() {
    if (!reading && !cli) return
    cache.setText(JSON.stringify({ place: place, reading: reading, fetchedAt: fetchedAt, fetchedFor: fetchedFor, cli: cli }))
  }

  Component.onCompleted: {
    mkdir.running = true
    reloadPlace()
    runCli()
  }
}
