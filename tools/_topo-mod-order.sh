#!/usr/bin/env bash
# Topological load order: module dependencies before dependents.
set -euo pipefail
MODDEP="$1"
shift
mods=("$@")
declare -A deps=()
for m in "${mods[@]}"; do
	line=$(grep -F "$m:" "$MODDEP" 2>/dev/null | head -1 || true)
	d="${line#*:}"
	d="${d# }"
	deps[$m]="$d"
done
sorted=()
declare -A done=()
visit() {
	local m="$1"
	[[ -n "${done[$m]:-}" ]] && return
	done[$m]=1
	for d in ${deps[$m]:-}; do
		[[ " ${mods[*]} " == *" $d "* ]] && visit "$d"
	done
	sorted+=("$m")
}
for m in "${mods[@]}"; do visit "$m"; done
printf '%s\n' "${sorted[@]}"
