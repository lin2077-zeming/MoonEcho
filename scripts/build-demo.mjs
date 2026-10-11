import { cpSync, existsSync, mkdirSync, statSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { resolve } from "node:path";

const root = resolve(import.meta.dirname, "..");
const moon = process.env.MOON || (process.platform === "win32" ? "moon.exe" : "moon");
const source = resolve(
  root,
  "_build/wasm-gc/release/build/src/web/web.wasm",
);
const destination = resolve(root, "web/moonecho.wasm");

const build = spawnSync(
  moon,
  ["build", "src/web", "--target", "wasm-gc", "--release", "--deny-warn"],
  {
    cwd: root,
    stdio: "inherit",
  },
);

if (build.error) {
  console.error(`Unable to start ${moon}: ${build.error.message}`);
  process.exit(1);
}
if (build.status !== 0) {
  process.exit(build.status ?? 1);
}
if (!existsSync(source)) {
  console.error(`WASM artifact was not produced: ${source}`);
  process.exit(1);
}

mkdirSync(resolve(root, "web"), { recursive: true });
cpSync(source, destination);
const size = (statSync(destination).size / 1024).toFixed(1);
console.log(`Built web demo runtime: web/moonecho.wasm (${size} KB)`);
