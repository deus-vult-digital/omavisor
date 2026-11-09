# Omavisor recipe: a live activity when a long command finishes (zsh).
#
# Not installed by Omavisor. To use it, source it from ~/.zshrc:
#   source /path/to/omavisor/recipes/long-command.zsh
#
# A command that ran for OMAVISOR_LONG_COMMAND_SECONDS or more (default 30, like
# Omavisor's `longCommandSeconds`) shows in the notch for a minute: the command,
# how long it took and whether it failed. It needs `omarchy-shell` and `jq`;
# without them, or with Omavisor off, it does nothing. Set OMAVISOR_LONG_COMMAND_SECONDS=0
# in a shell to turn it off there.

autoload -Uz add-zsh-hook

typeset -g __omavisor_start= __omavisor_command=

__omavisor_push() { # status seconds command
  (( $+commands[omarchy-shell] && $+commands[jq] )) || return 0
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

__omavisor_preexec() {
  __omavisor_start=$SECONDS
  __omavisor_command=$1
}

__omavisor_precmd() {
  local exit_status=$?
  if [[ -n $__omavisor_start ]]; then
    local took=$(( SECONDS - __omavisor_start ))
    local limit=${OMAVISOR_LONG_COMMAND_SECONDS:-30}
    (( limit > 0 && took >= limit )) && __omavisor_push $exit_status $took "$__omavisor_command"
  fi
  __omavisor_start=
}

add-zsh-hook preexec __omavisor_preexec
add-zsh-hook precmd __omavisor_precmd
