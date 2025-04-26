#!/bin/bash

# Author: coincashew.eth | coincashew.com
# License: GNU GPL
# Source: https://github.com/coincashew/ethpillar
# Description: prysm-client-stats helper script
#
# Made for home and solo stakers 🏠🥩

# Source directory
SOURCE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Load functions
source $SOURCE_DIR/../../functions.sh

while true; do
    # Define the options for the submenu
    SUBOPTIONS=(
      1 "View Logs"
      2 "Start client-stats"
      3 "Stop client-stats"
      4 "Restart client-stats"
      5 "Edit service configuration"
      6 "Update to latest release"
      7 "Uninstall plugin"
      - ""
      10 "Back to main menu"
    )

    # Display the submenu and get the user's choice
    SUBCHOICE=$(whiptail --clear --cancel-button "Back" \
      --backtitle "$BACKTITLE" \
      --title "Plugin - 🌈 Prysm client-stats collects metrics. Monitoring with beaconcha.in" \
      --menu "\nChoose one of the following options:" \
      0 0 0 \
      "${SUBOPTIONS[@]}" \
      3>&1 1>&2 2>&3)

    if [ $? -gt 0 ]; then # user pressed <Cancel> button
        break
    fi
    # Handle the user's choice from the submenu
    case $SUBCHOICE in
      1)
        sudo bash -c 'journalctl -fu client-stats | ccze -A'
        ;;
      2)
        sudo systemctl start client-stats
        sudo systemctl enable client-stats
        ;;
      3)
        sudo systemctl stop client-stats
        sudo systemctl disable client-stats
        ;;
      4)
        sudo systemctl restart client-stats
        ;;
      5)
        sudo "${EDITOR}" /etc/systemd/system/client-stats.service
        if whiptail --title "Restart services" --yesno "Do you want to restart with updated configurations?" 8 78; then
           sudo systemctl daemon-reload
           sudo systemctl restart client-stats
        fi
        ;;
      6)
        runScript plugins/client-stats/plugin_client_stats.sh -u
        ;;
      7)
        runScript plugins/client-stats/plugin_client_stats.sh -r
        ;;
      10)
        break
        ;;
    esac
done
