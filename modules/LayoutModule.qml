import QtQuick
import Quickshell
import Quickshell.Io
import "../lib/Layout.js" as Layout

// Onboarding and restore of the bar's center (SPEC.md section 9).
//
// "Replace clock & weather" (a click on the first-run card): the center as it
// is (entries with their inline settings, centerAnchor, Omavisor's own entry) is
// saved to $XDG_STATE_HOME/omavisor/layout-backup.json, Omavisor's entry gets
// `mode: "replace"` and the clock's formats, then Omarchy's own commands take
// the clock and weather off and put Omavisor where the clock was. "Keep them"
// sets `mode: "wrap"`. Restore (`omarchy-shell dev.deusvult.omavisor restore`, or the System
// tab) puts the saved center back, entry by entry and setting by setting.
//
// On Omarchy 4.5 the middle is three sections (centerBegin, center,
// centerEnd) with no anchor: replace puts Omavisor alone in `center` and the
// rest beside it, all by commands, and the backup keeps all three
// (lib/Layout.js). The anchor steps below are for 4.0 only.
//
// Placement commands run as argv arrays, one after the other, only from a
// click or the restore call. No bar change is made unless the backup was
// written first. A third-party plugin cannot set centerAnchor through the
// shell, so Omavisor edits shell.json for it, still only from those buttons
// and the restore call: shell.json is
// copied to shell.json.bak.<epoch> (the path goes in layout-backup.json),
// jq prints it with the anchor set, that goes to a temp file beside it, and
// the temp file is renamed over shell.json (atomic: the shell reloads it on
// change and must never read half a file).
// Without jq, or when that fails, the card shows the one-liner instead.
//
// The bar config is read with `omarchy-shell shell listShellConfig` (the
// shell's own in-memory copy) when the hub opens and after each run.
Item {
  id: root
  visible: false

  property var shell: null
  property string pluginId: ""

  readonly property string stateDir: ((Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/omavisor").replace(/\/+/g, "/")
  readonly property string backupPath: stateDir + "/layout-backup.json"
  // Where Omarchy's own scripts keep it (omarchy-shell-config).
  readonly property string configPath: Quickshell.env("HOME") + "/.config/omarchy/shell.json"
  // Beside shell.json, so the rename into place is atomic; a new name per
  // edit.
  property string tempPath: ""

  // The shell's config as last read (null until read), and the backup.
  property var config: null
  property var backup: null

  // A backup of a center Omavisor has replaced and not yet restored.
  readonly property bool replaced: backup !== null && !backup.restoredAt
  readonly property bool restored: backup !== null && !!backup.restoredAt
  // The first-run card; a restore counts as an answer.
  readonly property bool onboarding: config !== null && busy === "" && !restored && Layout.needsOnboarding(config, pluginId)
  // Replace offered again from the System tab: after a restore, or in wrap
  // mode, while there is a clock or weather to replace.
  readonly property bool canReplace: config !== null && !replaced && !onboarding && Layout.onBar(config, pluginId)
    && (restored || Layout.ownSettings(config, pluginId).mode === "wrap")
    && Layout.hasReplaceable(config)
  // The anchor the last replace or restore left for the user to set (Omavisor,
  // or the saved one), while shell.json does not have it and the widget it
  // names is on the bar.
  readonly property var anchorTarget: backup === null ? undefined : backup.restoredAt ? backup.centerAnchor : pluginId
  // Omarchy 4.5 has no anchor: the center slots keep Omavisor in the middle.
  readonly property bool anchorPending: config !== null && anchorTarget !== undefined
    && !Layout.hasSlots(config)
    && Layout.anchorOf(config) !== anchorTarget
    && (anchorTarget === null || Layout.onBar(config, anchorTarget))
  // The one-liner (with jq) or the hand edit (without) for the card.
  readonly property string anchorCommand: anchorPending ? (hasJq ? Layout.anchorCommand(anchorTarget) : Layout.anchorManual(anchorTarget)) : ""
  // "Leave it" on the card, kept in layout-backup.json until the next
  // replace or restore.
  readonly property bool anchorSkipped: backup !== null && backup.anchorSkipped === true

  // "", "replace" or "restore" while one runs.
  property string busy: ""
  // What the last run did (or why it stopped), for the card and `layout`.
  property string message: ""
  property bool failed: false

  property bool canCopy: false
  // jq is a dependency of the omarchy package; assumed until the probe at
  // start says otherwise.
  property bool hasJq: true

  // What the hub shows: "busy", "failed" (until dismissed), "anchor" (the
  // one-liner left to run), "onboarding" (the first-run card), "replaced"
  // (the Restore button) or "".
  readonly property string stage: busy !== "" ? "busy"
    : failed ? "failed"
    : anchorPending && !anchorSkipped ? "anchor"
    : onboarding ? "onboarding"
    : replaced ? "replaced" : ""

  function dismiss() {
    failed = false
  }

  function skipAnchor() {
    if (busy !== "" || backup === null) return
    writeBackup(Object.assign({}, backup, { anchorSkipped: true }), function() {})
  }

  // ---- Reading the config.

  property var _afterRead: []
  // A callback added while a read is under way waits for the next read, so
  // it never gets a config from before the change it waits on.
  property var _queued: []
  function refresh(then) {
    if (readConfig.running) {
      if (then || _queued.length === 0) _queued = _queued.concat(then ? [then] : [function() {}])
      return
    }
    if (then) _afterRead = _afterRead.concat([then])
    readConfig.running = true
  }

  Process {
    id: readConfig
    command: ["omarchy-shell", "shell", "listShellConfig"]
    stdout: StdioCollector { id: readOut; waitForEnd: true }
    onExited: function(code) {
      var parsed = null
      if (code === 0) {
        try { parsed = JSON.parse(readOut.text) } catch (e) {}
      }
      if (parsed !== null && typeof parsed === "object") root.config = parsed
      var callbacks = root._afterRead
      root._afterRead = []
      for (let i = 0; i < callbacks.length; i++) callbacks[i](parsed)
      if (root._queued.length > 0 && !readConfig.running) {
        root._afterRead = root._queued
        root._queued = []
        readConfig.running = true
      }
    }
  }

  // ---- The backup file.

  FileView {
    id: backupFile
    path: root.backupPath
    printErrors: false
    atomicWrites: true
    watchChanges: true
    onFileChanged: reload()
    onLoaded: root.backup = Layout.parseBackup(text())
    onLoadFailed: root.backup = null
    onSaved: { root.backup = Layout.parseBackup(text()); root._afterSave() }
    onSaveFailed: root.stop("could not write " + root.backupPath + (root.busy === "restore" ? "" : "; nothing was changed"))
  }

  property var _afterSave: null

  function writeBackup(data, then) {
    _afterSave = then
    mkdir.andThen = function() { backupFile.setText(JSON.stringify(data, null, 2) + "\n") }
    mkdir.running = true
  }

  Process {
    id: mkdir
    property var andThen: null
    command: ["mkdir", "-p", "--", root.stateDir]
    onExited: function(code) {
      if (code === 0) andThen()
      else root.stop("could not create " + root.stateDir + "; nothing was changed")
    }
  }

  // ---- Running commands, one after the other.

  property var _steps: []
  property var _done: null
  property int _step: 0

  function runSteps(steps, done) {
    _steps = steps
    _step = 0
    _done = done
    next()
  }

  function next() {
    if (_step >= _steps.length) { _done(); return }
    step.command = _steps[_step]
    step.running = true
  }

  Process {
    id: step
    stdout: StdioCollector { id: stepOut; waitForEnd: true }
    stderr: StdioCollector { id: stepErr; waitForEnd: true }
    onExited: function(code) {
      if (code !== 0) {
        const why = (stepErr.text || stepOut.text || ("exit " + code)).trim().split("\n").pop()
        root.stop(Layout.showCommand(root._steps[root._step]) + " failed: " + why)
        return
      }
      root._step++
      root.next()
    }
  }

  Timer {
    interval: 15000
    running: step.running
    onTriggered: step.running = false
  }

  function stop(why) {
    console.warn("omavisor:", why)
    // A temp file from an edit that stopped half way.
    if (tempPath !== "") Quickshell.execDetached(["rm", "-f", "--", tempPath])
    message = why
    failed = true
    busy = ""
    refresh()
  }

  function finish(text) {
    message = text
    failed = false
    busy = ""
  }

  // ---- centerAnchor (option b): only from replace() and restore().

  // Sets (or, for null, removes) centerAnchor in shell.json, then calls
  // done(path of the shell.json backup), or done("") without jq (the card
  // then shows the one-liner). Stops the run on a failure.
  //
  // The backup is taken first and jq reads the backup, so what gets written
  // is exactly that copy with the anchor changed. Just before the rename,
  // `cmp` checks shell.json still equals the backup; if the shell wrote it
  // meanwhile (it does so right after the bar commands answer, or for any
  // other change), the edit starts over (5 tries). That leaves only the
  // moment between `cmp` and `mv` in which a write by the shell could be
  // lost. Each try leaves its shell.json.bak.<epoch>.
  function setAnchor(anchor, done, attempt) {
    if (!hasJq) { done(""); return }
    var tries = attempt || 0
    var retry = function(why) {
      if (tries < 5) later(function() { root.setAnchor(anchor, done, tries + 1) })
      else stop("centerAnchor was not changed: " + why)
    }
    var saved = configPath + ".bak." + Math.floor(Date.now() / 1000)
    var argv = Layout.anchorJqArgv(saved, anchor)
    if (!argv) { stop("not a plain widget id: " + anchor + "; centerAnchor was not changed"); return }
    refresh(function(live) {
      if (!live) { stop("could not read the bar layout; centerAnchor was not changed"); return }
      root.runSteps([["cp", "-p", "--", root.configPath, saved]], function() {
        jqRun.andThen = function(text) {
          var why = Layout.checkAnchorEdit(text, anchor, live)
          if (why !== "") { retry(why); return }
          root.tempPath = root.configPath + ".omavisor-tmp-" + Date.now()
          tempFile.andThen = function() {
            root.runSteps([["chmod", "--reference=" + saved, "--", root.tempPath]], function() {
              same.andThen = function(unchanged) {
                if (!unchanged) {
                  root.runSteps([["rm", "-f", "--", root.tempPath]], function() { retry("shell.json kept changing") })
                  return
                }
                root.runSteps([["mv", "-f", "--", root.tempPath, root.configPath]], function() {
                  // Give the shell a moment to reload shell.json.
                  root.tempPath = ""
                  // Have the shell reload it now, as Omarchy's own commit()
                  // does, then read it back.
                  root.runSteps([["omarchy-shell", "shell", "reloadConfig"]], function() {
                    later(function() {
                      root.refresh(function(after) {
                        if (after && Layout.anchorOf(after) === anchor) done(saved)
                        else root.stop("shell.json has the new center widget but the shell did not take it; shell.json was saved as " + saved)
                      })
                    })
                  })
                })
              }
              same.command = ["cmp", "-s", "--", saved, root.configPath]
              same.running = true
            })
          }
          tempFile.setText(text)
        }
        jqRun.command = argv
        jqRun.running = true
      })
    })
  }

  Process {
    id: same
    property var andThen: null
    onExited: function(code) { andThen(code === 0) }
  }

  // The anchor card's "Set it" button: the one replace or restore left.
  function applyAnchor() {
    if (busy !== "" || !anchorPending) return
    busy = "anchor"
    failed = false
    var target = anchorTarget
    setAnchor(target, function(saved) {
      var key = root.backup.restoredAt ? "restoreShellBackup" : "shellBackup"
      var extra = { anchorSkipped: false }
      if (saved) extra[key] = saved
      root.writeBackup(Object.assign({}, root.backup, extra), function() {
        root.finish(saved ? "The bar is centered again. (shell.json saved as " + saved + ")" : "")
      })
    })
  }

  Process {
    id: jqRun
    property var andThen: null
    stdout: StdioCollector { id: jqOut; waitForEnd: true }
    stderr: StdioCollector { id: jqErr; waitForEnd: true }
    onExited: function(code) {
      if (code === 0) andThen(jqOut.text)
      else root.stop("jq failed (" + (jqErr.text.trim().split("\n").pop() || "exit " + code) + "); centerAnchor was not changed")
    }
  }

  // Writes the temp file: `tee <path>` fed on stdin (argv, no shell),
  // stdin closed after the text so tee ends.
  Process {
    id: tempFile
    property var andThen: null
    property string text: ""
    stdinEnabled: true
    stdout: StdioCollector { waitForEnd: true }
    stderr: StdioCollector { id: teeErr; waitForEnd: true }
    onStarted: {
      write(text)
      stdinEnabled = false
    }
    onExited: function(code) {
      stdinEnabled = true
      if (code === 0) andThen()
      else root.stop("could not write " + root.tempPath + " (" + (teeErr.text.trim() || "exit " + code) + "); centerAnchor was not changed")
    }
    function setText(value) {
      text = value
      command = ["tee", "--", root.tempPath]
      running = true
    }
  }

  property var _later: null
  function later(fn) { _later = fn; laterTimer.restart() }
  Timer { id: laterTimer; interval: 500; onTriggered: root._later() }

  // Omavisor's own entry, written whole (pluginShell.updateEntryInline replaces
  // it). False only without the facade: updateEntryInline also answers false
  // for "unchanged", so a refusal cannot be told apart (the restore's check
  // of the center catches it).
  function writeOwn(settings) {
    if (!shell || typeof shell.updateEntryInline !== "function") return false
    shell.updateEntryInline(pluginId, settings)
    return true
  }

  // ---- The three choices.

  // "Keep them": wrap mode, the stock clock and weather stay.
  function keep() {
    if (busy !== "") return
    busy = "keep"
    refresh(function(config) {
      if (!config) { root.stop("could not read the bar layout"); return }
      if (!Layout.onBar(config, root.pluginId)) { root.stop("Omavisor is not on the bar"); return }
      var settings = Layout.ownSettings(config, root.pluginId)
      settings.mode = "wrap"
      if (!root.writeOwn(settings)) { root.stop("the shell did not take Omavisor's settings"); return }
      root.finish("Omavisor sits beside the clock and weather and shows only activities.")
      root.refresh()
    })
  }

  // "Replace clock & weather".
  function replace() {
    if (busy !== "") return "error: busy"
    busy = "replace"
    failed = false
    message = ""
    refresh(function(config) {
      if (!config) { root.stop("could not read the bar layout; nothing was changed"); return }
      if (!Layout.onBar(config, root.pluginId)) { root.stop("Omavisor is not on the bar"); return }
      var plan = Layout.replacePlan(config, root.pluginId)
      var apply = function() {
        if (!root.writeOwn(plan.settings)) { root.stop("the shell did not take Omavisor's settings"); return }
        root.runSteps(plan.steps, function() {
          if (!plan.anchorNeeded) {
            root.refresh(function() { root.finish("Omavisor replaced the clock and weather. Restore puts them back.") })
            return
          }
          root.setAnchor(root.pluginId, function(saved) {
            if (saved === "") {
              root.refresh(function() { root.finish("Omavisor replaced the clock and weather. One step left: the bar's center widget.") })
              return
            }
            root.writeBackup(Object.assign({}, root.backup, { shellBackup: saved, anchorSkipped: false }), function() {
              root.finish("Omavisor replaced the clock and weather and centers the bar. Restore puts them back. (shell.json saved as " + saved + ")")
            })
          })
        })
      }
      // An earlier replace not restored yet keeps its backup: it holds the
      // center from before Omavisor.
      if (root.replaced) apply()
      else root.writeBackup(Layout.makeBackup(config, root.pluginId, new Date().toISOString()), apply)
    })
    return "ok"
  }

  // Restore the saved center. Answers at once; `status()` has the outcome.
  function restore() {
    if (busy !== "") return "error: busy"
    if (backup === null) return "error: no layout backup at " + backupPath
    // Once restored, a second run would put the old center over later changes.
    if (backup.restoredAt) return "error: already restored on " + backup.restoredAt
    busy = "restore"
    failed = false
    message = ""
    var saved = backup
    refresh(function(config) {
      if (!config) { root.stop("could not read the bar layout; nothing was changed"); return }
      var plan = Layout.restorePlan(saved, config, root.pluginId)
      root.runSteps(plan.steps, function() {
        if (plan.ownEntry !== null && !root.writeOwn(plan.ownEntry)) {
          root.stop("the shell did not take Omavisor's settings back")
          return
        }
        root.refresh(function(after) {
          var diff = after ? Layout.restoreDiff(saved, after, root.pluginId) : ["could not read the bar layout"]
          var notes = []
          if (plan.extras.length) notes.push("kept, added since: " + plan.extras.join(", "))
          if (plan.leftovers.length) notes.push("settings added since, left as they are: " + plan.leftovers.join(", "))
          if (diff.length) {
            root.stop("restore did not match the backup: " + diff.join("; "))
            return
          }
          var finishRestore = function(shellBackup) {
            var extra = { restoredAt: new Date().toISOString(), anchorSkipped: false }
            if (shellBackup) extra.restoreShellBackup = shellBackup
            root.writeBackup(Object.assign({}, saved, extra), function() {
              var anchorLeft = !Layout.hasSlots(root.config) && Layout.anchorOf(root.config) !== saved.centerAnchor
              root.finish("The bar's center is back as it was" + (anchorLeft ? "; one step left: the center widget." : ".")
                + (shellBackup ? " (shell.json saved as " + shellBackup + ")" : "")
                + (notes.length ? " (" + notes.join("; ") + ")" : ""))
            })
          }
          if (Layout.hasSlots(after) || Layout.anchorOf(after) === saved.centerAnchor) finishRestore("")
          else root.setAnchor(saved.centerAnchor, finishRestore)
        })
      })
    })
    return "ok"
  }

  // For `omarchy-shell dev.deusvult.omavisor layout` and bin/omavisor.
  function status() {
    return JSON.stringify({
      busy: busy,
      failed: failed,
      message: message,
      replaced: replaced,
      backup: backup !== null ? backupPath : "",
      restoredAt: backup && backup.restoredAt ? backup.restoredAt : "",
      anchorCommand: anchorCommand,
      shellBackup: backup && backup.shellBackup ? backup.shellBackup : "",
      restoreShellBackup: backup && backup.restoreShellBackup ? backup.restoreShellBackup : "",
      diff: backup && config ? Layout.centerDiff(backup, config, root.pluginId) : []
    })
  }

  function copyAnchorCommand() {
    if (canCopy && anchorCommand !== "") Quickshell.execDetached(["wl-copy", "--", anchorCommand])
  }

  Process {
    id: hasCopy
    command: ["sh", "-c", "command -v wl-copy"]
    onExited: function(code) { root.canCopy = code === 0 }
  }

  Process {
    id: hasJqProbe
    command: ["sh", "-c", "command -v jq"]
    onExited: function(code) { root.hasJq = code === 0 }
  }

  Component.onCompleted: {
    hasJqProbe.running = true
    hasCopy.running = true
    refresh()
  }
}
