#!/usr/bin/env bash
#
# Public curl entrypoint for the Morpheus CLI.
#
# Fetched fresh from `main` on every invocation, so it carries no version of
# its own — its only job is to resolve which release to install, download
# it, verify it, and delegate to the one true install.sh bundled inside.
#
#   Install (latest):
#     curl -fsSL https://raw.githubusercontent.com/mathew-v-keyvalue/cyber-sierra-vscode-extension-builder/main/bootstrap.sh | bash
#
#   Install / roll back to a specific version:
#     MORPHEUS_VERSION=1.1.0 curl -fsSL .../bootstrap.sh | bash
#
#   Uninstall:
#     curl -fsSL .../bootstrap.sh | bash -s -- --uninstall
#     curl -fsSL .../bootstrap.sh | bash -s -- --uninstall --yes   # skip confirmation

set -euo pipefail

REPO="mathew-v-keyvalue/cyber-sierra-vscode-extension-builder"

# Must match install.sh's PATH_LINE and vscode-extension/src/extension.ts's
# SHELL_PATH_LINE exactly — this is the literal line install.sh appends to
# a shell rc file, and how uninstall finds and removes it again.
SHELL_PATH_LINE='export PATH="$HOME/.morpheus/bin:$PATH"'
SHELL_RC_CANDIDATES=(.zshrc .bashrc .bash_profile)

err() {
  echo "Error: $*" >&2
  exit 1
}

detect_platform() {
  local os_raw arch_raw
  os_raw="$(uname -s)"
  arch_raw="$(uname -m)"

  case "$os_raw" in
    Linux) OS=linux ;;
    Darwin) OS=darwin ;;
    *) err "Unsupported OS '$os_raw'. Only Linux and macOS are supported (Windows is out of scope; try WSL)." ;;
  esac

  case "$arch_raw" in
    x86_64|amd64) ARCH=x64 ;;
    arm64|aarch64) ARCH=arm64 ;;
    *) err "Unsupported architecture '$arch_raw'." ;;
  esac
}

# Strips the exact PATH line install.sh appended, plus the blank line it
# inserted immediately before it — same algorithm as extension.ts's
# removeShellPathEntries, so both uninstall paths agree byte-for-byte.
strip_path_line() {
  local rc_path="$1"
  awk -v target="$SHELL_PATH_LINE" '
    {
      if ($0 == target) {
        if (n > 0 && kept[n] == "") { n-- }
        next
      }
      n++
      kept[n] = $0
    }
    END { for (i = 1; i <= n; i++) print kept[i] }
  ' "$rc_path" > "${rc_path}.morpheus-tmp" && mv "${rc_path}.morpheus-tmp" "$rc_path"
}

checksum_verify() {
  # $1 = dir containing the downloaded asset + SHA256SUMS, $2 = asset filename
  local dir="$1" asset="$2" line

  line="$(awk -v f="$asset" '$2 == f { print; found=1 } END { exit !found }' "$dir/SHA256SUMS")" \
    || err "No checksum entry for ${asset} in SHA256SUMS — refusing to install an unverified download."

  echo "$line" > "$dir/${asset}.sha256"

  if command -v sha256sum >/dev/null 2>&1; then
    ( cd "$dir" && sha256sum -c "${asset}.sha256" ) || err "Checksum verification failed for ${asset}. The download may be corrupt or tampered with."
  elif command -v shasum >/dev/null 2>&1; then
    ( cd "$dir" && shasum -a 256 -c "${asset}.sha256" ) || err "Checksum verification failed for ${asset}. The download may be corrupt or tampered with."
  else
    err "No sha256sum or shasum found on this machine — cannot verify download integrity. Install one and retry."
  fi
}

do_install() {
  detect_platform
  local asset="morpheus-${OS}-${ARCH}.tar.gz"
  local base_url

  if [[ -n "${MORPHEUS_VERSION:-}" ]]; then
    local v="${MORPHEUS_VERSION#v}"
    base_url="https://github.com/${REPO}/releases/download/v${v}"
  else
    base_url="https://github.com/${REPO}/releases/latest/download"
  fi

  local tmp
  tmp="$(mktemp -d "${TMPDIR:-/tmp}/morpheus-install.XXXXXX")"
  trap 'rm -rf "$tmp"' EXIT

  echo "Downloading ${asset}..."
  if ! curl -fsSL "${base_url}/${asset}" -o "${tmp}/${asset}"; then
    err "No release asset found for ${OS}-${ARCH} (looked for ${asset}).
This platform may not have a published build yet.
Check available assets: https://github.com/${REPO}/releases
If you believe this platform should be supported, contact the Cyber Sierra team."
  fi

  echo "Downloading checksums..."
  curl -fsSL "${base_url}/SHA256SUMS" -o "${tmp}/SHA256SUMS" \
    || err "Could not download SHA256SUMS for verification — refusing to run an unverified installer."

  checksum_verify "$tmp" "$asset"

  echo "Extracting..."
  tar -xzf "${tmp}/${asset}" -C "$tmp"

  local bundle_dir="${tmp}/morpheus-${OS}-${ARCH}"
  [[ -f "${bundle_dir}/install.sh" ]] || err "Downloaded bundle is missing install.sh — corrupt release asset."

  bash "${bundle_dir}/install.sh"

  local version
  version="$(cat "${bundle_dir}/VERSION" 2>/dev/null || echo "unknown")"
  mkdir -p "$HOME/.morpheus"
  cat > "$HOME/.morpheus/version.json" <<EOF
{"version": "${version}", "installedAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)", "platform": "${OS}-${ARCH}"}
EOF
  echo "Recorded version ${version} -> ~/.morpheus/version.json"
}

do_uninstall() {
  local skip_confirm=0
  for arg in "$@"; do
    [[ "$arg" == "--yes" || "$arg" == "-y" ]] && skip_confirm=1
  done

  if [[ "$skip_confirm" -ne 1 ]]; then
    local reply
    if [[ -t 0 ]]; then
      read -r -p "This removes ~/.morpheus, ~/.cursor/skills/cyber-sierra, ~/.claude/skills/cyber-sierra, and the PATH entry. Continue? [y/N] " reply
    elif [[ -r /dev/tty ]]; then
      read -r -p "This removes ~/.morpheus, ~/.cursor/skills/cyber-sierra, ~/.claude/skills/cyber-sierra, and the PATH entry. Continue? [y/N] " reply < /dev/tty
    else
      err "Cannot prompt for confirmation (no TTY available, e.g. running in a non-interactive pipe). Re-run with --uninstall --yes to skip confirmation."
    fi
    [[ "$reply" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }
  fi

  local removed_any=0

  for dir in "$HOME/.morpheus" "$HOME/.cursor/skills/cyber-sierra" "$HOME/.claude/skills/cyber-sierra"; do
    if [[ -e "$dir" ]]; then
      rm -rf "$dir"
      echo "Removed $dir"
      removed_any=1
    fi
  done

  for rc in "${SHELL_RC_CANDIDATES[@]}"; do
    local rc_path="$HOME/$rc"
    [[ -f "$rc_path" ]] || continue
    grep -qF "$SHELL_PATH_LINE" "$rc_path" || continue
    strip_path_line "$rc_path"
    echo "Removed PATH entry from $rc_path"
    removed_any=1
  done

  if [[ "$removed_any" -eq 0 ]]; then
    echo "Nothing to uninstall — no installed files were found."
  else
    echo "Uninstalled. Restart open terminals for the PATH change to take effect."
  fi
}

case "${1:-}" in
  --uninstall)
    shift
    do_uninstall "$@"
    ;;
  "")
    do_install
    ;;
  *)
    err "Unknown argument: $1"
    ;;
esac
