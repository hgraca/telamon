#!/usr/bin/env bash
# Background worker: runs incremental codebase-index rebuild for a project.
# Called from git post-commit hook.
# Must be completely silent — no output to terminal.
#
# Usage: codebase-index-hook-runner.sh <project-path>
#
# Requirements:
# - node must be installed
# - Ollama must be reachable at port 17434
# - Project must have .opencode/codebase-index.json config
# - Incremental: only re-embeds changed files (handled natively by codebase-index)
# - Respects .gitignore: skips gitignored paths/files (native behavior)

set -uo pipefail

PROJECT_PATH="${1:?codebase-index-hook-runner.sh requires project path as \$1}"

# Resolve absolute path
PROJECT_PATH="$(cd "${PROJECT_PATH}" && pwd)" || exit 0

PID_FILE="${PROJECT_PATH}/.opencode/.codebase-index-hook.pid"
LOG_FILE="${PROJECT_PATH}/.opencode/.codebase-index-hook.log"

# node must be installed
if ! command -v node >/dev/null 2>&1; then
  exit 0
fi

# .opencode/codebase-index.json must exist (project configured)
if [[ ! -f "${PROJECT_PATH}/.opencode/codebase-index.json" ]]; then
  exit 0
fi

# Ollama must be reachable
if ! curl -sf http://127.0.0.1:17434/v1/models >/dev/null 2>&1; then
  exit 0
fi

# Kill any running codebase-index process for this project
if [[ -f "${PID_FILE}" ]]; then
  OLD_PID="$(cat "${PID_FILE}" 2>/dev/null || true)"
  if [[ -n "${OLD_PID}" ]] && kill -0 "${OLD_PID}" 2>/dev/null; then
    OLD_CMD="$(ps -p "${OLD_PID}" -o command= 2>/dev/null || true)"
    if [[ "${OLD_CMD}" == *codebase-index* || "${OLD_CMD}" == *node* ]]; then
      kill "${OLD_PID}" 2>/dev/null || true
      sleep 0.2
    fi
  fi
  rm -f "${PID_FILE}"
fi

# Rotate log file if it exceeds ~100 KB
if [[ -f "${LOG_FILE}" ]] && [[ "$(wc -c < "${LOG_FILE}" 2>/dev/null || echo 0)" -gt 102400 ]]; then
  tail -n 50 "${LOG_FILE}" > "${LOG_FILE}.tmp" && mv "${LOG_FILE}.tmp" "${LOG_FILE}" || true
fi

# Resolve MCP binary
MCP_BIN=$(npx -y -p opencode-codebase-index -p @modelcontextprotocol/sdk which opencode-codebase-index-mcp 2>/dev/null || true)
if [[ -z "${MCP_BIN}" ]]; then
  exit 0
fi
MCP_SCRIPT=$(readlink -f "${MCP_BIN}")

# Launch codebase-index rebuild in background with nohup.
# The indexer is inherently incremental — only changed files are re-embedded.
(
  echo "${BASHPID}" > "${PID_FILE}"

  echo "[$(date '+%Y-%m-%d %H:%M:%S')] codebase-index update started" >> "${LOG_FILE}"

  nohup node - "${MCP_SCRIPT}" "${PROJECT_PATH}" <<'NODE_SCRIPT' >> "${LOG_FILE}" 2>&1
const { spawn } = require('child_process');
const [,, mcpScript, projectDir] = process.argv;

const child = spawn('node', [mcpScript, '--project', projectDir], {
  stdio: ['pipe', 'pipe', 'pipe'],
});

let stdoutBuf = '';
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
      clientInfo: { name: 'post-commit-hook', version: '1.0.0' },
    },
  });
}

let indexCallId = null;

child.stdout.on('data', (chunk) => {
  stdoutBuf += chunk.toString();
  const lines = stdoutBuf.split('\n');
  stdoutBuf = lines.pop();
  for (const line of lines) {
    if (!line.trim()) continue;
    let msg;
    try { msg = JSON.parse(line); } catch { continue; }

    // initialize response → send notifications/initialized + start indexing
    if (!initialized && msg.result && msg.result.protocolVersion !== undefined) {
      initialized = true;
      send({ jsonrpc: '2.0', method: 'notifications/initialized', params: {} });
      indexCallId = requestId;
      send({
        jsonrpc: '2.0',
        id: requestId++,
        method: 'tools/call',
        params: { name: 'index_codebase', arguments: {} },
      });
      continue;
    }

    // index response → done
    if (msg.id === indexCallId && msg.result && Array.isArray(msg.result.content)) {
      const text = msg.result.content.map(c => c.text || '').join('');
      process.stdout.write(text + '\n');
      child.stdin.end();
      continue;
    }

    // error
    if (msg.error) {
      process.stderr.write('MCP error: ' + JSON.stringify(msg.error) + '\n');
      child.stdin.end();
      process.exitCode = 1;
    }
  }
});

child.stderr.on('data', () => {});
child.on('close', (code) => {
  if (code !== 0 && process.exitCode !== 1) {
    process.stderr.write('MCP server exited with code ' + code + '\n');
    process.exitCode = 1;
  }
});

sendInitialize();
NODE_SCRIPT

  echo "[$(date '+%Y-%m-%d %H:%M:%S')] codebase-index update finished (exit $?)" >> "${LOG_FILE}"

  # Only remove PID file if it still contains our PID
  if [[ "$(cat "${PID_FILE}" 2>/dev/null || true)" == "${BASHPID}" ]]; then
    rm -f "${PID_FILE}"
  fi
) &

BGPID=$!

# Detach completely
disown "${BGPID}" 2>/dev/null || true
