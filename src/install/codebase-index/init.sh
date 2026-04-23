#!/usr/bin/env bash
# Write .opencode/codebase-index.json in the current project directory.
# Idempotent: skipped if the file already exists.

set -euo pipefail

INSTALL_PATH="${INSTALL_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "${INSTALL_PATH}/functions/autoload.sh"

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

let stdout = '';
let requestId = 1;
let initialized = false;

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

function sendIndexCodebase() {
  send({
    jsonrpc: '2.0',
    id: requestId++,
    method: 'tools/call',
    params: { name: 'index_codebase', arguments: {} },
  });
}

// Progress dots every 5 seconds so the user knows it's alive
const progressTimer = setInterval(() => {
  process.stderr.write('.');
}, 5000);

child.stdout.on('data', (chunk) => {
  stdout += chunk.toString();
  const lines = stdout.split('\n');
  stdout = lines.pop();
  for (const line of lines) {
    if (!line.trim()) continue;
    let msg;
    try { msg = JSON.parse(line); } catch { continue; }

    if (!initialized && msg.result && msg.result.protocolVersion !== undefined) {
      initialized = true;
      send({ jsonrpc: '2.0', method: 'notifications/initialized', params: {} });
      sendIndexCodebase();
    } else if (msg.result && Array.isArray(msg.result.content)) {
      clearInterval(progressTimer);
      process.stderr.write('\n');
      const text = msg.result.content.map(c => c.text || '').join('');
      process.stdout.write(text + '\n');
      child.stdin.end();
    } else if (msg.error) {
      clearInterval(progressTimer);
      process.stderr.write('\n');
      process.stderr.write('MCP error: ' + JSON.stringify(msg.error) + '\n');
      child.stdin.end();
      process.exitCode = 1;
    }
  }
});

child.stderr.on('data', () => {}); // suppress MCP server noise

child.on('close', (code) => {
  clearInterval(progressTimer);
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
