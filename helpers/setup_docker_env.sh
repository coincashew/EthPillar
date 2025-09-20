#!/bin/bash

# Setup environment variables for rootless Docker
cat > /etc/profile.d/docker-rootless.sh << 'EOF'
# Docker rootless mode configuration
export DOCKER_HOST="unix:///run/user/$(id -u)/docker.sock"
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
export PATH=/usr/bin:$PATH
EOF

# Make the script executable
chmod +x /etc/profile.d/docker-rootless.sh

# Create systemd user directory
mkdir -p ~/.config/systemd/user/

# Update systemd user service for rootless Docker
cat > ~/.config/systemd/user/docker.service << EOF
[Unit]
Description=Docker Application Container Engine (Rootless)
Documentation=https://docs.docker.com/engine/security/rootless/

[Service]
Environment=PATH=/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin
Environment=DOCKER_HOST=unix:///run/user/$(id -u)/docker.sock
ExecStart=/usr/bin/dockerd-rootless
ExecReload=/bin/kill -s HUP \$MAINPID
TimeoutSec=0
RestartSec=2
Restart=always
StartLimitBurst=3
StartLimitInterval=60s
LimitNOFILE=infinity
LimitNPROC=infinity
LimitCORE=infinity
TasksMax=infinity
Delegate=yes
Type=simple

[Install]
WantedBy=default.target
EOF

# Reload systemd user daemon
systemctl --user daemon-reload

# Start and enable rootless Docker service
systemctl --user enable docker
systemctl --user start docker

echo "✅ Docker rootless environment setup complete"
echo "⚠️ Log out and back in for changes to take effect"