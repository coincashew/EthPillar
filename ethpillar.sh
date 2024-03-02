# Author: coincashew.eth | coincashew.com
# License: GNU GPL
# Source: https://github.com/coincashew/ethpillar
#
# Made for home and solo stakers 🏠🥩

# 🫶 Make improvements and suggestions on GitHub:
#    * https://github.com/coincashew/ethpillar
# 🙌 Ask questions on Discord:
#    * https://discord.gg/w8Bx8W2HPW

#!/bin/bash

VERSION="1.0.0"

menuMain(){
# Define the options for the main menu
OPTIONS=(
  1 "View Logs (Exit: CTRL+B D)"
  - ""
  3 "Execution Client"
  4 "Consensus Client"
  5 "Validator Client"
  6 "MEV-Boost"
  - ""
  7 "Start all clients"
  8 "Stop all clients"
  9 "Restart all clients"
  - ""
  10 "System Administration"
)

while true; do
    getBackTitle
    # Display the main menu and get the user's choice
    CHOICE=$(whiptail --clear --cancel-button "Quit"\
      --backtitle "$BACKTITLE" \
      --title "EthPillar - Node Menu $VERSION" \
      --menu "Choose a category:" \
      0 42 0 \
      "${OPTIONS[@]}" \
      3>&1 1>&2 2>&3)
    if [ $? -gt 0 ]; then # user pressed <Cancel> button
        break
    fi

    # Handle the user's choice
    case $CHOICE in
      1)
        runScript view_logs.sh
        ;;
      # 2)
      #   runScript view_duties.sh
      #  ;;
      3)
        submenuExecution
        ;;
      4)
        submenuConsensus
        ;;
      5)
        submenuValidator
        ;;
      6)
        submenuMEV-Boost
        ;;
      7)
        sudo service execution start
        sudo service consensus start
        sudo service validator start
        sudo service mevboost start
        ;;
      8)
        sudo service execution stop
        sudo service consensus stop
        sudo service validator stop
        sudo service mevboost stop
        ;;
      9)
        sudo service execution restart
        sudo service consensus restart
        sudo service validator restart
        sudo service mevboost restart
        ;;
      10)
        submenuAdminstrative
        ;;
      99)
        break
        ;;
    esac
done
}

# Runs a script, name is passed as arg $1
function runScript() {
    CURRENT_DIR=$(pwd)
    SCRIPT_PATH="$CURRENT_DIR/$1"

    if [[ ! -x $SCRIPT_PATH ]]; then
        chmod +x $SCRIPT_PATH
    fi

    if [[ -f $SCRIPT_PATH && -x $SCRIPT_PATH ]]; then
      $SCRIPT_PATH
    else
        echo "Error: $SCRIPT_PATH not run. Check permissions or path."
        exit 1
    fi
}

submenuExecution(){
while true; do
    getBackTitle
    # Define the options for the submenu
    SUBOPTIONS=(
      1 "View logs"
      2 "Start execution"
      3 "Stop execution"
      4 "Restart execution"
      5 "Edit configuration"
      6 "Update to latest release"
      7 "Resync execution client"
      - ""
      8 "Back to main menu"
    )

    # Display the submenu and get the user's choice
    SUBCHOICE=$(whiptail --clear \
      --backtitle "$BACKTITLE" \
      --title "Execution Client" \
      --menu "Choose one of the following options:" \
      0 0 0 \
      "${SUBOPTIONS[@]}" \
      3>&1 1>&2 2>&3)

    if [ $? -gt 0 ]; then # user pressed <Cancel> button
        break
    fi

    # Handle the user's choice from the submenu
    case $SUBCHOICE in
      1)
        sudo bash -c 'journalctl -fu execution | ccze'
        ;;
      2)
        sudo service execution start
        ;;
      3)
        sudo service execution stop
        ;;
      4)
        sudo service execution restart
        ;;
      5)
        sudo nano /etc/systemd/system/execution.service
        if whiptail --title "Reload daemon and restart services" --yesno "Do you want to restart execution client?" 8 78; then
          sudo systemctl daemon-reload && sudo service execution restart
        fi
        ;;
      6)
        runScript update_execution.sh
        ;;
      7)
        runScript resync_execution.sh
        ;;
      8)
        break
        ;;
    esac
done
}

submenuConsensus(){
while true; do
    getBackTitle
    # Define the options for the submenu
    SUBOPTIONS=(
      1 "View logs"
      2 "Start consensus"
      3 "Stop consensus"
      4 "Restart consensus"
      5 "Edit configuration"
      6 "Update to latest release"
      7 "Resync consensus client"
      - ""
      8 "Back to main menu"
    )

    # Display the submenu and get the user's choice
    SUBCHOICE=$(whiptail --clear \
      --backtitle "$BACKTITLE" \
      --title "Consensus Client" \
      --menu "Choose one of the following options:" \
      0 0 0 \
      "${SUBOPTIONS[@]}" \
      3>&1 1>&2 2>&3)

    if [ $? -gt 0 ]; then # user pressed <Cancel> button
        break
    fi

    # Handle the user's choice from the submenu
    case $SUBCHOICE in
      1)
        sudo bash -c 'journalctl -fu consensus | ccze'
        ;;
      2)
        sudo service consensus start
        ;;
      3)
        sudo service consensus stop
        ;;
      4)
        sudo service consensus restart
        ;;
      5)
        sudo nano /etc/systemd/system/consensus.service
        if whiptail --title "Reload daemon and restart services" --yesno "Do you want to restart consensus client?" 8 78; then
          sudo systemctl daemon-reload && sudo service consensus restart
        fi
        ;;
      6)
        runScript update_consensus.sh
        ;;
      7)
        runScript resync_consensus.sh
        ;;
      8)
        break
        ;;
    esac
done
}

submenuValidator(){
while true; do
    getBackTitle
    # Define the options for the submenu
    SUBOPTIONS=(
      1 "View logs"
      2 "Start validator"
      3 "Stop validator"
      4 "Restart validator"
      5 "Edit configuration"
      - ""
      6 "Back to main menu"
    )

    # Display the submenu and get the user's choice
    SUBCHOICE=$(whiptail --clear \
      --backtitle "$BACKTITLE" \
      --title "Validator" \
      --menu "Choose one of the following options:" \
      0 0 0 \
      "${SUBOPTIONS[@]}" \
      3>&1 1>&2 2>&3)

    if [ $? -gt 0 ]; then # user pressed <Cancel> button
        break
    fi

    # Handle the user's choice from the submenu
    case $SUBCHOICE in
      1)
        sudo bash -c 'journalctl -fu validator | ccze'
        ;;
      2)
        sudo service validator start
        ;;
      3)
        sudo service validator stop
        ;;
      4)
        sudo service validator restart
        ;;
      5)
        sudo nano /etc/systemd/system/validator.service
        if whiptail --title "Reload daemon and restart services" --yesno "Do you want to restart validator?" 8 78; then
          sudo systemctl daemon-reload && sudo service validator restart
        fi
        ;;
      6)
        break
        ;;
    esac
done
}

submenuMEV-Boost(){
while true; do
    getBackTitle
    # Define the options for the submenu
    SUBOPTIONS=(
      1 "View logs"
      2 "Start MEV-Boost"
      3 "Stop MEV-Boost"
      4 "Restart MEV-Boost"
      5 "Edit configuration"
      6 "Update to latest release"
      - ""
      7 "Back to main menu"
    )

    # Display the submenu and get the user's choice
    SUBCHOICE=$(whiptail --clear \
      --backtitle "$BACKTITLE" \
      --title "MEV-Boost" \
      --menu "Choose one of the following options:" \
      0 0 0 \
      "${SUBOPTIONS[@]}" \
      3>&1 1>&2 2>&3)

    if [ $? -gt 0 ]; then # user pressed <Cancel> button
        break
    fi

    # Handle the user's choice from the submenu
    case $SUBCHOICE in
      1)
        sudo bash -c 'journalctl -fu mevboost | ccze'
        ;;
      2)
        sudo service mevboost start
        ;;
      3)
        sudo service mevboost stop
        ;;
      4)
        sudo service mevboost restart
        ;;
      5)
        sudo nano /etc/systemd/system/mevboost.service
        if whiptail --title "Reload daemon and restart services" --yesno "Do you want to restart MEV-Boost" 78; then
          sudo systemctl daemon-reload && sudo service mevboost restart
        fi
        ;;
      6)
        runScript update_mevboost.sh
        ;;
      7)
        break
        ;;
    esac
done
}

submenuAdminstrative(){
while true; do
    getBackTitle
    # Define the options for the submenu
    SUBOPTIONS=(
      1 "Update system"
      2 "Update system && restart system"
      3 "Restart system"
      4 "Shutdown system"
      - ""
      5 "View software versions"
      6 "View cpu/ram/disk/net (btop)"
      7 "Update EthPillar"
      8 "About EthPillar"
      - ""
      9 "Uninstall node"
      - ""
      99 "Back to main menu"
    )

    # Display the submenu and get the user's choice
    SUBCHOICE=$(whiptail --clear \
      --backtitle "$BACKTITLE" \
      --title "System Administration" \
      --menu "Choose one of the following options:" \
      0 0 0 \
      "${SUBOPTIONS[@]}" \
      3>&1 1>&2 2>&3)

    if [ $? -gt 0 ]; then # user pressed <Cancel> button
        break
    fi

    # Handle the user's choice from the submenu
    case $SUBCHOICE in
      1)
        sudo apt update && sudo apt upgrade -y && sudo apt autoremove -y
        ;;
      2)
        sudo apt update && sudo apt upgrade -y && sudo apt autoremove -y
        sudo reboot now
        ;;
      3)
        sudo reboot now
        ;;
      4)
        sudo shutdown now
        ;;
      5)
        CL=$(curl -s -X 'GET'   'http://localhost:5052/eth/v1/node/version'   -H 'accept: application/json' | jq -r '.data.version')
        EL=$(curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"web3_clientVersion","params":[],"id":2}' localhost:8545 | jq -r '.result')
        MB=$(mev-boost --version | sed 's/.*v\([0-9]*\.[0-9]*\).*/\1/')
        if [[ ! $CL ]] ; then
          CL="Not running or still starting up."
        fi
        if [[ ! $EL ]] ; then
          EL="Not running or still starting up."
        fi
        whiptail --title "Installed versions" --msgbox "Consensus client: $CL\nExecution client: $EL\nMev-boost: $MB" 10 78
        ;;
      6)
        # Install btop process monitoring
        if ! command -v btop &> /dev/null; then
            sudo apt-get install btop -y
        fi
        btop
      ;;
      7)
        cd ~/git/ethpillar ; git fetch origin main ; git checkout main ; git pull --ff-only ; git reset --hard ; git clean -xdf
        whiptail --title "Updated EthPillar" --msgbox "Restart EthPillar for latest version." 10 78
        ;;
      8)
        whiptail --title "About EthPillar" --msgbox "🫰 Created as a Public Good by CoinCashew.eth since Pre-Genesis 2020\n🫶 Make improvements and suggestions on GitHub: https://github.com/coincashew/ethpillar\n🙌 Ask questions on Discord: https://discord.gg/w8Bx8W2HPW\n" 10 78
        ;;
      9)
        runScript uninstall.sh
        ;;
      99)
        break
        ;;
    esac
done
}

function getNetwork(){
    # Get network name from execution client
    result=$(curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"net_version","params":[],"id":67}' localhost:8545 | jq -r '.result')
    case $result in
    1)
      NETWORK="Mainnet"
      ;;
    17000)
      NETWORK="Holesky"
      ;;
    11155111)
      NETWORK="Sepolia"
      ;;
    esac
}

function getBackTitle(){
    getNetwork
    # Read clients from systemd config files
    EL=$(cat /etc/systemd/system/execution.service | grep Description= | awk -F'=' '{print $2}' | awk '{print $1}')
    CL=$(cat /etc/systemd/system/consensus.service | grep Description= | awk -F'=' '{print $2}' | awk '{print $1}')
    VC=$(cat /etc/systemd/system/validator.service | grep Description= | awk -F'=' '{print $2}' | awk '{print $1}')

    # Latest block
    latest_block_number=$(curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' localhost:8545 | jq -r '.result')
    LB=$(printf '%d' "$latest_block_number")
    if [[ ! $LB  ]]; then 
      LB="N/A"
    fi

    # Latest slot
    LS=$(curl -s -X 'GET'   'http://localhost:5052/eth/v1/node/syncing'   -H 'accept: application/json' | jq -r '.data.head_slot')
    if [[ ! $LS ]]; then 
      LS="N/A"
    fi

    # Format gas price
    latest_gas_price=$(curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_gasPrice","params":[],"id":73}' localhost:8545 | jq -r '.result')
    if [[ $latest_gas_price ]]; then
      WEI=$(printf '%d' "$latest_gas_price")
      GP=$(echo "scale=3; $WEI / 1000000000" | bc) #convert to Gwei
    else
      GP="N/A"
    fi

    # Format backtitle
    BACKTITLE="$NETWORK | Block $LB | Slot $LS | Gas $GP Gwei | $CL-$EL-$VC VC | Public Goods by CoinCashew.eth"
}

function setWhiptailColors(){
    export NEWT_COLORS='root=,black
border=green,black
title=green,black
roottext=red,black
window=red,black
textbox=white,black
button=black,green
compactbutton=white,black
listbox=white,black
actlistbox=black,white
actsellistbox=black,green
checkbox=green,black
actcheckbox=black,green'
}

function checkV1StakingSetup(){
  if [[ -f /etc/systemd/system/eth1.service ]]; then
    echo "EthPillar is only compatible with V2 Staking Setups."
    exit
  fi
}

# If no consensus client service is installed, ask to install
function askInstallNode(){
  if [[ ! -f /etc/systemd/system/consensus.service ]]; then
    if whiptail --title "Install Node" --yesno "Would you like to install an Ethereum node?" 8 78; then
      runScript install-nimbus-nethermind.sh
    fi
  fi
}

checkV1StakingSetup
setWhiptailColors
askInstallNode
menuMain