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

set -e

# Check if the user is root
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root. Please use sudo."
  exit 1
fi

clear
echo "########################################################################################"
echo "Unattended-upgrades: Automatically install security updates"
echo "########################################################################################"
echo "Key Points:"
echo "* Automatic Updates: Installs security updates and important updates without requiring user input."
echo "* Convenience: This is particularly helpful for managing nodes, eliminating the need for manual update processes."
echo "* Security: By keeping systems up to date, this helps maintain system security and protect against vulnerabilities."
echo ""
echo "Do you wish to install? [y|n]"
read -rsn1 yn
if [[ ! ${yn} = [Yy]* ]]; then
    exit 0
fi

# Install required package
apt-get update && apt-get install -y unattended-upgrades

# Configure automatic security updates
CONFIG_FILE="/etc/apt/apt.conf.d/50unattended-upgrades"
BACKUP_FILE="${CONFIG_FILE}.bak"

# Create backup of original config
cp "${CONFIG_FILE}" "${BACKUP_FILE}"

# Modify configuration using sed
sed -i \
  -e 's/^\/\/\s*"\${distro_id}:\${distro_codename}-security";/        "\${distro_id}:\${distro_codename}-security";/' \
  -e 's/^\/\/\s*"origin=Debian";/        "origin=Ubuntu";/' \
  -e 's/^\/\/Unattended-Upgrade::AutoFixInterruptedDpkg/Unattended-Upgrade::AutoFixInterruptedDpkg/' \
  -e 's/^\/\/Unattended-Upgrade::Remove-Unused-Dependencies/Unattended-Upgrade::Remove-Unused-Dependencies/' \
  "${CONFIG_FILE}"

# Configure update intervals
cat > /etc/apt/apt.conf.d/20auto-upgrades <<EOF 
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
EOF

# Configure email notifications
read -p "Enter email for system notifications (leave blank for none): " EMAIL
if [ -n "$EMAIL" ]; then
  sed -i \
    -e "s/^\/\/Unattended-Upgrade::Mail\s*/Unattended-Upgrade::Mail \"$EMAIL\";/" \
    -e 's/^\/\/Unattended-Upgrade::MailReport/Unattended-Upgrade::MailReport "on-change";/' \
    "${CONFIG_FILE}"
fi

# Test configuration
unattended-upgrade --dry-run --debug

# Enable and restart service
systemctl enable unattended-upgrades
systemctl restart unattended-upgrades

echo "Unattended upgrades configured successfully!"
echo "Original configuration backed up to: ${BACKUP_FILE}"
echo "Recommended next steps:"
echo "1. Install mailutils for email notifications: apt install mailutils"
echo "2. Review configuration: ${CONFIG_FILE}"
echo "3. Monitor logs: journalctl -u unattended-upgrades"

#Test Email Functionality: Test email is working with 
#echo "Test email body" | mail -s "Test Subject" your@email.com

echo "Press ENTER to return to menu"    
read