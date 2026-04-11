#!/usr/bin/env bash
# Install Docker Desktop on macOS via Homebrew.

set -euo pipefail

step "Installing Docker Desktop via Homebrew..."
brew install --cask docker

step "Opening Docker Desktop..."
open -a Docker

info "Waiting for Docker Desktop to start..."
retry_count=0
max_retries=30
until docker info &>/dev/null 2>&1; do
  if (( retry_count >= max_retries )); then
    error "Docker Desktop did not start within expected time. Please start it manually."
  fi
  ((retry_count++))
  sleep 2
done

log "Docker Desktop is running — $(docker --version)"
