#!/bin/bash

set -e

echo "👥 Setting up Docker rootless mode configuration..."

# Create necessary directories
mkdir -p ~/.config/systemd/user/
mkdir -p ~/.docker

# Set up Docker daemon configuration for rootless mode
cat > ~/.config/docker/daemon.json << EOF
{
    "data-root": "~/.local/share/docker",
    "features": {
        "buildkit": true
    },
    "experimental": true
}
EOF

# Set correct permissions
chmod 700 ~/.docker
chmod 600 ~/.config/docker/daemon.json

# Configure environment variables if not already set
if ! grep -q "DOCKER_HOST" ~/.bashrc; then
    echo '# Docker rootless mode configuration' >> ~/.bashrc
    echo 'export PATH=/usr/bin:$PATH' >> ~/.bashrc
    echo 'export DOCKER_HOST=unix:///run/user/$(id -u)/docker.sock' >> ~/.bashrc
    echo 'export XDG_RUNTIME_DIR=/run/user/$(id -u)' >> ~/.bashrc
fi

# Reload user systemd daemon
systemctl --user daemon-reload

# Restart Docker daemon in rootless mode
systemctl --user restart docker

echo "✅ Docker rootless mode configuration complete!"
echo "💡 To verify the setup, run: docker info | grep 'rootless'"
echo "⚠️  Remember to log out and log back in if this is your first time setting up rootless mode."