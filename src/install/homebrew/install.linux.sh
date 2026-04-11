#!/usr/bin/env bash
# Install Linuxbrew (Homebrew for Linux).

set -euo pipefail

step "Installing build dependencies for Homebrew..."
apt.install build-essential curl file git

step "Installing Linuxbrew..."
NONINTERACTIVE=1 /bin/bash -c \
  "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

if command -v brew &>/dev/null || [[ -f /home/linuxbrew/.linuxbrew/bin/brew ]]; then
  log "Linuxbrew installed successfully"
else
  error "Linuxbrew installation failed. Check the output above."
fi
