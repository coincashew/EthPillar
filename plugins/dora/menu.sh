#!/bin/bash

# Author: coincashew.eth | coincashew.com
# License: GNU GPL
# Source: https://github.com/coincashew/ethpillar
# Description: Dora the Explorer helper script
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
      2 "Start dora"
      3 "Stop dora"
      4 "Restart dora"
      5 "Edit dora configuration"
      6 "Edit service configuration"
      7 "Update to latest release"
      8 "Uninstall plugin"
      - ""
      10 "Back to main menu"
    )

    # Display the submenu and get the user's choice
    SUBCHOICE=$(whiptail --clear --cancel-button "Back" \
      --backtitle "$BACKTITLE" \
      --title "Plugin - Dora: Lightweight Block Explorer " \
      --menu "\nAccess Dora at: http://127.0.0.1:8080 or http://$ip_current:8080\n\nChoose one of the following options:" \
      0 0 0 \
      "${SUBOPTIONS[@]}" \
      3>&1 1>&2 2>&3)

    if [ $? -gt 0 ]; then # user pressed <Cancel> button
        break
    fi
    # Handle the user's choice from the submenu
    case $SUBCHOICE in
      1)
        sudo bash -c 'journalctl -fu dora | ccze -A'
        ;;
      2)
        sudo systemctl start dora
        sudo systemctl enable dora
        ;;
      3)
        sudo systemctl stop dora
        sudo systemctl disable dora
        ;;
      4)
        sudo systemctl restart dora
        ;;
      5)
        sudo "${EDITOR}" /opt/ethpillar/plugin-dora/explorer-config.yaml
        if whiptail --title "Change explorer-config.yaml and restart services" --yesno "Do you want to restart with updated explorer-config.yaml?" 8 78; then
           sudo systemctl restart dora
        fi
        ;;
      6)
        sudo "${EDITOR}" /etc/systemd/system/dora.service
        if whiptail --title "Restart services" --yesno "Do you want to restart with updated configurations?" 8 78; then
           sudo systemctl daemon-reload
           sudo systemctl restart dora
        fi
        ;;
      7)
        runScript plugins/dora/plugin_dora.sh -u
        ;;
      8)
        runScript plugins/dora/plugin_dora.sh -r
        ;;
      10)
        break
        ;;
    esac
done