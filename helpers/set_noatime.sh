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
echo "noatime: Reduced Disk I/O and Improved Performance"
echo "########################################################################################"
echo "Key Points:"
echo "* Purpose: Filesystem does not update the access time (atime) every time a file is read"
echo "* Reduced Disk I/O: Fewer writes means less wear on your storage and faster read operations"
echo "* Improved Performance: Speed improvements, especially for file-intensive workloads"
echo ""
echo "Do you wish to continue? [y|n]"
read -rsn1 yn
if [[ ! ${yn} = [Yy]* ]]; then
    exit 0
fi
_CHANGED=""
cp /etc/fstab /etc/fstab.bak
echo "INFO: Backup of /etc/fstab created at /etc/fstab.bak"

# Function to append noatime to mount options
append_noatime() {
    local label=$1
    local mount_point=$2
    local options=$(grep -w "$label" /etc/fstab | awk '{print $4}')
    local options_after=""
    if [[ $options != *"noatime"* ]]; then
        if [[ $options == *","* ]]; then
            options_after="$options,noatime"
        else
            options_after="noatime,$options"
        fi
        sed -i "s|$options|$options_after|" /etc/fstab
        echo "SUCCESS: Appended noatime to $mount_point mount point"
        _CHANGED="1"
    else
        echo "INFO: noatime already present in $mount_point mount point"
    fi
}

# Loop through mount points in /etc/fstab and append noatime
while IFS= read -r line; do
    if [[ ! "$line" =~ "#" ]]; then #skip comments
        mount_point=$(echo $line | awk '{print $2}')
        label=$(echo $line | awk '{print $1}')
        if [[ ! "$mount_point" = /boot ]] &&
           [[ ! "$mount_point" = /boot/efi ]] &&
           [[ ! "$mount_point" = none ]] &&
           [[ -n $mount_point ]]; then
            append_noatime $label $mount_point
        else
            echo "INFO: SKIPPING $label $mount_point"
        fi
    fi
done < /etc/fstab
if [[ $_CHANGED == "1" ]]; then
    echo "DONE: Please reboot your system to apply the changes"
else
    echo "DONE: No mount point changes made."
fi
echo "Press ENTER to return to menu"
read