#!/usr/bin/env bash
# =============================================================================
# setup-ai-memory.sh
# Idempotent installer for the full PHP AI coding stack.
# Supports: macOS (Apple Silicon + Intel) and Linux Mint / Ubuntu / Debian.
# Safe to re-run at any time, in any project directory.
#
# Tools installed:
#   Ollama + nomic-embed-text   — local embeddings
#   Ogham MCP + Postgres        — semantic agent memory
#   Graphify                    — codebase knowledge graph
#   opencode-codebase-index     — semantic codebase search (MCP)
#   cass                        — agent session history search
#   Obsidian MCP (Docker)       — knowledge vault bridge
#
# Usage:
#   ./setup-ai-memory.sh            # first run OR re-run in a new project
#   ./setup-ai-memory.sh --status   # show what is/isn't installed
# =============================================================================

set -euo pipefail

INSTALL_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")/../src/install" && pwd)"
export INSTALL_PATH

exec bash "${INSTALL_PATH}/run.sh" "$@"
