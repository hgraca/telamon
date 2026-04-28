#!/usr/bin/env bash

# Install apt packages only if they are not already present.
apt.install() {
  local missing=()
  for pkg in "$@"; do
    dpkg -s "$pkg" &>/dev/null || missing+=("$pkg")
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    step "apt install: ${missing[*]}"
    sudo apt-get install -y "${missing[@]}"
  fi
}
