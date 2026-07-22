#!/usr/bin/env bash
#
# Morpheus CLI Installer
#
# Copies the morpheus binary and manifest to ~/.morpheus/
#
# Usage:
#   ./install.sh
#
# What it does:
#   1. Copies bin/morpheus       -> ~/.morpheus/bin/morpheus
#   2. Copies agent-api.json     -> ~/.morpheus/agent-api.json
#   3. Adds ~/.morpheus/bin to PATH in your shell profile
#   4. Deploys the compliance-agent skill to ~/.cursor/skills/cyber-sierra
#      and ~/.claude/skills/cyber-sierra
#   5. Configures default backend URL (http://localhost:8080)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MORPHEUS_HOME="$HOME/.morpheus"

# --- 1. Install binary ---

BINARY_SRC="$SCRIPT_DIR/bin/morpheus"
if [[ ! -f "$BINARY_SRC" ]]; then
  echo "Error: bin/morpheus not found in $SCRIPT_DIR"
  echo "Run 'npm run plugin:bundle' in morpheus/ first."
  exit 1
fi

mkdir -p "$MORPHEUS_HOME/bin"
cp "$BINARY_SRC" "$MORPHEUS_HOME/bin/morpheus"
chmod +x "$MORPHEUS_HOME/bin/morpheus"
echo "Installed morpheus binary -> $MORPHEUS_HOME/bin/morpheus"

# --- 2. Install manifest ---

MANIFEST_SRC="$SCRIPT_DIR/agent-api.json"
if [[ -f "$MANIFEST_SRC" ]]; then
  cp "$MANIFEST_SRC" "$MORPHEUS_HOME/agent-api.json"
  echo "Installed manifest        -> $MORPHEUS_HOME/agent-api.json"
else
  echo "Warning: agent-api.json not found — manifest not installed."
  echo "The CLI will still work but 'morpheus manifest' will fail."
fi

# --- 3. Add to PATH ---

PATH_LINE='export PATH="$HOME/.morpheus/bin:$PATH"'

if [[ -f "$HOME/.zshrc" ]]; then
  SHELL_RC="$HOME/.zshrc"
elif [[ -f "$HOME/.bashrc" ]]; then
  SHELL_RC="$HOME/.bashrc"
elif [[ -f "$HOME/.bash_profile" ]]; then
  SHELL_RC="$HOME/.bash_profile"
else
  SHELL_RC="$HOME/.zshrc"
fi

if ! grep -qF '.morpheus/bin' "$SHELL_RC" 2>/dev/null; then
  echo "" >> "$SHELL_RC"
  echo "$PATH_LINE" >> "$SHELL_RC"
  echo "Added PATH to $SHELL_RC"
else
  echo "PATH already configured in $SHELL_RC"
fi

export PATH="$HOME/.morpheus/bin:$PATH"

# --- 4. Deploy skill (global, both editors) ---
#
# _generated/index.json is a mutable, per-installation file the agent
# appends learned skills to over time — it is preserved across reinstalls
# rather than overwritten with the template.

SKILL_SRC="$SCRIPT_DIR/.cursor/skills/cyber-sierra"

if [[ -d "$SKILL_SRC" ]]; then
  for DEST in "$HOME/.cursor/skills/cyber-sierra" "$HOME/.claude/skills/cyber-sierra"; do
    INDEX_FILE="$DEST/_generated/index.json"
    INDEX_BACKUP="$DEST/_generated/.index.json.preserve.$$"
    PRESERVE=0

    if [[ -f "$INDEX_FILE" ]]; then
      cp "$INDEX_FILE" "$INDEX_BACKUP"
      PRESERVE=1
    fi

    mkdir -p "$DEST"
    cp -R "$SKILL_SRC/." "$DEST/"

    if [[ "$PRESERVE" -eq 1 ]]; then
      mv "$INDEX_BACKUP" "$INDEX_FILE"
    fi

    echo "Installed skill           -> $DEST"
  done
else
  echo "Warning: skill directory not found at $SKILL_SRC — skipping skill install."
fi

# --- 5. Configure default URL ---
#
# There is no `morpheus config` CLI command — the CLI's own config.ts reads
# ~/.morpheus/config.json directly (a map of profile name -> {baseUrl, orgId,
# token, expiresAt, email}), normally written by `auth login`/`auth
# set-token`. We write that file directly here, in plain bash (no Node
# dependency — morpheus itself may be a Node-free SEA binary), so a default
# backend URL is in place before the user ever authenticates.
#
# If config.json already exists (e.g. the user already ran `auth login`
# before a reinstall), it's left completely untouched rather than risking
# clobbering a stored token — same "preserve existing state" idempotency as
# the skill install above.

CONFIG_FILE="$MORPHEUS_HOME/config.json"
DEFAULT_URL="http://localhost:8080"

chmod 700 "$MORPHEUS_HOME"

if [[ -f "$CONFIG_FILE" ]]; then
  echo "Config already present    -> $CONFIG_FILE (left untouched)"
else
  cat > "$CONFIG_FILE" <<EOF
{
  "default": {
    "baseUrl": "$DEFAULT_URL"
  }
}
EOF
  chmod 600 "$CONFIG_FILE"
  echo "Configured default URL    -> $DEFAULT_URL"
fi

# --- 6. Done ---

echo ""
echo "Done. To apply PATH in existing terminals, run:"
echo ""
echo "  source $SHELL_RC"
echo ""
echo "To change the backend URL or authenticate later:"
echo ""
echo "  morpheus auth login --url <your-url> --org <org-id>"
echo ""
