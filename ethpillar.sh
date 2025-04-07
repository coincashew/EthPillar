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

EP_VERSION="4.2.1"

# Default text editor
EDITOR="nano"

# VARIABLES
export BASE_DIR="$HOME/git/ethpillar" && cd $BASE_DIR

# Load functions
source ./functions.sh

# Load environment variables, Lido CSM withdrawal address and fee recipient
source ./env

# Load environment variables overrides
[[ -f ./.env.overrides ]] && source ./.env.overrides

# Consensus client or beacon node HTTP Endpoint
export API_BN_ENDPOINT="http://${CL_IP_ADDRESS}:${CL_REST_PORT}"

# Execution layer RPC API
export EL_RPC_ENDPOINT="${EL_IP_ADDRESS}:${EL_RPC_PORT}"

# Get machine info
_platform=$(get_platform)
_arch=$(get_arch)

menuMain(){

# Define the options for the main menu
OPTIONS=(
  1 "View Logs (Exit: CTRL+B D)"
  - ""
)
test -f /etc/systemd/system/execution.service && OPTIONS+=(2 "Execution Client")
test -f /etc/systemd/system/consensus.service && OPTIONS+=(3 "Consensus Client")
test -f /etc/systemd/system/validator.service && OPTIONS+=(4 "Validator Client")
test -f /etc/systemd/system/mevboost.service && OPTIONS+=(5 "MEV-Boost")
test -f /etc/systemd/system/csm_nimbusvalidator.service && OPTIONS+=(6 "CSM Nimbus Validator Plugin")
OPTIONS+=(
  - ""
  10 "Start all clients"
  11 "Stop all clients"
  12 "Restart all clients"
  - ""
  20 "System Administration"
  21 "Toolbox"
  22 "Plugins"
  99 "Quit"
)

while true; do
    getBackTitle
    # Display the main menu and get the user's choice
    CHOICE=$(whiptail --clear --cancel-button "Quit"\
      --backtitle "$BACKTITLE" \
      --title "EthPillar $EP_VERSION | $NODE_MODE" \
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
      2)
        submenuExecution
        ;;
      3)
        submenuConsensus
        ;;
      4)
        submenuValidator
        ;;
      5)
        submenuMEV-Boost
        ;;
      6)
        submenuPluginCSMValidator
        ;;
      10)
        test -f /etc/systemd/system/execution.service && sudo service execution start
        test -f /etc/systemd/system/consensus.service && sudo service consensus start
        test -f /etc/systemd/system/validator.service && sudo service validator start
        test -f /etc/systemd/system/mevboost.service && sudo service mevboost start
        test -f /etc/systemd/system/csm_nimbusvalidator.service && sudo service csm_nimbusvalidator start
        ;;
      11)
        test -f /etc/systemd/system/execution.service && sudo service execution stop
        test -f /etc/systemd/system/consensus.service && sudo service consensus stop
        test -f /etc/systemd/system/validator.service && sudo service validator stop
        test -f /etc/systemd/system/mevboost.service && sudo service mevboost stop
        test -f /etc/systemd/system/csm_nimbusvalidator.service && sudo service csm_nimbusvalidator stop
        ;;
      12)
        test -f /etc/systemd/system/execution.service && sudo service execution restart
        test -f /etc/systemd/system/consensus.service && sudo service consensus restart
        test -f /etc/systemd/system/validator.service && sudo service validator restart
        test -f /etc/systemd/system/mevboost.service && sudo service mevboost restart
        test -f /etc/systemd/system/csm_nimbusvalidator.service && sudo service csm_nimbusvalidator restart
        ;;
      20)
        submenuAdminstrative
        ;;
      21)
        submenuTools
        ;;
      22)
        submenuPlugins
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
      8 "Expose execution client RPC Port"
      - ""
      9 "Back to main menu"
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
        sudo bash -c 'journalctl -fu execution | ccze -A'
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
        sudo "${EDITOR}" /etc/systemd/system/execution.service
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
        exposeRpcEL
        ;;
      9)
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
      8 "Expose consensus client RPC Port"
      - ""
      9 "Back to main menu"
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
        sudo bash -c 'journalctl -fu consensus | ccze -A'
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
        sudo "${EDITOR}" /etc/systemd/system/consensus.service
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
        exposeRpcCL
        ;;
      9)
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
      )
    [[ ${NODE_MODE} =~ "Validator Client Only" ]] && SUBOPTIONS+=(6 "Update to latest release")
    SUBOPTIONS+=(
      - ""
      10 "Generate / Import Validator Keys"
      11 "View validator pubkeys and indices"
      12 "🆕 Validator Actions: Compound/consolidate, partial withdrawals, top up, force exit"
      - ""
      20 "Generate Voluntary Exit Messages (VEM)"
      21 "Broadcast Voluntary Exit Messages (VEM)"
      22 "Next withdrawal: See expected time, blocks to go"
      23 "Check validator status, balance"
      24 "Check validator entry/exit queue with beaconcha.in"
      25 "Attestation Performance: Obtain information about attester inclusion"
      - ""
      99 "Back to main menu"
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
        sudo bash -c 'journalctl -fu validator | ccze -A'
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
        sudo "${EDITOR}" /etc/systemd/system/validator.service
        if whiptail --title "Reload daemon and restart services" --yesno "Do you want to restart validator?" 8 78; then
          sudo systemctl daemon-reload && sudo service validator restart
        fi
        ;;
      6)
        runScript update_consensus.sh
        ;;
      10)
        runScript manage_validator_keys.sh
        ;;
      11)
        getPubKeys && getIndices
        viewPubkeyAndIndices
        ;;
      12)
        showValidatorActions
        ;;
      20)
        installEthdo
        generateVoluntaryExitMessage
        ;;
      21)
        installEthdo
        broadcastVoluntaryExitMessageLocally
        ;;
      22)
        installEthdo
        ethdoNextWithdrawalSweep
        ;;
      23)
        installEthdo
        checkValidatorStatus
        ;;
      24)
         checkValidatorQueue
         ;;
      25)
        installEthdo
        checkValidatorAttestationInclusion
        ;;
      99)
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
      7 "Check relay registration"
      8 "Check relay latency"
      - ""
      9 "Back to main menu"
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
        sudo bash -c 'journalctl -fu mevboost | ccze -A'
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
        sudo "${EDITOR}" /etc/systemd/system/mevboost.service
        if whiptail --title "Reload daemon and restart services" --yesno "Do you want to restart MEV-Boost" 8 78; then
          sudo systemctl daemon-reload && sudo service mevboost restart
        fi
        ;;
      6)
        runScript update_mevboost.sh
        ;;
      7)
        checkRelayRegistration
        ;;
      8)
        checkRelayLatency
        ;;
      9)
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
      7 "Export logs: Save logs to disk"
      - ""
      10 "Update EthPillar"
      11 "About EthPillar"
      - ""
      20 "Configure autostart"
      21 "Uninstall node"
      22 "Reinstall node: Change installation type, network"
      23 "Override environment variables"
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
        test -f /etc/systemd/system/validator.service && getClient && getCurrentVersion && VC="Validator client: $CLIENT $VERSION"
        test -f /etc/systemd/system/consensus.service && CL=$(curl -s -X GET "${API_BN_ENDPOINT}/eth/v1/node/version" -H "accept: application/json" | jq -r '.data.version')
        test -f /etc/systemd/system/execution.service && EL=$(curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"web3_clientVersion","params":[],"id":2}' ${EL_RPC_ENDPOINT} | jq -r '.result')
        MB=$(if [[ -f /etc/systemd/system/mevboost.service ]]; then printf "Mev-boost: $(mev-boost --version 2>&1 | sed 's/.*\s\([0-9]*\.[0-9]*\).*/\1/')"; else printf "Mev-boost: Not Installed"; fi)
        if [[ -z $CL ]] ; then
          CL="Not installed or still starting up."
        fi
        if [[ -z $EL ]] ; then
          EL="Not installed or still starting up."
        fi
        whiptail --title "Installed versions" --msgbox "Consensus client: ${CL}\nExecution client: ${EL}\n${VC}\n${MB}" 10 78
        ;;
      5)
        # Install btop process monitoring
        if ! command -v btop &> /dev/null; then
            sudo apt-get install btop -y
        fi
        btop --utf-force
      ;;
      6)
        print_node_info
      ;;
      7)
        export_logs
      ;;
      10)
        cd $BASE_DIR ; git fetch origin main ; git checkout main ; git pull --ff-only ; git reset --hard ; git clean -xdf
        whiptail --title "Updated EthPillar" --msgbox "Restart EthPillar for latest version." 10 78
        ;;
      11)
        MSG_ABOUT="🫰 Created as a Public Good by CoinCashew.eth since Pre-Genesis 2020
        \n🫶 Make improvements and suggestions on GitHub: https://github.com/coincashew/ethpillar
        \n🙌 Ask questions on Discord: https://discord.gg/dEpAVWgFNB
        \nIf you'd like to support this public goods project, find us on the next Gitcoin Grants.
        \nOur donation address is 0xCF83d0c22dd54475cC0C52721B0ef07d9756E8C0 or coincashew.eth"
        whiptail --title "About EthPillar" --msgbox "$MSG_ABOUT" 20 78
        ;;
      20)
        configureAutoStart
      ;;
      21)
        runScript uninstall.sh
        ;;
      22)
        if whiptail --title "Reinstall EthPillar" --defaultno --yesno "Are you sure you want to reinstall?\nAll current node data will be removed." 9 78; then
           if runScript uninstall.sh; then
              installNode
              whiptail --title "Reinstall complete" --msgbox "Completed node reinstall process." 8 78
           fi
        fi
        ;;
      23)
        if [[ ! -f ${BASE_DIR}/.env.overrides ]]; then
           # Create from template
           cp .env.overrides.example .env.overrides
        fi
        "${EDITOR}" .env.overrides
        # Reload environment variables overrides
        [[ -f ./.env.overrides ]] && source ./.env.overrides
        ;;
      99)
        break
        ;;
    esac
done
}

submenuMonitoring(){
while true; do
    getNetworkConfig
    getBackTitle
    # Define the options for the submenu
    SUBOPTIONS=(
      1 "View Logs"
      2 "Start Monitoring"
      3 "Stop Monitoring"
      4 "Restart Monitoring"
      5 "Edit configuration"
      6 "Edit Prometheus.yml configuration"
      7 "Update to latest release"
      8 "Uninstall monitoring"
      9 "Configure alerting with Grafana"
      - ""
      10 "Back to main menu"
    )

    # Display the submenu and get the user's choice
    SUBCHOICE=$(whiptail --clear --cancel-button "Back" \
      --backtitle "$BACKTITLE" \
      --title "Monitoring - Ethereum Metrics Exporter" \
      --menu "\nAccess Grafana at: http://127.0.0.1:3000 or http://$ip_current:3000\n\nChoose one of the following options:" \
      0 0 0 \
      "${SUBOPTIONS[@]}" \
      3>&1 1>&2 2>&3)

    if [ $? -gt 0 ]; then # user pressed <Cancel> button
        break
    fi

    # Handle the user's choice from the submenu
    case $SUBCHOICE in
      1)
        sudo bash -c 'journalctl -fu grafana-server -fu prometheus -fu ethereum-metrics-exporter -fu prometheus-node-exporter -n 100 | ccze -A'
        ;;
      2)
        sudo systemctl start grafana-server prometheus ethereum-metrics-exporter prometheus-node-exporter
        ;;
      3)
        sudo systemctl stop grafana-server prometheus ethereum-metrics-exporter prometheus-node-exporter
        ;;
      4)
        sudo systemctl restart grafana-server prometheus ethereum-metrics-exporter prometheus-node-exporter
        ;;
      5)
        sudo "${EDITOR}" /etc/systemd/system/ethereum-metrics-exporter.service
        if whiptail --title "Reload daemon and restart services" --yesno "Do you want to restart ethereum metrics exporter?" 8 78; then
          sudo systemctl daemon-reload && sudo service ethereum-metrics-exporter restart
        fi
        ;;
      6)
        sudo "${EDITOR}" /etc/prometheus/prometheus.yml
        if whiptail --title "Restart services" --yesno "Do you want to restart prometheus?" 8 78; then
          sudo service prometheus restart
        fi
        ;;
      7)
        runScript ethereum-metrics-exporter.sh -u
        ;;
      8)
        runScript ethereum-metrics-exporter.sh -r
        ;;
      9)
        whiptail --title "Configure Alerting with Grafana" --msgbox "Grafana enables users to create custom alert systems that notify them via multiple channels, including email, messaging apps like Telegram and Discord.
\nWith the default install, basic alerts for CPU/DISK/RAM are configured.
\nTo receive these alerts:
\n- Navigate to Grafana in your web browser
\n- Click Alerting (the alert bell icon) on the left-hand side menu
\n- Create contact points and notification policies" 20 78
        ;;
      10)
        break
        ;;
    esac
done
}

submenuEthduties(){
while true; do
    getBackTitle
    # Define the options for the submenu
    SUBOPTIONS=(
      1 "View duties"
      2 "Wait for 90.0% of attestation duties to be executed in 90 sec. or later"
      3 "Update to latest release"
      4 "Uninstall eth-duties"
      - ""
      9 "Back to main menu"
    )

    # Display the submenu and get the user's choice
    SUBCHOICE=$(whiptail --clear --cancel-button "Back" \
      --backtitle "$BACKTITLE" \
      --title "eth-duties" \
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
        getNetwork && getPubKeys && getIndices
        if [[ ${#INDICES[@]} = "0" ]]; then echo "No validators currently active. Once validators are activated, you can query duties."; sleep 5;
return; fi
        /usr/local/bin/eth-duties --validators ${INDICES[@]} --beacon-nodes $API_BN_ENDPOINT
        ;;
      2)
        getNetwork && getPubKeys && getIndices
        if [[ ${#INDICES[@]} = "0" ]]; then echo "No validators currently active. Once validators are activated, you can query duties."; sleep 5;
return; fi
        /usr/local/bin/eth-duties --validators ${INDICES[@]} --beacon-nodes $API_BN_ENDPOINT --max-attestation-duty-logs 60 --mode cicd-wait --mode-cicd-attestation-time 90 --mode-cicd-attestation-proportion 0.90
        ohai "Ready! Press ENTER to continue."
        read
        ;;
      3)
        runScript eth-duties.sh -u
        ;;
      4)
        runScript eth-duties.sh -r
        ;;
      9)
        break
        ;;
    esac
done
}

submenuEthdo(){
while true; do
    getBackTitle
    # Define the options for the submenu
    SUBOPTIONS=(
      1 "Status: Check validator status, balance"
      2 "VEM: Generate Voluntary Exit Messages"
      3 "VEM: Broadcast Voluntary Exit Messages"
      4 "Next withdrawal: See expected time, blocks to go"
      5 "Earnings: Show expected yield (APY)"
      6 "Next duties: Show expected time between block proposals, sync comm"
      7 "Credentials: Show withdrawal address"
      8 "Attestation Performance: Obtain information about attester inclusion"
      9 "Update to latest release"
      10 "Uninstall ethdo"
      - ""
      99 "Back to main menu"
    )

    # Display the submenu and get the user's choice
    SUBCHOICE=$(whiptail --clear --cancel-button "Back" \
      --backtitle "$BACKTITLE" \
      --title "ethdo" \
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
        checkValidatorStatus
        ;;
      2)
        generateVoluntaryExitMessage
        ;;
      3)
        broadcastVoluntaryExitMessageLocally
        ;;
      4)
        ethdoNextWithdrawalSweep
        ;;
      5)
        ethdoYield
        ;;
      6)
        ethdoExpectation
        ;;
      7)
        ethdoWithdrawalAddress
        ;;
      8)
        checkValidatorAttestationInclusion
        ;;
      9)
        runScript ethdo.sh -u
        ;;
      10)
        runScript ethdo.sh -r
        ;;
      99)
        break
        ;;
    esac
done
}

submenuUFW(){
while true; do
    getBackTitle
    getNetworkConfig
    # Define the options for the submenu
    SUBOPTIONS=(
      1 "View ufw status"
      2 "Allow incoming traffic on a port"
      3 "Deny incoming traffic on a port"
      4 "Delete a rule"
      - ""
      5 "Enable firewall with default settings"
      6 "EC RPC Node: Allow local network access to RPC port 8545"
      7 "CC RPC Node: Allow local network access to RPC port 5052"
      8 "Monitoring: Allow local network access to Grafana port 3000"
      9 "Disable firewall"
      10 "Reset firewall rules: Delete all rules"
      - ""
      11 "Whitelist an IP address: Allow full access to this node"
      - ""
      99 "Back to main menu"
    )

    # Display the submenu and get the user's choice
    SUBCHOICE=$(whiptail --clear --cancel-button "Back" \
      --backtitle "$BACKTITLE" \
      --title "UFW Firewall" \
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
        sudo ufw status numbered
        ohai "Press ENTER to continue."
        read
        ;;
      2)
        read -p "Enter the port number to allow: " port_number
        sudo ufw allow $port_number
        ohai "Port allowed."
        sleep 2
        ;;
      3)
        read -p "Enter the port number to deny: " port_number
        sudo ufw deny $port_number
        ohai "Port denied."
        sleep 2
        ;;
      4)
        sudo ufw status numbered
        read -p "Enter the rule number to delete: " rule_number
        sudo ufw delete $rule_number
        ohai "Rule deleted."
        sleep 2
        ;;
      5)
        # Default ufw settings
        sudo ufw default deny incoming
        sudo ufw default allow outgoing
        echo "${tty_bold}Allow SSH access? [y|n]${tty_reset}"
        read -rsn1 yn
        if [[ ${yn} = [Yy]* ]]; then
          read -r -p "Enter your SSH port. Press Enter to use default '22': " _ssh_port
          _ssh_port=${_ssh_port:-22}
          sudo ufw allow ${_ssh_port}/tcp comment 'Allow SSH port'
        fi
        sudo ufw allow 30303 comment 'Allow execution client port'
        sudo ufw allow 9000 comment 'Allow consensus client port'
        sudo ufw enable
        sudo ufw status numbered
        ohai "UFW firewall enabled."
        sleep 3
        ;;
      6)
        sudo ufw allow from ${network_current} to any port 8545 comment 'Allow local network to access execution client RPC port'
        ohai "Local network ${network_current} can access RPC port 8545"
        sleep 2
        ;;
      7)
        sudo ufw allow from ${network_current} to any port 5052 comment 'Allow local network to access consensus client RPC port'
        ohai "Local network ${network_current} can access RPC port 5052"
        sleep 2
        ;;
      8)
        sudo ufw allow from ${network_current} to any port 3000 comment 'Allow local network to access Grafana'
        ohai "Local network ${network_current} can access RPC port 3000"
        sleep 2
        ;;
      9)
        sudo ufw disable
        ohai "UFW firewall disabled."
        sleep 2
        ;;
      10)
        sudo ufw disable
        sudo ufw --force reset
        ohai "UFW firewall reset."
        sleep 2
        ;;
      11)
        read -p "Enter the IP address to whitelist: " ip_whitelist
        sudo ufw allow from $ip_whitelist
        ohai "IP address whitelisted."
        sleep 2
        ;;
      99)
        break
        ;;
    esac
done
}

submenuPluginSentinel(){
while true; do
    getNetworkConfig
    getBackTitle
    # Define the options for the submenu
    SUBOPTIONS=(
      1 "View Logs"
      2 "Start sentinel"
      3 "Stop sentinel"
      4 "Restart sentinel"
      5 "Edit .env configuration"
      6 "Update to latest release"
      7 "Uninstall plugin"
      - ""
      10 "Back to main menu"
    )

    # Display the submenu and get the user's choice
    SUBCHOICE=$(whiptail --clear --cancel-button "Back" \
      --backtitle "$BACKTITLE" \
      --title "Plugin - CSM Sentinel" \
      --menu "\nGet private notifications for your CSM Node Operator ID on Telegram\nConnect with your bot at t.me/[YOUR-BOT-NAME] and initiate service by typing /start" \
      0 0 0 \
      "${SUBOPTIONS[@]}" \
      3>&1 1>&2 2>&3)

    if [ $? -gt 0 ]; then # user pressed <Cancel> button
        break
    fi

    # Handle the user's choice from the submenu
    case $SUBCHOICE in
      1)
        sudo bash -c 'docker logs csm-sentinel -f -n 300 | ccze -A'
        ohai "Press ENTER to exit logs."
        read
        ;;
      2)
        sudo docker start csm-sentinel
        ;;
      3)
        sudo docker stop csm-sentinel
        ;;
      4)
        sudo docker restart csm-sentinel
        ;;
      5)
        sudo "${EDITOR}" /opt/ethpillar/plugin-sentinel/csm-sentinel/.env
        if whiptail --title "Reload env and restart services" --yesno "Do you want to restart with updated env?" 8 78; then
          sudo docker stop csm-sentinel
          runScript plugins/sentinel/plugin_csm_sentinel.sh -s
          sudo docker start csm-sentinel
        fi
        ;;
      6)
        runScript plugins/sentinel/plugin_csm_sentinel.sh -u
        ;;
      7)
        runScript plugins/sentinel/plugin_csm_sentinel.sh -r
        ;;
      10)
        break
        ;;
    esac
done
}

submenuPluginCSMValidator(){
while true; do
    getBackTitle
    # Define the options for the submenu
    SUBOPTIONS=(
      1 "View logs"
      2 "Start validator"
      3 "Stop validator"
      4 "Restart validator"
      5 "Edit configuration"
      6 "Edit environment file"
      7 "Update to latest release"
      - ""
      10 "Generate Validator Keys: Make a new secret recovery phrase"
      11 "Import Validator Keys: From offline key generation or backup"
      12 "Add/Restore Validator Keys: From secret recovery phrase"
      13 "View validator pubkeys and indices"
      - ""
      20 "Generate Voluntary Exit Messages (VEM)"
      21 "Broadcast Voluntary Exit Messages (VEM)"
      22 "Next withdrawal: See expected time, blocks to go"
      23 "Check validator status, balance"
      24 "Check validator entry/exit queue with beaconcha.in"
      25 "Attestation Performance: Obtain information about attester inclusion"
      - ""
      42 "Uninstall plugin"
      - ""
      99 "Back to main menu"
    )

    # Display the submenu and get the user's choice
    SUBCHOICE=$(whiptail --clear --cancel-button "Back" \
      --backtitle "$BACKTITLE" \
      --title "Plugin - Separate Lido CSM Validator" \
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
        sudo bash -c 'journalctl -fu csm_nimbusvalidator | ccze -A'
        ;;
      2)
        sudo service csm_nimbusvalidator start
        ;;
      3)
        sudo service csm_nimbusvalidator stop
        ;;
      4)
        sudo service csm_nimbusvalidator restart
        ;;
      5)
        sudo "${EDITOR}" /etc/systemd/system/csm_nimbusvalidator.service
        if whiptail --title "Reload daemon and restart services" --yesno "Do you want to restart validator?" 8 78; then
          sudo systemctl daemon-reload && sudo service csm_nimbusvalidator restart
        fi
        ;;
      6)
        sudo "${EDITOR}" /opt/ethpillar/plugin-csm/csm_env_vars
        if whiptail --title "Reload Environment values and restart services" --yesno "Do you want to restart validator?" 8 78; then
          sudo systemctl daemon-reload && sudo service csm_nimbusvalidator restart
        fi
        ;;
      7)
        runScript plugins/csm/plugin_csm_validator.sh -u
        ;;
      10)
        runScript plugins/csm/plugin_csm_validator.sh -g
        ;;
      11)
        runScript plugins/csm/plugin_csm_validator.sh -m
        ;;
      12)
        runScript plugins/csm/plugin_csm_validator.sh -d
        ;;
      13)
        runScript plugins/csm/plugin_csm_validator.sh -p
        ;;
      20)
        installEthdo
        generateVoluntaryExitMessage
        ;;
      21)
        installEthdo
        broadcastVoluntaryExitMessageLocally
        ;;
      22)
        installEthdo
        ethdoNextWithdrawalSweep
        ;;
      23)
        installEthdo
        checkValidatorStatus
        ;;
      24)
        checkValidatorQueue
        ;;
      25)
        installEthdo
        checkValidatorAttestationInclusion
        ;;
      42)
        runScript plugins/csm/plugin_csm_validator.sh -r
        ;;
      99)
        break
        ;;
    esac
done
}

submenuPlugins(){
while true; do
    getBackTitle
    # Define the options for the submenu
    SUBOPTIONS=(
      1 "Lido CSM Validator: Activate an extra validator service. Re-use this node's EL/CL."
      2 "CSM-Sentinel: Sends notifications for your CSM Node Operator ID. Self-hosted. Docker. Telegram."
      - ""
      99 "Back to main menu"
    )

    # Display the submenu and get the user's choice
    SUBCHOICE=$(whiptail --clear --cancel-button "Back" \
      --backtitle "$BACKTITLE" \
      --title "Plugins" \
      --menu "Choose from the following plugins to add functionality to your node:" \
      0 0 0 \
      "${SUBOPTIONS[@]}" \
      3>&1 1>&2 2>&3)

    if [ $? -gt 0 ]; then # user pressed <Cancel> button
        break
    fi

    # Handle the user's choice from the submenu
    case $SUBCHOICE in
      1)
        if [[ ! -f /etc/systemd/system/csm_nimbusvalidator.service ]]; then
          if whiptail --title "Install Lido CSM Validator" --yesno "Do you want to install an extra Nimbus validator service for Lido's CSM?" 8 78; then
            runScript plugins/csm/plugin_csm_validator.sh -i
          fi
        fi
        submenuPluginCSMValidator
        ;;
      2)
        if [[ ! -d /opt/ethpillar/plugin-sentinel ]]; then
            runScript plugins/sentinel/plugin_csm_sentinel.sh -i
        fi
        submenuPluginSentinel
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
      1 "eth-duties: Show upcoming block proposals, attestations, sync duties"
      2 "Monitoring: Observe Ethereum Metrics. Explore Dashboards."
      3 "NCDU: Find large files. Analyze disk usage."
      4 "Port Checker: Test for Incoming Connections"
      5 "ethdo: Conduct Common Validator Tasks"
      6 "Peer Count: Show # peers connected to EL & CL"
      7 "Beaconcha.in Validator Dashboard: Create a link for my validators"
      8 "Beaconcha.in: Check Validator Entry/Exit Queue time"
      9 "EL: Switch Execution Clients"
      10 "Timezone: Update machine's timezone"
      11 "Locales: Fix terminal formatting issues"
      12 "Privacy: Clear bash shell history"
      13 "Swapfile: Use disk space as extra RAM"
      14 "UFW Firewall: Control network traffic against unauthorized access"
      15 "Speedtest: Test internet bandwidth using speedtest.net"
      16 "Yet-Another-Bench-Script: Test node performance. Automated Benchmarking."
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
        # Skip if no validators installed
        if [[ ! -f /etc/systemd/system/validator.service ]]; then echo "No validator(s) installed. Press ENTER to continue."; read; break; fi
        # Skip if arm64
        [[ "${_arch}" == "arm64" ]] && echo "eth-duties not available for arm64. Press ENTER to continue." && read && break

        # Install eth-duties if not yet installed
        if [[ ! -f /usr/local/bin/eth-duties ]]; then
          if whiptail --title "Install eth-duties" --yesno "Do you want to install eth-duties?\n\neth-duties shows upcoming validator duties." 8 78; then
            runScript eth-duties.sh -i
          else
            break
          fi
        fi
        submenuEthduties
        ;;
      2)
        # Install monitoring if not yet installed
        if [[ ! -f /etc/systemd/system/ethereum-metrics-exporter.service ]]; then
          if whiptail --title "Install Monitoring" --yesno "Do you want to install Monitoring?\nIncludes: Ethereum Metrics Exporter, grafana, prometheus" 8 78; then
            runScript ethereum-metrics-exporter.sh -i
          else
            break
          fi
        fi
        submenuMonitoring
        ;;
      3)
        findLargestDiskUsage
        ;;
      4)
        checkOpenPorts
        ;;
      5)
        installEthdo
        submenuEthdo
        ;;
      6)
        getPeerCount
        ;;
      7)
        createBeaconChainDashboardLink
        ;;
      8)
        checkValidatorQueue
        ;;
      9)
        [[ "${_arch}" == "arm64" ]] && echo "EL Switcher not available for arm64. Press ENTER to continue." && read && break
        sudo /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/coincashew/client-switcher/master/install.sh)"
        ;;
      10)
        sudo dpkg-reconfigure tzdata
        ohai "Timezone updated. Press ENTER to continue."
        read
        ;;
      11)
        sudo update-locale "LANG=en_US.UTF-8"
        sudo locale-gen --purge "en_US.UTF-8"
        sudo dpkg-reconfigure --frontend noninteractive locales
        ohai "Updated locale to en_US.UTF-8"
        ohai "Logout and login for terminal locale updates to take effect. Press ENTER to continue."
        read
        ;;
      12)
        history -c && history -w
        ohai "Cleared bash history"
        read
        ;;
      13)
        addSwapfile
        ;;
      14)
        submenuUFW
        ;;
      15)
        testBandwidth
        ;;
      16)
        testYetAnotherBenchScript
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
    latest_block_number=$(curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' ${EL_RPC_ENDPOINT} | jq -r '.result')
    if [[ -n "$latest_block_number" && "$latest_block_number" != "0x0" ]]; then LB=$(printf 'Block %d' "$latest_block_number"); else LB="EL Syncing"; fi

    # Latest slot
    LS=$(curl -s -X GET "${API_BN_ENDPOINT}/eth/v1/node/syncing" -H "accept: application/json" | jq -r '.data.head_slot')
    if [[ -n "$LS" ]]; then LS="Slot $LS"; else LS="CL Syncing"; fi

    # Format gas price
    latest_gas_price=$(curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_gasPrice","params":[],"id":73}' ${EL_RPC_ENDPOINT} | jq -r '.result')
    if [[ -n "$latest_gas_price" ]]; then
      WEI=$(printf '%d' "$latest_gas_price");
      if ((1000000000<=$WEI && $WEI<=1000000000000)); then
          GP="$(echo "scale=1; $WEI / 1000000000" | bc) Gwei"
      elif ((1000000<=$WEI && $WEI<=1000000000)); then
          GP="$(echo "scale=1; $WEI / 1000000" | bc) Mwei"
      elif ((1000<=$WEI && $WEI<=1000000)); then
          GP="$(echo "scale=1; $WEI / 1000" | bc) Kwei"
      elif ((1<=$WEI && $WEI<=1000)); then
          GP="$(echo "scale=1; $WEI / 1" | bc) wei"
      else
          GP="Gas N/A - Syncing"
      fi
    fi

    # Format backtitle
    EL_TEXT=$(if [[ $(systemctl is-active --quiet execution) ]] || [[ "$LB" != "EL Syncing" ]] || [[ "$LB" == "EL Syncing" && "$latest_block_number" == "0x0" ]] ; then printf "$LB | $GP" ; elif [[ -f /etc/systemd/system/execution.service ]]; then printf "Offline EL" ; fi)
    CL_TEXT=$(if [[ $(systemctl is-active --quiet consensus) ]] || [[ "$LS" != "CL Syncing" ]]; then printf "$LS" ; elif [[ -f /etc/systemd/system/consensus.service ]]; then printf "Offline CL" ; fi)
    VC_TEXT=$(if systemctl is-active --quiet validator; then printf " | VC $VC" ; elif [[ -f /etc/systemd/system/validator.service ]]; then printf " | Offline VC $VC"; fi)
    CSM_TEXT=$(if systemctl is-active --quiet csm_nimbusvalidator; then printf " | CSM VC $CSM_VC"; elif [[ -f /etc/systemd/system/csm_nimbusvalidator.service ]]; then printf " | Offline CSM VC $CSM_VC"; fi)
    HOSTNAME=$(hostname)
    NETWORK_TEXT=$(if [[ $(systemctl is-active --quiet execution) ]] || [[ $LB != "EL Syncing" ]] || [[ "$LB" == "EL Syncing" && "$latest_block_number" == "0x0" ]]; then printf "$NETWORK on $HOSTNAME | "; else printf "$HOSTNAME | " ; fi)
    if [[ $NODE_MODE =~ "Validator Client Only" ]]; then
        BACKTITLE="${NETWORK_TEXT}${EL_TEXT} | ${CL_TEXT}${VC_TEXT} | Public Goods by CoinCashew.eth"
    else
        BACKTITLE="${NETWORK_TEXT}${EL_TEXT} | $CL_TEXT | $CL-$EL$VC_TEXT | Public Goods by CoinCashew.eth"
    fi
    if [[ ${PLUGIN_MODE:-false} == true ]]; then
    BACKTITLE="${NETWORK_TEXT}${EL_TEXT} | ${CL_TEXT} | $CL-$EL$VC_TEXT$CSM_TEXT | Public Goods by CoinCashew.eth"
    fi
}

function checkV1StakingSetup(){
  if [[ -f /etc/systemd/system/eth1.service ]]; then
    echo "EthPillar is only compatible with V2 Staking Setups. Using EthPillar, build a new node in minutes after wiping system or uninstalling V1."
    exit
  fi
}

# If no consensus or validator client service is installed, start install workflow
function installNode(){
  if [[ ! -f /etc/systemd/system/consensus.service && ! -f /etc/systemd/system/validator.service ]]; then
          _CLIENTCOMBO=$(whiptail --title "Choose your consensus and execution clients" --menu \
          "Pick your combination:" 10 78 2 \
          "Nimbus-Nethermind" "lightweight. secure. easy to use. nim and .net" \
          "Teku-Besu" "institutional grade. enterprise staking. java" \
          3>&1 1>&2 2>&3)
          case $_CLIENTCOMBO in
          Nimbus-Nethermind)
            runScript install-nimbus-nethermind.sh true
            ;;
          Teku-Besu)
            runScript install-teku-besu.sh true
            ;;
          esac
  fi
}

# Ask to apply patches
function applyPatches(){
  # Add motd to login message
  if ! grep -q "cat.*motd" ~/.profile; then
      echo "cat ~/git/ethpillar/motd" >> ~/.profile
  fi
}

# Determine node configuration
function setNodeMode(){
  if [[ -f /etc/systemd/system/execution.service && -f /etc/systemd/system/consensus.service && -f /etc/systemd/system/validator.service ]]; then
     if [[ $(grep --ignore-case -oE "${CSM_FEE_RECIPIENT_ADDRESS_MAINNET}" /etc/systemd/system/validator.service) || $(grep --ignore-case -oE "${CSM_FEE_RECIPIENT_ADDRESS_HOLESKY}" /etc/systemd/system/validator.service) || $(grep --ignore-case -oE "${CSM_FEE_RECIPIENT_ADDRESS_HOODI}" /etc/systemd/system/validator.service) ]]; then
        NODE_MODE="Lido CSM Staking Node"
     else
        NODE_MODE="Solo Staking Node"
     fi
  elif [[ -f /etc/systemd/system/execution.service ]] && [[ -f /etc/systemd/system/consensus.service ]] && [[ -f /etc/systemd/system/mevboost.service ]]; then
    NODE_MODE="Failover Staking Node"
  elif [[ -f /etc/systemd/system/execution.service ]] && [[ -f /etc/systemd/system/consensus.service ]]; then
    NODE_MODE="Full Node Only"
  elif [[ -f /etc/systemd/system/validator.service ]]; then
    if [[ $(grep --ignore-case -oE "${CSM_FEE_RECIPIENT_ADDRESS_MAINNET}" /etc/systemd/system/validator.service) || $(grep --ignore-case -oE "${CSM_FEE_RECIPIENT_ADDRESS_HOLESKY}" /etc/systemd/system/validator.service) || $(grep --ignore-case -oE "${CSM_FEE_RECIPIENT_ADDRESS_HOODI}" /etc/systemd/system/validator.service) ]]; then
        NODE_MODE="Lido CSM Validator Client Only"
    else
        NODE_MODE="Validator Client Only"
    fi
  else
    NODE_MODE="Not Installed"
  fi
  if [[ -f /etc/systemd/system/csm_nimbusvalidator.service ]]; then
    PLUGIN_MODE=true
  fi
  export NODE_MODE
}

checkV1StakingSetup
setWhiptailColors
installNode
applyPatches
checkDiskSpace
checkCPULoad
setNodeMode
menuMain
