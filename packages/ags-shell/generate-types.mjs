import {
  chmodSync,
  cpSync,
  mkdirSync,
  readFileSync,
  readdirSync,
  writeFileSync,
} from "node:fs";
import { spawnSync } from "node:child_process";
import { join } from "node:path";

const [astalSource, girDirectory] = process.argv.slice(2);
if (!astalSource || !girDirectory) {
  throw new Error("Expected Astal sources and the GIR directory");
}

function run(command, args) {
  const result = spawnSync(command, args, { stdio: "inherit" });
  if (result.error) throw result.error;
  if (result.status !== 0) process.exit(result.status ?? 1);
}

run("node_modules/.bin/ts-for-gir", [
  "generate",
  "Astal-3.0",
  "Astal-4.0",
  "AstalIO-0.1",
  "AstalHyprland-0.1",
  "GioUnix-2.0",
  "--girDirectories",
  girDirectory,
  "--outdir",
  "node_modules/@girs",
  "--package",
  "--ignoreVersionConflicts",
  "--noPrettyPrint",
]);

// Astal distributes TS implementations rather than declarations. Preserve its
// actual public types and inference, but do not apply our stricter compiler
// settings to the third-party implementation. Runtime bundling uses the original
// astal.gjs package; no shell source receives this dependency-only annotation.
cpSync(astalSource, "node_modules/astal", { recursive: true });
for (const file of readdirSync("node_modules/astal", { recursive: true })) {
  if (!file.endsWith(".ts")) continue;
  const path = join("node_modules/astal", file);
  const source = readFileSync(path, "utf8");
  chmodSync(path, 0o644);
  writeFileSync(path, `// @ts-nocheck\n${source}`);
}

// Ambient gi:// imports are opt-in, including all generated dependency modules.
mkdirSync("node_modules/ags-shell-types", { recursive: true });
writeFileSync(
  "node_modules/ags-shell-types/index.d.ts",
  [
    "@girs/gjs",
    "@girs/gjs/dom",
    "@girs/astal-3.0",
    "@girs/astal-4.0",
    "@girs/astalio-0.1",
    "@girs/astalhyprland-0.1",
    "@girs/giounix-2.0",
  ]
    .map((module) => `import "${module}";\n`)
    .join(""),
);
