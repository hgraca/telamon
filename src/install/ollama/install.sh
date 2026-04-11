#!/usr/bin/env bash
# Install Ollama and pull the nomic-embed-text embedding model.

set -euo pipefail

INSTALL_PATH="${INSTALL_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
# shellcheck disable=SC1091
. "${INSTALL_PATH}/functions/autoload.sh"

header "Ollama"

OS=$(os.get_os)

if ! command -v ollama &>/dev/null; then
  if [[ "${OS}" == "macos" ]]; then
    step "Installing Ollama via Homebrew..."
    brew install ollama
  else
    step "Installing Ollama..."
    curl -fsSL https://ollama.com/install.sh | sh
  fi
  log "Ollama installed"
else
  skip "Ollama binary"
fi

# Start service
if ! pgrep -x ollama &>/dev/null; then
  step "Starting Ollama..."
  if [[ "${OS}" == "macos" ]]; then
    brew services start ollama
  else
    sudo systemctl enable --now ollama
  fi
  sleep 4
  log "Ollama started"
else
  skip "Ollama (already running)"
fi

# Pull embedding model
if ollama list 2>/dev/null | grep -q "nomic-embed-text"; then
  skip "nomic-embed-text model"
else
  step "Pulling nomic-embed-text (may take a few minutes)..."
  ollama pull nomic-embed-text
  log "Embedding model ready"
fi
