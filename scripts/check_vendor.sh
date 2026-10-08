#!/usr/bin/env bash
# Vendor drift check: every file a game vendored under <game-dir>/vendor/sdk/
# must byte-match its source in sdk/. Prints "DRIFT <file>" lines and exits 1
# on any mismatch (or missing source); "OK" + exit 0 otherwise.
#
# File list: vendor/VENDOR.md bullet lines ("- `file` — ...") when present,
# else every regular file under vendor/sdk/ matched by basename against
# sdk/** (core/, items/, prefabs/, level_builder.gd).
# Usage: scripts/check_vendor.sh <game-dir>
set -euo pipefail
GAME="${1:?usage: check_vendor.sh <game-dir>}"
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SDK="$ROOT/sdk"
VDIR="$GAME/vendor/sdk"
VMD="$VDIR/VENDOR.md"
[[ -d "$VDIR" ]] || { echo "no vendored SDK at $VDIR"; exit 1; }

# Candidate sources: everything an agent may legitimately vendor.
mapfile -t SOURCES < <(find "$SDK/core" "$SDK/items" "$SDK/prefabs" -type f \
	\( -name '*.gd' -o -name '*.tscn' -o -name '*.tres' \) 2>/dev/null; \
	ls "$SDK/level_builder.gd" 2>/dev/null)

src_for() {  # basename -> sdk source path (first match), empty if none
	local base="$1" s
	for s in "${SOURCES[@]}"; do
		[[ "$(basename "$s")" == "$base" ]] && { echo "$s"; return; }
	done
	echo ""
}

# Which files are vendored? VENDOR.md's list if it names any, else dir contents.
files=()
if [[ -f "$VMD" ]]; then
	while IFS= read -r b; do files+=("$b"); done \
		< <(grep -oE '^- `[A-Za-z0-9_.-]+`' "$VMD" | sed 's/^- `//; s/`$//')
fi
if [[ ${#files[@]} -eq 0 ]]; then
	while IFS= read -r f; do files+=("$(basename "$f")"); done \
		< <(find "$VDIR" -maxdepth 1 -type f ! -name VENDOR.md | sort)
fi

drift=0
for base in "${files[@]}"; do
	# .uid sidecars are generated per-project; only compare real sources.
	[[ "$base" == *.uid ]] && continue
	src=$(src_for "$base")
	vend="$VDIR/$base"
	if [[ ! -f "$vend" ]]; then
		echo "DRIFT $base (listed in VENDOR.md but not vendored)"; drift=1; continue
	fi
	if [[ -z "$src" ]]; then
		echo "DRIFT $base (no matching source in sdk/)"; drift=1; continue
	fi
	if ! cmp -s "$vend" "$src"; then
		echo "DRIFT $base ($vend != ${src#"$ROOT"/})"; drift=1
	fi
done

if [[ $drift -ne 0 ]]; then
	echo "== vendor drift detected against sdk/VERSION $(tr -d '\n' < "$SDK/VERSION")"
	exit 1
fi
echo "OK ${#files[@]} vendored files match sdk/VERSION $(tr -d '\n' < "$SDK/VERSION")"
