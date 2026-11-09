# Omavisor

A minimal notch in the center of the Omarchy 4 bar. At rest, Omavisor is just
the clock; while music plays, the album art sits beside it (the pill keeps its
width either way). Rest the pointer on it (or click it, or press a key) and it
grows into three views: Now playing, Calendar and Activity. Scripts, coding
agents and other plugins can push **live activities** into it, which peek out
of the pill or bloom when urgent.

More is a switch away on the hub's Settings page: Home tiles, Capture, System,
Theme and Keys. None of it shows until you turn it on.

Omavisor is an Omarchy shell plugin (QML, running inside `omarchy-shell`). It uses
only your theme's colors and fonts, calls `omarchy …` commands instead of
reimplementing them, and adds no process of its own. Every external tool is
optional: when one is missing, its module just doesn't show.

Inspired by [MacNotch](https://macnotch.io/).

Requires Omarchy 4 ("Quattro"), whose bar is `omarchy-shell`; tested on 4.0.6
and 4.5.0. Omavisor is not a Waybar module.

## Install

```bash
omarchy plugin add https://github.com/deus-vult-digital/omavisor.git --enable
```

The installer clones the repo into
`~/.config/omarchy/plugins/dev.deusvult.omavisor`, validates it and
enables it. The installer itself runs none of Omavisor's code (enabling loads
it into the shell) and needs no root rights. Enabling puts
Omavisor in the middle of the bar next to the stock clock and weather (on Omarchy
4.5 just after the center group, in `centerEnd`); nothing else changes until
you answer the first-run card below.

Update with `omarchy plugin update dev.deusvult.omavisor`, then
`omarchy restart shell`: Omavisor's background service stays loaded across
plugin reloads, so the new version only fully runs after a restart.

## First run: replace the clock and weather?

The first time you open the hub, its Home tab asks whether Omavisor should take
the place of the clock and weather. Nothing changes until you click.

- **Replace clock & weather** saves the middle of the bar as it is (every entry
  with its inline settings, such as the clock's `format` or `birthYear`, and
  Omavisor's own entry) to
  `${XDG_STATE_HOME:-~/.local/state}/omavisor/layout-backup.json`. Then Omavisor takes
  over the clock's formats and runs Omarchy's own commands.

  On **Omarchy 4.5**, the middle of the bar is a `center` box with
  `centerBegin` and `centerEnd` beside it. Omavisor goes alone in `center`, so it
  sits exactly in the middle; whatever stood before the clock moves to the end
  of `centerBegin` and whatever stood after it to the start of `centerEnd`, so
  the bar reads in the same order. For a center of indicators, clock,
  system-update and weather that is:

  ```bash
  omarchy plugin disable omarchy.clock
  omarchy plugin disable omarchy.weather
  omarchy bar move omarchy.indicators --from-section center --from-index 0 --section centerBegin --index 0
  omarchy bar move dev.deusvult.omavisor --from-section centerEnd --from-index 0 --section center --index 0
  ```

  (and `omarchy.system-update` to `centerEnd`). Omavisor never edits shell.json
  itself here; the bar commands do it.

  On **Omarchy 4.0**, Omavisor goes where the clock was in `center`
  (`omarchy bar move dev.deusvult.omavisor --section center --index <n>`),
  and the backup also keeps `centerAnchor`. Omarchy 4.0 has no command for the
  bar's center widget and does not let a plugin set it, so on the same click
  Omavisor edits shell.json itself: it copies it to `shell.json.bak.<epoch>` first
  (the path is recorded in `layout-backup.json` as `shellBackup`), runs `jq -S`
  on that copy to set the anchor (sorted keys, as Omarchy's bar commands write
  it), renames the result over shell.json after checking it has not changed
  meanwhile, and asks the shell to reload it. Each run leaves its
  `shell.json.bak.<epoch>` in `~/.config/omarchy/`; delete old ones when you
  like. If the edit could not be made, or the center widget changes later, the
  card offers **Set it** (the same edit, on your click) and **Leave it** (don't
  ask again), and shows the edit as one line to run yourself:

  ```bash
  f="$HOME/.config/omarchy/shell.json"; cp "$f" "$f.bak.$(date +%s)" && t=$(mktemp "$f.XXXXXX") && jq -S '.bar.centerAnchor = "dev.deusvult.omavisor"' "$f" > "$t" && chmod --reference="$f" "$t" && mv "$t" "$f"
  ```

  `jq` comes with Omarchy; were it missing, the card would say to set `"centerAnchor"` under `"bar"` in
  shell.json by hand. Without the anchor everything works; the center group is just centered as a
  whole instead of on Omavisor.
- **Keep them** sets `mode: "wrap"`: the stock clock and weather stay, and Omavisor
  becomes a small activities glyph beside them.

Changed your mind? The System tab has a **Bar layout** tile with **Restore**
while Omavisor has the clock's place, and **Replace** after a restore or in wrap
mode.

## Removal

If you installed any recipes (see Recipes), take them out first: they live
in the plugin folder, which removal deletes. Delete the `source …/recipes/…`
line from `~/.bashrc` / `~/.zshrc` (otherwise every new shell prints "No such
file or directory"), the Omavisor hooks from `~/.claude/settings.json`, and the
copies `omarchy hook install` made under `~/.config/omarchy/hooks/`.

Put the stock clock and weather back first, and only then remove the plugin.
`bin/omavisor restore` waits for the restore and fails if it did not finish, so
the rest runs only after a good restore:

```bash
omavisor=~/.config/omarchy/plugins/dev.deusvult.omavisor
"$omavisor/bin/omavisor" restore &&
  omarchy plugin remove dev.deusvult.omavisor &&
  rm -rf "${XDG_STATE_HOME:-$HOME/.local/state}/omavisor"
```

If you never clicked **Replace clock & weather** (or you already restored),
there is nothing to put back and `restore` says so (`error: no layout backup …` or
`error: already restored …`); skip it:

```bash
omarchy plugin remove dev.deusvult.omavisor
rm -rf "${XDG_STATE_HOME:-$HOME/.local/state}/omavisor"
```

Omavisor writes nothing else outside its plugin folder and that state folder,
except, on Omarchy 4.0, the `shell.json.bak.<epoch>` copies a Replace or
Restore leaves in `~/.config/omarchy/` (delete them when you like).

`restore` puts back the middle of the bar saved in `layout-backup.json` exactly
(`center`, and on 4.5 `centerBegin` and `centerEnd` too): each entry
at its place with its inline settings (the clock comes back with its `format`,
`birthYear` and the rest), and Omavisor's own entry as it was, apart from the keys
that choose what the hub shows (`tabs`, `tabsSeen`, `homeTiles`, `pillItems`,
`activityRules`), which stay as you last set them. On 4.0 the saved
`centerAnchor` is put back the same way as on replace (shell.json backed up
first, the path recorded as `restoreShellBackup`); only without `jq` does it
print the one-liner instead, for example:

```bash
f="$HOME/.config/omarchy/shell.json"; cp "$f" "$f.bak.$(date +%s)" && t=$(mktemp "$f.XXXXXX") && jq -S '.bar.centerAnchor = "omarchy.clock"' "$f" > "$t" && chmod --reference="$f" "$t" && mv "$t" "$f"
```

`omarchy-shell dev.deusvult.omavisor restore` does the same but answers at once (it only
starts the run); `omarchy-shell dev.deusvult.omavisor layout` then has the outcome. A
backup restores once; after that, `restore` refuses (Replace on the System
tab saves a new one). Widgets
added to those sections after onboarding stay, after the restored ones, and
settings added since to the other widgets stay too. Omavisor's other settings go
back as they were saved, so `openOn` or a clock format changed after onboarding
is reset.

Removed Omavisor without restoring? The bar keeps working: `omarchy plugin
remove` takes Omavisor's entry (and the clock settings it had taken over) off the
bar, and an id left behind takes no space. The clock and weather stay off (and
on 4.0 `centerAnchor` still names Omavisor). Your saved layout is still in
`${XDG_STATE_HOME:-~/.local/state}/omavisor/layout-backup.json` (unless you
deleted the folder): put the widgets back at the indexes and with the settings
listed there, for example

```bash
jq -c '{centerBegin, center, centerEnd}' "${XDG_STATE_HOME:-$HOME/.local/state}/omavisor/layout-backup.json"
omarchy plugin enable omarchy.clock --section center --index <its index>
omarchy bar set omarchy.clock format '"dddd h:mm AP"' --json   # each setting it had
```

and on 4.0 set `centerAnchor` back with the one-liner above. Disabling a widget drops
its inline settings, which is why the backup keeps whole entries.

## Settings

Settings live inline on Omavisor's bar entry in `~/.config/omarchy/shell.json`
(Omarchy's rule: no separate config file). Change one with
`omarchy bar set dev.deusvult.omavisor <key> <value>`, for example
`omarchy bar set dev.deusvult.omavisor openOn click`.

For a list (`tabs`, `homeTiles`), give the names in one quoted string, with
spaces or commas between them:

```bash
omarchy bar set dev.deusvult.omavisor tabs "home media system keys"
omarchy bar set dev.deusvult.omavisor homeTiles "media weather stats hypr"
```

A JSON array (`'["media","weather"]' --json`) does not work through
`omarchy bar set`: the shell's IPC (`qs ipc call`, under `omarchy-shell`)
reads an argument that starts with `[` as a list of arguments and splits it
at the commas, so the call fails with "Too many arguments provided". Omavisor
reads the string form as the list. For a real array in `shell.json`, call the
shell directly with a space before the bracket (JSON allows it, the IPC then
leaves it alone), or edit `shell.json` by hand after backing it up:

```bash
omarchy-shell shell setBarWidget dev.deusvult.omavisor homeTiles ' ["media","weather"]' '{}'
```

| Key | Values (default first) | What it does |
|---|---|---|
| `mode` | `replace`, `wrap` | `replace`: Omavisor shows the clock and weather. `wrap`: the stock clock and weather stay; Omavisor shows only activities. Set by the first-run card. |
| `format` | `dddd h:mm AP` | Clock format, the stock clock's syntax (`ww` is the ISO week). |
| `formatAlt` | `d MMMM 'W'ww yyyy` | Shown after a right click (for the session). |
| `verticalFormat`, `verticalFormatAlt` | `HH\n—\nmm`, `dd\nMMM` | The same on a left or right bar. |
| `openOn` | `hover`, `click` | `hover` opens the hub after `peekDelayMs` and closes it when the pointer leaves; `click` behaves like the stock popups. |
| `peekDelayMs` | `250` (0–2000) | Hover delay before the hub opens. |
| `tabs` | `media, calendar, activities` | The tabs in the hub's strip, in this order; the digits and Tab follow it. See [Choosing tabs](#choosing-tabs). |
| `homeTiles` | `media, weather, timers, updates` | Up to four Home tiles, in this order, from `media`, `weather`, `timers`, `updates`, `capture`, `stats`, `power` (only with a battery: level, time, draw and the power profiles), `hypr` (workspace, active window, monitor, the dwindle/scrolling layout toggle; the wheel on it switches workspace) and `today`. A tile that can't show right now gives its place to the next one listed, or to a Today tile. Fewer than four give wider tiles; none gives Today alone. With `timers` showing on Home the System tab leaves them to it. |
| `scrollAction` | `auto`, `volume`, `workspace`, `none` | Wheel on the pill: the playing player's volume, else workspaces (`auto`). |
| `updatePollMinutes` | `360` (30–1440) | How often to check for an Omarchy update. |
| `pkgPollMinutes` | `60` (15–1440) | How often to count pending repo (`checkupdates`) and AUR (`yay -Qua`) updates. |
| `statsWhileOpenMs` | `1000` (250–10000) | CPU and memory refresh while the System tab or stats tile is on screen (temperatures and GPU every 5 s at most, disk every 30 s). Nothing is polled while the hub is closed. |
| `allowActions` | `true` | Allow the action buttons that pushed activities carry. |
| `hubOpacity` | `85` | How solid the hub's card (and the cap around the pill while it's open) is, 40 to 100 percent of the theme's popup background. Text and controls stay solid. Nothing blurs behind it (Omarchy has no blur rule for the hub's layer), so lower values show the desktop plainly. |
| `corners` | `auto`, `square`, `round` | The hub's corners and the joint where it grows out of the pill. `auto` follows the theme: square on a square theme, the theme's rounding otherwise. `square` keeps them square on any theme; `round` curves them on any theme (a small curve when the theme is square). |
| `reduceMotion` | `auto`, `on`, `off` | `on` stops Omavisor's animations (the hub's grow-out, the pill's meter, pulsing badges); `auto` follows the shell's own switch (`omarchy toggle animations`). |
| `unit` | `auto`, `metric`, `imperial` | Temperature unit; `auto` keeps the unit `omarchy weather status` prints (wttr.in picks it by place), or follows the weather location without the CLI. |
| `remoteArt` | `true` | Load album art from the web link a player publishes when it has no local art (current track only). It is downloaded with curl (http/https only, at most 3 redirects, 5 MB and 8 s) to `~/.local/state/omavisor/art/`, and only that file is shown; the previous track's file is removed, and the folder is emptied when the shell starts. |
| `actions` | unset | Your own commands for the Actions Home tile (see below). |
| `birthYear`, `lifeExpectancy`, `weekStartDay` | unset | As on the stock clock: life progress and the calendar's first day. |

The table follows the settings schema in `manifest.json` (`pillItems` is below), plus the clock keys
Omavisor takes over from the stock clock. `actions` is a JSON object, so it is
edited in `shell.json` (or on the Settings page) rather than in the shell's
settings form. The long-command recipe has its own `OMAVISOR_LONG_COMMAND_SECONDS`.

**Reorder the pill by dragging:** press and hold a part of the pill (the
clock, the weather, the album art or levels spot) for half a second, then
drag it left or right among the others and let go. The new order is saved
as `pillItems`. A plain click still opens the hub; right and middle clicks
work as before. Along a left or right bar the pill can't be dragged.

Two more keys, also set on the hub's Settings page: what the pill shows, and
how far each kind of activity may interrupt. Without `pillItems` the pill shows
clock, now playing and badge, or glyph and badge in wrap mode:

```bash
omarchy bar set dev.deusvult.omavisor pillItems "clock weather badge"   # clock, weather, glyph, media, badge
omarchy bar set dev.deusvult.omavisor activityRules '{"updates":"badge"}' --json
```

`activityRules` maps `timers`, `recording`, `updates`, `units`, `privacy`,
`dictation`, `agents`, `notices` and `other` to `quiet`, `badge`, `peek` or `bloom`.

### Actions

The Actions Home tile holds buttons for your own commands. Each is a label and
the command as a list of words (argv), with an optional icon (a Nerd Font
glyph). A click closes the hub and runs it directly, never through a shell, so
quotes, `;` or `$` are passed as they are; for a pipeline, run `sh -c '…'`
yourself. The tile shows the first six. Add `actions` to `homeTiles` (or switch
on Actions on the Settings page) to show it:

```bash
omarchy bar set dev.deusvult.omavisor actions '{"Lock":["omarchy-lock-screen"],"btop":{"argv":["omarchy-launch-or-focus-tui","btop"],"icon":"󰍛"},"Files":["nautilus","--new-window"]}' --json
omarchy bar set dev.deusvult.omavisor homeTiles "actions media weather timers"
```

The value has to be an object (`omarchy bar set` can't pass a JSON list); in
shell.json a list of `{ "label", "argv", "icon" }` works too. Reset on the
Settings page leaves your actions alone, and so does Restore.

`tabsSeen` is written by the Settings page: the tabs Omavisor had when you last
edited the list, which is how it knows a later one is new. There is no need to
set it.

### The Settings page

The gear at the end of the hub's tab strip opens Settings, as does
`omarchy-shell dev.deusvult.omavisor expand settings`. Everything here is also a key above, and
a change shows at once and is written to Omavisor's own entry in `shell.json` a
moment later, so a burst of moves is one write.

| Column | Sets | Equivalent |
|---|---|---|
| Tabs | Which tabs show, and their order | `tabs` |
| Home tiles | Which Home tiles show, and their order (the first four that can show) | `homeTiles` |
| Pill | What the collapsed pill shows, and the order of its text. The badge sits around the rest, so it has no order. Now playing shows the track only while a player plays | `pillItems` |
| Activities | The most each kind of activity may do | `activityRules` |

Keys, on top of [the hub's own](#keys-inside-the-hub):

| Key | Does |
|---|---|
| Arrows | Move between rows and columns, down to the buttons at the bottom |
| Space or Enter | Show or hide a row, or step an activity through its levels. Space never plays or pauses here |
| Shift+Up, Shift+Down | Move a row |
| Esc | Back to the tab you came from (the first tab, if that one is hidden now), or close if you opened Settings by name |

With the mouse, use the switches, the arrows on each row and the level buttons.
Settings holds the hub open and takes the keyboard until you press Esc, click
outside or pick a tab; hovering a tab won't leave it.

- **A hidden row goes to the end of its list,** and comes back at the end of the
  shown ones.
- **Activity levels** step Quiet (only on the Activities tab), Badge, Peek, Bloom.
  Each is a ceiling, and Bloom means no limit, so the default changes nothing: an
  activity only blooms if it is urgent, and Do Not Disturb still wins.
- **New** marks a tab an update added after you made your list. It stays hidden
  and marked until you switch it on or off. A list set with `omarchy bar set`
  alone has no record of what it knew, so nothing is marked until the page has
  edited it once.
- **Some rows won't turn off:** the last tab that can show, and the pill's last
  clock or glyph, since the pill needs something to hover and click. A row that
  can't show on this machine is dimmed. Weather has no room on a left or right
  bar, so there its row changes nothing.
- **`omavisor end top` ignores levels:** it can end an activity held to Quiet that
  the pill isn't showing.
- **Reset to defaults,** pressed twice, clears `tabs`, `tabsSeen`, `homeTiles`,
  `pillItems` and `activityRules`. `mode`, the clock's formats
  and the rest stay.
- **Restore stock clock** (or Replace) is the System tab's bar layout button, here
  too for when System is hidden.

### Choosing tabs

Without a `tabs` key the hub has Now playing, Calendar and Activity. Once
you set one, it is the whole list:

- **Listed means shown, in that order.** The first opens first, then the hub
  reopens on the last one
  you viewed. `1`–`9`, Tab and the arrows on the strip
  go by this list.
- **Hidden is not gone.** `omavisor expand media`, a keybind for it or a click on a
  bloom opens a hidden tab, with no tab selected in the strip. It is only
  reached that way: the next plain open goes back to the strip.
- **A tab added by a later update stays hidden** until you add it to your list,
  marked New in Settings.
- **A listed tab that can't show is skipped:** `theme` without Omarchy's theme
  commands.
- **An empty or all-unknown list shows Home**, so the hub always has a tab.
- **With Home hidden,** the first-run card shows on your first tab, and the
  System tab shows the timers even if `homeTiles` lists them.

To go back to the defaults, use Reset in Settings. Listing every tab shows them
all, but it is still your list, so a later new tab stays hidden. `omavisor restore`
leaves `tabs`, `tabsSeen`, `homeTiles`, `pillItems` and `activityRules` as
they are.
`omarchy plugin disable` drops Omavisor's entry and every setting on it, so disabling
and enabling again starts from the defaults.

## Keybindings

Omavisor never edits your Hyprland config. These combos are free on a stock
Omarchy 4 (`test/keybinds-free.sh` checks them against its defaults); add the
ones you want to `~/.config/hypr/bindings.lua`:

```lua
o.bind("SUPER + CTRL + U", "Omavisor hub", "omarchy-shell shell toggle dev.deusvult.omavisor '{}'")
o.bind("SUPER + CTRL + J", "Omavisor activities", "omarchy-shell dev.deusvult.omavisor expand activities")
o.bind("SUPER + CTRL + Y", "Omavisor 25m timer", "omarchy-shell dev.deusvult.omavisor timer \"25 Focus\"")
o.bind("SUPER + CTRL + M", "Omavisor dismiss top", "omarchy-shell dev.deusvult.omavisor end top")
o.bind("SUPER + CTRL + G", "Omavisor do not disturb", "omarchy-shell dev.deusvult.omavisor dnd")
o.bind("SUPER + CTRL + ALT + G", "Omavisor clock format", "omarchy-shell dev.deusvult.omavisor format")
o.bind("SUPER + CTRL + ALT + J", "Omavisor scroll down", "omarchy-shell dev.deusvult.omavisor scroll down")
o.bind("SUPER + CTRL + ALT + K", "Omavisor scroll up", "omarchy-shell dev.deusvult.omavisor scroll up")
o.bind("SUPER + CTRL + ALT + M", "Omavisor stop recording", "omarchy-shell dev.deusvult.omavisor stopRecording")
o.bind("SUPER + CTRL + ALT + N", "Omavisor next workspace", "omarchy-shell dev.deusvult.omavisor workspace next")
o.bind("SUPER + CTRL + ALT + P", "Omavisor previous workspace", "omarchy-shell dev.deusvult.omavisor workspace prev")
o.bind("SUPER + CTRL + ALT + U", "Omavisor volume up", "omarchy-shell dev.deusvult.omavisor volume up")
o.bind("SUPER + CTRL + ALT + Y", "Omavisor volume down", "omarchy-shell dev.deusvult.omavisor volume down")
o.bind("SUPER + CTRL + ALT + X", "Omavisor close hub", "omarchy-shell dev.deusvult.omavisor collapse")
```

Then run `hyprctl reload && hyprctl configerrors`. If a key is already bound,
`hl.unbind("…")` it first. Don't reuse `SUPER + CTRL + ALT + D` (the stock
calendar).

Everything the pill does with the mouse has a command, to bind as you like:

| Pill | Command |
|---|---|
| Hover or left click: open the hub | `omarchy-shell dev.deusvult.omavisor expand ""` (or a tab name), or `shell toggle` as above |
| Click again, or leave: close it | `omarchy-shell dev.deusvult.omavisor collapse` |
| Right click: the other clock format | `omarchy-shell dev.deusvult.omavisor format` |
| Wheel, as `scrollAction` says | `omarchy-shell dev.deusvult.omavisor scroll up` or `down` |
| Wheel on workspaces | `omarchy-shell dev.deusvult.omavisor workspace next` or `prev` |
| Wheel on the playing player's volume | `omarchy-shell dev.deusvult.omavisor volume up` or `down` |
| Click on the REC side: stop recording | `omarchy-shell dev.deusvult.omavisor stopRecording` |
| Do not disturb (a toggle in the hub) | `omarchy-shell dev.deusvult.omavisor dnd` |

### Keys inside the hub

The keybind or `omarchy-shell dev.deusvult.omavisor expand ""` opens the hub with the keyboard on
the current tab's first useful control, marked with a ring; Esc, the keybind
again or a click outside gives it back. A click with `openOn: "click"` takes
the keyboard too, with no ring until you press a key.

| Key | Does |
|---|---|
| Arrows | Left and Right along a row, Up and Down between rows; in a list or grid they move within it first |
| Up from the top row | The tab strip. There, Left and Right switch tabs (the Settings gear last) and Down goes back into the tab |
| Enter | Run the focused control (on a theme card: apply that theme) |
| Space | Flip a focused toggle or pause a focused timer; otherwise play or pause the media player |
| Left, Right on a slider | Seek five seconds, or step the volume; Up and Down leave it |
| Tab, Shift+Tab | Next or previous tab, the Settings gear last |
| 1–9 | Jump to that tab (the order of `tabs`); with text in the Keys search they filter instead |
| Typing on the Keys tab | Filters the list; Esc clears it, Down or Enter goes to the list |
| Esc | Close the hub (on Settings: back) |

A hub opened by hovering leaves your keyboard alone while the pointer is on the
pill, so typing still goes to the window you were in. Move the pointer onto the
card and the keys work there, as focus follows the pointer into any window;
leaving hands them back and closes the hub. The keybind on a hovered hub takes
the keyboard for good, and then leaving no longer closes it until you come back
with the pointer; the next press closes it.

A control with nothing directly above it goes up to the tab strip; move sideways
first to reach a row that doesn't line up with it.

## Live activities (IPC)

Omavisor registers the IPC target `dev.deusvult.omavisor` (its plugin id; `bin/omavisor` saves the typing). Every argument and answer is a string;
errors start with `error:`.

| Call | Answer | Effect |
|---|---|---|
| `omarchy-shell dev.deusvult.omavisor push '<json>'` | the id | Create or replace an activity by `id`. |
| `omarchy-shell dev.deusvult.omavisor update <id> '<json-patch>'` | `ok` / `unknown` | Shallow-merge fields into it. |
| `omarchy-shell dev.deusvult.omavisor end '<id\|top> [success\|error]'` | `ok` / `unknown` | Show the result for 3 s, then remove it. `top` is the top activity that isn't Omavisor's own. |
| `omarchy-shell dev.deusvult.omavisor list` | JSON array | Every activity, for scripts and tests. |
| `omarchy-shell dev.deusvult.omavisor timer '<minutes> [label]'` | the timer id | A countdown that survives `omarchy restart shell` and blooms and notifies when done. `end <id>` cancels it. |
| `omarchy-shell dev.deusvult.omavisor expand '[tab]'` | `ok` | Open the hub (`home`, `media`, `calendar`, `capture`, `system`, `theme`, `activities`, `keys`, `settings`, hidden from the strip or not; `""` for the last one). |
| `omarchy-shell dev.deusvult.omavisor collapse` | `ok` | Close it. |
| `omarchy-shell dev.deusvult.omavisor restore` | `ok` / `error: …` | Put back the middle of the bar (and on 4.0 the anchor) saved by onboarding (see Removal). |
| `omarchy-shell dev.deusvult.omavisor layout` | JSON | The bar-layout state: last result, backup paths, the anchor one-liner when one is left to run, and how the center differs from the backup. |
| `omarchy-shell dev.deusvult.omavisor version` | semver | For scripts to feature-detect. |

Quickshell IPC calls take exactly the arguments a method declares, so `end`,
`timer` and `expand` take their optional parts in one argument:
`omarchy-shell dev.deusvult.omavisor end "build:api error"`. `bin/omavisor` takes them as separate
words: `bin/omavisor end build:api error`.

An activity:

```jsonc
{
  "id": "build:api",          // required, ≤ 64 chars of [A-Za-z0-9:._-]
  "source": "make",           // ≤ 32, shown muted
  "title": "Building api",    // required, ≤ 80
  "subtitle": "142/380",      // ≤ 120
  "glyph": "",               // a Nerd Font glyph
  "state": "running",         // running | waiting | success | error
  "progress": 0.37,           // 0..1, or null for indeterminate
  "priority": "normal",       // low | normal | urgent (urgent blooms, unless Do Not Disturb is on)
  "ttl": 3600,                // seconds, 1..86400; counted from the last push or update
  "compact": { "leading": "", "trailing": "37%" },
  "actions": [ { "label": "Focus", "exec": ["hyprctl", "dispatch", "focuswindow", "class:Alacritty"] } ]
}
```

Actions are argv arrays, never shell strings, at most three, and run only on a
click (and only while `allowActions` is on). Unknown fields are dropped; bad
ones reject the push with an error. At most 20 activities live at once.

**Spool directory.** Tools that would rather write files can drop
`*.json` into `${XDG_STATE_HOME:-~/.local/state}/omavisor/activities/`: each file is
a push whose id is the file name, and deleting the file ends it. Write to a
temporary name and rename it into place.

## Recipes

Copy-paste integrations in `recipes/`. Omavisor never installs them.

| Recipe | Install | What it does |
|---|---|---|
| `long-command.bash` | `source …/recipes/long-command.bash` in `~/.bashrc` | A command that ran 30 s or more (`OMAVISOR_LONG_COMMAND_SECONDS`) shows in the notch for a minute with its time and exit status. |
| `long-command.zsh` | `source …/recipes/long-command.zsh` in `~/.zshrc` | The same for zsh. |
| `claude-code-hooks.json` + `claude-code-hook.sh` | merge the JSON's `hooks` into `~/.claude/settings.json` (or a project's `.claude/settings.json`); it runs the script from Omavisor's plugin folder | When a Claude Code session waits for you at a permission prompt (or a question) it shows urgent: it blooms and the notch's badge pulses until Claude Code reports it went on (a tool result, the next prompt or Stop: Claude Code has no hook for a prompt being answered, so after a "No" it pulses until your next prompt); the activity ends when Claude finishes its turn. Focus brings its terminal window forward. |
| `omarchy-hook-post-update.sh` | `omarchy hook install post-update …/recipes/omarchy-hook-post-update.sh` | "Omarchy updated" with the new version after `omarchy update` (through the spool, so it survives the shell restart). |
| `omarchy-hook-battery-low.sh` | `omarchy hook install battery-low …/recipes/omarchy-hook-battery-low.sh` | An urgent bloom with the battery percentage. |

They need `omarchy-shell` and `jq` (Omarchy's own scripts use jq), and do nothing when
Omavisor isn't running.

## Glances

- **Notifications** (Activities tab): the newest few as app · summary (never
  the body), read from the files Omarchy's notification service keeps
  (`~/.local/state/omarchy/notifications/`, an internal format, so best
  effort). Do not disturb, dismiss, dismiss all, open the last one and show
  history are the shell's own `omarchy-shell notifications …` calls. Omavisor
  is not a notification server and never runs a notification's action.
- **Now playing**: while a player plays, the album art sits left of the clock.
  The pill keeps room for it whenever Now playing is in `pillItems`, so music
  never changes its width, and a new track changes nothing you see: no title,
  nothing opens. Paused, the art goes. Instead of the art, the spot can
  show **Audio levels** (pill item `meter`, switched on in place of Album
  art): a small level meter that follows your audio when cava is installed
  (see below), and is a drawing that moves while the player plays when it
  isn't. The next
  open after a new track lands
  on Now playing, where the art has the transport under it and a **wave
  display** sits over the scrubber, in one of four styles (`visualizerStyle`:
  bars, mirror, wave, dots; a click on it steps through them and saves the
  choice).
- **The wave and cava**: with [cava](https://github.com/karlstav/cava)
  installed (`omarchy pkg add cava`, optional), the wave and the pill's
  Audio levels follow your audio: cava reads the default output's monitor
  while a player plays and either the Now playing view is open or Audio
  levels is in the pill, and stops the moment that ends. Nothing is recorded
  or kept; its config is `~/.local/state/omavisor/cava.conf`. Without cava,
  both are a drawing that moves while the player plays. Any MPRIS player
  (Spotify, browsers, mpv
  with mpv-mpris). Leave `media` out of `pillItems` (or switch it off in
  Settings) to hide it.
- **Notices**: a short peek when the power cable goes in or out (on a laptop),
  a monitor is connected or removed, or a Bluetooth device connects,
  disconnects or runs low (20%, once per charge). They go by themselves after
  a few seconds; set Notices to Quiet on the Settings page (or
  `activityRules: {"notices": "quiet"}`) to keep them to the Activity view.
- **Dictation**: while Superwhisper or voxtype records or transcribes, the pill
  shows it, with Stop and Cancel. Omavisor follows the backend
  `omarchy default dictation` names (Omarchy 4.5), else whichever is installed,
  Superwhisper first (`superwhisper status --bar --follow`, `voxtype status
  --follow`).
- **Microphone / camera in use**: an app reading the microphone or a camera
  through Pipewire (or holding `/dev/video*`, with `fuser`) peeks and stays in
  the badge while it does.
- **Keys tab**: every binding `omarchy menu keybindings --print` lists. Typing
  filters them; the button beside the search field opens Omarchy's own
  keybindings menu.

## Optional tools

| Tool | Used for |
|---|---|
| `omarchy-update-available`, `checkupdates` (pacman-contrib) | the update badge and System tile (hidden without `checkupdates`), the pending package count |
| `yay` | the pending AUR count |
| `systemctl` | the failed-units badge and tile |
| `sensors` (lm_sensors) | the CPU temperature |
| `nvidia-smi` | NVIDIA GPU use and temperature (not asked while the card is runtime-suspended, which would wake it) |
| `btrfs` (btrfs-progs) | disk use on a Btrfs root (otherwise `df`) |
| `btop` | opened by a click on the stats |
| `gpu-screen-recorder` (`omarchy capture screenrecording`) | the REC pill |
| `localsend` | Share on "Recording saved" |
| `hyprsunset` | the night-light toggle |
| `power-profiles-daemon` (`omarchy powerprofiles`) | the profile chips on the Power tile (the battery readout works without it) |
| `jq` | Omarchy 4.0 only: setting `centerAnchor` (without it, the card says what to edit by hand) |
| `wl-copy` | the Copy button on that one-liner |
| `tesseract`, `zbarimg` (via `omarchy capture text` / `qr`) | OCR and QR capture |
| Superwhisper or `voxtype` (Omarchy's Setup > Defaults > Dictation) | Listening / Transcribing in the notch while you dictate, with Stop and Cancel |
| `fuser` (psmisc) | cameras opened without Pipewire in "Camera in use" (the microphone and Pipewire cameras need nothing) |

No network except Open-Meteo for the weather, album-art links that your
media players publish, and the Omarchy update check every
`updatePollMinutes` and the package count every `pkgPollMinutes`
(`checkupdates` asks the package mirrors, `yay -Qua` the AUR). The pill's temperature and glyph come from
`omarchy weather status` / `icon`, which Omavisor runs every 15 minutes; those
Omarchy commands ask wttr.in by place name, not the stored coordinates. No root rights, no downloaded code.

Like every Omarchy plugin, Omavisor runs unsandboxed inside the shell, with your
user's permissions. What it runs: Omarchy's own `omarchy …` and
`omarchy-shell …` commands, the optional tools above when they are installed,
and the commands an activity or your `actions` carry, as argv and only when
you click. It writes only its own bar entry, `${XDG_STATE_HOME:-~/.local/state}/omavisor/`,
and, after you click Replace or Restore, the bar layout through Omarchy's bar
commands (on Omarchy 4.0 also `centerAnchor` in shell.json, backed up first).

## Development

Omavisor is developed in a private repository; this public one mirrors its
releases. Code comments that cite SPEC refer to the design spec kept there. The marketplace's
[development guide](https://plugins.omarchy.org/develop.html) checks, as they
apply to Omavisor:

```bash
dir=~/.config/omarchy/plugins/dev.deusvult.omavisor
omarchy plugin validate "$dir/"                    # trailing slash: a symlinked dev folder
omarchy plugin list --json | jq '.[] | select(.id == "dev.deusvult.omavisor")'
omarchy-shell shell summon dev.deusvult.omavisor '{}'
omarchy-shell shell hide dev.deusvult.omavisor
qs log -p "$OMARCHY_PATH/shell" --tail 100           # QML errors when something doesn't load
```

Tests:

```bash
test/lint.sh                                                   # qmllint
QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input test/
bash test/ipc-smoke.sh                                         # against the running shell
test/fresh-install.sh                                          # add/replace/restore/remove in a throwaway shell (Xvfb)
```

## Support

Questions and bugs: open an issue on the public repository, with your
Omavisor version (`omarchy-shell dev.deusvult.omavisor version`), your
Omarchy version and what you expected. Logs help:
`qs log -p "$OMARCHY_PATH/shell" --tail 200` and `journalctl -b -t
omarchy-shell`. Security problems go privately, as `SECURITY.md` says.

Tested on Omarchy 4.0.6 and 4.5.0 (top bar on both, all four edges on 4.0.6);
not yet on several monitors.

## License

MIT, Copyright (c) 2026 Deus Vult Digital. See [LICENSE](LICENSE).
