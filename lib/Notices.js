.pragma library

// Short notices (docs/macnotch-audit.md, shortlist 3): power plugged in or
// out, a monitor connected or removed, a Bluetooth device connected or low.
// Each is a normal-priority activity that peeks for a moment and goes after
// `TTL` seconds; `activityRules.notices` can quiet them (category "notices").
// Pure, so it is unit-tested; NoticesModule feeds it.

var TTL = 8
// A Bluetooth battery at or under LOW warns once; it warns again only after
// it has been back above RECOVER (charged), so a reading that wobbles at the
// line doesn't repeat.
var LOW = 0.2
var RECOVER = 0.3

function notice(key, title, subtitle, glyph) {
  return {
    id: "omavisor:notice-" + key,
    source: "omavisor",
    title: title,
    subtitle: subtitle || "",
    glyph: glyph,
    state: "success",
    priority: "normal",
    ttl: TTL,
    compact: { leading: glyph, trailing: "" }
  }
}

function percent(fraction) {
  var v = Number(fraction)
  if (!isFinite(v) || v < 0) return ""
  return Math.round(Math.min(1, v) * 100) + "%"
}

// A key safe in an activity id: letters, digits, dot, dash.
function keyOf(text) {
  return String(text || "").toLowerCase().replace(/[^a-z0-9.-]+/g, "-").replace(/^-+|-+$/g, "").slice(0, 40) || "device"
}

// The AC adapter changed. `percentage` is UPower's 0–100 or 0–1 reading of
// the battery, or NaN without one.
function power(onBattery, percentage) {
  var p = Number(percentage)
  var level = isFinite(p) && p >= 0 ? percent(p > 1 ? p / 100 : p) : ""
  return onBattery
    ? notice("power", "On battery", level, "󰂃")
    : notice("power", "Plugged in", level !== "" ? level + ", charging" : "", "󰚥")
}

// A Hyprland event: `monitoraddedv2` / `monitorremovedv2` carry
// "ID,NAME,DESCRIPTION" (the description may itself hold commas), the older
// `monitoradded` / `monitorremoved` just the name. Null for anything else.
function monitor(eventName, data) {
  var name = String(eventName || "")
  var added = name === "monitoraddedv2" || name === "monitoradded"
  var removed = name === "monitorremovedv2" || name === "monitorremoved"
  if (!added && !removed) return null
  var text = String(data || "")
  var output = text
  var description = ""
  if (/v2$/.test(name)) {
    var parts = text.split(",")
    output = parts.length > 1 ? parts[1] : text
    description = parts.length > 2 ? parts.slice(2).join(",").trim() : ""
  }
  output = output.trim()
  if (output === "") return null
  var subtitle = description !== "" && description !== output ? output + " · " + description : output
  return added
    ? notice("monitor-" + keyOf(output), "Monitor connected", subtitle, "󰍹")
    : notice("monitor-" + keyOf(output), "Monitor removed", subtitle, "󰶐")
}

// A Bluetooth device connected or disconnected.
function bluetooth(name, address, connected, battery) {
  var label = String(name || "").trim() || String(address || "").trim() || "Device"
  var level = battery === null || battery === undefined ? "" : percent(battery)
  return connected
    ? notice("bt-" + keyOf(address || label), "Connected", level !== "" ? label + " · " + level : label, "󰂱")
    : notice("bt-" + keyOf(address || label), "Disconnected", label, "󰂲")
}

// Whether a battery reading should warn now, given whether this device has
// warned since it was last charged. Returns { warn, warned } (the new state).
function lowBattery(battery, warned) {
  var v = Number(battery)
  if (battery === null || battery === undefined || !isFinite(v)) return { warn: false, warned: warned }
  if (v > RECOVER) return { warn: false, warned: false }
  if (v <= LOW && !warned) return { warn: true, warned: true }
  return { warn: false, warned: warned }
}

function bluetoothLow(name, address, battery) {
  var label = String(name || "").trim() || String(address || "").trim() || "Device"
  var a = notice("bt-low-" + keyOf(address || label), "Battery low", label + " · " + percent(battery), "󰥇")
  a.state = "error"
  return a
}
