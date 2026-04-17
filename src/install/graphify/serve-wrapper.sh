#!/usr/bin/env bash
# MCP wrapper for graphify.serve — checks for graph.json before starting.
# TELAMON_ROOT is injected via the MCP environment block.
set -euo pipefail

GRAPH_FILE="${1:?Usage: serve-wrapper.sh <path-to-graph.json>}"
if [[ ! -f "${GRAPH_FILE}" ]]; then
  echo "graphify: no graph.json found at ${GRAPH_FILE} — MCP server not starting" >&2
  exit 0
fi

PYTHON="$(cat "${TELAMON_ROOT}/storage/secrets/graphify-python")"
exec "${PYTHON}" -m graphify.serve "${GRAPH_FILE}"
