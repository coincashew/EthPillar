#!/bin/bash

# Author: coincashew.eth | coincashew.com
# License: GNU GPL
# Source: https://github.com/coincashew/ethpillar
# Description: Contributoor helper script
#
# Made for home and solo stakers 🏠🥩

#set -e

# Colors
g="\033[32m" # Green
y="\033[33m" # Yellow
b="\033[34m" # Blue
p="\033[35m" # Purple
r="\033[31m" # Red
nc="\033[0m" # No-color
bold="\033[1m"

function info {
  echo -e "${g}INFO: $1${nc}"
}

function error {
  echo -e "${r}${bold}ERROR: $1${nc}"
}

function question {
  read -p "$1" -r
  echo "$REPLY"
}

# Load env variables
PLUGIN_INSTALL_PATH=/opt/ethpillar/plugin-eth-validator-cli
[[ -f $PLUGIN_INSTALL_PATH/env ]] && source $PLUGIN_INSTALL_PATH/env
[[ -f $PLUGIN_INSTALL_PATH/current_version ]] && VERSION=$(cat $PLUGIN_INSTALL_PATH/current_version)

cli_options=(
  --json-rpc-url="$JSON_RPC_URL"
  --beacon-api-url="$BEACON_API_URL"
  --max-requests-per-block="$MAX_REQUESTS_PER_BLOCK"
)

function consolidateCommand(){
    local s t
    s=$(question "Space separated list of validator pubkeys which will be consolidated into the target validator: ")
    t=$(question "Target validator pubkey: ")
    cli_options+=(--source=\""$s"\")
    cli_options+=(--target="$t")
    info "Executing command > eth-validator-cli consolidate ${cli_options[*]}"
    yn=$(question "Please double-check your inputs before executing a command. Is the above correct? [y|n]")
    if [[ $yn = [Yy]* ]]; then
      exec $PLUGIN_INSTALL_PATH/eth-validator-cli consolidate "${cli_options[*]}" || error "Error running command"
    fi
    read -p "Press ENTER to return to menu" -r
}

function exitCommand(){
    local v
    v=$(question "Space separated list of validator pubkeys which will be exited: ")
    cli_options+=(--validator=\""$v"\")
    info "Executing command > eth-validator-cli exit ${cli_options[*]}"
    yn=$(question "Please double-check your inputs before executing a command. Is the above correct? [y|n]")
    if [[ $yn = [Yy]* ]]; then
      exec $PLUGIN_INSTALL_PATH/eth-validator-cli exit "${cli_options[*]}" || error "Error running command"
    fi
    read -p "Press ENTER to return to menu" -r
}

function switchWithdrawalCredentialTypeCommand(){
    local v
    v=$(question "Space separated list of validator pubkeys for which the withdrawal credential type will be changed to 0x02: ")
    cli_options+=(--validator=\""$v"\")
    info "Executing command > eth-validator-cli switch ${cli_options[*]}"
    yn=$(question "Please double-check your inputs before executing a command. Is the above correct? [y|n]")
    if [[ $yn = [Yy]* ]]; then
      exec $PLUGIN_INSTALL_PATH/eth-validator-cli switch "${cli_options[*]}" || error "Error running command"
    fi
    read -p "Press ENTER to return to menu" -r
}

function withdrawCommand(){
    local v a
    v=$(question "Space separated list of validator pubkeys for which the withdrawal will be executed: ")
    a=$(question "Amount of ETH which will be withdrawn from the validator(s) (in ETH notation e.g. 0.001): ")
    cli_options+=(--validator=\""$v"\")
    cli_options+=(--amount="$a")
    info "Executing command > eth-validator-cli withdraw ${cli_options[*]}"
    yn=$(question "Please double-check your inputs before executing a command. Is the above correct? [y|n]")
    if [[ $yn = [Yy]* ]]; then
      exec $PLUGIN_INSTALL_PATH/eth-validator-cli withdraw "${cli_options[*]}" || error "Error running command"
    fi
    read -p "Press ENTER to return to menu" -r
}

while true; do
    # Define the options for the submenu
    SUBOPTIONS=(
      1 "Edit env configuration"
      2 "Switch: Switch withdrawal credential type from 0x01 to 0x02 for one or many validators"
      3 "Consolidate: Consolidate one or many source validators into one target validator"
      4 "Withdraw: Partially withdraw ETH from one or many validators"
      5 "Exit: Space separated list of validator pubkeys which will be exited"
      6 "Update to latest release"
      7 "Uninstall plugin"
      - ""
      10 "Back to main menu"
    )

    # Display the submenu and get the user's choice
    SUBCHOICE=$(whiptail --clear --cancel-button "Back" \
      --backtitle "$BACKTITLE" \
      --title "Plugin - 🔧 eth-validator-cli $VERSION by TobiWo: managing validators via execution layer requests" \
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
        sudo "${EDITOR}" "$PLUGIN_INSTALL_PATH"/env
        ;;
      2)
        switchWithdrawalCredentialTypeCommand
        ;;
      3)
        consolidateCommand
        ;;
      4)
        withdrawCommand
        ;;
      5)
        exitCommand
        ;;
      6)
        exec ./plugins/eth-validator-cli/plugin_eth-validator-cli.sh -u
        ;;
      7)
        exec ./plugins/eth-validator-cli/plugin_eth-validator-cli.sh -r
        ;;
      10)
        break
        ;;
    esac
done
