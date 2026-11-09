.pragma library

// Onboarding and restore of the bar's center (SPEC.md section 9).
//
// Omavisor cannot edit the bar config itself (a third-party plugin's
// mutateShellConfig is refused, SPEC Open question 2), so placement goes
// through Omarchy's own commands, run as argv arrays after a click:
//   omarchy plugin disable <id>      takes a widget off the bar, and its
//                                    inline settings with it
//   omarchy plugin enable <id> …     puts it back as a bare { id }
//   omarchy bar move <id> …          moves an entry, settings and all
//   omarchy bar set <id> <key> <json> --json …   sets one inline setting
// Omavisor's own entry is written with pluginShell.updateEntryInline, which
// replaces it whole.
//
// Two bar layouts:
// - Omarchy 4.5 ("slots"): `center` is a box centered on the bar, and
//   `centerBegin` and `centerEnd` hang off its two edges. Replace puts Omavisor
//   alone in `center` and moves what stood before the clock to the end of
//   `centerBegin` and what stood after it to the start of `centerEnd`, so the
//   order reads the same and Omavisor sits exactly in the middle. All by
//   commands; shell.json is never edited directly.
// - Up to 4.0: one `center` section and `bar.centerAnchor` naming the
//   widget kept in the middle. `centerAnchor` has no command: Omavisor edits
//   shell.json after a click, or the user runs the one-liner
//   anchorCommand() prints.
//
// Everything here is pure: plans are computed from a shell.json object
// (`omarchy-shell shell listShellConfig`) and a backup, and tested.

.import "Settings.js" as Settings

var REPLACED = ["omarchy.clock", "omarchy.weather"]
// Every section a widget can be in (centerBegin, centerEnd and tray from 4.5).
var SECTIONS = ["left", "centerBegin", "center", "centerEnd", "right", "tray"]
// The bar's middle, in order, as backups keep it.
var CENTER_SECTIONS = ["centerBegin", "center", "centerEnd"]
// The stock clock's settings Omavisor reads the same way (lib/Settings.js,
// lib/Calendar.js), carried over to Omavisor's entry on replace.
var CLOCK_KEYS = ["format", "formatAlt", "verticalFormat", "verticalFormatAlt", "birthYear", "lifeExpectancy", "weekStartDay"]
var ID_PATTERN = /^[A-Za-z0-9._-]{1,128}$/

function clone(value) {
  return value === undefined ? undefined : JSON.parse(JSON.stringify(value))
}

// Layout stages that show the bar-layout card (LayoutModule.stage).
function showsCard(stage) {
  return ["busy", "failed", "onboarding", "anchor"].indexOf(stage) !== -1
}

function isObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value)
}

function entryId(entry) {
  return String(isObject(entry) ? entry.id || "" : entry || "")
}

function layoutOf(config) {
  return isObject(config) && isObject(config.bar) && isObject(config.bar.layout) ? config.bar.layout : {}
}

function sectionOf(config, section) {
  var layout = layoutOf(config)
  return Array.isArray(layout[section]) ? layout[section] : []
}

// Omarchy 4.5's layout: the shell's config always lists centerBegin and
// centerEnd, empty or not.
function hasSlots(config) {
  var layout = layoutOf(config)
  return Array.isArray(layout.centerBegin) || Array.isArray(layout.centerEnd)
}

// The middle sections this config has, in order.
function centerSections(config) {
  return hasSlots(config) ? CENTER_SECTIONS.slice() : ["center"]
}

// A backup's middle sections in order: center, with centerBegin and
// centerEnd when it was taken on 4.5.
function savedSections(backup) {
  return CENTER_SECTIONS.filter(function(s) { return isObject(backup) && Array.isArray(backup[s]) })
}

function anchorOf(config) {
  return isObject(config) && isObject(config.bar) && typeof config.bar.centerAnchor === "string"
    ? config.bar.centerAnchor : null
}

// { section, index } of the first entry with this id, or null.
function locate(config, id) {
  for (var s = 0; s < SECTIONS.length; s++) {
    var entries = sectionOf(config, SECTIONS[s])
    for (var i = 0; i < entries.length; i++)
      if (entryId(entries[i]) === id) return { section: SECTIONS[s], index: i }
  }
  return null
}

function entryOf(config, id) {
  var at = locate(config, id)
  return at ? sectionOf(config, at.section)[at.index] : null
}

// Omavisor's own inline settings (its entry without the id).
function ownSettings(config, pluginId) {
  var entry = entryOf(config, pluginId)
  var out = {}
  if (isObject(entry)) for (var k in entry) if (k !== "id") out[k] = clone(entry[k])
  return out
}

function onBar(config, id) {
  return locate(config, id) !== null
}

// A stock clock or weather in the bar's middle (centerBegin, center or
// centerEnd). Only those are replaced (and backed up): ones the user put in
// another section are left alone.
function inCenter(config, id) {
  var at = locate(config, id)
  return at !== null && CENTER_SECTIONS.indexOf(at.section) !== -1
}

function hasReplaceable(config) {
  return REPLACED.some(function(id) { return inCenter(config, id) })
}

// The first-run card: Omavisor is on the bar, nobody has picked a mode yet,
// and there is a stock clock or weather in the center to replace.
function needsOnboarding(config, pluginId) {
  var entry = entryOf(config, pluginId)
  if (!entry) return false
  if (isObject(entry) && entry.mode !== undefined) return false
  return hasReplaceable(config)
}

// What layout-backup.json holds: the whole center, entries with their
// inline settings (and on 4.5 centerBegin and centerEnd the same way), the
// anchor (null when shell.json had none), and where Omavisor itself was with its
// own entry.
function makeBackup(config, pluginId, savedAt) {
  var data = {
    version: 1,
    savedAt: savedAt,
    centerAnchor: anchorOf(config),
    center: clone(sectionOf(config, "center")),
    omavisor: locate(config, pluginId),
    omavisorEntry: clone(entryOf(config, pluginId))
  }
  if (hasSlots(config)) {
    data.centerBegin = clone(sectionOf(config, "centerBegin"))
    data.centerEnd = clone(sectionOf(config, "centerEnd"))
  }
  return data
}

// A backup read from disk, or null when it is not one.
function parseBackup(text) {
  var data
  try { data = JSON.parse(String(text || "")) } catch (e) { return null }
  if (!isObject(data) || data.version !== 1 || !Array.isArray(data.center)) return null
  if (data.centerAnchor !== null && typeof data.centerAnchor !== "string") return null
  for (var s = 0; s < CENTER_SECTIONS.length; s++) {
    var section = data[CENTER_SECTIONS[s]]
    if (section === undefined) continue
    if (!Array.isArray(section)) return null
    for (var i = 0; i < section.length; i++)
      if (!ID_PATTERN.test(entryId(section[i]))) return null
  }
  return data
}

// Replace clock & weather: Omavisor's new settings (mode replace plus the
// clock's formats, its own settings winning), the commands that take the
// clock and weather off and put Omavisor where the clock was, and the anchor
// still to set.
function replacePlan(config, pluginId) {
  var center = sectionOf(config, "center")
  var settings = ownSettings(config, pluginId)
  var clock = entryOf(config, "omarchy.clock")
  if (isObject(clock)) {
    for (var k = 0; k < CLOCK_KEYS.length; k++) {
      var key = CLOCK_KEYS[k]
      if (clock[key] !== undefined && settings[key] === undefined) settings[key] = clone(clock[key])
    }
  }
  settings.mode = "replace"

  var steps = []
  REPLACED.forEach(function(id) {
    if (inCenter(config, id)) steps.push(["omarchy", "plugin", "disable", id])
  })

  if (hasSlots(config)) {
    var target = slotTarget(config, pluginId)
    var model = modelOf(config)
    REPLACED.forEach(function(id) { if (inCenter(config, id)) removeFrom(model, id) })
    steps = steps.concat(arrange(model, target, CENTER_SECTIONS))
    return { settings: settings, steps: steps, anchor: null, anchorNeeded: false }
  }

  // Where the clock (else the weather, else the anchor) sits among the
  // entries that stay.
  var ids = center.map(entryId)
  var target = ids.indexOf("omarchy.clock") !== -1 ? "omarchy.clock"
    : ids.indexOf("omarchy.weather") !== -1 ? "omarchy.weather" : anchorOf(config) || ""
  var index = 0
  var found = false
  for (var i = 0; i < center.length; i++) {
    var id = entryId(center[i])
    if (id === target) { found = true; break }
    if (REPLACED.indexOf(id) === -1 && id !== pluginId) index++
  }
  if (!found) {
    index = center.filter(function(e) { var id = entryId(e); return REPLACED.indexOf(id) === -1 && id !== pluginId }).length
  }

  steps.push(["omarchy", "bar", "move", pluginId, "--section", "center", "--index", String(index)])
  return { settings: settings, steps: steps, anchor: pluginId, anchorNeeded: anchorOf(config) !== pluginId }
}

// 4.5: what the three middle sections hold after a replace. The entries that
// stay, in the order they read, split at the clock (else the weather): those
// before it end centerBegin, those after it start centerEnd, Omavisor alone in
// center.
function slotTarget(config, pluginId) {
  var all = []
  CENTER_SECTIONS.forEach(function(s) { sectionOf(config, s).forEach(function(e) { all.push(entryId(e)) }) })
  var at = all.indexOf("omarchy.clock")
  if (at === -1) at = all.indexOf("omarchy.weather")
  if (at === -1) at = all.length
  var stays = function(id) { return REPLACED.indexOf(id) === -1 && id !== pluginId }
  return { centerBegin: all.slice(0, at).filter(stays), center: [pluginId], centerEnd: all.slice(at + 1).filter(stays) }
}

// Ids per section, for planning.
function modelOf(config) {
  var model = {}
  SECTIONS.forEach(function(s) { model[s] = sectionOf(config, s).map(entryId) })
  return model
}

function removeFrom(model, id) {
  for (var s in model) {
    var i = model[s].indexOf(id)
    if (i !== -1) { model[s].splice(i, 1); return }
  }
}

// The commands that make each section in `order` start with
// `desired[section]` (ids), worked out on `model` (ids per section), which
// they keep in step. An entry is moved from where it is, settings and all,
// never from the part of a section already arranged; one not on the bar is
// enabled in place, bare. Whatever else is in an arranged section stays,
// after.
function arrange(model, desired, order) {
  var steps = []
  var placed = {}
  order.forEach(function(s) { if (!model[s]) model[s] = [] })

  function find(id, target) {
    var list = model[target]
    for (var i = placed[target] || 0; i < list.length; i++) if (list[i] === id) return { section: target, index: i }
    for (var k = 0; k < SECTIONS.length; k++) {
      var s = SECTIONS[k]
      if (s === target || !model[s]) continue
      for (var j = placed[s] || 0; j < model[s].length; j++) if (model[s][j] === id) return { section: s, index: j }
    }
    return null
  }

  order.forEach(function(section) {
    placed[section] = 0
    var want = desired[section] || []
    for (var i = 0; i < want.length; i++) {
      var id = want[i]
      var at = find(id, section)
      if (at && at.section === section && at.index === i) {
        placed[section]++
        continue
      }
      if (at) {
        steps.push(["omarchy", "bar", "move", id, "--from-section", at.section, "--from-index", String(at.index),
                    "--section", section, "--index", String(i)])
        model[at.section].splice(at.index, 1)
      } else {
        steps.push(["omarchy", "plugin", "enable", id, "--section", section, "--index", String(i)])
      }
      model[section].splice(i, 0, id)
      placed[section]++
    }
  })
  return steps
}

// The ids of the center once a replace plan has run.
function centerAfterReplace(config, pluginId) {
  if (hasSlots(config)) return [pluginId]
  var plan = replacePlan(config, pluginId)
  var ids = sectionOf(config, "center").map(entryId)
    .filter(function(id) { return REPLACED.indexOf(id) === -1 && id !== pluginId })
  ids.splice(Number(plan.steps[plan.steps.length - 1][7]), 0, pluginId)
  return ids
}

// Restore: the commands that make the center read exactly as the backup
// (each entry at its index, with its inline settings), Omavisor's entry to
// write back, and the anchor. Entries added to the center since the backup
// stay, after the restored ones (`extras`); inline keys added since then to
// an entry that never left the bar cannot be removed by a command and are
// listed in `leftovers`.
function restorePlan(backup, config, pluginId) {
  // A model of the layout, ids only, kept in step with each command.
  var model = modelOf(config)
  var order = savedSections(backup)
  var desired = {}
  var wanted = []
  order.forEach(function(s) {
    desired[s] = backup[s].map(entryId)
    wanted = wanted.concat(desired[s])
  })
  var steps = arrange(model, desired, order)

  // Omavisor was not in the middle: back where it was.
  if (wanted.indexOf(pluginId) === -1 && isObject(backup.omavisor) && SECTIONS.indexOf(backup.omavisor.section) !== -1) {
    var now = null
    for (var s = 0; s < SECTIONS.length && !now; s++) {
      var at = model[SECTIONS[s]].indexOf(pluginId)
      if (at !== -1) now = { section: SECTIONS[s], index: at }
    }
    if (now && !(now.section === backup.omavisor.section && now.index === backup.omavisor.index)) {
      steps.push(["omarchy", "bar", "move", pluginId, "--from-section", now.section, "--from-index", String(now.index),
                  "--section", backup.omavisor.section, "--index", String(Math.max(0, Number(backup.omavisor.index) || 0))])
    }
  }

  // Inline settings: an entry that was off the bar comes back bare.
  var leftovers = []
  var own
  order.forEach(function(section) {
    for (var j = 0; j < backup[section].length; j++) {
      var want = backup[section][j]
      var wid = entryId(want)
      if (wid === pluginId) {
        if (own === undefined) own = want
        continue
      }
      // A moved entry keeps its settings; an enabled one has none.
      var had = onBar(config, wid) && isObject(entryOf(config, wid)) ? entryOf(config, wid) : {}
      var wantObj = isObject(want) ? want : {}
      for (var key in wantObj) {
        if (key === "id" || JSON.stringify(had[key]) === JSON.stringify(wantObj[key])) continue
        steps.push(["omarchy", "bar", "set", wid, key, JSON.stringify(wantObj[key]), "--json",
                    "--section", section, "--index", String(j)])
      }
      for (var extra in had) if (extra !== "id" && !(extra in wantObj)) leftovers.push(wid + "." + extra)
    }
  })

  if (own === undefined && backup.omavisorEntry) own = backup.omavisorEntry
  var ownEntry = null
  if (own !== undefined) {
    ownEntry = {}
    if (isObject(own)) for (var ok in own) if (ok !== "id") ownEntry[ok] = clone(own[ok])
    // The hub's customization stays as it is now, set or unset. (An entry that
    // left the bar lost its settings, so there the backup's are all there is.)
    if (onBar(config, pluginId)) {
      var current = ownSettings(config, pluginId)
      Settings.RESTORE_KEEPS.forEach(function(ck) {
        if (ck in current) ownEntry[ck] = current[ck]
        else delete ownEntry[ck]
      })
    }
  }

  var extras = []
  order.forEach(function(section) {
    extras = extras.concat(model[section].slice(desired[section].length).filter(function(id) { return id !== pluginId }))
  })
  return {
    steps: steps,
    ownEntry: ownEntry,
    anchor: backup.centerAnchor,
    // 4.5 has no anchor: the slots keep the middle.
    anchorNeeded: !hasSlots(config) && anchorOf(config) !== backup.centerAnchor,
    extras: extras,
    leftovers: leftovers
  }
}

// How the center differs from the backup: [] when it reads the same,
// entries and inline settings both, Omavisor's customization keys aside.
function centerDiff(backup, config, pluginId) {
  var out = []
  savedSections(backup).forEach(function(section) {
    var saved = backup[section]
    var now = sectionOf(config, section)
    for (var i = 0; i < saved.length; i++) {
      var want = saved[i]
      var got = now[i]
      if (entryId(got) !== entryId(want)) out.push(section + "[" + i + "] is " + (entryId(got) || "missing") + ", was " + entryId(want))
      else if (JSON.stringify(comparable(got, pluginId)) !== JSON.stringify(comparable(want, pluginId))) out.push(entryId(want) + " settings differ")
    }
    for (var j = saved.length; j < now.length; j++) out.push(section + "[" + j + "] " + entryId(now[j]) + " was not there")
  })
  if (!hasSlots(config) && anchorOf(config) !== backup.centerAnchor)
    out.push("centerAnchor is " + (anchorOf(config) || "unset") + ", was " + (backup.centerAnchor || "unset"))
  return out
}

// What a restore must have achieved: every saved entry at its index with
// every saved setting. Entries added after the saved ones and settings
// added since (restorePlan's extras and leftovers) are allowed; the anchor
// is checked on its own. So are Omavisor's customization keys (restorePlan keeps
// them as they are).
function restoreDiff(backup, config, pluginId) {
  var out = []
  savedSections(backup).forEach(function(section) {
    var saved = backup[section]
    var now = sectionOf(config, section)
    for (var i = 0; i < saved.length; i++) {
      var want = saved[i]
      var got = now[i]
      if (entryId(got) !== entryId(want)) {
        out.push(section + "[" + i + "] is " + (entryId(got) || "missing") + ", was " + entryId(want))
        continue
      }
      var wantObj = isObject(want) ? want : {}
      var gotObj = isObject(got) ? got : {}
      var kept = entryId(want) === pluginId ? Settings.RESTORE_KEEPS : []
      for (var key in wantObj) {
        if (kept.indexOf(key) !== -1) continue
        if (JSON.stringify(gotObj[key]) !== JSON.stringify(wantObj[key])) out.push(entryId(want) + "." + key + " differs")
      }
    }
  })
  return out
}

// An entry with its keys sorted at every depth (jq -S sorts nested objects
// too), so two copies compare equal however their keys were ordered.
function sorted(entry) {
  if (!isObject(entry)) return { id: entryId(entry) }
  return canonical(entry)
}

function comparable(entry, pluginId) {
  var out = sorted(entry)
  if (entryId(entry) === pluginId) Settings.RESTORE_KEEPS.forEach(function(k) { delete out[k] })
  return out
}

function canonical(value) {
  if (Array.isArray(value)) return value.map(canonical)
  if (!isObject(value)) return value
  var out = {}
  Object.keys(value).sort().forEach(function(k) { out[k] = canonical(value[k]) })
  return out
}

// The shell-config path as Omarchy's own scripts use it.
var CONFIG_PATH = "$HOME/.config/omarchy/shell.json"

// The one-liner that sets (or, for null, removes) centerAnchor: a backup
// of shell.json first, then `jq -S` (sorted keys, as Omarchy's own bar
// commands write it) into a temp file beside it, renamed over it so the
// shell, which reloads it on change, never reads half a file. Empty for an id that is not a plain id.
function anchorCommand(anchor) {
  var program
  if (anchor === null) program = "'del(.bar.centerAnchor)'"
  else if (ID_PATTERN.test(String(anchor))) program = "'.bar.centerAnchor = \"" + anchor + "\"'"
  else return ""
  return "f=\"" + CONFIG_PATH + "\"; cp \"$f\" \"$f.bak.$(date +%s)\" && t=$(mktemp \"$f.XXXXXX\") && jq -S " + program
    + " \"$f\" > \"$t\" && chmod --reference=\"$f\" \"$t\" && mv \"$t\" \"$f\""
}

// Option (b) of SPEC Open question 2, after a click: the jq argv that prints
// shell.json with centerAnchor set (or removed, for null), keys sorted like
// Omarchy's own bar commands. No shell: the caller captures stdout, writes it
// to a temp file and copies that over shell.json. Null for an id that is not a
// plain id.
function anchorJqArgv(configPath, anchor) {
  if (anchor === null) return ["jq", "-S", "del(.bar.centerAnchor)", "--", configPath]
  if (!ID_PATTERN.test(String(anchor))) return null
  return ["jq", "-S", "--arg", "anchor", String(anchor), ".bar.centerAnchor = $anchor", "--", configPath]
}

// Whether jq's output is safe to write: JSON with the wanted anchor and the
// same center the shell has in memory (shell.json on disk could lag behind
// the bar commands just run). "" when it is, else why not.
function checkAnchorEdit(text, anchor, liveConfig) {
  var edited
  try { edited = JSON.parse(String(text || "")) } catch (e) { return "jq printed no JSON" }
  if (!isObject(edited) || !isObject(edited.bar)) return "jq printed no bar config"
  if (anchorOf(edited) !== anchor) return "the anchor did not change"
  var want = sectionOf(liveConfig, "center").map(sorted)
  var got = sectionOf(edited, "center").map(sorted)
  if (JSON.stringify(want) !== JSON.stringify(got)) return "shell.json on disk does not match the shell's center yet"
  return ""
}

// The hand edit to show when jq is missing (the one-liner needs it).
function anchorManual(anchor) {
  if (anchor === null) return "In ~/.config/omarchy/shell.json, remove \"centerAnchor\" from \"bar\"."
  if (!ID_PATTERN.test(String(anchor))) return ""
  return "In ~/.config/omarchy/shell.json, under \"bar\", set \"centerAnchor\": \"" + anchor + "\"."
}

// A command as one line to show (each word quoted only when it needs it).
function showCommand(argv) {
  return argv.map(function(word) {
    return /^[A-Za-z0-9_./:=@+-]+$/.test(word) ? word : "'" + String(word).replace(/'/g, "'\\''") + "'"
  }).join(" ")
}
