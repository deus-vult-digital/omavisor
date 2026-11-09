#!/bin/bash
# Omavisor recipe: "Omarchy updated" in the notch after `omarchy update`.
#
# Not installed by Omavisor. Install it as an Omarchy hook:
#   omarchy hook install post-update /path/to/omavisor/recipes/omarchy-hook-post-update.sh
#
# The hook runs during the update, which may restart the shell afterwards,
# so it writes Omavisor's spool directory instead of calling IPC: Omavisor picks
# the file up when it is running (or once it starts again), and it lapses
# after an hour. Without Omavisor the file is harmless and nothing else happens.

spool="${XDG_STATE_HOME:-$HOME/.local/state}/omavisor/activities"
mkdir -p "$spool" || exit 0

version=$(omarchy version 2>/dev/null) || version=""
tmp=$(mktemp "$spool/.omarchy-update.XXXXXX") || exit 0
if command -v jq >/dev/null 2>&1; then
  jq -nc --arg version "$version" '{
    source: "omarchy",
    title: "Omarchy updated",
    subtitle: (if $version == "" then "Update finished" else "Now on \($version)" end),
    glyph: "󰚰",
    state: "success",
    ttl: 3600
  }' >"$tmp"
else
  printf '{"source":"omarchy","title":"Omarchy updated","subtitle":"Update finished","state":"success","ttl":3600}\n' >"$tmp"
fi
# Renamed into place so Omavisor never reads half a file; the name is the id.
mv -f "$tmp" "$spool/omarchy-update.json"
exit 0
