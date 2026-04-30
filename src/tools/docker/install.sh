#!/usr/bin/env bash
# Install Docker Engine (Linux) or Docker Desktop (macOS).
# Also ensures the daemon is running and sets up host.docker.internal on Linux.

set -euo pipefail

TOOLS_PATH="${TOOLS_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck disable=SC1091
. "${FUNCTIONS_PATH}/autoload.sh"

header "Docker"

OS=$(os.get_os)

if ! command -v docker &>/dev/null; then
  case "${OS}" in
    macos)
      # shellcheck disable=SC1091
      . "${TOOLS_PATH}/docker/install.macos.sh"
      ;;
    linux)
      # shellcheck disable=SC1091
      . "${TOOLS_PATH}/docker/install.linux.sh"
      ;;
    *)
      error "Unsupported OS: ${OS}. Supports macOS and Linux."
      ;;
  esac
  log "Docker installed"
else
  skip "Docker binary"
fi

# Ensure daemon is running
if ! docker info &>/dev/null 2>&1; then
  if [[ "${OS}" == "macos" ]]; then
    step "Starting Docker Desktop..."
    open -a Docker
    info "Waiting for Docker daemon (up to 90s)..."
    tries=0
    until docker info &>/dev/null 2>&1; do
      sleep 3; tries=$((tries+1))
      [[ $tries -gt 30 ]] && error "Docker did not start. Open Docker Desktop manually and re-run."
    done
  else
    step "Starting Docker service..."
    sudo systemctl start docker
    sleep 3
  fi
  log "Docker daemon running"
else
  skip "Docker daemon (already running)"
fi

# On Linux, ensure host.docker.internal resolves (needed for MCP containers)
if [[ "${OS}" == "linux" ]]; then
  if ! grep -q "host.docker.internal" /etc/hosts 2>/dev/null; then
    step "Adding host.docker.internal to /etc/hosts..."
    echo "172.17.0.1 host.docker.internal" | sudo tee -a /etc/hosts > /dev/null
    log "host.docker.internal → 172.17.0.1"
  else
    skip "host.docker.internal in /etc/hosts"
  fi
fi

# ── Detect Docker GPU passthrough ─────────────────────────────────────────────
ENV_FILE="${TELAMON_ROOT:?TELAMON_ROOT must be set}/.env"
DOCKER_GPU_CONFIG="$(config.read_ini "${TELAMON_ROOT}/.ai/telamon/telamon.jsonc" "docker_gpu_enabled" || echo "null")"
if [[ "${DOCKER_GPU_CONFIG}" == "true" ]]; then
  log "Docker GPU: force-enabled (telamon.jsonc)"
  os.sed_i "s|^GPU_ENABLED=.*|GPU_ENABLED=true|" "${ENV_FILE}"
  grep -q '^GPU_ENABLED=' "${ENV_FILE}" || echo 'GPU_ENABLED=true' >> "${ENV_FILE}"
  log "GPU_ENABLED=true written to .env"
elif [[ "${DOCKER_GPU_CONFIG}" == "false" ]]; then
  log "Docker GPU: force-disabled (telamon.jsonc)"
  os.sed_i "s|^GPU_ENABLED=.*|GPU_ENABLED=false|" "${ENV_FILE}"
  grep -q '^GPU_ENABLED=' "${ENV_FILE}" || echo 'GPU_ENABLED=false' >> "${ENV_FILE}"
  log "GPU_ENABLED=false written to .env"
else
  step "Detecting Docker GPU support..."
  if os.has_docker_gpu; then
    log "GPU acceleration: enabled (NVIDIA Container Toolkit detected)"
    os.sed_i "s|^GPU_ENABLED=.*|GPU_ENABLED=true|" "${ENV_FILE}"
    grep -q '^GPU_ENABLED=' "${ENV_FILE}" || echo 'GPU_ENABLED=true' >> "${ENV_FILE}"
    log "GPU_ENABLED=true written to .env"
  else
    log "GPU acceleration: disabled (no Docker GPU support detected)"
    os.sed_i "s|^GPU_ENABLED=.*|GPU_ENABLED=false|" "${ENV_FILE}"
    grep -q '^GPU_ENABLED=' "${ENV_FILE}" || echo 'GPU_ENABLED=false' >> "${ENV_FILE}"
  fi
fi
