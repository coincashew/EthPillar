# Author: coincashew.eth | coincashew.com
# License: GNU GPL
# Source: https://github.com/coincashew/ethpillar
# Description: EthPillar is a one-liner setup tool and node management TUI
#
# Made for home and solo stakers 🏠🥩

# 🫶 Make improvements and suggestions on GitHub:
#    * https://github.com/coincashew/ethpillar
# 🙌 Ask questions on Discord:
#    * https://discord.gg/w8Bx8W2HPW

#!/bin/bash

VERSION="1.2.5"
BASE_DIR=$HOME/git/ethpillar

# Load functions
source $BASE_DIR/functions.sh && cd $BASE_DIR

menuMain(){

# Define the options for the main menu
OPTIONS=(
  1 "View Logs (Exit: CTRL+B D)"
  - ""
  3 "Execution Client"
  4 "Consensus Client"
)
test -f /etc/systemd/system/validator.service && OPTIONS+=(5 "Validator Client")
test -f /etc/systemd/system/mevboost.service && OPTIONS+=(6 "MEV-Boost")
OPTIONS+=(
  - ""
  7 "Start all clients"
  8 "Stop all clients"
  9 "Restart all clients"
  - ""
  10 "System Administration"
  11 "Tools"
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
        test -f /etc/systemd/system/validator.service && sudo service validator start
        test -f /etc/systemd/system/mevboost.service && sudo service mevboost start
        ;;
      8)
        sudo service execution stop
        sudo service consensus stop
        test -f /etc/systemd/system/validator.service && sudo service validator stop
        test -f /etc/systemd/system/mevboost.service && sudo service mevboost stop
        ;;
      9)
        sudo service execution restart
        sudo service consensus restart
        test -f /etc/systemd/system/validator.service && sudo service validator restart
        test -f /etc/systemd/system/mevboost.service && sudo service mevboost restart
        ;;
      10)
        submenuAdminstrative
        ;;
      11)
        submenuTools
        ;;
      99)
        break
        ;;
    esac
done
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
    SUBCHOICE=$(whiptail --clear --cancel-button "Back" \
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
    SUBCHOICE=$(whiptail --clear --cancel-button "Back" \
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
      6 "Generate / Import Validator Keys"
      - ""
      7 "Back to main menu"
    )

    # Display the submenu and get the user's choice
    SUBCHOICE=$(whiptail --clear --cancel-button "Back" \
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
        runScript manage_validator_keys.sh
        ;;
      7)
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
    SUBCHOICE=$(whiptail --clear --cancel-button "Back" \
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
        if whiptail --title "Reload daemon and restart services" --yesno "Do you want to restart MEV-Boost" 8 78; then
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
      2 "Restart system"
      3 "Shutdown system"
      - ""
      4 "View software versions"
      5 "View cpu/ram/disk/net (btop)"
      6 "View general node information"
      - ""
      10 "Update EthPillar"
      11 "About EthPillar"
      - ""
      20 "Uninstall node"
      - ""
      99 "Back to main menu"
    )

    # Display the submenu and get the user's choice
    SUBCHOICE=$(whiptail --clear --cancel-button "Back" \
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
        if whiptail --title "Reboot" --defaultno --yesno "Are you sure you want to reboot?" 8 78; then sudo reboot now; fi
        ;;
      3)
        if whiptail --title "Shutdown" --defaultno --yesno "Are you sure you want to shutdown?" 8 78; then sudo shutdown now; fi
        ;;
      4)
        CL=$(curl -s -X 'GET'   'http://localhost:5052/eth/v1/node/version'   -H 'accept: application/json' | jq -r '.data.version')
        EL=$(curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"web3_clientVersion","params":[],"id":2}' localhost:8545 | jq -r '.result')
        MB=$($(test -f /etc/systemd/system/mevboost.service && if systemctl is-active --quiet mevboost ; then $(mev-boost --version | sed 's/.*v\([0-9]*\.[0-9]*\).*/\1/') ; fi) || printf "Not Installed")
        if [[ ! $CL ]] ; then
          CL="Not running or still starting up."
        fi
        if [[ ! $EL ]] ; then
          EL="Not running or still starting up."
        fi
        whiptail --title "Installed versions" --msgbox "Consensus client: $CL\nExecution client: $EL\nMev-boost: $MB" 10 78
        ;;
      5)
        # Install btop process monitoring
        if ! command -v btop &> /dev/null; then
            sudo apt-get install btop -y
        fi
        btop
      ;;
      7)
        print_node_info
      ;;
      10)
        cd $BASE_DIR ; git fetch origin main ; git checkout main ; git pull --ff-only ; git reset --hard ; git clean -xdf
        whiptail --title "Updated EthPillar" --msgbox "Restart EthPillar for latest version." 10 78
        ;;
      11)
        MSG_ABOUT="🫰 Created as a Public Good by CoinCashew.eth since Pre-Genesis 2020
        \n🫶 Make improvements and suggestions on GitHub: https://github.com/coincashew/ethpillar
        \n🙌 Ask questions on Discord: https://discord.gg/w8Bx8W2HPW
        \nIf you'd like to support this public goods project, find us on the next Gitcoin Grants.
        \nOur donation address is 0xCF83d0c22dd54475cC0C52721B0ef07d9756E8C0 or coincashew.eth"
        whiptail --title "About EthPillar" --msgbox "$MSG_ABOUT" 20 78
        ;;
      20)
        runScript uninstall.sh
        ;;
      99)
        break
        ;;
    esac
done
}


submenuTools(){
while true; do
    getBackTitle
    # Define the options for the submenu
    SUBOPTIONS=(
      1 "Port Checker: Test for Incoming Connections"
      9 "EL: Switch Execution Clients"
      - ""
      99 "Back to main menu"
    )

    # Display the submenu and get the user's choice
    SUBCHOICE=$(whiptail --clear --cancel-button "Back" \
      --backtitle "$BACKTITLE" \
      --title "Tools" \
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
        checkOpenPorts
        ;;
      9)
        sudo /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/coincashew/client-switcher/master/install.sh)"
        ;;
      99)
        break
        ;;
    esac
done
}

function getBackTitle(){
    getNetwork
    getClient
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
    EL_TEXT=$(if systemctl is-active --quiet execution ; then printf "Block $LB | Gas $GP Gwei" ; else printf "Offline EL" ; fi)
    CL_TEXT=$(if systemctl is-active --quiet consensus ; then printf "Slot $LS" ; else printf "Offline CL" ; fi)
    VC_TEXT=$(if systemctl is-active --quiet validator && systemctl is-enabled --quiet validator; then printf " | VC $VC" ; fi)
    NETWORK_TEXT=$(if systemctl is-active --quiet execution ; then printf "$NETWORK |" ; fi)
    BACKTITLE="$NETWORK_TEXT $EL_TEXT | $CL_TEXT | $CL-$EL$VC_TEXT | Public Goods by CoinCashew.eth"
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
    if whiptail --title "Install Node" --yesno "Would you like to install an Ethereum node (Nimbus CL & Nethermind EL)?" 8 78; then
      runScript install-nimbus-nethermind.sh
    fi
  fi
}

checkV1StakingSetup
setWhiptailColors
askInstallNode
menuMain
