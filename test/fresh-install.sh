#!/usr/bin/env bash
# Fresh-install test (SPEC M2): install Omavisor the marketplace way into a
# brand-new Omarchy user, go through Replace and the README's removal, and
# check that nothing is left behind.
#
#   test/fresh-install.sh [git-url]
#
# The git URL defaults to a bare clone of this checkout's HEAD (file://), so
# the test runs before the repo is public. Pass the public https URL later.
#
# The real session's bar and files are left alone: the test runs a throwaway
# omarchy-shell with its own HOME, XDG dirs, runtime dir (so its IPC socket,
# and every omarchy-shell call made here, reach only it), D-Bus session bus
# and X display (Xvfb). The clipboard overlay is disabled there (it pkills
# every wl-paste watcher of the user). Shared: the system bus (its polkit
# agent is refused, the real one holds the session) and the network. No sudo. Xvfb has no layer shell, so the bar is not drawn
# and the first-run card can't be clicked; Replace is done with the same
# commands and backup file the card writes (lib/Layout.js makeBackup), and the
# restore is Omavisor's own (bin/omavisor restore). KEEP=1 keeps the temp dir.
set -euo pipefail

if [[ ${1:-} == --inner ]]; then
  root=$2 url=$3
  id=dev.deusvult.omavisor
  plugin="$HOME/.config/omarchy/plugins/$id"
  state="$XDG_STATE_HOME/omavisor"
  shell_json="$HOME/.config/omarchy/shell.json"
  pass() { echo "ok   $*"; }
  fail() { echo "FAIL $*" >&2; exit 1; }

  start_shell() {
    quickshell -n -p "$OMARCHY_PATH/shell" >>"$root/shell.log" 2>&1 &
    shell_pid=$!
    for _ in $(seq 80); do
      [[ $(omarchy-shell shell ping 2>/dev/null) == ok ]] && return 0
      sleep 0.25
    done
    fail "throwaway shell did not start (see $root/shell.log)"
  }
  stop_shell() { [[ -n ${shell_pid:-} ]] || return 0; kill "$shell_pid" 2>/dev/null || true; wait "$shell_pid" 2>/dev/null || true; }
  # wait_for <description> <command…>: up to 10 s.
  wait_for() {
    local what=$1; shift
    for _ in $(seq 40); do "$@" >/dev/null 2>&1 && return 0; sleep 0.25; done
    fail "$what"
  }
  center() { omarchy-shell shell listShellConfig | jq -c '[.bar.layout.center[] | if type == "object" then .id else . end]'; }
  snapshot() {
    (cd "$HOME" && find . -path ./.cache -prune -o -printf '%y %p\n' | sort)
    jq -S 'del(.. | nulls)' "$shell_json"
  }

  read -r display < <(Xvfb -displayfd 1 -screen 0 1920x1080x24 -nolisten tcp 2>"$root/xvfb.log" & echo "$!" >"$root/xvfb.pid")
  export DISPLAY=":$display" QT_QPA_PLATFORM=xcb
  trap 'stop_shell; kill "$(cat "$root/xvfb.pid" 2>/dev/null)" 2>/dev/null || true' EXIT

  # A new Omarchy user: the stock shell.json, nothing else.
  mkdir -p "$HOME/.config/omarchy"
  # Except the clipboard overlay: on load it runs `pkill -f wl-paste …`, which
  # would kill the real session's clipboard watchers too.
  jq '.disabledPlugins = ["omarchy.clipboard"]' "$OMARCHY_PATH/config/omarchy/shell.json" >"$shell_json"
  start_shell
  omarchy-shell shell listPlugins | jq -e 'all(.[]; .id != "omarchy.clipboard" or (.enabled | not))' >/dev/null ||
    fail "omarchy.clipboard is enabled in the throwaway shell"
  sleep 2
  snapshot >"$root/before"
  pass "throwaway shell up; stock center $(center)"

  # 1. The marketplace install.
  omarchy plugin add "$url" --enable --yes
  [[ -d $plugin/.git && ! -L $plugin ]] || fail "not cloned into $plugin"
  omarchy plugin validate "$plugin" || fail "installed copy does not validate"
  wait_for "plugin not enabled" bash -c "omarchy-shell shell listPlugins | jq -e '.[] | select(.id == \"$id\") | .enabled'"
  center | jq -e --arg id "$id" 'index($id) != null' >/dev/null || fail "Omavisor not in the center: $(center)"
  want=$(jq -r .version "$plugin/manifest.json")
  wait_for "IPC target omavisor not answering" bash -c "[[ \$(omarchy-shell dev.deusvult.omavisor version) == '$want' ]]"
  pass "omarchy plugin add --enable --yes: cloned, validated, enabled, in the center $(center), omavisor version $want"
  omarchy-shell dev.deusvult.omavisor push '{"id":"fi:test","title":"Fresh install","ttl":60}' >/dev/null
  omarchy-shell dev.deusvult.omavisor list | jq -e 'any(.[]; .id == "fi:test")' >/dev/null || fail "push not listed"
  omarchy-shell dev.deusvult.omavisor end fi:test >/dev/null
  pass "live activity push/list/end"

  # 2. Replace clock & weather, as the first-run card does it.
  config=$(omarchy-shell shell listShellConfig)
  mkdir -p "$state"
  jq --arg id "$id" --arg now "$(date -u +%FT%TZ)" '
    def eid: if type == "object" then .id else . end;
    .bar as $bar
    | ([["left", "center", "right"][] as $s | ($bar.layout[$s] // []) | to_entries[]
        | select(.value | eid == $id) | {section: $s, index: .key}] | first) as $at
    | {version: 1, savedAt: $now, centerAnchor: ($bar.centerAnchor // null),
       center: $bar.layout.center, omavisor: $at,
       omavisorEntry: ($bar.layout[$at.section][$at.index])}
  ' <<<"$config" >"$state/layout-backup.json"
  index=$(jq --arg id "$id" '[.bar.layout.center[] | if type == "object" then .id else . end
    | select(. != $id)] | (index("omarchy.clock") // length)' <<<"$config")
  omarchy bar set "$id" mode '"replace"' --json >/dev/null
  omarchy plugin disable omarchy.clock >/dev/null
  omarchy plugin disable omarchy.weather >/dev/null
  omarchy bar move "$id" --section center --index "$index" >/dev/null
  shell_backup="$shell_json.bak.$(date +%s)"
  cp -p -- "$shell_json" "$shell_backup"
  t=$(mktemp "$shell_json.XXXXXX")
  jq -S --arg a "$id" '.bar.centerAnchor = $a' "$shell_backup" >"$t" && chmod --reference="$shell_json" "$t" && mv -f "$t" "$shell_json"
  omarchy-shell shell reloadConfig >/dev/null
  jq --arg b "$shell_backup" '.shellBackup = $b' "$state/layout-backup.json" >"$state/b" && mv "$state/b" "$state/layout-backup.json"
  wait_for "replace did not take" bash -c "omarchy-shell shell listShellConfig | jq -e '.bar.centerAnchor == \"$id\" and ([.bar.layout.center[] | if type == \"object\" then .id else . end] | index(\"omarchy.clock\") == null)'"
  pass "replaced: center $(center), anchor $id"
  # Omavisor reads a backup made while it runs; a shell restart also proves
  # the keepLoaded service comes back.
  stop_shell; start_shell
  wait_for "omavisor not back after restart" bash -c "[[ \$(omarchy-shell dev.deusvult.omavisor version) == '$want' ]]"
  omarchy-shell dev.deusvult.omavisor layout | jq -e '.backup != "" and .replaced' >/dev/null || fail "Omavisor does not see the backup: $(omarchy-shell dev.deusvult.omavisor layout)"
  pass "after a shell restart Omavisor sees the backup"

  # 3. README removal, verbatim but for --yes.
  if "$plugin/bin/omavisor" restore &&
    omarchy plugin remove "$id" --yes &&
    rm -rf "${XDG_STATE_HOME:-$HOME/.local/state}/omavisor"; then
    pass "restore, omarchy plugin remove --yes, rm -rf state"
  else
    fail "the README removal stopped (above)"
  fi
  [[ ! -e $plugin ]] || fail "$plugin still there"
  wait_for "shell still lists $id" bash -c "omarchy-shell shell listPlugins | jq -e 'all(.[]; .id != \"$id\")'"
  # A service left running could write its state dir again after the rm.
  [[ $(omarchy-shell dev.deusvult.omavisor version 2>&1) == "Target not found." ]] || fail "Omavisor's service still answers after remove"
  pass "IPC target omavisor gone"
  sleep 5
  snapshot >"$root/after"
  # The shell.json backups Omavisor made (README: delete them when you like)
  # are the only files allowed to be new.
  if ! diff <(grep -v -E '^f \./\.config/omarchy/shell\.json\.bak\.[0-9]+$' "$root/after") "$root/before" >"$root/diff"; then
    cat "$root/diff" >&2
    fail "the user's files or shell.json differ from before the install (above: < after, > before)"
  fi
  left=$(cd "$HOME" && find .config/omarchy -name 'shell.json.bak.*' | sort | tr '\n' ' ')
  pass "no trace: shell.json and the file tree match the fresh user; left on purpose: ${left:-none}"
  pass "center back to $(center), anchor $(omarchy-shell shell listShellConfig | jq -r .bar.centerAnchor)"
  exit 0
fi

for tool in Xvfb dbus-run-session quickshell omarchy omarchy-shell jq git; do
  command -v "$tool" >/dev/null || { echo "fresh-install: needs $tool" >&2; exit 1; }
done
repo=$(cd "$(dirname "$0")/.." && pwd)
# Short: Quickshell's IPC socket path must fit in 108 bytes.
root=$(mktemp -d "${TMPDIR:-/tmp}/omavisor-fi.XXXXXX")
# The shell leaves helpers behind (inotifywait on the plugins dir): end
# every process that names the temp dir, then remove it.
cleanup() {
  pkill -f "$root" 2>/dev/null || true
  if [[ ${KEEP:-} == 1 ]]; then echo "fresh-install: kept $root"; else rm -rf "$root"; fi
}
trap cleanup EXIT
url=${1:-}
if [[ -z $url ]]; then
  git clone -q --bare "$repo" "$root/omavisor.git"
  url="file://$root/omavisor.git"
fi
mkdir -p "$root/home" "$root/run" "$root/tmp"
chmod 700 "$root/run"
echo "fresh-install: $url into a new user at $root/home"
env -i PATH="$PATH" GIO_USE_VFS=local GVFS_DISABLE_FUSE=1 OMARCHY_PATH="${OMARCHY_PATH:-/usr/share/omarchy}" LANG="${LANG:-C.UTF-8}" TERM=dumb \
  HOME="$root/home" XDG_RUNTIME_DIR="$root/run" TMPDIR="$root/tmp" \
  XDG_CONFIG_HOME="$root/home/.config" XDG_STATE_HOME="$root/home/.local/state" \
  XDG_CACHE_HOME="$root/home/.cache" XDG_DATA_HOME="$root/home/.local/share" \
  dbus-run-session -- bash "$repo/test/fresh-install.sh" --inner "$root" "$url"
