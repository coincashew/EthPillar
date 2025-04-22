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

# Enable 2fa only if ssh keys are present
[[ ! $(grep -E '^ssh-([a-zA-Z0-9]+)' ~/.ssh/authorized_keys) ]] && echo "⚠️ Please setup SSH key authentication first by adding your public key to authorized_keys. Enter to continue." && read && exit 1

# Check if the user is root
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root. Please use sudo."
  exit 1
fi

clear
echo "########################################################################################"
echo "2FA: Secure your SSH access with two-factor authentication"
echo "########################################################################################"
echo "Key Points:"
echo "* Enhanced Access Control: Requires two verification factors (e.g., SSH key + time-based code)."
echo "* Mitigates Credential Theft: Renders stolen passwords/SSH keys useless without the second factor."
echo "* Phishing/Keylogger Resistance: Time-sensitive codes prevent reuse, thwarting most phishing and keylogging attacks."
echo "* ⚠️ Critical Note: Always test 2FA in a parallel session to avoid accidental lockouts."
echo ""

function install(){
echo "Do you wish to install? [y|n]"
read -rsn1 yn
[[ ! ${yn} = [Yy]* ]] && exit 0

# Install required package
echo "🔧 Installing libpam-google-authenticator..."
apt-get update -qq && apt-get install -y libpam-google-authenticator

# Generate Google Authenticator credentials
echo "🔐 Generating 2FA credentials..."
google-authenticator -C -t -d -f -r 3 -R 30 -w 3

# Create SSH config directory if it doesn't exist
echo "🔧 Creating SSH config directory..."
mkdir -p /etc/ssh/sshd_config.d

# Backup original PAM config
cp /etc/pam.d/sshd /etc/pam.d/sshd.bak

# Configure PAM
echo "📝 Configuring PAM..."
echo "auth required pam_google_authenticator.so" >> /etc/pam.d/sshd
sed -i 's/^@include common-auth/#@include common-auth/' /etc/pam.d/sshd
echo "📝 PAM configuration saved to /etc/pam.d/sshd"

# Configure SSH
echo "🔧 Creating custom SSH configuration..."
echo "ChallengeResponseAuthentication yes
UsePAM yes
AuthenticationMethods publickey,keyboard-interactive" > /etc/ssh/sshd_config.d/two-factor.conf
echo "🔧 SSH configuration saved to /etc/ssh/sshd_config.d/two-factor.conf"

# Restart SSH service
echo "🔄 Restarting SSH service..."
systemctl restart ssh

echo -e "\n✅ Setup complete! Scan the QR code above with your 2FA app (i.e. Aegis, Google Authenticator)"
echo "⚠️  IMPORTANT: Keep your backup codes safe!"
echo "⚠️  Test connection in new terminal before closing this session!"
}

function uninstall(){
# Safety warning
echo "🔐 2FA is currently ENABLED!"
echo "WARNING: Disabling 2FA reduces security!"
read -p "Continue to uninstall 2FA? (y/N) " -n 1 -r
echo
[[ ! $REPLY =~ ^[Yy]$ ]] && exit 0

# Restore original PAM config
if [ -f /etc/pam.d/sshd.bak ]; then
    echo "🔙 Restoring PAM configuration..."
    mv /etc/pam.d/sshd.bak /etc/pam.d/sshd
else
    echo "🔧 Removing 2FA from PAM..."
    sed -i '/pam_google_authenticator.so/d' /etc/pam.d/sshd
    sed -i 's/^#@include common-auth/@include common-auth/' /etc/pam.d/sshd
fi

# Remove custom SSH config
echo "🔙 Removing custom SSH configuration..."
rm -f /etc/ssh/sshd_config.d/two-factor.conf

# Restart SSH service
echo "🔄 Restarting SSH service..."
systemctl restart ssh

echo -e "\n✅ 2FA disabled. Test connection before closing this session!"
}

# Check for 2FA installation and offer to uninstall, otherwise install.
if grep -q --ignore-case -oE "pam_google_authenticator.so" /etc/pam.d/sshd || \
   [ -f /etc/ssh/sshd_config.d/two-factor.conf ]; then
    uninstall
else
    install
fi
echo "Press ENTER to return to menu"
read