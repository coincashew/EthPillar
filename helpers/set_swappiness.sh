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
echo "Swappiness: How aggressively Linux swaps pages between memory and the swap space"
echo "########################################################################################"
echo "Key Points:"
echo "* Linux systems tend to heavily utilize swap space by default"
echo "* This can negatively impact performance-sensitive applications, such as Ethereum nodes"
echo "* Benefits: Systems > 16GB RAM improve performance by setting 'swappiness' value to 1"
echo "* Defaults: Swappiness value on most Linux distributions is 60"
echo "* Valid Values: Swappiness value can be set between 0 and 200"
echo ""
while true; do
  read -r -p "${tty_blue}Enter your swappiness value: (Press enter to use default, 1)${tty_reset} " SWAPPINESS_VALUE
  # Default swappiness to 1
  SWAPPINESS_VALUE=${SWAPPINESS_VALUE:-1}
  if [[ "$SWAPPINESS_VALUE" =~ ^-?[0-9]+$ ]] && (( "$SWAPPINESS_VALUE" >= 0 && "$SWAPPINESS_VALUE" <= 200 )); then
    break
  else
    echo "Invalid input. Please enter a valid number."
  fi
done

# Backup the original sysctl.conf file
cp /etc/sysctl.conf /etc/sysctl.conf.bak
echo "INFO: Backup of /etc/sysctl.conf created at /etc/sysctl.conf.bak"

if grep -q "^vm.swappiness" /etc/sysctl.conf; then
    sed -i "s/^vm.swappiness=.*/vm.swappiness=$SWAPPINESS_VALUE/" /etc/sysctl.conf
    echo "INFO: Updated vm.swappiness to $SWAPPINESS_VALUE in /etc/sysctl.conf"
else
    echo "vm.swappiness=$SWAPPINESS_VALUE" >> /etc/sysctl.conf
    echo "INFO: Added vm.swappiness=$SWAPPINESS_VALUE to /etc/sysctl.conf"
fi

# Apply the changes immediately
sysctl -p
echo "DONE: Swappiness value set to $SWAPPINESS_VALUE and changes applied immediately"
echo "Press ENTER to return to menu"
read