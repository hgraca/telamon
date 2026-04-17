// graphify OpenCode plugin
// Injects knowledge graph context (god nodes, communities, surprising connections)
// on the first bash tool call of each session.
import { readFileSync, existsSync } from "fs";
import { join } from "path";

/**
 * Parse GRAPH_REPORT.md and extract a concise summary.
 * Returns a string with god nodes, communities, and surprising connections,
 * or null if the report doesn't exist or can't be parsed.
 */
function extractGraphContext(directory) {
  const reportPath = join(directory, "graphify-out", "GRAPH_REPORT.md");
  if (!existsSync(reportPath)) return null;

  let report;
  try {
    report = readFileSync(reportPath, "utf8");
  } catch {
    return null;
  }

  const sections = [];

  // Extract God Nodes section (top 5 lines after the heading)
  const godMatch = report.match(/##\s*God Nodes[^\n]*\n([\s\S]*?)(?=\n##\s|\n---|\Z)/i);
  if (godMatch) {
    const lines = godMatch[1].trim().split("\n").filter(l => l.trim()).slice(0, 5);
    if (lines.length > 0) {
      sections.push("God Nodes (most connected): " + lines.map(l => l.replace(/^[-*]\s*/, "").replace(/\*\*/g, "").trim()).join(", "));
    }
  }

  // Extract Communities section (just names)
  const commMatch = report.match(/##\s*Communit(?:y|ies)[^\n]*\n([\s\S]*?)(?=\n##\s|\n---|\Z)/i);
  if (commMatch) {
    // Look for community names — typically formatted as ### Name or **Name** or "N: Name"
    const names = [];
    for (const line of commMatch[1].split("\n")) {
      const nameMatch = line.match(/^###\s+(.+)/) || line.match(/^\*\*(.+?)\*\*/) || line.match(/^\d+[.:]\s*(.+)/);
      if (nameMatch && names.length < 10) {
        names.push(nameMatch[1].trim());
      }
    }
    if (names.length > 0) {
      sections.push("Communities: " + names.join(", "));
    }
  }

  // Extract Surprising Connections section (top 3 lines)
  const surpriseMatch = report.match(/##\s*Surprising Connections[^\n]*\n([\s\S]*?)(?=\n##\s|\n---|\Z)/i);
  if (surpriseMatch) {
    const lines = surpriseMatch[1].trim().split("\n").filter(l => l.trim()).slice(0, 3);
    if (lines.length > 0) {
      sections.push("Surprising Connections: " + lines.map(l => l.replace(/^[-*]\s*/, "").replace(/\*\*/g, "").trim()).join("; "));
    }
  }

  if (sections.length === 0) return null;

  return "[graphify] Knowledge graph context:\n" + sections.join("\n");
}

export const GraphifyPlugin = async ({ directory }) => {
  let injected = false;

  return {
    "tool.execute.before": async (input, output) => {
      if (injected) return;
      if (input.tool !== "bash") return;

      const context = extractGraphContext(directory);
      if (!context) return;

      // Prepend the context as an echo before the actual command
      const escaped = context.replace(/'/g, "'\\''");
      output.args.command =
        `echo '${escaped}' && ` + output.args.command;
      injected = true;
    },
  };
};
