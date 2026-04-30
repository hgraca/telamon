// opencode-patches OpenCode plugin
// Detects when opencode auto-updates (binary hash changes) and re-applies patches.
// Fires once on the first tool call of each session.

import { readFileSync, existsSync } from "fs";
import { join, dirname } from "path";
import { execSync } from "child_process";

function findTelamonRoot(dir) {
  let current = dir;
  while (true) {
    if (existsSync(join(current, ".telamon.jsonc"))) return current;
    const parent = dirname(current);
    if (parent === current) break;
    current = parent;
  }
  return dir;
}

function parseJsonc(text) {
  return JSON.parse(text.replace(/\/\/[^\n]*/g, "").replace(/\/\*[\s\S]*?\*\//g, ""));
}

export const OpencodePatchesPlugin = async ({ directory }) => {
  let checked = false;

  return {
    "tool.execute.before": async () => {
      if (checked) return;
      checked = true;

      try {
        const telamonRoot = findTelamonRoot(directory);
        const stateFile = join(telamonRoot, "storage", "opencode-patch-state.json");
        const configFile = join(telamonRoot, ".telamon.jsonc");

        if (!existsSync(stateFile) || !existsSync(configFile)) return;

        const config = parseJsonc(readFileSync(configFile, "utf8"));
        const patches = config.opencode_patches || [];
        if (patches.length === 0) return;

        const state = JSON.parse(readFileSync(stateFile, "utf8"));
        const currentVersion = execSync("opencode --version", { encoding: "utf8" }).trim();

        if (state.version === currentVersion) {
          // Same version — check binary hash
          const binaryPath = join(process.env.HOME || "", ".opencode", "bin", "opencode");
          if (!existsSync(binaryPath)) return;
          const currentHash = execSync(`sha256sum "${binaryPath}" | cut -d' ' -f1`, { encoding: "utf8" }).trim();
          if (currentHash === state.binary_sha) return; // No change
        }

        // Version or hash mismatch — re-apply patches
        console.log("[opencode-patches] Detected version change — re-applying patches in background...");
        const patchScript = join(telamonRoot, "src", "tools", "opencode", "apply-patches.sh");
        if (existsSync(patchScript)) {
          // Spawn in background — don't block the session
          const { spawn } = await import("child_process");
          const child = spawn("bash", [patchScript], {
            detached: true,
            stdio: "ignore",
            env: {
              ...process.env,
              TELAMON_ROOT: telamonRoot,
              TOOLS_PATH: join(telamonRoot, "src", "tools"),
              FUNCTIONS_PATH: join(telamonRoot, "src", "functions"),
            },
          });
          child.unref();
          console.log("[opencode-patches] Patch rebuild started (PID " + child.pid + "). Restart opencode when done.");
        }
      } catch (err) {
        // Silent failure — don't disrupt the session
      }
    },
  };
};
