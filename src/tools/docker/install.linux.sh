#!/usr/bin/env bash
# Install Docker Engine on Linux (Ubuntu / Linux Mint / Debian).
# Supports Linux Mint (maps to Ubuntu codename), Ubuntu, and Debian.

set -euo pipefail

DISTRIBUTION="$(os.get_distribution)"

# Determine the Ubuntu-compatible apt codename
case "${DISTRIBUTION}" in
  linuxmint)
    MINT_VERSION=$(lsb_release -cs)
    case "${MINT_VERSION}" in
      vanessa|vera)   UBUNTU_CODENAME="focal"  ;;  # Mint 20.x
      victoria|virginia|wilma) UBUNTU_CODENAME="jammy" ;; # Mint 21.x
      *)              UBUNTU_CODENAME="jammy"  ;;  # default fallback
    esac
    ;;
  ubuntu)
    UBUNTU_CODENAME=$(lsb_release -cs)
    ;;
  debian)
    UBUNTU_CODENAME=$(. /etc/os-release && echo "${VERSION_CODENAME}")
    ;;
  *)
    error "Cannot install Docker on distribution '${DISTRIBUTION}'. Supported: ubuntu, linuxmint, debian."
    ;;
esac

info "Using Docker apt repo with codename: ${UBUNTU_CODENAME}"

step "Removing old Docker versions (if any)..."
sudo apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

step "Installing prerequisites..."
apt.install ca-certificates curl gnupg lsb-release apt-transport-https software-properties-common

step "Adding Docker official GPG key..."
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

step "Adding Docker apt repository..."
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu ${UBUNTU_CODENAME} stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

step "Updating package index with Docker repo..."
sudo apt-get update -qq

step "Installing Docker Engine, CLI, containerd, and Compose plugin..."
apt.install docker-ce docker-ce-cli containerd.io docker-compose-plugin

step "Adding ${USER} to docker group..."
sudo usermod -aG docker "$USER"
warn "Added ${USER} to docker group. You may need to log out and back in."

step "Enabling and starting Docker service..."
sudo systemctl enable --now docker

log "Docker $(docker --version) installed"
log "Docker Compose $(docker compose version) installed"
