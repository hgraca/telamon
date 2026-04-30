// tool-stats OpenCode plugin
// Logs every tool call to a SQLite database for usage statistics.
import { Database } from "bun:sqlite";
import { readFileSync, existsSync, mkdirSync } from "fs";
import { join, dirname } from "path";

/**
 * Find the nearest ancestor of `dir` that contains `.telamon.jsonc`.
 * Falls back to `dir` itself if not found.
 */
function findTelamonRoot(dir) {
  let current = dir;
  while (true) {
    if (existsSync(join(current, ".telamon.jsonc"))) {
      return current;
    }
    const parent = dirname(current);
    if (parent === current) break; // reached filesystem root
    current = parent;
  }
  return dir;
}

/**
 * Strip `//` line comments from JSONC and parse.
 */
function parseJsonc(text) {
  const stripped = text.replace(/\/\/[^\n]*/g, "");
  return JSON.parse(stripped);
}

/**
 * Read project name from <root>/.ai/telamon/telamon.jsonc.
 * Returns "unknown" on any failure.
 */
function readProjectName(telamonRoot) {
  try {
    const configPath = join(telamonRoot, ".ai", "telamon", "telamon.jsonc");
    const text = readFileSync(configPath, "utf8");
    const config = parseJsonc(text);
    return config.project_name ?? "unknown";
  } catch {
    return "unknown";
  }
}

export const ToolStatsPlugin = async ({ directory }) => {
  let db = null;
  let insertStmt = null;
  let projectName = null;
  let telamonRoot = null;

  function getDb() {
    if (db) return db;

    telamonRoot = findTelamonRoot(directory);
    projectName = readProjectName(telamonRoot);

    const dbDir = join(telamonRoot, "storage", "stats");
    mkdirSync(dbDir, { recursive: true });

    const dbPath = join(dbDir, "stats.sqlite");
    db = new Database(dbPath);

    db.run(`
      CREATE TABLE IF NOT EXISTS tool_calls (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tool TEXT NOT NULL,
        agent TEXT,
        skill TEXT,
        project TEXT NOT NULL,
        timestamp TEXT NOT NULL
      )
    `);
    db.run(`CREATE INDEX IF NOT EXISTS idx_tool_calls_project ON tool_calls(project)`);
    db.run(`CREATE INDEX IF NOT EXISTS idx_tool_calls_timestamp ON tool_calls(timestamp)`);

    insertStmt = db.prepare(
      `INSERT INTO tool_calls (tool, agent, skill, project, timestamp) VALUES (?, ?, ?, ?, ?)`
    );

    return db;
  }

  return {
    "tool.execute.before": async (input) => {
      try {
        getDb();

        const tool = input.tool ?? "unknown";
        const agent = input.agent ?? input.metadata?.agent ?? null;
        const skill = input.skill ?? input.metadata?.skill ?? null;
        const timestamp = new Date().toISOString();

        insertStmt.run(tool, agent, skill, projectName, timestamp);
      } catch (err) {
        console.error("[tool-stats] Failed to log tool call:", err);
      }
    },
  };
};
