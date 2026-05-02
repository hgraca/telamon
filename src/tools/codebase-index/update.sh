#!/usr/bin/env bash
# Rebuild missing codebase indices for all initialized projects.
# Exit codes: 0=success  1=failed  2=not-installed (skipped)

set -euo pipefail

TOOLS_PATH="${TOOLS_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck disable=SC1091
. "${FUNCTIONS_PATH}/autoload.sh"

header "Codebase Index"

if ! command -v node &>/dev/null; then
  echo -e "  ${TEXT_DIM}–  codebase-index (node not installed — skipping)${TEXT_CLEAR}"
  exit 2
fi

if ! curl -sf http://127.0.0.1:17434/v1/models >/dev/null 2>&1; then
  warn "Ollama not reachable — skipping codebase index rebuild"
  exit 0
fi

# Resolve MCP binary once before the loop
step "Resolving codebase-index MCP binary..."
MCP_BIN=$(npx -y -p opencode-codebase-index -p @modelcontextprotocol/sdk which opencode-codebase-index-mcp 2>/dev/null || true)
if [[ -z "${MCP_BIN}" ]]; then
  warn "Could not resolve opencode-codebase-index-mcp binary — skipping index rebuild"
  exit 0
fi
MCP_SCRIPT=$(readlink -f "${MCP_BIN}")

# ── Rebuild missing indices for initialized projects (background, incremental) ─
# Codebase-index natively respects .gitignore (skips gitignored paths/files).
# Running in background with nohup so the process survives terminal close.
TELAMON_ROOT="${TELAMON_ROOT:-$(cd "${TOOLS_PATH}/../.." && pwd)}"
_BG_PIDS=()
for storage_dir in "${TELAMON_ROOT}/storage/graphify"/*/; do
  [[ -d "${storage_dir}" ]] || continue
  [[ -f "${storage_dir}.project-path" ]] || continue
  proj="$(cat "${storage_dir}.project-path")"
  [[ -d "${proj}" ]] || { warn "Project directory not found: ${proj} — skipping"; continue; }
  [[ -d "${proj}/.opencode/index" ]] && continue
  [[ -f "${proj}/.opencode/codebase-index.json" ]] || continue

  step "Building missing codebase index for $(basename "${proj}") (background)..."

  # Run the embedding in a background subshell with nohup so it survives terminal close
  _LOG_FILE="${storage_dir}.codebase-index-build.log"
  (
    nohup node - "${MCP_SCRIPT}" "${proj}" <<'NODE_SCRIPT'
const { spawn } = require('child_process');
const [,, mcpScript, projectDir] = process.argv;

const child = spawn('node', [mcpScript, '--project', projectDir], {
  stdio: ['pipe', 'pipe', 'pipe'],
});

let stdoutBuf = '';
let requestId = 1;
let initialized = false;

// ── Helpers ───────────────────────────────────────────────────────────────────
function formatDuration(ms) {
  const s = Math.floor(ms / 1000);
  const m = Math.floor(s / 60);
  return m > 0 ? `${m}m ${s % 60}s` : `${s}s`;
}

function send(obj) {
  child.stdin.write(JSON.stringify(obj) + '\n');
}

function sendInitialize() {
  send({
    jsonrpc: '2.0',
    id: requestId++,
    method: 'initialize',
    params: {
      protocolVersion: '2024-11-05',
      capabilities: {},
      clientInfo: { name: 'update-script', version: '1.0.0' },
    },
  });
}

// ── Phase state ───────────────────────────────────────────────────────────────
let estimateCallId = null;
let indexCallId = null;
let indexStartTime = null;
let elapsedTimer = null;

function startElapsedTimer() {
  indexStartTime = Date.now();
  elapsedTimer = setInterval(() => {
    const elapsed = Date.now() - indexStartTime;
    const elapsedStr = formatDuration(elapsed);
    process.stderr.write(`  \u2192  Embedding chunks via Ollama...   ${elapsedStr}\n`);
  }, 30000);
}

function stopElapsedTimer() {
  if (elapsedTimer) { clearInterval(elapsedTimer); elapsedTimer = null; }
}

// ── MCP message handler ───────────────────────────────────────────────────────
child.stdout.on('data', (chunk) => {
  stdoutBuf += chunk.toString();
  const lines = stdoutBuf.split('\n');
  stdoutBuf = lines.pop();
  for (const line of lines) {
    if (!line.trim()) continue;
    let msg;
    try { msg = JSON.parse(line); } catch { continue; }

    // initialize response → send notifications/initialized + estimate call
    if (!initialized && msg.result && msg.result.protocolVersion !== undefined) {
      initialized = true;
      send({ jsonrpc: '2.0', method: 'notifications/initialized', params: {} });
      estimateCallId = requestId;
      send({
        jsonrpc: '2.0',
        id: requestId++,
        method: 'tools/call',
        params: { name: 'index_codebase', arguments: { estimateOnly: true } },
      });
      continue;
    }

    // estimate response → print info line, start actual index
    if (msg.id === estimateCallId && msg.result && Array.isArray(msg.result.content)) {
      const text = msg.result.content.map(c => c.text || '').join('');
      const filesMatch = text.match(/Files to index:\s+(\d[\d,]*)/i);
      const chunksMatch = text.match(/Estimated chunks:\s+~?(\d[\d,]*)/i);
      const filesNum = filesMatch ? parseInt(filesMatch[1].replace(/,/g, ''), 10) : '?';
      const estimatedChunks = chunksMatch ? parseInt(chunksMatch[1].replace(/,/g, ''), 10) : 0;
      const dateStr = new Date().toLocaleString('en-GB', { dateStyle: 'medium', timeStyle: 'short' });
      const chunksDisplay = estimatedChunks > 0 ? estimatedChunks.toLocaleString('en-GB') : '?';
      process.stderr.write(
        `  \u2139  ${dateStr} \u2014 Indexing ${filesNum} files (~${chunksDisplay} chunks estimated)\n`
      );
      startElapsedTimer();
      indexCallId = requestId;
      send({
        jsonrpc: '2.0',
        id: requestId++,
        method: 'tools/call',
        params: { name: 'index_codebase', arguments: {} },
      });
      continue;
    }

    // index response → stop timer, emit result
    if (msg.id === indexCallId && msg.result && Array.isArray(msg.result.content)) {
      stopElapsedTimer();
      const text = msg.result.content.map(c => c.text || '').join('');
      process.stdout.write(text + '\n');
      child.stdin.end();
      continue;
    }

    // error on any call
    if (msg.error) {
      stopElapsedTimer();
      process.stderr.write('MCP error: ' + JSON.stringify(msg.error) + '\n');
      child.stdin.end();
      process.exitCode = 1;
    }
  }
});

child.stderr.on('data', () => {}); // suppress MCP server noise

child.on('close', (code) => {
  stopElapsedTimer();
  if (code !== 0 && process.exitCode !== 1) {
    process.stderr.write('MCP server exited with code ' + code + '\n');
    process.exitCode = 1;
  }
});

sendInitialize();
NODE_SCRIPT
  ) > "${_LOG_FILE}" 2>&1 &
  _BG_PIDS+=($!)
  log "Embedding started in background (pid $!) — log: ${_LOG_FILE}"
done

# Wait briefly for background processes and report status
if [[ ${#_BG_PIDS[@]} -gt 0 ]]; then
  info "Background embedding processes: ${_BG_PIDS[*]}"
  info "Logs are in storage/graphify/<project>/.codebase-index-build.log"
fi
