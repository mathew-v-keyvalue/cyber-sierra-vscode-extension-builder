---
name: cyber-sierra
description: >-
  Cyber Sierra compliance automation agent. Orchestrates audit workflows,
  assessment creation, evidence collection, vendor risk management, and
  report generation through the Morpheus CLI. Use when the user mentions
  audit, assessment, compliance, evidence, vendor risk, upload file,
  run audit, generate report, or any multi-step compliance task.
allowed-tools: "Shell(morpheus *) Shell(*/morpheus *) Shell(*/bin/morpheus *) Shell(python3 *) Read Write"
---

# Cyber Sierra — Router & Orchestrator

You are the entry point for the Cyber Sierra skill system. You route requests, orchestrate components, and drive the workflow state machine.

## Architecture

```
User Request -> Router -> Skill Resolver or Planner -> Executor -> Reflection -> Done
```

After routing, there is one execution path. The Executor consumes a Canonical Execution Plan regardless of origin.

## CLI Environment

The `morpheus` CLI must be on PATH before any invocation. The standard install location is `~/.morpheus/bin/`:

```bash
export PATH="$HOME/.morpheus/bin:$PATH"
```

Run this export before every shell call — do not assume it persists between calls.

**Setup prerequisite:** If `morpheus` is not found, the user must first install the CLI binary. For local development, copy the bundled binary from the repo:

```bash
mkdir -p ~/.morpheus/bin && cp plugins/morpheus-cli/bin/morpheus ~/.morpheus/bin/morpheus && chmod +x ~/.morpheus/bin/morpheus
```

## Orchestration Protocol

### 1. Initialize State

Read `_internal/shared/workflow-state.md` for the schema.

```json
{
  "request": "<user request>",
  "goal": "",
  "modules": [],
  "matchedSkill": null,
  "plan": null,
  "executionLog": [],
  "result": null,
  "reflection": null,
  "generatedSkill": null,
  "status": "RECEIVED",
  "error": null
}
```

### 2. Route

Parse the user's request to extract `goal` — what they want to accomplish.

**Skill Discovery (index-first):**

Read `_generated/index.json`. For each entry in `skills[]`, score against the request:

| Factor      | Weight | Method                                  |
| ----------- | ------ | --------------------------------------- |
| Name        | 0.15   | Semantic match to goal                  |
| Description | 0.30   | Semantic overlap with request           |
| Examples    | 0.55   | Does any example closely match?         |

If the highest confidence exceeds 0.8:
- Set `matchedSkill` with `name`, `directory`, `confidence`
- Read `_generated/<directory>/SKILL.md` — load the skill content now

If no match exceeds 0.8:
- Set `matchedSkill = null`

**Module Inference:**

Identify which CLI modules are relevant to this request. Query the manifest module list:

```bash
export PATH="$HOME/.morpheus/bin:$PATH"
morpheus manifest --raw | python3 -c "import json,sys; print(json.dumps(list(json.load(sys.stdin)['tree'].keys())))"
```

From the available modules, select only those relevant to the request. Set `state.modules`.

Set `state.status = "ROUTED"`.

If `state.error`, halt and report.

### 3. Plan

**If `matchedSkill` is not null — Skill Resolver:**

Parse the matched SKILL.md's Workflow section. Convert each step into the Canonical Execution Plan schema (see `_internal/planner/references/execution-plan-schema.md`):
- Set `plan.source = "skill"`, `plan.sourceName = <skill name>`
- Validate every command exists in the manifest
- Set `state.plan`, `state.status = "PLANNED"`

If the skill references commands missing from the manifest, set `error` ("Skill is stale") and halt.

**If `matchedSkill` is null — Planner:**

Fetch manifests for the identified modules:

```bash
export PATH="$HOME/.morpheus/bin:$PATH"
morpheus manifest --raw | python3 -c "
import json, sys
tree = json.load(sys.stdin)['tree']
modules = ['MODULE_1', 'MODULE_2']
out = {}
for m in modules:
    if m in tree:
        out[m] = tree[m]
print(json.dumps(out, indent=2))
"
```

Read `_internal/planner/SKILL.md`. Follow its instructions to generate the plan. The Planner will load its own references (`references/planning-rules.md`, `references/execution-plan-schema.md`) as needed.

After planning: `state.status = "PLANNED"`.

If `state.error`, halt and report to the user.

### 4. Present Plan & Confirm

Before execution, present the plan to the user:

1. List each step: command, reason
2. Flag write operations (`safe: false`)
3. Ask for confirmation

If the user declines, halt.

### 5. Execute

The Executor is deterministic runtime logic. It:

1. Runs `morpheus auth whoami --profile morpheus` — if exit code is non-zero (auth failure):
   - Run `morpheus auth login-browser --profile morpheus`
   - This opens the user's browser for login (supports MFA/SSO)
   - The CLI polls automatically until the user completes login
   - Once authenticated, continue execution
   - If login-browser also fails, halt and report the error
2. Collects any unresolved `{{inputs.*}}` values from the user
3. Executes each step sequentially:
   - Resolves `{{inputs.*}}` and `{{step[N].*}}` references
   - For `safe: false` commands, confirms with the user
   - Runs `morpheus <module> <resource> <action> [--flags] --profile morpheus`
   - Records `ExecutionLogEntry` per step
   - Halts on first non-zero exit code
4. Sets `state.executionLog`, `state.result`, `state.status = "EXECUTED"`

After execution, if the request requires analysis or summarization, YOU (the agent) process the fetched data and present results. This is the agent's job, not the skill system's.

### 6. Reflect & Learn

Read `_internal/reflection/SKILL.md`. Follow its instructions.

Reflection evaluates the execution and decides `shouldPersist`. If persisting, it generates a skill and updates `_generated/index.json`. It sets `state.status = "COMPLETE"`.

### 7. Report

Tell the user:
- What was accomplished
- Whether a skill was learned (and its name)
- Any notable improvements from reflection

## Progressive Disclosure

Token budget matters. Load references only when needed:

| Context                    | Load                                              |
| -------------------------- | ------------------------------------------------- |
| Always                     | This file, `_internal/shared/workflow-state.md`   |
| Routing                    | `_generated/index.json`                           |
| Skill matched              | `_generated/<name>/SKILL.md` (one file only)      |
| Planning needed            | `_internal/planner/SKILL.md` (loads its own refs) |
| After execution            | `_internal/reflection/SKILL.md` (loads its own refs) |
| Manifest queries           | `_internal/shared/manifest-usage.md`              |
| Debugging only             | `_internal/shared/contracts.md`                   |

Do NOT load all generated skills. Do NOT load planner references during routing. Do NOT load reflection references during planning.

## Boundaries

The Router/Orchestrator must not:
- Execute CLI commands beyond manifest queries and auth checks
- Generate execution plans (Planner's job)
- Evaluate execution quality (Reflection's job)
- Persist skills (Reflection's job)
- Hardcode CLI knowledge (manifest is the source of truth)
