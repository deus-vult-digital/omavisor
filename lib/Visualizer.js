.pragma library

// The Now playing view's wave display: its styles, cava's config and output,
// and the drawn stand-in when cava is not installed. Pure, so it is tested.
//
// cava reads the speakers' output (PipeWire's monitor) and prints one line of
// bar heights per frame. Omavisor runs it only while the Now playing view is
// on screen and a player plays; nothing is recorded or kept.

var STYLES = ["bars", "mirror", "wave", "dots"]
var LABELS = { bars: "Bars", mirror: "Mirror", wave: "Wave", dots: "Dots" }
var BARS = 32
var FRAMERATE = 30
// cava's ascii output range: each bar is 0 to this.
var RANGE = 100

function normalizeStyle(style) {
  return STYLES.indexOf(style) !== -1 ? style : STYLES[0]
}

// The style after `style`, round to the first.
function nextStyle(style) {
  return STYLES[(STYLES.indexOf(normalizeStyle(style)) + 1) % STYLES.length]
}

// cava's config: raw ascii output, `bars` values 0..RANGE per line, ";"
// between them. Input left to cava's default (PipeWire or Pulse, the
// default output's monitor), so no device is named here.
function cavaConfig(bars, framerate) {
  return [
    "[general]",
    "bars = " + (bars > 0 ? bars : BARS),
    "framerate = " + (framerate > 0 ? framerate : FRAMERATE),
    "",
    "[output]",
    "method = raw",
    "raw_target = /dev/stdout",
    "data_format = ascii",
    "ascii_max_range = " + RANGE,
    "bar_delimiter = 59",
    "frame_delimiter = 10",
    ""
  ].join("\n")
}

// One line of cava output ("12;40;7;") as `bars` levels from 0 to 1. A
// short or garbled line is padded with zeros, never longer than `bars`.
function parseFrame(line, bars) {
  var n = bars > 0 ? bars : BARS
  var parts = String(line === undefined || line === null ? "" : line).split(";")
  var out = []
  for (var i = 0; i < n; i++) {
    var v = Number(parts[i])
    out.push(isFinite(v) && parts[i] !== "" ? Math.max(0, Math.min(1, v / RANGE)) : 0)
  }
  return out
}

// Without cava: levels that move like music but follow none, from the time
// in seconds. Smooth (a few slow sines per bar) and the same for the same t.
function drawn(t, bars) {
  var n = bars > 0 ? bars : BARS
  var out = []
  for (var i = 0; i < n; i++) {
    var x = i / Math.max(1, n - 1)
    // Louder in the low end, as music mostly is.
    var tilt = 0.55 + 0.45 * (1 - x)
    var v = 0.5
      + 0.25 * Math.sin(t * 2.1 + i * 0.7)
      + 0.15 * Math.sin(t * 3.7 + i * 1.9)
      + 0.10 * Math.sin(t * 5.3 + i * 0.3)
    out.push(Math.max(0.04, Math.min(1, v * tilt)))
  }
  return out
}

// `levels` folded into `n` bands for a small meter: each band the louder of
// its range's mean and 0.7 × its peak, so a quiet range still moves when one
// band in it jumps. Zeros when there are no levels.
function bands(levels, n) {
  var out = []
  var len = levels && levels.length ? levels.length : 0
  for (var b = 0; b < n; b++) {
    if (len === 0) { out.push(0); continue }
    var from = Math.floor(b * len / n), to = Math.max(from + 1, Math.floor((b + 1) * len / n))
    var sum = 0, peak = 0
    for (var i = from; i < to; i++) { sum += levels[i]; peak = Math.max(peak, levels[i]) }
    out.push(Math.max(sum / (to - from), peak * 0.7))
  }
  return out
}

// Eases the shown levels toward the new ones: up fast, down slower, so the
// bars fall back like a meter instead of flickering.
function smooth(shown, next) {
  var out = []
  for (var i = 0; i < next.length; i++) {
    var a = shown && i < shown.length ? shown[i] : 0
    var b = next[i]
    out.push(b > a ? a + (b - a) * 0.6 : a + (b - a) * 0.25)
  }
  return out
}
