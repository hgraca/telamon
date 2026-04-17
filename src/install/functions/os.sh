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
