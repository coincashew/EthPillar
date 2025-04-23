#!/bin/bash

# Author: coincashew.eth | coincashew.com
# License: GNU GPL
# Source: https://github.com/coincashew/ethpillar
#
# Made for home and solo stakers 🏠🥩

######################################################################
# Patch 2 : Fix terminal formatting issues - strange chars, missing emojis
# If you installed EthPillar before v4.4.0, run this to patch
######################################################################

detect_os() {
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    case "$ID" in
      debian|ubuntu|raspbian)
        echo "debian"
        ;;
      *)
        echo "unsupported"
        ;;
    esac
  else
    echo "unsupported"
  fi
}

OS=$(detect_os)

if [ "$OS" = "unsupported" ]; then
  echo "❌ Patch 2: Unsupported OS=$OS"
  exit 1
fi

echo "📦 Running Locale patch to fix terminal formatting issues..."

# Get the current locale setting
current_locale=$(locale | grep '^LANG=' | awk -F= '{print $2}')

# Check if the current locale contains "UTF"
if [[ "$current_locale" == *"UTF"* ]]; then
    echo "✅ Patch 2: Locale is UTF compatible. No patching required."
    # Flag patch as completed
    sudo mkdir -p /opt/ethpillar/patches
    touch 002-locale.completed && sudo mv 002-locale.completed /opt/ethpillar/patches
else
    echo "Locale not set. Patching..."
    sudo update-locale "LANG=en_US.UTF-8"
    sudo locale-gen --purge "en_US.UTF-8"
    sudo dpkg-reconfigure --frontend noninteractive locales
    echo "Updated locale to en_US.UTF-8"
    echo "Logout and login for terminal locale updates to take effect."
    echo "✅ Patch 2: Locale patching complete"
fi