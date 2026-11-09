#!/usr/bin/env bash
# Live smoke test of Omavisor's IPC contract (SPEC.md section 8, M1 acceptance):
# push → list contains it → update progress → end success → gone after 3 s,
# plus the error answers. Needs the running shell with Omavisor enabled (after
# `omarchy restart shell` when Service.qml changed).
set -uo pipefail

omavisor() { omarchy-shell dev.deusvult.omavisor "$@"; }
id="smoke:$$"
fails=0

check() { # name expected actual
  if [[ $3 == "$2" ]]; then echo "ok   $1"; else echo "FAIL $1: expected '$2', got '$3'"; fails=$((fails + 1)); fi
}
# shellcheck disable=SC2329 # called through pass_if
has() { omavisor list | jq -e --arg id "$id" "$1" >/dev/null; }
# pass_if <name> <command…>: ok when the command succeeds.
pass_if() {
  local name=$1
  shift
  if "$@"; then echo "ok   $name"; else echo "FAIL $name"; fails=$((fails + 1)); fi
}
# shellcheck disable=SC2329 # called through pass_if
is_error() { [[ $1 == error:* ]]; }

version=$(omavisor version) || { echo "FAIL: omavisor IPC target unreachable"; exit 1; }
echo "omavisor $version"

check "push returns the id" "$id" "$(omavisor push "{\"id\":\"$id\",\"title\":\"Smoke test\",\"progress\":0.1}")"
# shellcheck disable=SC2016 # $id is a jq variable
pass_if "list contains it" has 'any(.[]; .id == $id and .state == "running")'

check "update" "ok" "$(omavisor update "$id" '{"progress":0.6,"subtitle":"60%"}')"
# shellcheck disable=SC2016 # $id is a jq variable
pass_if "update merged" has 'any(.[]; .id == $id and .progress == 0.6 and .title == "Smoke test")'

check "end success" "ok" "$(omavisor end "$id success")"
# shellcheck disable=SC2016 # $id is a jq variable
pass_if "shows success while ending" has 'any(.[]; .id == $id and .state == "success")'
sleep 3.3
# shellcheck disable=SC2016 # $id is a jq variable
pass_if "gone after 3 s" has 'any(.[]; .id == $id) | not'

check "update unknown" "unknown" "$(omavisor update "$id" '{}')"
check "end unknown" "unknown" "$(omavisor end "$id")"
check "invalid JSON" "error: invalid JSON" "$(omavisor push '{nope')"
pass_if "bad id rejected" is_error "$(omavisor push '{"id":"x y","title":"t"}')"
pass_if "unknown state rejected" is_error "$(omavisor push "{\"id\":\"$id\",\"title\":\"t\",\"state\":\"paused\"}")"
check "update of unknown id" "unknown" "$(omavisor update nope '{bad')"
check "still alive" "$version" "$(omavisor version)"

tid=$(omavisor timer "1 Smoke timer")
pass_if "timer → $tid" [ "${tid#timer:}" != "$tid" ]
check "end timer" "ok" "$(omavisor end "$tid")"

# The pill's mouse actions; the ones with an effect are only tried with bad
# arguments (a run must not switch the user's workspace); DND there and back.
check "format" "ok" "$(omavisor format)"
check "format back" "ok" "$(omavisor format)"
check "dnd" "ok" "$(omavisor dnd)"
sleep 0.5
check "dnd back" "ok" "$(omavisor dnd)"
pass_if "scroll usage" is_error "$(omavisor scroll sideways)"
pass_if "workspace usage" is_error "$(omavisor workspace up)"
pass_if "volume usage" is_error "$(omavisor volume loud)"

if (( fails == 0 )); then echo "PASS"; else echo "$fails failed"; fi
exit $(( fails > 0 ))
