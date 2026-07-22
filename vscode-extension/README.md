# Morpheus (Cyber Sierra)

Installs the Morpheus CLI and deploys the Cyber Sierra compliance-automation agent skill, for use from Cursor and Claude Code.

## What it does

On first activation (and any time you run **Morpheus: Initialize** from the Command Palette), this extension runs the bundled `install.sh`, which:

1. Copies the `morpheus` CLI binary to `~/.morpheus/bin/morpheus`.
2. Copies the command manifest to `~/.morpheus/agent-api.json`.
3. Adds `~/.morpheus/bin` to your shell `PATH` (`.zshrc`/`.bashrc`/`.bash_profile`, idempotently).
4. Deploys the compliance-automation skill to `~/.cursor/skills/cyber-sierra/` and `~/.claude/skills/cyber-sierra/`.
5. Sets the default backend URL to `http://localhost:8080` (change later with `morpheus config set --url <url>`).

Progress and full installer output are shown in the **Morpheus** Output channel.

## Requirements

- Linux or macOS (Windows is not supported).
- `bash` available at `/bin/bash`.

## Commands

| Command | Description |
|---|---|
| `Morpheus: Initialize` | Re-runs the installer. Safe to run repeatedly — already-installed pieces are left alone or safely refreshed, and any skills the agent has already learned (`_generated/index.json`) are preserved. |
| `Morpheus: Uninstall (remove CLI + skills)` | Prompts for confirmation, then removes `~/.morpheus`, `~/.cursor/skills/cyber-sierra`, `~/.claude/skills/cyber-sierra`, and the PATH entry from your shell profile. |

## Uninstalling

Uninstalling the extension itself (from the Extensions view) does **not** remove anything this extension installed — the CLI, skills, and PATH entry are meant to keep working standalone even without the editor integration. `deactivate()` intentionally does no filesystem cleanup, since it also fires on a plain "disable extension" and must not be destructive in that case.

To fully remove everything, run **Morpheus: Uninstall** from the Command Palette *before* uninstalling the extension.

## Development

```bash
npm install
npm run sync-resources   # refresh resources/ from the parent bundle
npm run build             # bundle src/extension.ts -> out/extension.js
```

Press **F5** to launch an Extension Development Host for manual testing. Run `npm run package` to produce an installable `.vsix`.

This package has no `repository` field yet, so packaging passes `--allow-missing-repository` explicitly.
