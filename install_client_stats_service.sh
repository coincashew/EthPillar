#!/bin/bash

# Copy the service file to systemd directory
sudo cp client-stats.service /etc/systemd/system/

# Reload systemd to recognize the new service
sudo systemctl daemon-reload

# Enable the service to start on boot
sudo systemctl enable client-stats

# Start the service
sudo systemctl start client-stats

echo "Prysm client-stats service has been installed and started." 