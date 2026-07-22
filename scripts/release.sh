#!/usr/bin/env bash
#
# Packages whatever platform binaries are present in release-input/ into
# per-platform release tarballs in dist/, plus a combined SHA256SUMS.
#
# Reuses install.sh, agent-api.json, and .cursor/skills/cyber-sierra
# unmodified from repo root — same "root is source of truth, sync into a
# package's own resources before build" pattern already used by
# vscode-extension/scripts/sync-resources.sh.
#
# Usage: scripts/release.sh [<version>]
#   <version> defaults to the contents of VERSION if not passed (CI passes
#   the tag name with its leading "v" stripped).

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INPUT_DIR="$ROOT/release-input"
DIST_DIR="$ROOT/dist"
STAGE_DIR="$DIST_DIR/stage"

COMMITTED_VERSION="$(tr -d ' \t\n\r' < "$ROOT/VERSION")"
VERSION="${1:-$COMMITTED_VERSION}"
VERSION="${VERSION#v}"

if [[ "$COMMITTED_VERSION" != "$VERSION" ]]; then
  echo "Error: VERSION file ($COMMITTED_VERSION) does not match release version ($VERSION)." >&2
  echo "Bump VERSION to $VERSION and commit it on the commit you tag v$VERSION." >&2
  exit 1
fi

PLATFORMS=(linux-x64 linux-arm64 darwin-arm64 darwin-x64)
BUILT=()
SKIPPED=()

checksum_cmd() {
  if command -v sha256sum >/dev/null 2>&1; then
    echo "sha256sum"
  elif command -v shasum >/dev/null 2>&1; then
    echo "shasum -a 256"
  else
    echo "Error: neither sha256sum nor shasum found." >&2
    exit 1
  fi
}

rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

for PLATFORM in "${PLATFORMS[@]}"; do
  SRC_BIN="$INPUT_DIR/morpheus-${PLATFORM}"

  if [[ ! -f "$SRC_BIN" ]]; then
    echo "SKIP  ${PLATFORM}  (no binary at release-input/morpheus-${PLATFORM})"
    SKIPPED+=("$PLATFORM")
    continue
  fi

  BUNDLE="morpheus-${PLATFORM}"
  BUNDLE_DIR="$STAGE_DIR/$BUNDLE"
  mkdir -p "$BUNDLE_DIR/bin" "$BUNDLE_DIR/.cursor/skills"

  cp "$SRC_BIN" "$BUNDLE_DIR/bin/morpheus"
  chmod +x "$BUNDLE_DIR/bin/morpheus"

  cp "$ROOT/agent-api.json" "$BUNDLE_DIR/agent-api.json"
  cp "$ROOT/install.sh" "$BUNDLE_DIR/install.sh"
  chmod +x "$BUNDLE_DIR/install.sh"
  cp -R "$ROOT/.cursor/skills/cyber-sierra" "$BUNDLE_DIR/.cursor/skills/cyber-sierra"
  printf '%s' "$VERSION" > "$BUNDLE_DIR/VERSION"

  find "$BUNDLE_DIR" -name ".DS_Store" -delete

  TARBALL="$DIST_DIR/${BUNDLE}.tar.gz"
  tar -czf "$TARBALL" -C "$STAGE_DIR" "$BUNDLE"

  echo "BUILT ${PLATFORM}  -> $TARBALL"
  BUILT+=("$PLATFORM")
done

rm -rf "$STAGE_DIR"

if [[ ${#BUILT[@]} -eq 0 ]]; then
  echo "Error: no platform binaries found in release-input/ — nothing to release." >&2
  exit 1
fi

CKSUM_CMD="$(checksum_cmd)"
( cd "$DIST_DIR" && $CKSUM_CMD morpheus-*.tar.gz > SHA256SUMS )

echo ""
echo "Release $VERSION packaged."
echo "  built:   ${BUILT[*]}"
echo "  skipped: ${SKIPPED[*]:-none}"
echo ""
ls -la "$DIST_DIR"
