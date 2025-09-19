#!/bin/bash

set -e

echo "🔄 Updating and upgrading all system packages..."
sudo apt update -y && sudo apt upgrade -y

echo "🧹 Removing old or conflicting Docker packages..."
for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do sudo apt-get remove -y $pkg; done

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