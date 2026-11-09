#!/usr/bin/env bash
# qmllint every QML file in the plugin.
#
# On Omarchy the shell's own qs.Commons/qs.Ui modules are linked into a
# throwaway import dir so their types resolve. Without Omarchy (CI), imports
# that cannot resolve are not reported; everything else still is.
#
# missing-property is reported as info only: Omarchy's Style and Color
# singletons group tokens in untyped QtObjects (Style.font.body,
# Color.popups.text), which qmllint cannot see into. The stock clock widget
# gets the same reports. Any other warning fails the run.
set -euo pipefail

cd "$(dirname "$0")/.."
QMLLINT=${QMLLINT:-$(command -v qmllint || command -v qmllint6 || echo /usr/lib/qt6/bin/qmllint)}
OMARCHY_SHELL="${OMARCHY_PATH:-/usr/share/omarchy}/shell"

args=(--max-warnings 0 --missing-property info)
if [[ -f $OMARCHY_SHELL/Commons/qmldir && -f $OMARCHY_SHELL/Ui/qmldir ]]; then
  imports=$(mktemp -d)
  trap 'rm -rf "$imports"' EXIT
  mkdir -p "$imports/qs"
  ln -s "$OMARCHY_SHELL/Commons" "$imports/qs/Commons"
  ln -s "$OMARCHY_SHELL/Ui" "$imports/qs/Ui"
  args+=(-I "$imports")
else
  args+=(--import disable --unresolved-type disable --unqualified disable --required disable --incompatible-type disable)
fi

# Suggested keybinds must stay free (only where Omarchy's defaults exist).
if [[ -d ${OMARCHY_PATH:-/usr/share/omarchy}/default/hypr/bindings ]]; then
  test/keybinds-free.sh
fi

mapfile -t files < <(find . -name '*.qml' -not -path './.git/*' | sort)
"$QMLLINT" "${args[@]}" -I . "${files[@]}"
