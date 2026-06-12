#!/usr/bin/env bash
MODDEP="$1"
shift
resolve() {
	local q=("$1") seen=() out=()
	while ((${#q[@]})); do
		local m="${q[0]}"
		q=("${q[@]:1}")
		local s=" ${seen[*]} "
		[[ "$s" == *" $m "* ]] && continue
		seen+=("$m")
		out+=("$m")
		local deps
		deps=$(grep -F "$m:" "$MODDEP" 2>/dev/null | head -1 | cut -d: -f2-)
		for d in $deps; do q+=("$d"); done
	done
	printf '%s\n' "${out[@]}"
}
for root in "$@"; do
	resolve "$root"
done | sort -u
