# Morpheus CLI — Setup Guide

## 0. Installing via VS Code / Cursor extension (recommended)

Install the bundled `.vsix` (see `vscode-extension/`) into VS Code or Cursor. It runs this exact `install.sh` for you automatically the first time it activates, and again any time you run **Morpheus: Initialize** from the Command Palette. Skip to step 4 below to see what it deploys — everything past this point happens for you.

## 1. Install

```bash
./install.sh
```

Copies the CLI binary and command manifest to `~/.morpheus/`.

## 2. Add to PATH

Append to `~/.zshrc` (or `~/.bashrc`):

```bash
export PATH="$HOME/.morpheus/bin:$PATH"
```

Reload your shell:

```bash
source ~/.zshrc
```

## 3. Configure

Set the backend URL (persisted to `~/.morpheus/config.json`):

```bash
morpheus config set --url http://localhost:8080
```

Verify:

```bash
morpheus config show
```

## 4. Skill installation

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
