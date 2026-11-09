#!/usr/bin/env bash
# Omavisor recipe: Claude Code sessions as live activities (agent sessions).
#
# Not installed by Omavisor. claude-code-hooks.json runs it from Claude Code's
# hooks with the event as its argument and the hook's JSON on stdin:
#   notification  (Notification)     a permission prompt or a question for
#                                    you (notification_type permission_prompt
#                                    or elicitation_dialog): urgent, waiting,
#                                    the notch pulses and blooms (DND
#                                    respected). Idle-input and other
#                                    notifications are ignored, so a finished
#                                    turn is not reopened.
#   resume        (PostToolUse,      it goes on: back to running, if it waited
#                  PostToolUseFailure,
#                  UserPromptSubmit)
#   stop          (Stop)             the turn is done: ends with success
#   fail          (StopFailure)      the turn failed (API error): ends with error
#   end           (SessionEnd)       the session is gone: ends it
# Claude Code fires no hook when a prompt is answered (tested, v2.1.312: a
# "No" or Esc fires nothing, a "Yes" nothing until the tool finishes), so a
# waiting session turns back to running on the tool's result, the next
# prompt or Stop; one denied and then left alone waits until its ttl (1 h).
# One activity per session, id "claude:<first 8 of the session id>". Its
# Focus action brings the terminal the session runs in to the front (the
# first ancestor process with a Hyprland window). Needs omarchy-shell and
# jq; without them, or with Omavisor off, it does nothing and never fails the
# hook.

event=${1:-}
command -v omarchy-shell >/dev/null 2>&1 && command -v jq >/dev/null 2>&1 || exit 0
input=$(cat)

session=$(jq -r '(.session_id // "session") | tostring | .[0:8] | gsub("[^A-Za-z0-9._-]"; "")' <<<"$input" 2>/dev/null)
id="claude:${session:-session}"

# The terminal window: walk up from Claude Code to the first process that
# owns a Hyprland client.
focus_address() {
  command -v hyprctl >/dev/null 2>&1 || return 0
  local clients pid=$PPID address
  clients=$(hyprctl clients -j 2>/dev/null) || return 0
  while [[ $pid =~ ^[0-9]+$ ]] && ((pid > 1)); do
    address=$(jq -r --argjson pid "$pid" 'first(.[] | select(.pid == $pid) | .address) // empty' <<<"$clients" 2>/dev/null)
    if [[ $address =~ ^0x[0-9a-fA-F]+$ ]]; then
      printf '%s' "$address"
      return 0
    fi
    pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
  done
}

push() { # state priority title
  local json
  json=$(jq -c --arg id "$id" --arg state "$1" --arg priority "$2" --arg title "$3" --arg address "$(focus_address)" '{
    id: $id,
    source: "claude",
    title: $title,
    subtitle: (((.cwd // "") | tostring | split("/") | last) as $dir
               | if $state == "waiting" and (.message // "") != "" then ($dir + ": " + (.message | tostring)) else $dir end),
    glyph: "󰚩",
    state: $state,
    priority: $priority,
    ttl: 3600,
    compact: { leading: "󰚩", trailing: (if $state == "waiting" then "waiting" else "" end) },
    actions: (if $address == "" then [] else
      [{ label: "Focus", exec: ["hyprctl", "dispatch", "hl.dsp.focus({ window = \"address:" + $address + "\" })"] }] end)
  }' <<<"$input" 2>/dev/null) || return 0
  omarchy-shell dev.deusvult.omavisor push "$json" >/dev/null 2>&1
}

case $event in
  notification)
    # An older Claude Code without notification_type: go by the message.
    kind=$(jq -r 'if .notification_type then .notification_type
      elif ((.message // "") | test("permission"; "i")) then "permission_prompt" else "" end' <<<"$input" 2>/dev/null)
    case $kind in
      permission_prompt | elicitation_dialog) push waiting urgent "Claude Code needs you" ;;
    esac
    ;;
  resume)
    # Only a session that waited changes; a busy one is left alone (one
    # cheap IPC read per tool call).
    if omarchy-shell dev.deusvult.omavisor list 2>/dev/null | jq -e --arg id "$id" 'any(.[]; .id == $id and .state == "waiting")' >/dev/null 2>&1; then
      omarchy-shell dev.deusvult.omavisor update "$id" '{"state":"running","priority":"normal","title":"Claude Code working","compact":{"leading":"󰚩","trailing":""}}' >/dev/null 2>&1
    fi
    ;;
  stop) omarchy-shell dev.deusvult.omavisor end "$id success" >/dev/null 2>&1 ;;
  fail) omarchy-shell dev.deusvult.omavisor end "$id error" >/dev/null 2>&1 ;;
  end) omarchy-shell dev.deusvult.omavisor end "$id" >/dev/null 2>&1 ;;
esac
exit 0
