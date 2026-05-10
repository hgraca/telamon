import { execSync } from "child_process";
import { readFileSync, existsSync } from "fs";
import { join, basename } from "path";

const MAX_COMMIT_LINES = 30;
const MAX_DIFFSTAT_LINES = 20;

function worktreeSlug(worktree, directory) {
  const raw = basename(worktree || directory || "default");
  return raw.replace(/[^a-z0-9_-]/gi, "-").toLowerCase();
}

function getWatermarkTimestamp(directory, worktree) {
  const slug = worktreeSlug(worktree, directory);
  const path = join(directory, `.ai/telamon/memory/thinking/.last-capture-${slug}.json`);
  if (!existsSync(path)) return null;
  try {
    const data = JSON.parse(readFileSync(path, "utf8"));
    // timestamp is ISO/UTC (ends with Z) — git --since handles this correctly
    const ts = data.timestamp || null;
    // Validate ISO format to prevent shell injection from tampered watermark files
    if (ts && !/^\d{4}-\d{2}-\d{2}T[\d:.]+Z?$/.test(ts)) return null;
    return ts;
  } catch {
    return null;
  }
}

function runGit(cmd, directory) {
  try {
    return execSync(cmd, { cwd: directory, encoding: "utf8", timeout: 5000 }).trim();
  } catch {
    return null;
  }
}

function buildContext(directory, worktree) {
  // Verify git repo
  if (!existsSync(join(directory, ".git"))) return null;

  const timestamp = getWatermarkTimestamp(directory, worktree);
  let commits, diffstat;

  if (timestamp) {
    commits = runGit(`git log --oneline --no-decorate --since="${timestamp}"`, directory);
    if (!commits) return null; // no commits since last session
    // Get oldest commit hash in range for diffstat
    const oldest = runGit(`git log --format=%H --since="${timestamp}" --reverse -1`, directory);
    // oldest~1 may not exist for initial commits — fallback to oldest..HEAD via || operator
    diffstat = oldest ? runGit(`git diff --stat ${oldest}~1..HEAD 2>/dev/null || git diff --stat ${oldest}..HEAD`, directory) : null;
  } else {
    // Fallback: last 10 commits
    commits = runGit("git log --oneline --no-decorate -10", directory);
    if (!commits) return null;
    diffstat = runGit("git diff --stat HEAD~10..HEAD 2>/dev/null", directory);
  }

  // Assemble with budget split: commits get MAX_COMMIT_LINES, diffstat gets MAX_DIFFSTAT_LINES
  let commitLines = commits ? commits.split("\n") : [];
  let diffstatLines = diffstat ? diffstat.split("\n") : [];

  if (commitLines.length > MAX_COMMIT_LINES) {
    const remaining = commitLines.length - MAX_COMMIT_LINES;
    commitLines = commitLines.slice(0, MAX_COMMIT_LINES);
    commitLines.push(`... (${remaining} more commits)`);
  }

  if (diffstatLines.length > MAX_DIFFSTAT_LINES) {
    const remaining = diffstatLines.length - MAX_DIFFSTAT_LINES;
    diffstatLines = diffstatLines.slice(0, MAX_DIFFSTAT_LINES);
    diffstatLines.push(`... (${remaining} more lines)`);
  }

  let lines = [...commitLines];
  if (diffstatLines.length > 0) {
    lines.push("");
    lines.push(...diffstatLines);
  }

  if (lines.length === 0) return null;

  const header = timestamp
    ? `[diff-context] Changes since last session (${timestamp}):`
    : `[diff-context] Recent changes (last 10 commits):`;

  return header + "\n" + lines.join("\n");
}

export const DiffContextPlugin = async ({ directory, worktree }) => {
  let injected = false;

  return {
    "tool.execute.before": async (input, output) => {
      if (injected) return;
      if (input.tool !== "bash") return;

      const context = buildContext(directory, worktree);
      if (!context) {
        injected = true; // Don't retry on subsequent bash calls
        return;
      }

      const escaped = context.replace(/'/g, "'\\''");
      output.args.command = `echo '${escaped}' && ` + output.args.command;
      injected = true;
    },
  };
};
