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

set -euo pipefail
trap 'echo -e "\n❌ Operation aborted."; exit 1' INT

clear
echo "########################################################################################"
echo "2FA: Secure your SSH access with two-factor authentication"
echo "########################################################################################"
echo "Key Points:"
echo "* Enhanced Access Control: Requires two verification factors (e.g., SSH key + time-based code)."
echo "* Mitigates Credential Theft: Renders stolen passwords/SSH keys useless without the second factor."
echo "* Phishing/Keylogger Resistance: Time-sensitive codes prevent reuse, thwarting most phishing and keylogging attacks."
echo "* ⚠️  Critical Note: Always test 2FA in a parallel session to avoid accidental lockouts."
echo ""

function check_ssh_config() {
    echo "🧪 Validating SSH configuration..."
    if ! sudo sshd -t; then
        echo "❌ SSH configuration is invalid. Aborting to avoid lockout."
        exit 1
    fi
}

function install() {
    echo "🔐 SSH 2FA Setup: Proceed with installation? [y/N]"
    read -rsn1 yn
    [[ ! ${yn:-n} =~ ^[Yy]$ ]] && exit 0

    echo "🔧 Installing required package..."
    sudo apt-get update -qq
    sudo apt-get install -y libpam-google-authenticator

    echo "🔐 Generating 2FA credentials..."
    if [[ -f ~/.google_authenticator ]]; then
        echo "⚠️  Existing 2FA config detected for this user."
        echo "Overwrite? This will invalidate your current setup. [y/N]"
        read -rsn1 ow
        [[ ! ${ow:-n} =~ ^[Yy]$ ]] && exit 0
    fi
    google-authenticator -t -d -f -r 3 -R 30 -w 3

    echo "📁 Ensuring SSH config directory exists..."
    sudo mkdir -p /etc/ssh/sshd_config.d

    echo "📝 Backing up PAM SSH config..."
    sudo cp /etc/pam.d/sshd /etc/pam.d/sshd.bak

    echo "🔧 Configuring PAM for 2FA..."
    if ! grep -q "pam_google_authenticator.so" /etc/pam.d/sshd; then
        echo "auth required pam_google_authenticator.so" | sudo tee -a /etc/pam.d/sshd
    fi
    sudo sed -i "s/^@include common-auth/#@include common-auth/" /etc/pam.d/sshd

    echo "🛡️  Creating SSH 2FA config..."
    sudo tee /etc/ssh/sshd_config.d/two-factor.conf > /dev/null <<EOF
ChallengeResponseAuthentication yes
UsePAM yes
AuthenticationMethods publickey,keyboard-interactive
EOF

    # Check if Include directive is present and not commented out
    if grep -q "^#Include /etc/ssh/sshd_config.d/\*.conf" /etc/ssh/sshd_config; then
        echo "❌ Include directive is commented out in /etc/ssh/sshd_config"
        echo "✏️  Uncommenting Include directive..."
        sudo sed -i 's|^#Include /etc/ssh/sshd_config.d/\*.conf|Include /etc/ssh/sshd_config.d/*.conf|' /etc/ssh/sshd_config
    elif ! grep -q "^Include /etc/ssh/sshd_config.d/\*.conf" /etc/ssh/sshd_config; then
        echo "❌ Required Include directive not found in /etc/ssh/sshd_config"
        echo "✏️  Adding Include directive..."
        echo "Include /etc/ssh/sshd_config.d/*.conf" | sudo tee -a /etc/ssh/sshd_config
    fi
    
    # Ensure KbdInteractiveAuthentication is explicitly enabled
    if grep -qE "^[[:space:]]*#?[[:space:]]*KbdInteractiveAuthentication" /etc/ssh/sshd_config; then
        echo "🪛 Normalizing KbdInteractiveAuthentication to 'yes' in /etc/ssh/sshd_config"
        sudo sed -ri 's|^[[:space:]]*#?[[:space:]]*KbdInteractiveAuthentication.*|KbdInteractiveAuthentication yes|' /etc/ssh/sshd_config
    else
        echo "🪛 Adding KbdInteractiveAuthentication yes to /etc/ssh/sshd_config"
        echo "KbdInteractiveAuthentication yes" | sudo tee -a /etc/ssh/sshd_config
    fi
    check_ssh_config

    echo "🔄 Restarting SSH service..."
    sudo systemctl restart ssh

    echo -e "\n✅ 2FA setup complete!"
    echo "⚠️  Verify login in another terminal before logging out of this session!"
}

function uninstall() {
    echo "🔐 2FA is currently ENABLED."
    echo "⚠️  WARNING: Disabling 2FA reduces security!"
    echo "⚠️  Proceed to uninstall and disable 2FA? [y/N]"
    read -rsn1 yn
    [[ ! ${yn:-n} =~ ^[Yy]$ ]] && exit 0

    if [[ -f /etc/pam.d/sshd.bak ]]; then
        echo "🔙 Restoring original PAM configuration..."
        sudo mv /etc/pam.d/sshd.bak /etc/pam.d/sshd
    else
        echo "🔧 Cleaning PAM config manually..."
        sudo sed -i "/pam_google_authenticator.so/d" /etc/pam.d/sshd
        sudo sed -i "s/^#@include common-auth/@include common-auth/" /etc/pam.d/sshd
    fi

    echo "🧹 Removing SSH 2FA config..."
    sudo rm -f /etc/ssh/sshd_config.d/two-factor.conf

    echo "🗑️  Do you also want to delete your 2FA secret file? (~/.google_authenticator)?"
    echo "⚠️  WARNING: This will invalidate your current 2FA setup! - This is irreversible!!"
    echo "⚠️  Proceed to delete your 2FA secret file? [y/N]"
    read -rsn1 del
    echo
    if [[ ${del:-n} =~ ^[Yy]$ ]]; then
        rm -f ~/.google_authenticator
        echo "✅ 2FA secret file deleted."
    else
        echo "ℹ️  2FA config file retained."
    fi

    check_ssh_config

    echo "🔄 Restarting SSH service..."
    sudo systemctl restart ssh

    echo -e "\n✅ 2FA has been disabled."
    echo "⚠️  Verify login in another terminal before logging out of this session!"
}

# Entry point
if grep -q "pam_google_authenticator.so" /etc/pam.d/sshd || [[ -f /etc/ssh/sshd_config.d/two-factor.conf ]]; then
    uninstall
else
    install
fi

echo "Press ENTER to return to menu"
read