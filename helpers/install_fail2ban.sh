#!/bin/bash
# Author: coincashew.eth | coincashew.com
# License: GNU GPL
# Source: https://github.com/coincashew/ethpillar
# Description: EthPillar is a one-liner setup tool and node management TUI
#
# Made for home and solo stakers 🏠🥩

# 🫶 Make improvements and suggestions on GitHub:
#    * https://github.com/coincashew/ethpillar
# 🙌 Ask questions on Discord:
#    * https://discord.gg/dEpAVWgFNB

# Check if the user is root
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root. Please use sudo."
  exit 1
fi

clear
echo "########################################################################################"
echo "Fail2Ban: Automatically protecting your node from common attack patterns"
echo "########################################################################################"
echo "Key Points:"
echo "* Monitors log files for suspicious activity (repeated login failures, brute force attacks)"
echo "* Fail2Ban automatically blocks malicious IPs"
echo ""
read -rp "Do you wish to install? [y|n]" yn
if [[ ! ${yn} = [Yy]* ]]; then
    exit 0
fi

# Prompt user to change SSH port
read -rp "Do you want to change the SSH port? [y/n] " change_port

if [[ "$change_port" == "y" ]]; then
  read -rp "Enter the new SSH port: " new_port
else
  new_port="22"
fi

# Install fail2ban
echo "Installing fail2ban..."
apt update && apt install -y fail2ban

# Create config file
config_path="/etc/fail2ban/jail.local"
echo "[sshd]
enabled = true
port = $new_port
filter = sshd
logpath = /var/log/auth.log
maxretry = 3" > $config_path

# Start fail2ban service
echo "Starting fail2ban service..."
systemctl start fail2ban

# Enable fail2ban service to start on boot
echo "Enabling fail2ban to start on boot..."
systemctl enable fail2ban

# Display success message
echo "SUCCESS: Fail2ban installation complete. SSH port set to $new_port."
echo "Press ENTER to return to menu"    
read