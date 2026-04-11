#!/usr/bin/env bash
# Install Homebrew on macOS.

set -euo pipefail

step "Installing Homebrew on macOS..."
NONINTERACTIVE=1 /bin/bash -c \
  "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

if command -v brew &>/dev/null; then
  log "Homebrew installed successfully — $(brew --version | head -1)"
else
  error "Homebrew installation failed. Check the output above."
fi
