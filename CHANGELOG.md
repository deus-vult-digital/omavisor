# Changelog

All notable changes to Omavisor. Versions follow [semver](https://semver.org/).

## [Unreleased]

## [0.4.1] - 2026-11-09

The first public release, at github.com/deus-vult-digital/omavisor.

### Changed
- Released under **Deus Vult Digital**: the manifest's `author` and the
  LICENSE's copyright holder, and the homepage and install URL
  `github.com/deus-vult-digital/omavisor`, the public mirror of each release.

## [0.4.0] - 2026-11-09

Renamed from Crest to Omavisor, minimal by default (three views, a quiet
pill), music in the pill, and the marketplace review's fixes. Still private on
Forgejo; nothing published.

### Changed
- The pill follows the bar's `fixedEdge`. Sharing the centre with other
  widgets, a peeking activity grows one way, glyph, title and time in one
  wing, so the clock doesn't move. Alone in the centre it is as before.
- The pill keeps looking for its service (every 30 s after the first
  minute) instead of giving up, so a service that loads late is found.
- Settings schema: rows for the side-bar clock formats, defaults for Hub
  tabs and Pill items, and no `actions` row (an object; edit it in
  shell.json or on the Settings page). `longCommandSeconds` and `monitors`,
  reserved for modules never built, are gone.
- The IPC target is the plugin id: `omarchy-shell dev.deusvult.omavisor …`
  (was `omarchy-shell omavisor …`), as the marketplace's service contract
  asks. `bin/omavisor` is unchanged to use.
- Renamed from Crest to **Omavisor**: plugin id `dev.deusvult.omavisor`,
  `bin/omavisor`, activity ids `omavisor:*`, state in
  `${XDG_STATE_HOME:-~/.local/state}/omavisor/`. Nothing was public under the
  old name, so there is no migration.
- Minimal by default. A new install shows three views (Now playing,
  Calendar, Activity) and a pill that is just the clock; Home, Capture,
  System, Theme and Keys are a switch away in Settings. Weather left the
  default pill. Existing `tabs` and `pillItems` lists are kept; Reset on the
  Settings page gives the new defaults.
- Quieter hub: borderless tabs (only the selected one is filled), no date
  line or divider under them, and a narrower card (680 instead of 820) for
  the three everyday views when the strip is short.
- Now playing in the pill: the album art left of the clock, instead of the
  title. The pill keeps room for it whenever Now playing is listed, so music
  never changes its width; a track change never widens the pill or calls for
  attention. The title is in the Now playing view.
- Album art or audio levels in the pill: one spot left of the clock, while
  a player plays. Pill items `media` (Album art) and `meter` (Audio levels,
  a small meter, real levels with cava, drawn without) share it: switching one
  on in Settings > Pill takes the other off. The spot keeps its room while
  either is listed, so music never changes the pill's width.
- Now playing view: the transport sits under the art, and a wave display
  over the scrubber, in four styles (`visualizerStyle`: bars, mirror, wave,
  dots; a click steps through them). With cava installed it follows the
  audio, run only while the view is open and a player plays; without, a
  drawing. The Now playing view drops its
  side column (player, album, volume): art, title, artist, scrubber,
  transport.
- A new track or playback starting makes the next open land on Now playing.
- Hub corners follow the theme, joint included: on a rounded theme the cap
  around the pill curves into the card where they meet (`ui/Fillet.qml`)
  with the theme's rounding, on a square theme they meet at a right angle.
  A new `corners` setting (`auto` default, `square`, `round`) holds one look
  on any theme; `round` on a square theme is a small curve. Top and bottom
  bars; along a left or right bar the joint stays square.
- Tabs renamed: Media is "Now playing", Activities is "Activity". The ids
  (`media`, `activities`) are unchanged.
- Settings no longer warns that timers are hidden when only Activity shows
  them: a running timer is a live activity.

### Added
- Actions: a Home tile of your own commands (`actions`: label to argv), run
  on a click as argv, never through a shell. Reset and Restore leave them
  alone.
- Notices: a short peek when the power cable goes in or out, a monitor is
  connected or removed, or a Bluetooth device connects, disconnects or runs
  low. A new `notices` group in `activityRules` and on the Settings page.
- Audio levels in the pill follow the real audio when cava is installed
  (cava then runs while a player plays and the meter shows, not only while
  the Now playing view is open); a drawing without it.
- Drag to reorder the pill: press and hold a part (clock, weather, the art or
  levels spot), drag it along the pill, let go; saved as `pillItems`. The
  pill now draws its parts itself, one item each.
- `hubOpacity` (default 85): the hub's card and cap are see-through, text and
  controls solid.
- `SECURITY.md` (private reporting, supported versions, what counts) and a
  Support section in the README.
- CI pins `actions/checkout` to a commit and the Arch image to a digest,
  with read-only permissions; the manifest check knows 4.5's six bar
  sections.
- `preview.png` for the marketplace listing: the pill and the open Now
  playing card on a stock theme, from a staged setup with no personal data.

### Removed
- The experimental Widgets tab (`hostedWidgets`). It loaded other plugins'
  QML into the hub and reached inside it, which the marketplace's plugin
  contract rules out. A `widgets` entry left in `tabs` is ignored.

### Fixed
- On a rounded theme the card's corners at the bar side are square, fill and
  border alike; the border used to round there inside a square fill, a
  doubled line.
- The curves where the cap meets the card no longer show a square step: the
  cap and card no longer draw a border on the side where they meet (it was
  painted over), the curve's outline runs on past its ends, and the sliver
  of it that falls past the bar's edge is drawn in the hub's window. The
  hub re-checks the pill's place while open.
- Web album art is downloaded with limits (curl: http/https only, 3
  redirects, 5 MB, 8 s) to a local file, and only that file reaches an
  Image, as the marketplace review asks. One file at a time, under
  `~/.local/state/omavisor/art/`, emptied at start.
- `reduceMotion: auto` now follows the shell's animations switch (`omarchy
  toggle animations`); before, auto behaved like off, and pulsing badges and
  the meter kept moving with animations turned off.
- No "Unable to assign [undefined] to QUrl" warning from a theme card without
  a preview image.
- README no longer says `pillItems` and `activityRules` have no effect.

## [0.3.0] - 2026-11-07

The first tagged version (Forgejo, private). Everything since 0.2.0 below, which
was never tagged: in-hub keys, the Settings page and customization, the M3
modules, Omarchy 4.5 support and Superwhisper dictation.

### Fixed (Omarchy 4.5)
- The hub opens again. On Omarchy 4.5 the bar's window covers the whole
  screen, so the hub opened below the screen and the pill's cap ran down to
  the bottom. Omavisor now measures the bar by its strip.
- Replace clock & weather and Restore work with 4.5's center layout, which has
  no `centerAnchor`: Omavisor goes alone in the center box, and what stood before
  and after the clock moves to `centerBegin` and `centerEnd`, in the same
  order. Omavisor no longer edits shell.json itself on 4.5.
- Do not disturb shows and toggles again (4.5 renamed `dndState` to `isDnd`).
- Notifications show again (4.5 keeps them in `live.json` and `history.json`).
- No "Cannot read property 'title' of null" warning when a window closes.

### Added (Omarchy 4.5)
- Dictation with Superwhisper: Listening and Transcribing in the pill with Stop
  and Cancel, like voxtype. Omavisor follows the backend
  `omarchy default dictation` names, else whichever is installed.

### Changed (Omarchy 4.5)
- Voxtype is followed with `voxtype status --follow` directly; 4.5 removed
  `omarchy voxtype status`.

### Added (Settings page, ON-17)
- A Settings page, off a gear after the hub's tabs or with
  `omarchy-shell omavisor expand settings`: columns for tabs, Home tiles, what the
  pill shows and how far each kind of activity may interrupt. Arrows move, Space
  or Enter toggles, Shift+Up and Shift+Down reorder, Esc goes back; switches and
  arrows work with the mouse. It holds the hub open, works on all four bar edges
  and follows the theme. Changes show at once and go to Omavisor's own entry in
  `shell.json` after a short quiet.
- Reset to defaults, pressed twice, clears only what the page sets. The bar layout
  Restore or Replace is here too.
- A tab added by an update stays hidden and shows as New in Settings.
- `pillItems` now decides what the pill shows and in what order. `activityRules`
  now sets the most each kind of activity may do. Without either key nothing
  changes.

### Changed (ON-17)
- The hub is a little wider, to fit the gear. With all nine tabs on, only the
  selected tab keeps its name, so the last one is no longer clipped.

### Added (customization foundations, ON-16)
- `tabs`: which tabs the hub's strip shows and in what order, for example
  `omarchy bar set dev.deusvult.omavisor tabs "home media system keys"`.
  Digits, Tab and arrows on the strip follow it, and the first tab is where the
  hub opens first. Without the key nothing changes. Once you have a list, a tab
  added by a later update stays hidden.
- A hidden tab still opens by name (`omavisor expand media`, a bloom's click on
  Activities) with no tab selected.
- `homeTiles` can list `today`. `pillItems` and `activityRules` are accepted but
  not read yet.
- `lib/Catalog.js`: one list of tabs, tiles and pill items with their ids,
  labels and availability, in place of the lists in the UI and settings.

### Changed (ON-16)
- A short `homeTiles` list stays short: two tiles are two wide tiles, with no
  Today tile added. Today still fills in for a listed tile that can't show.
- A settings write no longer rebuilds the Home tiles under the pointer or the
  keyboard focus.

### Fixed (ON-16)
- Timers could show nowhere: with `homeTiles: power hypr stats media timers`,
  Home filled up before reaching them while System believed Home had them. Both
  now ask the same function.
- `omavisor restore` no longer undoes `tabs`, `homeTiles`, `pillItems`,
  `activityRules` or `hostedWidgets` changed since the backup, and no longer
  fails on them.
- `omavisor expand theme` with no theme module opens the hub normally instead of
  showing Home with no tab selected.

### Changed (review fixes, ON-14)
- Every tab switches on hover the same way, Theme and Widgets too: one code
  path for pointer and keys. Theme cards still apply on click or Enter only.
- A keybind or IPC open lands on the tab's first useful control with a focus
  ring. Arrows are the main way around: Left and Right in a row, Up and Down
  between rows, Up off the top to the tab strip, where Left and Right switch
  tabs. Space flips a focused toggle, else plays or pauses.
- A hovered hub has the keys while the pointer is on its card, and the toggle
  keybind on it takes the keyboard rather than closing it.
- Sliders, the Widgets chips and the cheatsheet list are reachable by key;
  typing on the Keys tab filters the cheatsheet (its search field is real now,
  with a button for Omarchy's own menu).
- Suggested keybinds: SUPER + CTRL + U is the hub, J activities; more for DND
  and the clock format.

### Added (review fixes, ON-14)
- `omavisor format`, `dnd`, `scroll up|down`, `workspace next|prev`,
  `volume up|down` and `stopRecording`, so every pill mouse action can be bound.
- `test/keybinds-free.sh` (run by `test/lint.sh`): fails if a suggested combo is
  among Omarchy's default bindings.

### Added (M3, ON-11)
- System stats: CPU (from `/proc/stat`), memory, CPU temperature
  (`sensors -j`), GPU (`nvidia-smi`, or amdgpu's `gpu_busy_percent`) and
  disk (`btrfs filesystem usage`, else `df`), as rails in a Stats column on
  the System tab and an optional `stats` Home tile; a click opens btop.
  Polled only while one of them is on screen (`statsWhileOpenMs`); a
  runtime-suspended NVIDIA card is shown as asleep instead of being woken.
- Pending packages: repo (`checkupdates`) and AUR (`yay -Qua`) counts every
  `pkgPollMinutes`, in the Updates tile with an Update button (Omarchy's
  updater in a floating terminal; Update AUR when only AUR packages wait).
- Failed units: `systemctl --failed` for the system and the user, checked
  every minute; a failed unit is an activity (badge, peek, Journal action)
  and a System tab column whose rows open the unit's journal.
- `pkgPollMinutes` and `statsWhileOpenMs` are in the settings schema.

### Changed (M3, ON-11)
- The System tab leads with Stats; Timers stay on the Home tab when
  `homeTiles` has them (the default), to leave the columns room.

### Added (M3, ON-12)
- Notifications glance in the Activities tab: the newest notifications as
  app · summary from the shell's notification files (watched, never polled;
  never the body or the action), DND, dismiss, dismiss all, open last, show
  history through `omarchy-shell notifications`.
- Dictation: voxtype's listening and transcribing as an activity first in the
  pill, with Stop and Cancel (`omarchy voxtype status`, streamed).
- Microphone and camera in use, from Pipewire links into streams, plus
  `fuser` on `/dev/video*` for cameras opened directly.
- Keys tab: the `omarchy menu keybindings --print` cheatsheet; its search
  field opens Omarchy's searchable keybindings menu.
- The pill's badge pulses while an urgent activity waits for you
  (`reduceMotion: on` keeps it still).

### Changed (M3, ON-12)
- Claude Code recipe: the hooks now run `recipes/claude-code-hook.sh`. A
  session turns urgent and waiting at a permission prompt or question
  (bloom and pulse; idle-input notifications are ignored), goes back to
  running on the next tool result (or failure) or prompt, ends with success on Stop, with error on StopFailure, and
  goes on SessionEnd. Claude Code has no hook for an answered prompt, so a
  denied one pulses until the next prompt. Its Focus action raises
  the session's terminal window.

### Added (M3, ON-13)
- In-hub keys: a hub opened from a keybind or `omarchy-shell` (or a click
  with `openOn: "click"`) takes the keyboard. Tab and Shift+Tab switch tabs,
  1–9 jump to one, arrows move the focus between buttons and rows (and
  through the theme cards), Enter runs the focused one (applies a theme),
  Space plays or pauses, Esc closes. The focus is drawn with the theme's
  focus tokens. A hover-opened hub still takes no keyboard focus.
- `homeTiles` also takes a string, `"media weather stats"`, so
  `omarchy bar set … homeTiles "…"` works (a JSON array can't pass through
  `omarchy bar set`: the shell's IPC splits an argument starting with `[` at
  its commas).

### Changed (M3, ON-13)
- The hub is a layer-shell window instead of an xdg-popup (needed for the
  keyboard); its look, size and grow-out animation are unchanged.
- The Hyprland layout chip and the power profile chips follow changes made
  elsewhere while the hub is open (Omarchy's layout toggle, the stock power
  panel, `powerprofilesctl`).

### Fixed (M3, ON-13)
- Notification folders with a space or `#` in the path are watched
  correctly (the file URLs are encoded).

### Added (M3, ON-10)
- Theme tab: every theme `omarchy theme list` prints, in its order, as a
  card with its preview and colors.toml swatches; a click applies it with
  `omarchy theme set`, and the current one is marked (re-read after an apply
  and whenever the shell's theme changes). The leading column shows the
  current theme with Next background (`omarchy theme bg next`) and the full
  built-in switcher. `omavisor expand theme` opens it.
- Power Home tile (`homeTiles: power`), only on machines where
  `omarchy battery present` succeeds: level, state, time left or to full and
  draw from UPower, plus the power profiles as chips
  (`omarchy powerprofiles set ac|battery <profile>`).
- Hyprland Home tile (`homeTiles: hypr`): focused workspace and monitor, the
  active window's title and class, and the workspace's dwindle/scrolling
  layout with Omarchy's toggle; the wheel on it switches workspace.
- `lib/Theme.js`, `lib/Power.js`, `lib/Hypr.js` with qmltestrunner tests.

## [0.2.0] - never tagged

The first marketplace candidate: M1 (the MVP) and M2 (marketplace prep). Not
tagged or published on its own; it ships in 0.3.0. The repo stayed private
until its publisher's go-ahead.

### Added (M2, ON-9)
- README: marketplace install (`omarchy plugin add … --enable`), removal with
  and without a layout backup. No screenshots or `preview.png` yet: those
  come from a staged clean setup, approved, before going public.
- `docs/marketplace-submission.md`: the drafted submission body and the
  `gh issue create` command, not run.
- `test/fresh-install.sh`: `omarchy plugin add --enable --yes`, the first-run
  Replace, restore, `omarchy plugin remove --yes` and the documented cleanup,
  run against a throwaway Omarchy shell with its own HOME and Wayland
  display, so the real bar, files and session bus are left alone (the
  throwaway shell's clipboard overlay is disabled: it would pkill the real
  clipboard watchers).
- Ran the marketplace's own validator and Automated Security Baseline
  locally against the private repo (token auth; only "must be public"
  skipped): validation passes, baseline `passed` with no findings. README no
  longer has the manual `git clone` install or the word sudo, which made the
  baseline ask for a manual review.
- CI checks the marketplace's repository rules too (root README and license,
  preview within 50 MB and 40 megapixels, one manifest, no symlinks).

### Changed (M2, ON-9)
- Version 0.2.0.
- The settings schema no longer lists `pkgPollMinutes`,
  `longCommandSeconds` and `monitors`: nothing reads them yet, so Omarchy's
  settings panel offered knobs that did nothing. Their defaults stay.


### Changed
- Weather (ON-8): the pill's temperature and glyph now come from
  `omarchy weather status` and `omarchy weather icon`, which Omavisor runs every
  15 minutes, so the pill always shows what the CLI shows. Open-Meteo still
  gives the condition, high/low and humidity, shown only while its
  temperature agrees with the CLI's (within 3 °C). Without the CLI Omavisor uses
  Open-Meteo alone, as before. Offline the last CLI reading stays, marked `~`.
  The CLI asks wttr.in by place name, not the stored coordinates, so an
  ambiguous name ("Portland") can be another town; store a clearer name,
  e.g. `omarchy weather location --set "Portland, Oregon" <lat,lon>`.

### Fixed
- The shell no longer spins at 100% CPU when two media players are around
  (say a paused Spotify and a stopped browser tab): the Media module's pick
  flipped between them forever. Found in the M1 acceptance pass (ON-7).
- Updates: without `checkupdates` (pacman-contrib) the Updates tile and badge
  hide instead of showing "Up to date" from a check that never ran.

### Checked (M1 acceptance, ON-7)
- Idle CPU 0.03% vs 0.02% without Omavisor, System tab open 0.81%, RSS about
  +14 MB, hub open to first frame 15–41 ms; all 22 stock themes and all four
  bar edges; stripped PATH; ipc-smoke and stress pass.

### Added
- Onboarding (SPEC M1, section 9): on first run the Home tab asks whether
  Omavisor should replace the stock clock and weather. "Replace clock & weather"
  saves the center (entries with their inline settings, `centerAnchor`, Omavisor's
  own entry) to `$XDG_STATE_HOME/omavisor/layout-backup.json`, gives Omavisor the
  clock's formats and moves the widgets with `omarchy plugin disable` and
  `omarchy bar move`, then sets `centerAnchor` in shell.json itself (backup to
  `shell.json.bak.<epoch>` first, then `jq -S`, as argv steps; Omarchy has no
  command for it). Without `jq` the card shows that edit as a one-line
  command with a Copy button instead. "Keep
  them" sets `mode: "wrap"`, where the pill is only the activities glyph.
- Restore: `omarchy-shell omavisor restore` (and `bin/omavisor restore`, which waits
  and prints the result) or the Restore button on the System tab's Bar layout
  tile puts the saved center back exactly, entry by entry and setting by
  setting, and the saved anchor the same way.
  `omarchy-shell omavisor layout` reports the state. `lib/Layout.js` with tests.
- README v1: install, first run, removal with the restore steps, settings,
  keybindings, the IPC contract and recipes.
- Recipes (not installed by Omavisor): `long-command.bash`/`.zsh`,
  `claude-code-hooks.json`, `omarchy-hook-post-update.sh`,
  `omarchy-hook-battery-low.sh`.
- Spike: Widgets tab behind `hostedWidgets` (default off). Other plugins' bar
  widgets (built-ins first, then third-party) are hosted in the hub, and stock
  panels (audio, network, bluetooth, power, display, weather, agents, …) are
  shown inline; overlays without a widget get a link chip. See SPEC M4
  "Hosting other plugins" for limits.
- Live activities (SPEC.md section 8): `omarchy-shell omavisor push`, `update`,
  `end`, `list`, `timer`, `expand`, `collapse`; `lib/ActivityStore.js`
  (validation, upsert, shallow-merge update, end with a 3 s result state, ttl
  expiry, priority sorting, max 20 with low-priority eviction, ≤ 10 renders/s)
  with unit tests.
- Spool directory `${XDG_STATE_HOME:-~/.local/state}/omavisor/activities/*.json`:
  a file is a push named by its file, removing it ends it, expired files are
  swept.
- The pill shows the top activity's glyph and peeks (glyph, title, trailing)
  for 4 s on a new one; urgent activities bloom out of the pill unless Do Not
  Disturb is on; the Activities tab lists them with progress, countdowns,
  action buttons (argv only, on click, `allowActions`) and dismiss.
- `bin/omavisor` wrapper, `test/ipc-smoke.sh`, `test/stress.sh`.
- Weather in the pill after the clock (glyph and temperature, `~` while the
  reading is stale), from Open-Meteo every 15 minutes for the place
  `omarchy weather location` names (coordinates from Omarchy's own location
  file, or Open-Meteo's geocoder for a bare name, such as the IP-detected
  city when no location is stored, which picks the namesake in the machine's
  UTC offset). With a stored location it is the stock
  weather panel's request, and the glyphs are the panel's; the summary line reads like
  `omarchy weather status` (whose wttr.in-by-name data can differ, see
  SPEC Open question 13). Offline, the last reading stays (also across
  restarts, cached in `$XDG_STATE_HOME/omavisor/weather.json`); no errors,
  and retries back off from 2 to 15 minutes. New
  `unit` setting (`auto`, `metric`, `imperial`).
- Media tab: album art, title and artist, a scrubber with elapsed and
  remaining time, previous / play-pause / next, and the player's volume when
  it supports one, straight from MPRIS (no playerctl). It follows the playing
  player, else the one that played last. Local art always; web art (Spotify,
  browsers) with the new `remoteArt` setting.
- Calendar tab: today with its ISO week, day and year progress, life
  progress when `birthYear` (and optionally `lifeExpectancy`) is set, and a
  month grid with ISO week numbers that steps by month (chevrons or wheel).
  Same grid and numbering as the stock clock, `weekStartDay` included.
- Home tab tiles follow `homeTiles`: live media and weather tiles that step
  aside when there is nothing to show, and a Today tile in a free slot.
- Scrolling on the pill sets the playing player's volume (`scrollAction:
  auto` or `volume`); with `auto` and nothing playing it switches workspace.
- `modules/ClockModule.qml`, `WeatherModule.qml`, `MediaModule.qml`; the
  weather and media modules live in the service, shared by every pill.
- `lib/Calendar.js` (port of the stock clock's model), `lib/Weather.js`,
  `lib/Media.js`, and duration/temperature helpers in `lib/Format.js`, each
  with tests.

- System modules (SPEC M1): Omarchy updates, screen recording, capture,
  quick toggles and timers, in a real Capture tab, a System tab (Timers,
  Updates, Quick toggles) and Home tiles (`timers`, `updates`, `capture`).
  - Updates: `omarchy-update-available` at start and every
    `updatePollMinutes`; a pending update is a low-priority activity (pill
    badge, Activities row with an Update action) and an Update button opens
    `omarchy-update` in a floating terminal.
  - Recording: noticed at once from the file Omarchy's recorder writes
    (pgrep every 5 s while recording, 30 s otherwise); the pill shows REC with
    the elapsed time, a click on that side stops it, and a "Recording saved"
    bloom offers Open, Share (when LocalSend is installed) and Transcode.
  - Capture: screenshot region, window, screen (saved) and smart, OCR and QR;
    the hub closes before the capture so Omavisor is not in the shot.
  - Quick toggles: Do Not Disturb, night light and stay awake, read from and
    switched with Omarchy's own commands.
  - Timers: 5/15/25/50-minute countdowns and a pomodoro (25 min focus, then a
    5 min break), pause/resume and cancel, kept in
    `$XDG_STATE_HOME/omavisor/timers.json` so they survive `omarchy restart
    shell`; when one ends it blooms and sends an Omarchy notification.
    `omarchy-shell omavisor timer` now starts these persisted timers.
- `modules/Probe.qml` (process guards: skip while running, kill timeout,
  missing tool → module hidden), `lib/Timers.js`, `lib/System.js`, with tests.

### Changed
- MIT LICENSE added.
- Album art may now come from the web: `remoteArt` defaults to on. Local art
  is used first; a player's web art URL only when it has no local art, only
  for the current track and only while a player is present. Omavisor's network
  rule is now "Open-Meteo, plus album-art URLs that MPRIS players publish"
  (SPEC sections 11 and 12, CLAUDE.md). Set `remoteArt` to `false` for local
  art only.
- Omavisor's own activities (recording, update) show their action buttons even
  with `allowActions` off; senders cannot claim that, and `omavisor update` on
  one of them answers an error.
- Capture's Text and QR buttons show only when `tesseract` / `zbarimg` are
  installed.
- Album art (local or web) is loaded only while it is on screen.
- `end top` skips Omavisor's own activities (REC, timers, update), and a push
  or spool file cannot replace one.

### Notes
- Quickshell IPC needs exact argument counts, so `end`, `timer` and `expand`
  take their optional parts in one argument (`end "build:api error"`);
  `bin/omavisor` joins words for you.

## [0.1.0] - 2026-10-29 (M0 spike)

### Added
- Manifest with three kinds (`bar-widget`, `service`, `panel`) and `keepLoaded`.
- Pill in the bar showing the clock with `format`/`formatAlt`; right click swaps
  them, left/right bars show the compact `verticalFormat` stack.
- Hub that grows out of the pill (MacNotch-style), 760 × 260, with native tabs
  (Home, Media, Calendar, Capture, System, Activities) and placeholder tiles.
- Opens on hover (default `openOn: "hover"`) and collapses when the pointer
  leaves; opened by hover it holds no input. A click on a hover-opened hub keeps
  it open. Keybind and click-mode opens take the usual click-outside grab. Tabs
  switch on hover. Opening it closes any other bar popup; hover never takes over
  one the user opened.
- `omarchy-shell shell toggle dev.deusvult.omavisor '{}'` opens/closes the
  hub on the focused monitor; `summon` takes `{"tab":"<name>"}`.
- `omarchy-shell omavisor version` IPC.
- `lib/Settings.js` defaults and coercion, `lib/Format.js` clock helpers, with
  `qmltestrunner` tests; `test/lint.sh`; CI (manifest check, qmllint, tests,
  shellcheck).
