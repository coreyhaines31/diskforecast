import { execFile } from "node:child_process";
import { accessSync, constants } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

export const INSTALL_MESSAGE =
  "Disk Forecast isn't installed on this Mac, so there's nothing to ask yet. " +
  "Install the free Disk Forecast app from https://diskforecast.com (or `brew install --cask coreyhaines31/tap/diskforecast`), " +
  "open it once, then try again.";

const BUNDLE_ID = "app.diskforecast.DiskForecast";
const APP_BINARY = "Contents/MacOS/diskforecast";
// The CLI waits up to 60 seconds for the app's reply, so give it time to report its own timeout.
const TIMEOUT_MS = 75_000;
const MAX_OUTPUT_CHARS = 200_000;

// Only these subcommands can ever be spawned. trash, undo, scan, and open change things or start work.
const ALLOWED_COMMANDS = new Set(["status", "changes", "cleanup"]);

type RunResult = { ok: true; text: string } | { ok: false; text: string };

function isExecutable(path: string): boolean {
  try {
    accessSync(path, constants.X_OK);
    return true;
  } catch {
    return false;
  }
}

function spotlightAppPaths(): Promise<string[]> {
  return new Promise((resolve) => {
    try {
      execFile(
        "/usr/bin/mdfind",
        [`kMDItemCFBundleIdentifier == '${BUNDLE_ID}'`],
        { timeout: 5_000 },
        (error, stdout) => {
          if (error) return resolve([]);
          const apps = stdout.split("\n").map((line) => line.trim()).filter(Boolean);
          resolve(apps.filter((app) => !app.includes("/.Trash/")));
        },
      );
    } catch {
      resolve([]);
    }
  });
}

export async function locateCli(): Promise<string | null> {
  const fromEnv = process.env.DISKFORECAST_CLI?.trim();
  if (fromEnv && isExecutable(fromEnv)) return fromEnv;

  const candidates = [
    join("/Applications/Disk Forecast.app", APP_BINARY),
    join(homedir(), "Applications/Disk Forecast.app", APP_BINARY),
    "/opt/homebrew/bin/diskforecast",
    "/usr/local/bin/diskforecast",
  ];
  for (const path of candidates) {
    if (isExecutable(path)) return path;
  }

  for (const app of await spotlightAppPaths()) {
    const path = join(app, APP_BINARY);
    if (isExecutable(path)) return path;
  }
  return null;
}

// The CLI pretty-prints; compact JSON costs Claude far fewer tokens.
function compact(text: string): string {
  try {
    return JSON.stringify(JSON.parse(text));
  } catch {
    return text.trim();
  }
}

function truncate(text: string): string {
  if (text.length <= MAX_OUTPUT_CHARS) return text;
  return `${text.slice(0, MAX_OUTPUT_CHARS)}\n… output truncated at ${MAX_OUTPUT_CHARS} characters.`;
}

// With --json, an error from the app comes back as {"error": "..."}; usage errors only reach stderr.
function errorFrom(stdout: string, stderr: string): string | null {
  try {
    const parsed = JSON.parse(stdout);
    if (parsed && typeof parsed === "object" && !Array.isArray(parsed) && typeof parsed.error === "string") {
      return parsed.error;
    }
  } catch {
    // Not JSON; fall through to stderr.
  }
  return stderr.trim().replace(/^diskforecast: /, "") || null;
}

// The CLI exits 0 on success and 1 on any error. There is no "found a problem" status code:
// a low disk is reported inside the JSON (lowOnSpace, outlook), not by the exit code.
export async function runDiskForecast(args: string[]): Promise<RunResult> {
  if (!ALLOWED_COMMANDS.has(args[0])) {
    return { ok: false, text: `Not allowed: ${args[0]}` };
  }
  if (process.platform !== "darwin") {
    return { ok: false, text: "Disk Forecast only runs on macOS." };
  }
  const cli = await locateCli();
  if (!cli) return { ok: false, text: INSTALL_MESSAGE };

  return new Promise((resolve) => {
    try {
      execFile(
        cli,
        [...args, "--json"],
        { timeout: TIMEOUT_MS, maxBuffer: 20 * 1024 * 1024 },
        (error, stdout, stderr) => {
          const code = error ? (typeof error.code === "number" ? error.code : null) : 0;
          const message = errorFrom(stdout, stderr);

          if (code === 0) return resolve({ ok: true, text: truncate(compact(stdout)) });
          if (message) return resolve({ ok: false, text: message });
          if (error?.killed) {
            return resolve({ ok: false, text: `Disk Forecast didn't answer within ${TIMEOUT_MS / 1000} seconds.` });
          }
          resolve({ ok: false, text: `Disk Forecast's command line tool failed: ${error?.message ?? "unknown error"}` });
        },
      );
    } catch (error) {
      resolve({ ok: false, text: `Couldn't start Disk Forecast's command line tool at ${cli}: ${(error as Error).message}` });
    }
  });
}
