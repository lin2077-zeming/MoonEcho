import { spawnSync } from "node:child_process";
import { existsSync, readdirSync, statSync } from "node:fs";
import { resolve } from "node:path";

const root = resolve(import.meta.dirname, "..");
const executableDir = resolve(
  root,
  "_build/native/release/build/cmd/moonecho-cli",
);
const executableCandidates = existsSync(executableDir)
  ? readdirSync(executableDir, { withFileTypes: true })
      .filter((entry) => entry.isFile())
      .map((entry) => resolve(executableDir, entry.name))
      .filter((path) => {
        if (process.platform === "win32") {
          return path.endsWith(".exe");
        }
        const mode = statSync(path).mode;
        return (mode & 0o111) !== 0 && !/\.(lib|exp|pdb)$/i.test(path);
      })
  : [];
const executable = executableCandidates[0];

if (!executable) {
  console.error(`CLI executable is missing in: ${executableDir}`);
  process.exit(1);
}

const success = spawnSync(executable, ["version"], {
  cwd: root,
  encoding: "utf8",
});
if (success.status !== 0) {
  console.error(`version command failed: ${success.stderr || success.stdout}`);
  process.exit(1);
}
if (!success.stdout.includes("MoonEcho v")) {
  console.error(`unexpected version output: ${success.stdout}`);
  process.exit(1);
}

const failure = spawnSync(
  executable,
  ["index", "--input", "_build/missing-cli-input.wav", "--output", "_build/missing.idx"],
  {
    cwd: root,
    encoding: "utf8",
  },
);
if (failure.status === 0) {
  console.error("CLI error path returned exit code 0");
  process.exit(1);
}
const failureOutput = `${failure.stdout}${failure.stderr}`;
if (!failureOutput.includes("failed to read file")) {
  console.error(`unexpected CLI error output: ${failureOutput}`);
  process.exit(1);
}

console.log(
  `CLI exit-code smoke passed: success=${success.status}, failure=${failure.status}`,
);
