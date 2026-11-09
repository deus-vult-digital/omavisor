.pragma library

// Theme switcher parsing (SPEC.md section 7, v1): the output of
// `omarchy theme list`, `omarchy theme current` and the per-theme dump
// ThemeModule's one probe prints. Pure, so it is unit-tested.

// `omarchy theme list` prints one display name per line ("Osaka Jade").
function parseList(text) {
  var out = []
  var lines = String(text || "").split("\n")
  for (let i = 0; i < lines.length; i++) {
    var name = lines[i].trim()
    if (name !== "" && out.indexOf(name) === -1) out.push(name)
  }
  return out
}

// The directory name `omarchy theme set` derives from a display name:
// tags stripped, lower case, spaces to hyphens ("Osaka Jade" → osaka-jade).
function slug(name) {
  return String(name || "").replace(/<[^>]+>/g, "").trim().toLowerCase().replace(/ /g, "-")
}

// True when two names (display or slug) are the same theme.
function same(a, b) {
  var left = slug(a)
  return left !== "" && left === slug(b)
}

// The colors a card shows, in order: the theme's ground and text, then its
// accent and four hues.
var swatchKeys = ["background", "foreground", "accent", "red", "yellow", "green", "blue", "magenta"]

// colors.toml: `key = "#rrggbb"` lines. Returns { mode, colors: {key: hex} }
// with only well-formed hex colors; anything else is skipped.
function parseColors(text) {
  var colors = {}
  var mode = ""
  var lines = String(text || "").split("\n")
  for (let i = 0; i < lines.length; i++) {
    var m = lines[i].match(/^\s*([A-Za-z_]+)\s*=\s*"([^"]*)"\s*(#.*)?$/)
    if (!m) continue
    if (m[1] === "mode") { mode = m[2]; continue }
    if (/^#[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?$/.test(m[2])) colors[m[1]] = m[2]
  }
  return { mode: mode, colors: colors }
}

// The swatch strip for a card: swatchKeys the theme defines, in order.
function swatches(colors) {
  var out = []
  for (let i = 0; i < swatchKeys.length; i++)
    if (colors && colors[swatchKeys[i]]) out.push(colors[swatchKeys[i]])
  return out
}

// ThemeModule's probe prints, for each slug, a header line
// "@@omavisor-theme\t<slug>\t<dir>\t<preview path or empty>" followed by that
// theme's colors.toml. Returns { slug: { dir, preview, mode, swatches } }.
function parseDump(text) {
  var out = {}
  var current = null
  var body = []
  function flush() {
    if (!current) return
    var parsed = parseColors(body.join("\n"))
    current.mode = parsed.mode
    current.swatches = swatches(parsed.colors)
    out[current.slug] = current
  }
  var lines = String(text || "").split("\n")
  for (let i = 0; i < lines.length; i++) {
    if (lines[i].indexOf("@@omavisor-theme\t") === 0) {
      flush()
      var parts = lines[i].split("\t")
      current = { slug: parts[1] || "", dir: parts[2] || "", preview: parts[3] || "", mode: "", swatches: [] }
      body = []
    } else if (current) {
      body.push(lines[i])
    }
  }
  flush()
  return out
}

// The theme cards: one per listed name, in list order, with what the dump
// knows about it. A theme the dump missed still gets a card (name only).
function cards(names, dump, current) {
  var out = []
  for (let i = 0; i < names.length; i++) {
    var s = slug(names[i])
    var info = dump && dump[s] ? dump[s] : null
    out.push({
      name: names[i],
      slug: s,
      preview: info && info.preview ? "file://" + info.preview : "",
      mode: info ? info.mode : "",
      swatches: info ? info.swatches : [],
      current: same(names[i], current)
    })
  }
  return out
}
