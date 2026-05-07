// tool-stats OpenCode plugin
// Logs every tool call to a SQLite database for usage statistics.
import { Database } from "bun:sqlite";
import { readFileSync, existsSync, mkdirSync } from "fs";
import { join, dirname } from "path";

const AGENT_CACHE_TTL_MS = 60_000;

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

export const ToolStatsPlugin = async ({ directory, client, _now }) => {
  let db = null;
  let insertStmt = null;
  let projectName = null;
  let telamonRoot = null;

  const agentCache = new Map();
  const skillBySession = new Map();
  const now = _now ?? (() => Date.now());

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
        const timestamp = new Date().toISOString();

        // Skill tracking: update active skill if this is a skill tool call
        try {
          if (input.tool === "skill") {
            const name = input.args?.name;
            if (typeof name === "string" && name.length > 0) {
              skillBySession.set(input.sessionID, name);
            }
          }
        } catch {}

        // Agent derivation
        let agent;
        if (client && input.sessionID) {
          const sessionID = input.sessionID;
          const cached = agentCache.get(sessionID);
          if (cached && (now() - cached.fetchedAt) < AGENT_CACHE_TTL_MS) {
            agent = cached.agent;
          } else {
            try {
              const result = await client.session.messages({ path: { id: sessionID } });
              const messages = result.data ?? [];
              let lastAgent = null;
              for (const m of messages) {
                if (m.info?.role === "assistant") {
                  lastAgent = m.info?.agent ?? null;
                }
              }
              agent = lastAgent;
              agentCache.set(sessionID, { agent, fetchedAt: now() });
            } catch (err) {
              process.stderr.write(`[tool-stats] Failed to fetch agent for session ${sessionID}: ${err}\n`);
              agentCache.set(sessionID, { agent: null, fetchedAt: now() });
              agent = null;
            }
          }
        } else {
          agent = input.agent ?? input.metadata?.agent ?? null;
        }

        // Skill derivation
        let skill;
        try {
          if (client && input.sessionID) {
            skill = skillBySession.get(input.sessionID) ?? null;
          } else {
            skill = input.skill ?? input.metadata?.skill ?? null;
          }
        } catch {
          skill = null;
        }

        insertStmt.run(tool, agent, skill, projectName, timestamp);
      } catch (err) {
        console.error("[tool-stats] Failed to log tool call:", err);
      }
    },
  };
};
