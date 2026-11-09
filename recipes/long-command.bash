# Omavisor recipe: a live activity when a long command finishes (bash).
#
# Not installed by Omavisor. To use it, source it from ~/.bashrc:
#   source /path/to/omavisor/recipes/long-command.bash
#
# A command that ran for OMAVISOR_LONG_COMMAND_SECONDS or more (default 30, like
# Omavisor's `longCommandSeconds`) shows in the notch for a minute: the command,
# how long it took and whether it failed. It needs `omarchy-shell` and `jq`;
# without them, or with Omavisor off, it does nothing. Set OMAVISOR_LONG_COMMAND_SECONDS=0
# in a shell to turn it off there.
#
# It hooks bash's DEBUG trap and PROMPT_COMMAND. If another tool (bash-preexec,
# starship's preexec) owns the DEBUG trap already, use that tool's preexec and
# precmd hooks to call __omavisor_preexec and __omavisor_precmd instead.

__omavisor_armed=
__omavisor_start=
__omavisor_command=

__omavisor_push() { # status seconds command
  command -v omarchy-shell >/dev/null 2>&1 && command -v jq >/dev/null 2>&1 || return 0
  local json
  json=$(jq -nc --arg id "cmd:$$" --arg cmd "$3" --argjson status "$1" --argjson took "$2" '{
    id: $id,
    source: "shell",
    title: $cmd,
    subtitle: ((if $took >= 3600 then "\($took / 3600 | floor) h \($took % 3600 / 60 | floor) min"
                elif $took >= 60 then "\($took / 60 | floor) min \($took % 60) s"
                else "\($took) s" end)
               + (if $status == 0 then "" else "  ·  exit \($status)" end)),
    glyph: "",
    state: (if $status == 0 then "success" else "error" end),
    ttl: 60
  }') || return 0
  (omarchy-shell dev.deusvult.omavisor push "$json" >/dev/null 2>&1 &)
}

# The first command after a prompt starts the clock.
__omavisor_preexec() {
  [[ -n $__omavisor_armed && -z ${COMP_LINE-} ]] || return 0
  __omavisor_armed=
  __omavisor_start=$SECONDS
  # The whole line from history (BASH_COMMAND is only its first command).
  local line
  line=$(HISTTIMEFORMAT='' builtin history 1 2>/dev/null)
  line=${line#"${line%%[![:space:]]*}"}
  line=${line#*[[:space:]]}
  line=${line#"${line%%[![:space:]]*}"}
  __omavisor_command=${line:-$BASH_COMMAND}
}

__omavisor_precmd() {
  local status=$?
  if [[ -n $__omavisor_start ]]; then
    local took=$((SECONDS - __omavisor_start))
    local limit=${OMAVISOR_LONG_COMMAND_SECONDS:-30}
    if ((limit > 0 && took >= limit)); then __omavisor_push "$status" "$took" "$__omavisor_command"; fi
  fi
  __omavisor_start=
  return "$status"
}

__omavisor_arm() { __omavisor_armed=1; }

trap '__omavisor_preexec' DEBUG
# precmd first (it needs the command's exit status), arm last, so the
# prompt's own commands never start the clock.
PROMPT_COMMAND="__omavisor_precmd${PROMPT_COMMAND:+; $PROMPT_COMMAND}; __omavisor_arm"
