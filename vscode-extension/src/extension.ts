import * as vscode from 'vscode';
import * as cp from 'child_process';
import * as fs from 'fs';
import * as os from 'os';
import * as path from 'path';

const INIT_VERSION_KEY = 'morpheus.initializedVersion';

// Must match the PATH_LINE constant in resources/install.sh exactly — this is
// the literal (unexpanded) line install.sh appends to the shell rc file, and
// is how we find and remove it again on uninstall.
const SHELL_PATH_LINE = 'export PATH="$HOME/.morpheus/bin:$PATH"';
const SHELL_RC_CANDIDATES = ['.zshrc', '.bashrc', '.bash_profile'];

function skillDestDirs(home: string): string[] {
  return [
    path.join(home, '.cursor', 'skills', 'cyber-sierra'),
    path.join(home, '.claude', 'skills', 'cyber-sierra'),
  ];
}

// Whether the CLI binary and both skill destinations are actually present on
// disk. A stale "already initialized" flag must never be trusted on its own —
// if any of these are missing (e.g. the user deleted ~/.morpheus, or a skill
// folder), activation self-heals by re-running the installer regardless of
// what was recorded previously.
function isFullyInstalled(): boolean {
  const home = os.homedir();
  return (
    fs.existsSync(path.join(home, '.morpheus', 'bin', 'morpheus')) &&
    skillDestDirs(home).every((dir) => fs.existsSync(path.join(dir, 'SKILL.md')))
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

  context.subscriptions.push(
    vscode.commands.registerCommand('morpheus.uninstall', () => runUninstall(context, output))
  );

  const currentVersion = context.extension.packageJSON.version as string;
  const lastInitializedVersion = context.globalState.get<string>(INIT_VERSION_KEY);
  const needsInit = lastInitializedVersion !== currentVersion || !isFullyInstalled();

  if (needsInit) {
    void runInit(context, output, { manual: false }, getInFlight, setInFlight);
  }
}

export function deactivate(): void {
  // No teardown beyond what context.subscriptions already disposes. Uninstall
  // is a distinct, explicit action (see runUninstall) — deactivate() also
  // fires on a plain "disable extension", so it must never touch disk.
}

function removeDirIfPresent(target: string): boolean {
  if (!fs.existsSync(target)) {
    return false;
  }
  fs.rmSync(target, { recursive: true, force: true });
  return true;
}

// Strips the exact PATH line install.sh appended, plus the blank line it
// inserted immediately before it, from any shell rc file that has it.
function removeShellPathEntries(home: string): string[] {
  const touched: string[] = [];

  for (const rc of SHELL_RC_CANDIDATES) {
    const rcPath = path.join(home, rc);
    if (!fs.existsSync(rcPath)) {
      continue;
    }

    const original = fs.readFileSync(rcPath, 'utf8');
    if (!original.includes(SHELL_PATH_LINE)) {
      continue;
    }

    const lines = original.split('\n');
    const kept: string[] = [];
    for (const line of lines) {
      if (line === SHELL_PATH_LINE) {
        if (kept.length > 0 && kept[kept.length - 1] === '') {
          kept.pop();
        }
        continue;
      }
      kept.push(line);
    }

    fs.writeFileSync(rcPath, kept.join('\n'));
    touched.push(rcPath);
  }

  return touched;
}

async function runUninstall(context: vscode.ExtensionContext, output: vscode.OutputChannel): Promise<void> {
  const confirm = await vscode.window.showWarningMessage(
    'This removes the Morpheus CLI (~/.morpheus), the deployed skills ' +
      '(~/.cursor/skills/cyber-sierra and ~/.claude/skills/cyber-sierra), and the PATH entry ' +
      'added to your shell profile. This cannot be undone. Continue?',
    { modal: true },
    'Uninstall'
  );
  if (confirm !== 'Uninstall') {
    return;
  }

  const home = os.homedir();
  output.show(true);
  output.appendLine('[Morpheus] Uninstalling...');

  const removedDirs = [path.join(home, '.morpheus'), ...skillDestDirs(home)].filter(removeDirIfPresent);

  const touchedRc = removeShellPathEntries(home);

  await context.globalState.update(INIT_VERSION_KEY, undefined);

  for (const dir of removedDirs) {
    output.appendLine(`[Morpheus] Removed ${dir}`);
  }
  for (const rc of touchedRc) {
    output.appendLine(`[Morpheus] Removed PATH entry from ${rc}`);
  }

  if (removedDirs.length === 0 && touchedRc.length === 0) {
    void vscode.window.showInformationMessage('Morpheus: nothing to uninstall — no installed files were found.');
    return;
  }

  void vscode.window.showInformationMessage(
    'Morpheus: uninstalled. Restart open terminals for the PATH change to take effect. ' +
      'You can now remove the extension itself from the Extensions view.'
  );
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
