#!/usr/bin/env bash
# release.sh — Export the Windows build and push it to BOTH itch.io channels:
#   - windows : full install (Dungeoneers.exe + Dungeoneers.pck)  -> "first download"
#   - patch   : standalone Dungeoneers.pck                        -> "just update"
#
# Usage:
#   ./release.sh <version>          e.g.  ./release.sh 4
#   DRY_RUN=1 ./release.sh <ver>    export & stage only, skip the butler pushes
#
# Machine-specific paths are overridable via env vars (handy on other machines):
#   GODOT BUTLER GAME PRESET

set -euo pipefail

VERSION="${1:?Usage: $0 <version>}"

GODOT="${GODOT:-C:/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe}"
BUTLER="${BUTLER:-C:/Users/barte/butler-windows-amd64/butler.exe}"
GAME="${GAME:-thezemor/dungeoneers}"
PRESET="${PRESET:-Windows Desktop}"

BUILDS="builds"
EXE="$BUILDS/Dungeoneers.exe"
PCK="$BUILDS/Dungeoneers.pck"
DIST="dist"
DIST_PATCH="dist-patch"

# 1) Refuse to export while the game is running (the exe file-lock would fail).
if tasklist 2>/dev/null | grep -qi dungeoneer; then
  echo "ERROR: Dungeoneers.exe appears to be running. Close it before exporting." >&2
  exit 1
fi

# 2) Export (embed_pck=false -> produces a separate exe + pck).
echo "== Exporting ($PRESET) =="
"$GODOT" --headless --export-release "$PRESET" "$EXE"

# 3) Stage the two distributions.
rm -rf "$DIST" "$DIST_PATCH"
mkdir -p "$DIST" "$DIST_PATCH"
cp "$EXE" "$PCK" "$DIST/"
cp "$PCK" "$DIST_PATCH/Dungeoneers.pck"

echo "== Staged full install (windows) =="
ls -la "$DIST"
echo "== Staged patch pck (patch) =="
ls -la "$DIST_PATCH"

# 4) Push both channels (skip entirely in dry-run mode).
if [[ "${DRY_RUN:-0}" == "1" ]]; then
  echo "== DRY_RUN: skipping butler pushes =="
  exit 0
fi

echo "== Pushing windows (full install) v$VERSION =="
"$BUTLER" push "$DIST" "$GAME:windows" --userversion "$VERSION"
echo "== Pushing patch (pck update) v$VERSION =="
"$BUTLER" push "$DIST_PATCH" "$GAME:patch" --userversion "$VERSION"

echo "== Done: v$VERSION pushed to windows + patch =="
"$BUTLER" status "$GAME"
