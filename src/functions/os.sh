#!/usr/bin/env bash

os.get_os() {
  if [[ "$(uname -s)" == "Darwin" ]]; then
    echo 'macos'
  elif [[ "$(uname -s)" == "Linux" ]]; then
    echo 'linux'
  else
    echo 'windows'
  fi
}

os.get_distribution() {
  # shellcheck disable=SC1091
  . /etc/os-release
  echo "${ID}"
}

os.get_arch() {
  local arch
  arch="$(uname -m)"
  case "$arch" in
    x86_64|amd64)  echo "x86_64"  ;;
    aarch64|arm64) echo "arm64"   ;;
    *)
      echo "Unsupported architecture: $arch. Supported: x86_64, amd64, aarch64, arm64" >&2
      exit 1
      ;;
  esac
}

os.version_to_number() {
  local version="$1"
  local IFS=.
  # shellcheck disable=SC2086
  set -- $version
  local major="${1:-0}"
  local minor="${2:-0}"
  local patch="${3:-0}"
  echo $((10#$major * 10000 + 10#$minor * 100 + 10#$patch))
}

# Portable in-place sed — works on both macOS (BSD sed) and Linux (GNU sed)
# Usage: os.sed_i "s|old|new|" file
#        os.sed_i -e "s|a|b|" -e "s|c|d|" file
os.sed_i() {
  if [[ "$(uname -s)" == "Darwin" ]]; then
    sed -i '' "$@"
  else
    sed -i "$@"
  fi
}

# os.has_gpu — returns 0 if usable GPU acceleration is available on the host.
#
# Linux: nvidia-smi must exist AND succeed (driver loaded, GPU present).
# macOS: Apple Silicon (arm64) — Metal acceleration available for llama.cpp tools.
#        Note: Docker on macOS does NOT support GPU passthrough.
os.has_gpu() {
  local current_os
  current_os="$(os.get_os)"
  case "${current_os}" in
    linux)
      command -v nvidia-smi &>/dev/null && nvidia-smi &>/dev/null
      ;;
    macos)
      [[ "$(uname -m)" == "arm64" ]]
      ;;
    *)
      return 1
      ;;
  esac
}

# os.has_docker_gpu — returns 0 if Docker GPU passthrough is available.
#
# Linux only: os.has_gpu() must pass AND the NVIDIA Container Toolkit must be
#   installed (detected via `docker info` or /usr/bin/nvidia-container-toolkit).
# macOS: always returns 1 (false) — Docker Desktop does not support GPU passthrough.
os.has_docker_gpu() {
  local current_os
  current_os="$(os.get_os)"
  if [[ "${current_os}" != "linux" ]]; then
    return 1
  fi
  if ! os.has_gpu; then
    return 1
  fi
  docker info 2>/dev/null | grep -qi nvidia \
    || [[ -x "/usr/bin/nvidia-container-toolkit" ]]
}

# Detect Docker bridge gateway for Linux (replaces host.docker.internal)
os.docker_host() {
  if [[ "$(os.get_os)" == "macos" ]]; then
    echo "host.docker.internal"
  else
    docker network inspect bridge \
      --format '{{range .IPAM.Config}}{{.Gateway}}{{end}}' 2>/dev/null \
      || echo "172.17.0.1"
  fi
}
