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

# Exit on first error
set -e

# Check if the user is root
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root. Please use sudo."
  exit 1
fi

clear
echo "########################################################################################"
echo "Swappiness: How aggressively Linux swaps pages between memory and the swap space"
echo "########################################################################################"
echo "Key Points:"
echo "* Linux systems tend to heavily utilize swap space by default"
echo "* This can negatively impact performance-sensitive applications, such as Ethereum nodes"
echo "* Benefits: Systems > 16GB RAM improve performance by setting 'swappiness' value to 1"
echo "* Defaults: Swappiness value on most Linux distributions is 60"
echo "* Valid Values: Swappiness value can be set between 0 and 100"
echo ""
while true; do
  read -r -p "${tty_blue}Enter your swappiness value: (Press enter to use default, 1)${tty_reset} " SWAPPINESS_VALUE
  # Default swappiness to 1
  SWAPPINESS_VALUE=${SWAPPINESS_VALUE:-1}
  # Validate swappiness value
  if [[ "$SWAPPINESS_VALUE" =~ ^-?[0-9]+$ ]] && (( "$SWAPPINESS_VALUE" >= 0 && "$SWAPPINESS_VALUE" <= 100 )); then
    break
  else
    echo "ERROR: Swappiness value must be a number between 0 and 100"
  fi
done

echo "INFO: Setting vm.swappiness to $SWAPPINESS_VALUE"

# Create sysctl.d directory if it doesn't exist
sudo mkdir -p /etc/sysctl.d

# Create or update the swappiness configuration file
echo "vm.swappiness=$SWAPPINESS_VALUE" | sudo tee /etc/sysctl.d/99-swappiness.conf > /dev/null

# Apply the new setting
sudo sysctl -p /etc/sysctl.d/99-swappiness.conf

echo "INFO: Configuration saved to /etc/sysctl.d/99-swappiness.conf"
echo "INFO: Successfully set vm.swappiness to $SWAPPINESS_VALUE"
echo "Press ENTER to return to menu"
read