#!/bin/bash

# Author: coincashew.eth | coincashew.com
# License: GNU GPL
# Source: https://github.com/coincashew/ethpillar
# Description: Contributoor helper script
#
# Made for home and solo stakers 🏠🥩

# Source directory
SOURCE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Load functions
# shellcheck disable=SC1091
source "$SOURCE_DIR"/../../functions.sh

# Load version
PLUGIN_INSTALL_PATH=/opt/ethpillar/plugin-contributoor
[[ -f $PLUGIN_INSTALL_PATH/current_version ]] && VERSION=$(cat $PLUGIN_INSTALL_PATH/current_version)

while true; do
    # Define the options for the submenu
    SUBOPTIONS=(
      1 "View Logs"
      2 "Start contributoor"
      3 "Stop contributoor"
      4 "Restart contributoor"
      5 "Edit contributoor config.yaml"
      6 "Edit service configuration"
      7 "Update to latest release"
      8 "Uninstall plugin"
      - ""
      10 "Back to main menu"
    )

    # Display the submenu and get the user's choice
    SUBCHOICE=$(whiptail --clear --cancel-button "Back" \
      --backtitle "$BACKTITLE" \
      --title "Plugin - 🐼 Contributoor $VERSION by ethpandaops.io" \
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
        sudo bash -c 'journalctl -fu contributoor | ccze -A'
        ;;
      2)
        sudo systemctl enable contributoor
        sudo systemctl start contributoor
        ;;
      3)
        sudo systemctl disable contributoor
        sudo systemctl stop contributoor
        ;;
      4)
        sudo systemctl restart contributoor
        ;;
      5)
        sudo "${EDITOR}" /opt/ethpillar/plugin-contributoor/config.yaml
        if whiptail --title "Restart services" --yesno "Do you want to restart with updated configurations?" 8 78; then
           sudo systemctl daemon-reload
           sudo systemctl restart contributoor
        fi
        ;;        
      6)
        sudo "${EDITOR}" /etc/systemd/system/contributoor.service
        if whiptail --title "Restart services" --yesno "Do you want to restart with updated configurations?" 8 78; then
           sudo systemctl daemon-reload
           sudo systemctl restart contributoor
        fi
        ;;
      7)
        runScript plugins/contributoor/plugin_contributoor.sh -u
        ;;
      8)
        runScript plugins/contributoor/plugin_contributoor.sh -r
        ;;
      10)
        break
        ;;
    esac
done
