#!/bin/bash

set -e

# Get the current user
CURRENT_USER=$(whoami)

echo "🔄 Updating and upgrading all system packages..."
sudo apt update -y && sudo apt upgrade -y

echo "🧹 Removing old or conflicting Docker packages..."
for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do sudo apt-get remove -y $pkg; done

echo "🔑 Adding Docker's official GPG key..."
sudo install -m 0755 -d /etc/apt/keyrings
sudo apt-get install -y ca-certificates curl gnupg
source /etc/os-release
curl -fsSL https://download.docker.com/linux/${ID}/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo "📚 Adding Docker's official repository..."
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/${ID} \
  ${VERSION_CODENAME} stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

echo "🔄 Updating package lists..."
sudo apt-get update

echo "🐳 Installing Docker Engine, CLI, containerd, Buildx, and Compose plugin..."
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "� Setting up Docker rootless mode..."
# Install uidmap package for rootless mode
sudo apt-get install -y uidmap dbus-user-session

# Install Docker rootless setup tool
dockerd-rootless-setuptool.sh install

# Enable systemd lingering for the current user
sudo loginctl enable-linger $(whoami)

# Configure environment variables
echo '# Docker rootless mode configuration' >> ~/.bashrc
echo 'export PATH=/usr/bin:$PATH' >> ~/.bashrc
echo 'export DOCKER_HOST=unix:///run/user/$(id -u)/docker.sock' >> ~/.bashrc
echo 'export XDG_RUNTIME_DIR=/run/user/$(id -u)' >> ~/.bashrc

# Start Docker rootless daemon
systemctl --user enable docker
systemctl --user start docker

echo "🎉 Docker rootless mode is now configured!"
echo "⚠️  Please log out and log back in for all changes to take effect."
echo "💡 To verify rootless mode, run: docker info | grep 'rootless'"