# Morpheus CLI — Setup Guide

## 0. Quick install (recommended) — curl + bash

```bash
curl -fsSL https://raw.githubusercontent.com/mathew-v-keyvalue/cyber-sierra-vscode-extension-builder/main/bootstrap.sh | bash
```

No manual file handling, no VSIX trust prompt, and no system Node.js
required to run `morpheus` afterward — this installs a standalone,
SEA-compiled binary for your platform (Linux or macOS; Windows is out of
scope). It downloads the latest GitHub Release, verifies its SHA256
checksum, and runs the same `install.sh` described in the sections below,
so the result is identical to a manual or VSIX install.

**Update:** re-run the exact same command — it always installs the latest release.

**Pin / roll back to a specific version:**

```bash
MORPHEUS_VERSION=1.1.0 curl -fsSL https://raw.githubusercontent.com/mathew-v-keyvalue/cyber-sierra-vscode-extension-builder/main/bootstrap.sh | bash
```

**Uninstall:**

```bash
curl -fsSL https://raw.githubusercontent.com/mathew-v-keyvalue/cyber-sierra-vscode-extension-builder/main/bootstrap.sh | bash -s -- --uninstall
```

Removes `~/.morpheus`, both skill directories, and the PATH entry added to
your shell profile — with a confirmation prompt (pass `--uninstall --yes`
to skip it).

See [RELEASING.md](./RELEASING.md) if you're cutting a new release rather
than installing one.

## 1. VS Code / Cursor extension (alternative)

Install the bundled `.vsix` (see `vscode-extension/`) into VS Code or Cursor. It runs this exact `install.sh` for you automatically the first time it activates, and again any time you run **Morpheus: Initialize** from the Command Palette. Skip to section 2.3 below to see what it deploys — everything past this point happens for you.

Note: this path installs the Node-script build of `morpheus` (`bin/morpheus`), which still requires a system Node.js to run — unlike the curl+bash install above.

## 2. Manual local install (development / repo checkout)

```bash
./install.sh
```

Copies the CLI binary and command manifest to `~/.morpheus/`.

### 2.1 Add to PATH

Append to `~/.zshrc` (or `~/.bashrc`):

```bash
export PATH="$HOME/.morpheus/bin:$PATH"
```

Reload your shell:

```bash
source ~/.zshrc
```

### 2.2 Configure

Set the backend URL (persisted to `~/.morpheus/config.json`):

```bash
morpheus config set --url http://localhost:8080
```

Verify:

```bash
morpheus config show
```

### 2.3 Skill installation

`install.sh` also deploys the compliance-automation agent skill globally, for both editors:

- `~/.cursor/skills/cyber-sierra/`
- `~/.claude/skills/cyber-sierra/`

Re-running `install.sh` is safe: it's idempotent (no duplicate PATH lines, no re-clobbered config) and preserves any skills the agent has already learned and recorded in `_generated/index.json` — only the rest of the skill tree is refreshed on reinstall.

That's it. Authentication is handled automatically by the Cursor skill system when you start using it — no manual auth step needed.

---

## Quick reference

| Command | What it does |
|---|---|
| `morpheus config set --url <url>` | Set backend URL |
| `morpheus config set --org <id>` | Set organisation ID |
| `morpheus config show` | Show current config |
| `morpheus auth whoami` | Check auth status |
| `morpheus auth logout` | Clear stored token |
| `morpheus version` | Print CLI + manifest versions |

## Changing environments

```bash
morpheus config set --url https://api.staging.example.com
```

## File layout

```
~/.morpheus/
├── bin/morpheus        # CLI binary
├── agent-api.json      # Command manifest
└── config.json         # Configuration (0600 permissions)

~/.cursor/skills/cyber-sierra/   # Cursor skill
~/.claude/skills/cyber-sierra/   # Claude Code skill (same content)
```
