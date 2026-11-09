#!/bin/bash
# Omavisor recipe: an urgent bloom when the battery runs low.
#
# Not installed by Omavisor. Install it as an Omarchy hook:
#   omarchy hook install battery-low /path/to/omavisor/recipes/omarchy-hook-battery-low.sh
#
# Omarchy runs battery-low hooks with the percentage in $1. The bloom
# respects Do Not Disturb (it peeks instead), and the activity goes away by
# itself after 10 minutes. Without Omavisor (or omarchy-shell) it does nothing.

percent=${1:-}
[[ $percent =~ ^[0-9]+$ ]] || percent=""

command -v omarchy-shell >/dev/null 2>&1 || exit 0

title="Battery low"
[[ -n $percent ]] && title="Battery at $percent%"

json=$(printf '{"id":"battery:low","source":"battery","title":"%s","subtitle":"Plug in soon","glyph":"󰂃","state":"waiting","priority":"urgent","ttl":600}' "$title")
omarchy-shell dev.deusvult.omavisor push "$json" >/dev/null 2>&1
exit 0
