#!/usr/bin/env bash
# Insert A3D product branding into Armbian 10-armbian-header MOTD script.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HEADER="${1:-/etc/update-motd.d/10-armbian-header}"
SNIP="$SCRIPT_DIR/artillery-motd-branding.snippet"
MARK_START="# --- Artillery product branding ---"
MARK_END="# --- Board name and version line ---"

[[ -f "$HEADER" ]] || { echo "Missing $HEADER"; exit 1; }
[[ -f "$SNIP" ]] || { echo "Missing $SNIP"; exit 1; }

if grep -q "A3D M1 Pro X1" "$HEADER" 2>/dev/null; then
  echo "Artillery branding already present in $HEADER"
  exit 0
fi

TMP=$(mktemp)
if grep -qF "$MARK_START" "$HEADER"; then
  awk -v start="$MARK_START" -v end="$MARK_END" -v snip="$SNIP" '
    $0 == start { skip=1; print start; while ((getline line < snip) > 0) print line; close(snip); print ""; next }
    skip && $0 == end { skip=0 }
    skip { next }
    { print }
  ' "$HEADER" > "$TMP"
else
  awk -v end="$MARK_END" -v snip="$SNIP" -v start="$MARK_START" '
    index($0, end) {
      print start
      while ((getline line < snip) > 0) print line
      close(snip)
      print ""
    }
    { print }
  ' "$HEADER" > "$TMP"
fi
mv "$TMP" "$HEADER"
chmod +x "$HEADER"
echo "Updated Artillery branding in $HEADER"