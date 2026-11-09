#!/usr/bin/env bash
# The keybinds README's Keybindings section and SPEC section 10 suggest must
# not be taken by Omarchy's defaults (read only). Modifiers count in any order,
# keys in any case. SPEC.md is left out of the public mirror; then README only.
set -euo pipefail

cd "$(dirname "$0")/.."
BINDINGS=${BINDINGS:-${OMARCHY_PATH:-/usr/share/omarchy}/default/hypr/bindings}

[[ -d $BINDINGS ]] || { echo "keybinds-free: $BINDINGS not found, skipped"; exit 0; }

# combos <file…>: every combo given to o.bind, o.bind_toggle or hl.bind, one
# normalized per line (a call may span lines).
combos() {
  cat "$@" | tr '\n' ' ' | grep -oE '\bbind[a-z_]*\( *"[^"]+"' | sed -E 's/^bind[a-z_]*\( *"//; s/"$//' | while IFS= read -r combo; do
    tr '[:lower:]' '[:upper:]' <<<"$combo" | sed -E 's/ *\+ */\n/g' | {
      mapfile -t parts
      key=${parts[-1]}
      unset 'parts[-1]'
      printf '%s\n' "$(printf '%s\n' "${parts[@]}" | sort | tr '\n' ' ')+ $key"
    }
  done
}

# section <file> <heading regex>: from that heading up to the next one like it.
section() {
  awk -v start="$2" 'found && /^##? [^#]/ { exit } $0 ~ start { found = 1 } found' "$1"
}

suggested=$(mktemp)
taken=$(mktemp)
trap 'rm -f "$suggested" "$taken"' EXIT
{
  section README.md '^## Keybindings' | combos /dev/stdin
  if [[ -f SPEC.md ]]; then section SPEC.md '^## 10[.] ' | combos /dev/stdin; fi
} | sort -u >"$suggested"
combos "$BINDINGS"/*.lua | sort -u >"$taken"

[[ -s $suggested ]] || { echo "keybinds-free: no suggested combos found in README or SPEC"; exit 1; }
[[ -s $taken ]] || { echo "keybinds-free: no bindings parsed from $BINDINGS"; exit 1; }

clashes=$(comm -12 "$suggested" "$taken")
if [[ -n $clashes ]]; then
  echo "keybinds-free: suggested combos Omarchy already binds:"
  while IFS= read -r clash; do echo "  $clash"; done <<<"$clashes"
  exit 1
fi
echo "keybinds-free: $(wc -l <"$suggested") suggested combos free among $(wc -l <"$taken") defaults"
