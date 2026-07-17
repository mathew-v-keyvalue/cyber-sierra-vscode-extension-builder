#!/usr/bin/env bash
#
# Copies the canonical bundle (bin/morpheus, agent-api.json, install.sh,
# .cursor/skills/cyber-sierra) from the repo root into resources/, so the
# extension packages a fresh copy on every build rather than hand-duplicating
# these files inside vscode-extension/.

set -euo pipefail

EXT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$EXT_DIR/.." && pwd)"
DEST="$EXT_DIR/resources"

rm -rf "$DEST"
mkdir -p "$DEST/bin"

cp "$ROOT/bin/morpheus" "$DEST/bin/morpheus"
chmod +x "$DEST/bin/morpheus"

cp "$ROOT/agent-api.json" "$DEST/agent-api.json"

cp "$ROOT/install.sh" "$DEST/install.sh"
chmod +x "$DEST/install.sh"

mkdir -p "$DEST/.cursor/skills"
cp -R "$ROOT/.cursor/skills/cyber-sierra" "$DEST/.cursor/skills/cyber-sierra"

find "$DEST" -name ".DS_Store" -delete

echo "Synced resources -> $DEST"
