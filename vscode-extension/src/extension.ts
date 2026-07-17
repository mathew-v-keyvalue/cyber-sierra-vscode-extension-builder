import * as vscode from 'vscode';
import * as cp from 'child_process';
import * as fs from 'fs';
import * as os from 'os';
import * as path from 'path';

const INIT_VERSION_KEY = 'morpheus.initializedVersion';

// Whether the CLI binary and both skill destinations are actually present on
// disk. A stale "already initialized" flag must never be trusted on its own —
// if any of these are missing (e.g. the user deleted ~/.morpheus, or a skill
// folder), activation self-heals by re-running the installer regardless of
// what was recorded previously.
function isFullyInstalled(): boolean {
  const home = os.homedir();
  return (
    fs.existsSync(path.join(home, '.morpheus', 'bin', 'morpheus')) &&
    fs.existsSync(path.join(home, '.cursor', 'skills', 'cyber-sierra', 'SKILL.md')) &&
    fs.existsSync(path.join(home, '.claude', 'skills', 'cyber-sierra', 'SKILL.md'))
  );
}

export function activate(context: vscode.ExtensionContext): void {
  const output = vscode.window.createOutputChannel('Morpheus');
  context.subscriptions.push(output);

  let initInFlight = false;
  const getInFlight = () => initInFlight;
  const setInFlight = (value: boolean) => {
    initInFlight = value;
  };

  context.subscriptions.push(
    vscode.commands.registerCommand('morpheus.initialize', () =>
      runInit(context, output, { manual: true }, getInFlight, setInFlight)
    )
  );

  const currentVersion = context.extension.packageJSON.version as string;
  const lastInitializedVersion = context.globalState.get<string>(INIT_VERSION_KEY);
  const needsInit = lastInitializedVersion !== currentVersion || !isFullyInstalled();

  if (needsInit) {
    void runInit(context, output, { manual: false }, getInFlight, setInFlight);
  }
}

export function deactivate(): void {
  // No teardown beyond what context.subscriptions already disposes.
}

async function runInit(
  context: vscode.ExtensionContext,
  output: vscode.OutputChannel,
  opts: { manual: boolean },
  getInFlight: () => boolean,
  setInFlight: (value: boolean) => void
): Promise<void> {
  if (getInFlight()) {
    return;
  }
  setInFlight(true);

  try {
    if (process.platform === 'win32') {
      void vscode.window.showErrorMessage(
        'Morpheus: Windows is not supported. Please install manually on Linux or macOS.'
      );
      return;
    }

    const scriptUri = vscode.Uri.joinPath(context.extensionUri, 'resources', 'install.sh');
    const scriptPath = scriptUri.fsPath;

    if (!fs.existsSync(scriptPath)) {
      void vscode.window.showErrorMessage(
        'Morpheus: bundled install.sh not found in the extension package.'
      );
      return;
    }

    output.show(true);
    output.appendLine(
      `[Morpheus] Running install.sh (${opts.manual ? 'manual' : 'auto, on activation'})...`
    );

    const exitCode = await vscode.window.withProgress(
      {
        location: vscode.ProgressLocation.Notification,
        title: 'Morpheus: installing CLI + skills...',
      },
      () => runInstallScript(scriptPath, output)
    );

    if (exitCode === 0) {
      const currentVersion = context.extension.packageJSON.version as string;
      await context.globalState.update(INIT_VERSION_KEY, currentVersion);
      void vscode.window.showInformationMessage(
        'Morpheus: CLI installed to ~/.morpheus and skills deployed to ~/.cursor/skills/cyber-sierra and ~/.claude/skills/cyber-sierra. ' +
          'Open a new terminal (or source your shell rc file) to use the morpheus command.'
      );
    } else if (exitCode !== null) {
      output.appendLine(`[Morpheus] install.sh exited with code ${exitCode}`);
      void vscode.window.showErrorMessage(
        `Morpheus: install.sh exited with code ${exitCode}. See the "Morpheus" output channel for details.`
      );
    }
  } finally {
    setInFlight(false);
  }
}

function runInstallScript(scriptPath: string, output: vscode.OutputChannel): Promise<number | null> {
  return new Promise((resolve) => {
    const child = cp.spawn('/bin/bash', [scriptPath], {
      cwd: path.dirname(scriptPath),
      env: { ...process.env, HOME: os.homedir() },
    });

    child.stdout.on('data', (data: Buffer) => output.append(data.toString()));
    child.stderr.on('data', (data: Buffer) => output.append(data.toString()));

    child.on('error', (err) => {
      output.appendLine(`[Morpheus] Failed to launch install.sh: ${err.message}`);
      void vscode.window.showErrorMessage(`Morpheus: failed to run installer — ${err.message}`);
      resolve(null);
    });

    child.on('close', (code) => resolve(code));
  });
}
