#!/bin/bash

set -euo pipefail

ROOTLESS=${ROOTLESS:-false}

echo "🔄 Updating and upgrading all system packages..."
sudo apt update -y && sudo apt upgrade -y

echo "🧹 Removing old or conflicting Docker packages..."
for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do sudo apt-get remove -y $pkg; done

if [[ "$ROOTLESS" == "true" ]]; then
  echo "🐳 Installing Docker (rootless mode)..."
  sudo apt-get install -y uidmap dbus-user-session
  # Follow Docker rootless install script
  curl -fsSL https://get.docker.com/rootless | sh
  echo "💡 To use rootless docker, add the following to your shell profile if not present:"
  echo "    export PATH=\"$HOME/bin:$PATH\""
  echo "    export DOCKER_HOST=unix://$XDG_RUNTIME_DIR/docker.sock"
  echo "🎉 Rootless Docker installed. Start a new shell to pick up PATH changes."
else
  echo "🔑 Adding Docker’s official GPG key..."
  sudo install -m 0755 -d /etc/apt/keyrings
  sudo apt-get install -y ca-certificates curl gnupg
  source /etc/os-release
  curl -fsSL https://download.docker.com/linux/${ID}/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  sudo chmod a+r /etc/apt/keyrings/docker.gpg

  echo "📚 Adding Docker’s official repository..."
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/${ID} \
    ${VERSION_CODENAME} stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  echo "🔄 Updating and upgrading all system packages again (with Docker repo)..."
  sudo apt update -y && sudo apt upgrade -y

  echo "🐳 Installing Docker Engine, CLI, containerd, Buildx, and Compose plugin..."
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

  echo "🚦 Enabling and starting Docker service..."
  sudo systemctl enable docker
  sudo systemctl restart docker

  echo "🎉 Docker and Docker Compose are fully installed and up to date!"
fi

# Create a user bridge network used by EthPillar plugins (idempotent).
echo "🌐 Ensuring docker network 'ethpillar_default' exists..."
# Prefer the user's docker command if rootless; fall back to sudo for system Docker
if command -v docker >/dev/null 2>&1; then
  DOCKER_CMD=docker
else
  DOCKER_CMD="sudo docker"
fi

# Try to inspect the network; create if missing. Use the DOCKER_CMD so this works for rootless and system installs.
${DOCKER_CMD} network inspect ethpillar_default >/dev/null 2>&1 || ${DOCKER_CMD} network create ethpillar_default >/dev/null
echo "✅ Network 'ethpillar_default' is ready."