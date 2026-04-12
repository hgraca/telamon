#!/usr/bin/env bash
# Post-compose service setup: apply DB schema, configure Ogham,
# pull the embedding model, init cass, and enable reranking.
# Run after 'docker compose up' has brought services healthy.
# Idempotent: each step checks state flags or skips if already done.
#
# Credentials are loaded from STATE_DIR/setup-inputs (written by run.sh).

set -euo pipefail

INSTALL_PATH="${INSTALL_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
STATE_DIR="${STATE_DIR:-$HOME/.config/ogham}"
# shellcheck disable=SC1091
. "${INSTALL_PATH}/functions/autoload.sh"

# Load saved credentials if not already exported
if [[ -z "${POSTGRES_PASSWORD:-}" || -z "${OGHAM_PROFILE:-}" ]]; then
  if [[ -f "${STATE_DIR}/setup-inputs" ]]; then
    # shellcheck disable=SC1091
    source "${STATE_DIR}/setup-inputs"
    POSTGRES_PASSWORD="${SAVED_POSTGRES_PASSWORD:?POSTGRES_PASSWORD not found in setup-inputs}"
    OGHAM_PROFILE="${SAVED_OGHAM_PROFILE:?OGHAM_PROFILE not found in setup-inputs}"
    export POSTGRES_PASSWORD OGHAM_PROFILE
  else
    echo "Error: ${STATE_DIR}/setup-inputs not found. Run src/install/run.sh first." >&2
    exit 1
  fi
fi

# Pull nomic-embed-text into the ollama container (idempotent)
if ! docker exec adk-ollama ollama list 2>/dev/null | grep -q "nomic-embed-text"; then
  step "Pulling nomic-embed-text into Ollama container..."
  docker exec adk-ollama ollama pull nomic-embed-text
  log "Embedding model ready"
else
  skip "nomic-embed-text (already in Ollama container)"
fi

bash "${INSTALL_PATH}/ogham/apply-schema.sh"
bash "${INSTALL_PATH}/ogham/init.sh"
bash "${INSTALL_PATH}/cass/init.sh"
bash "${INSTALL_PATH}/ogham/enable-reranking.sh"
