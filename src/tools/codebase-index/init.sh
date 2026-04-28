#!/usr/bin/env bash
# Write .opencode/codebase-index.json in the current project directory.
# Idempotent: skipped if the file already exists.

set -euo pipefail

TOOLS_PATH="${TOOLS_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "${FUNCTIONS_PATH}/autoload.sh"

header "opencode-codebase-index Config"

INDEX_CONFIG="$(pwd)/.opencode/codebase-index.json"

if [[ -f "${INDEX_CONFIG}" ]]; then
  skip "codebase-index config (already exists)"; exit 0
fi

mkdir -p "$(pwd)/.opencode"
cp "${SCRIPT_DIR}/codebase-index.json" "${INDEX_CONFIG}"
log "codebase-index config written → .opencode/codebase-index.json"

# ── Build initial codebase index ─────────────────────────────────────────────
if [[ -d "$(pwd)/.opencode/index" ]]; then
  skip "Codebase index (already exists)"
elif ! command -v node &>/dev/null; then
  info "node not found — index will be built on first session"
elif ! curl -sf http://127.0.0.1:17434/v1/models >/dev/null 2>&1; then
  info "Ollama not reachable — index will be built on first session"
else
  step "Resolving codebase-index MCP binary..."
  MCP_BIN=$(npx -y -p opencode-codebase-index -p @modelcontextprotocol/sdk which opencode-codebase-index-mcp 2>/dev/null || true)
  if [[ -z "${MCP_BIN}" ]]; then
    info "Could not resolve opencode-codebase-index-mcp binary — index will be built on first session"
  else
    MCP_SCRIPT=$(readlink -f "${MCP_BIN}")
    PROJECT_DIR="$(pwd)"
    step "Building initial codebase index for $(basename "${PROJECT_DIR}")..."

    RESULT=$(node - "${MCP_SCRIPT}" "${PROJECT_DIR}" <<'NODE_SCRIPT'
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
      clientInfo: { name: 'init-script', version: '1.0.0' },
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
    ) && NODE_EXIT=0 || NODE_EXIT=$?

    if [[ ${NODE_EXIT} -ne 0 ]]; then
      warn "Codebase index build failed — the agent will build it on first session"
    else
      # Parse result fields from the response text
      FILES=$(echo "${RESULT}"    | grep -oP '\d+(?= files processed)'        || echo "?")
      EMBEDDED=$(echo "${RESULT}" | grep -oP '\d+(?= new chunks embedded)'    || echo "0")
      SKIPPED=$(echo "${RESULT}"  | grep -oP '\d+(?= unchanged chunks skipped)' || echo "0")
      REMOVED=$(echo "${RESULT}"  | grep -oP '\d+(?= stale chunks)'           || echo "0")
      TOKENS=$(echo "${RESULT}"   | grep -oP '(?<=Tokens: )[\d,]+'            || echo "?")
      DURATION=$(echo "${RESULT}" | grep -oP '(?<=Duration: )[^\n]+'          || echo "?")
      TOTAL=$(( ${EMBEDDED:-0} + ${SKIPPED:-0} ))

      echo -e ""
      echo -e "  ${TEXT_BOLD}${TEXT_BLUE}┌─ Codebase Index Summary ──────────────────────────────┐${TEXT_CLEAR}"
      echo -e "  ${TEXT_BOLD}${TEXT_BLUE}│${TEXT_CLEAR}  ${TEXT_GREEN}✔${TEXT_CLEAR}  Files processed   : ${TEXT_BOLD}${FILES}${TEXT_CLEAR}"
      echo -e "  ${TEXT_BOLD}${TEXT_BLUE}│${TEXT_CLEAR}  ${TEXT_GREEN}✔${TEXT_CLEAR}  Chunks embedded   : ${TEXT_BOLD}${EMBEDDED}${TEXT_CLEAR}"
      echo -e "  ${TEXT_BOLD}${TEXT_BLUE}│${TEXT_CLEAR}  ${TEXT_DIM}–${TEXT_CLEAR}  Chunks skipped    : ${SKIPPED}"
      echo -e "  ${TEXT_BOLD}${TEXT_BLUE}│${TEXT_CLEAR}  ${TEXT_DIM}–${TEXT_CLEAR}  Stale removed     : ${REMOVED}"
      echo -e "  ${TEXT_BOLD}${TEXT_BLUE}│${TEXT_CLEAR}  ${TEXT_DIM}–${TEXT_CLEAR}  Total indexed     : ${TEXT_BOLD}${TOTAL}${TEXT_CLEAR}"
      echo -e "  ${TEXT_BOLD}${TEXT_BLUE}│${TEXT_CLEAR}  ${TEXT_DIM}⏱${TEXT_CLEAR}  Duration          : ${DURATION}   (tokens: ${TOKENS})"
      echo -e "  ${TEXT_BOLD}${TEXT_BLUE}│${TEXT_CLEAR}"
      echo -e "  ${TEXT_BOLD}${TEXT_BLUE}│${TEXT_CLEAR}  ${TEXT_DIM}Available tools:${TEXT_CLEAR}"
      echo -e "  ${TEXT_BOLD}${TEXT_BLUE}│${TEXT_CLEAR}  ${TEXT_DIM}  codebase_search · codebase_peek · find_similar${TEXT_CLEAR}"
      echo -e "  ${TEXT_BOLD}${TEXT_BLUE}│${TEXT_CLEAR}  ${TEXT_DIM}  implementation_lookup · call_graph${TEXT_CLEAR}"
      echo -e "  ${TEXT_BOLD}${TEXT_BLUE}└───────────────────────────────────────────────────────┘${TEXT_CLEAR}"
    fi
  fi
fi
