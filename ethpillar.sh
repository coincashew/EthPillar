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

EP_VERSION="5.2.4"

# Default text editor
export EDITOR="nano"

# VARIABLES
export BASE_DIR="$HOME/git/ethpillar" && cd $BASE_DIR

# Load functions
source ./functions.sh

# Load environment variables, Lido CSM withdrawal address and fee recipient
source ./env

# Load environment variables overrides
[[ -f ./.env.overrides ]] && source ./.env.overrides

# Get machine info
_platform=$(get_platform)
_arch=$(get_arch)
export _platform _arch

initializeNetwork(){
  # Defaults if not provided
  : "${CL_IP_ADDRESS:=127.0.0.1}"
  : "${CL_REST_PORT:=5052}"
  : "${EL_IP_ADDRESS:=127.0.0.1}"
  : "${EL_RPC_PORT:=8545}"
  # Consensus client or beacon node HTTP Endpoint
  export API_BN_ENDPOINT="http://${CL_IP_ADDRESS}:${CL_REST_PORT}"
  # Execution layer RPC API
  export EL_RPC_ENDPOINT="http://${EL_IP_ADDRESS}:${EL_RPC_PORT}"

  # Handle Aztec remote RPC nodes
  if [[ -d /opt/ethpillar/aztec ]] && [[ ! -f /etc/systemd/system/consensus.service ]]; then
    # Load RPC URLs from .env
    if [[ -f /opt/ethpillar/aztec/.env ]]; then
      consensus_beacon_rpc=$(grep ^L1_CONSENSUS_HOST_URLS /opt/ethpillar/aztec/.env | sed 's/L1_CONSENSUS_HOST_URLS=//g')
      execution_l1_rpc=$(grep ^ETHEREUM_HOSTS /opt/ethpillar/aztec/.env | sed 's/ETHEREUM_HOSTS=//g')
    fi

    # If there's a list of comma separated rpc nodes, use the first node
    consensus_beacon_rpc=${consensus_beacon_rpc%%,*}
    execution_l1_rpc=${execution_l1_rpc%%,*}

    if [[ -n "$consensus_beacon_rpc" && -n "$execution_l1_rpc" ]]; then
      export API_BN_ENDPOINT="$consensus_beacon_rpc"
      export EL_RPC_ENDPOINT="$execution_l1_rpc"
    fi
  fi

  # Initialize network variables
  getNetworkConfig
  getNetwork
}

menuMain(){

# Define systemctl services
_SERVICES=("execution" "consensus" "validator" "mevboost" "csm_nimbusvalidator" "dora")
_SERVICES_NAME=("Execution Client" "Consensus Client" "Validator Client" "MEV-Boost" "CSM Nimbus Validator Plugin" "Dora the Explorer")
_SERVICES_ICON=("🔗" "🧠" "🚀" "⚡" "💧" "🔎")

function testAndServiceCommand() {
  for _service in "${_SERVICES[@]}"; do
    test -f /etc/systemd/system/"${_service}".service && sudo service "${_service}" "$1"
  done
}

function testAndPluginCommand() {
  local _DIRNAME=("aztec")
  for (( i=0; i<${#_DIRNAME[@]}; i++ )); do
    test -d /opt/ethpillar/"${_DIRNAME[i]}" && cd "/opt/ethpillar/${_DIRNAME[i]}" && docker compose "$1"
  done
}

function buildMenu() {
  for (( i=0; i<${#_SERVICES[@]}; i++ )); do
    test -f /etc/systemd/system/"${_SERVICES[i]}".service && OPTIONS+=("${_SERVICES_ICON[i]}" "${_SERVICES_NAME[i]}")
  done
}

function buildMenuPlugins() {
  local _DIRNAME=("aztec")
  local _NAME=("Aztec Sequencer")
  local _ICON=("🦆")
  for (( i=0; i<${#_NAME[@]}; i++ )); do
    test -d /opt/ethpillar/"${_DIRNAME[i]}" && OPTIONS+=("${_ICON[i]}" "${_NAME[i]}")
  done
}

# Define the options for the main menu
OPTIONS=(
  📈 "Logging & Monitoring"
  🛡️ "Security & Node Checks"
  - ""
)
buildMenu
buildMenuPlugins
OPTIONS+=(
  - ""
  ✅ "Start all clients"
  🛑 "Stop all clients"
  🔄 "Restart all clients"
  - ""
  🖥️ "System Administration"
  🛠️ "Toolbox"
  ⚙️ "Plugins"
  👋 "Quit"
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
      📈)
        submenuLogsMonitoring
        ;;
      🛡️)
        submenuSecurityNodeChecks
        ;;
      🔗)
        submenuExecution
        ;;
      🧠)
        submenuConsensus
        ;;
      🚀)
        submenuValidator
        ;;
      ⚡)
        submenuMEV-Boost
        ;;
      💧)
        submenuPluginCSMValidator
        ;;
      🔎)
        runScript plugins/dora/menu.sh
        ;;
      🦆)
        runScript plugins/aztec/menu.sh
        ;;
      ✅)
        testAndServiceCommand start
        testAndPluginCommand start
        ;;
      🛑)
        testAndServiceCommand stop
        testAndPluginCommand stop
        ;;
      🔄)
        testAndServiceCommand restart
        testAndPluginCommand restart
        ;;
      🖥️)
        submenuAdminstrative
        ;;
      🛠️)
        submenuTools
        ;;
      ⚙️)
        submenuPlugins
        ;;
      👋)
        break
        ;;
    esac
done
}

submenuLogsMonitoring(){
while true; do
    getBackTitle
    # Define the options for the submenu
    SUBOPTIONS=(
      📊 "View Log Dashboard: Maximize window, see all. To exit, press CTRL+B D"
      🔍 "View Rolling Consolidated Logs: All logs in one screen"
      📜 "Export logs: Save logs to disk for further analysis or sharing"
      🚨 "Monitoring: Observe Ethereum Metrics. Explore Dashboards. Grafana. Alerts."
      - ""
      👋 "Back to main menu"
    )

    # Display the submenu and get the user's choice
    SUBCHOICE=$(whiptail --clear --cancel-button "Back" \
      --backtitle "$BACKTITLE" \
      --title "Logging & Monitoring" \
      --menu "Choose one of the following options:" \
      0 0 0 \
      "${SUBOPTIONS[@]}" \
      3>&1 1>&2 2>&3)

    if [ $? -gt 0 ]; then # user pressed <Cancel> button
        break
    fi

    # Handle the user's choice from the submenu
    case $SUBCHOICE in
      📊)
        runScript view_logs.sh
        ;;
      🔍)
        # Aztec with remote rpc
        if [[ -d /opt/ethpillar/aztec ]] && [[ ! -f /etc/systemd/system/consensus.service ]]; then
              cd  /opt/ethpillar/aztec && docker compose logs -f --tail=233
        fi
        sudo bash -c 'journalctl -u validator -u consensus -u execution -u mevboost -u csm_nimbusvalidator --no-hostname -f | ccze -A'
        ;;
      📜)
        export_logs
        ;;
      🚨)
        # Install monitoring if not installed
        [[ ! -f /etc/systemd/system/ethereum-metrics-exporter.service ]] && runScript ethereum-metrics-exporter.sh -i
        submenuMonitoring
        ;;
      👋)
        break
        ;;
    esac
done
}

submenuSecurityNodeChecks(){
while true; do
    getBackTitle
    # Define the options for the submenu
    SUBOPTIONS=(
      🛡️ "Node Checker: Automated security and health checks for your node"
      🧱 "UFW Firewall: Control network traffic against unauthorized access"
      🤗 "Peer Count: Show # peers connected to EL & CL"
      🔄 "Port Checker: Test for Incoming Connections"
      🥷 "Privacy: Clear bash shell history"
      🛠️ "Unattended-upgrades: Automatically install security updates"
      🔐 "Fail2Ban: Automatically protecting your node from common attack patterns"
      🔒 "2FA: Secure your SSH access with two-factor authentication"
      - ""
      👋 "Back to main menu"
    )

    # Display the submenu and get the user's choice
    SUBCHOICE=$(whiptail --clear --cancel-button "Back" \
      --backtitle "$BACKTITLE" \
      --title "Security & Node Checks" \
      --menu "Choose one of the following options:" \
      0 0 0 \
      "${SUBOPTIONS[@]}" \
      3>&1 1>&2 2>&3)

    if [ $? -gt 0 ]; then # user pressed <Cancel> button
        break
    fi

    # Handle the user's choice from the submenu
    case $SUBCHOICE in
      🛡️)
        sudo bash -c './plugins/node-checker/run.sh'
        ;;
      🧱)
        submenuUFW
        ;;
      🤗)
        getPeerCount
        ;;
      🔐)
        sudo bash -c './helpers/install_fail2ban.sh'
        ;;
      🛠️)
        sudo bash -c './helpers/install_unattendedupgrades.sh'
        ;;
      🔒)
        # Enable 2fa only if ssh keys are present, check current user
        [[ ! $(grep -E '^ssh-([a-zA-Z0-9]+)' ~/.ssh/authorized_keys) ]] && whiptail --msgbox "⚠️ Please setup SSH key authentication first.\nAdd your public key to ~/.ssh/authorized_keys" 8 78 && return
        runScript ./helpers/install_2fa.sh
        ;;
      🔄)
        checkOpenPorts
        ;;
      🥷)
        history -c && history -w
        ohai "Cleared bash history"
        sleep 3
        ;;
      👋)
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
      🛠️ "Update system"
      🔄 "Restart system"
      ⏻ "Shutdown system"
      - ""
      📦 "View software versions"
      📊 "View cpu/ram/disk/net (btop)"
      📋 "View general node information"
      - ""
      ⬆️ "Update EthPillar"
      ℹ️ "About EthPillar"
      ❓ "Support: Get help"
      - ""
      ⚙️ "Configure autostart"
      🗑️ "Uninstall node"
      🔁 "Reinstall node: Change installation type, network"
      🔧 "Override environment variables"
      - ""
      👋 "Back to main menu"
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
      🛠️)
        sudo apt update && sudo apt upgrade -y && sudo apt autoremove -y
        ;;
      🔄)
        if whiptail --title "Reboot" --defaultno --yesno "Are you sure you want to reboot?" 8 78; then sudo reboot now; fi
        ;;
      ⏻)
        if whiptail --title "Shutdown" --defaultno --yesno "Are you sure you want to shutdown?" 8 78; then sudo shutdown now; fi
        ;;
      📦)
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
        whiptail --title "Installed versions" --msgbox "Consensus client: ${CL}\nExecution client: ${EL}\n${VC}\n${MB}\nEthPillar: $EP_VERSION" 12 78
        ;;
      📊)
        # Install btop process monitoring
        if ! command -v btop &> /dev/null; then
            sudo apt-get install btop -y
        fi
        btop --utf-force
      ;;
     📋)
        print_node_info
      ;;
      ⬆️)
        # Get current version
        local current_version=$EP_VERSION
        
        # Fetch latest version from remote
        cd "$BASE_DIR" || true
        git fetch origin main
        
        # Get latest version from remote
        latest_version=$(git show origin/main:ethpillar.sh | grep '^EP_VERSION=' | cut -d'"' -f2)
        
        # Format msgs
        if [[ "$current_version" == "$latest_version" ]]; then
          local MSG1="You are already on the latest version ($current_version).\n\nWould you like to pull the latest changes anyway?"
          local MSG2="Restart EthPillar for latest version."
        else
          local MSG1="Current version: $current_version\nLatest version: $latest_version\n\nWould you like to update?"
          local MSG2="Updated from $current_version to $latest_version.\nRestart EthPillar for latest version."
        fi

        # Prompt to update
        if whiptail --title "EthPillar Update" --yesno "$MSG1" 10 78; then
            # Backup .env.overrides if it exists
            [[ -f .env.overrides ]] && cp .env.overrides /tmp/env.overrides.backup
            
            # Update to latest
            git checkout main
            git pull --ff-only
            git reset --hard
            git clean -xdf
            
            # Restore .env.overrides if it was backed up
            [[ -f /tmp/env.overrides.backup ]] && mv /tmp/env.overrides.backup .env.overrides
            
            whiptail --title "Updated EthPillar" --msgbox "$MSG2" 10 78
        fi
        ;;
      ℹ️)
        MSG_ABOUT="🏡🥩 Since Pre-Merge 2020,\n- EthPillar is a free, open source, public good.\n- Made for Ethereum. Built on-chain. Powered by community.
        \n🚀 Get Involved: Make improvements & suggestions on GitHub\n- https://github.com/coincashew/ethpillar
        \n📣 Join community & ask questions on Discord:\n- https://discord.gg/dEpAVWgFNB
        \n✨ Support EthPillar on the next Gitcoin Grants round
        \n🙏 Donations:\n[ 0xCF83d0c22dd54475cC0C52721B0ef07d9756E8C0 ] || [ coincashew.eth ]"
        whiptail --title "About EthPillar" --msgbox "$MSG_ABOUT" 21 78
        ;;
      ❓)
      local MSG="
  official 🌐:
    https://docs.coincashew.com/ethpillar
    https://docs.coincashew.com/guides/mainnet

  FAQs ✨:
    https://docs.coincashew.com/ethpillar/faq

  discord 📣:
    https://discord.gg/WS8E3PMzrb

  ethstaker community 🚨:
    knowledge base - https://docs.ethstaker.org
    discord - http://dsc.gg/ethstaker
    reddit - https://www.reddit.com/r/ethstaker

  github 👀:
    https://github.com/coincashew/EthPillar

  lido csm 💧:
    https://docs.lido.fi/run-on-lido/csm/node-setup/intermediate/ethpillar
"
      whiptail --title "❓ somETHing helpful" --msgbox "$MSG" 28 78
      ;;
      ⚙️)
        configureAutoStart
      ;;
      🗑️)
        runScript uninstall.sh
        ;;
      🔁)
        if whiptail --title "Reinstall EthPillar" --defaultno --yesno "Are you sure you want to reinstall?\nAll current node data will be removed." 9 78; then
           if runScript uninstall.sh; then
              installNode
              whiptail --title "Reinstall complete" --msgbox "Completed node reinstall process." 8 78
           fi
        fi
        ;;
      🔧)
        if [[ ! -f ${BASE_DIR}/.env.overrides ]]; then
           # Create from template
           cp .env.overrides.example .env.overrides
        fi
        "${EDITOR}" .env.overrides
        # Reload environment variables overrides
        [[ -f ./.env.overrides ]] && source ./.env.overrides
        ;;
      👋)
        break
        ;;
    esac
done
}

submenuMonitoring(){
while true; do
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
        sudo bash -c 'journalctl -u grafana-server -u prometheus -u ethereum-metrics-exporter -u prometheus-node-exporter --no-hostname -f | ccze -A'
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
        getPubKeys && getIndices
        if [[ ${#INDICES[@]} = "0" ]]; then echo "No validators currently active. Once validators are activated, you can query duties."; sleep 5;
return; fi
        /usr/local/bin/eth-duties --validators "${INDICES[@]}" --beacon-nodes "$API_BN_ENDPOINT"
        ;;
      2)
        getPubKeys && getIndices
        if [[ ${#INDICES[@]} = "0" ]]; then echo "No validators currently active. Once validators are activated, you can query duties."; sleep 5;
return; fi
        /usr/local/bin/eth-duties --validators "${INDICES[@]}" --beacon-nodes "$API_BN_ENDPOINT" --max-attestation-duty-logs 60 --mode cicd-wait --mode-cicd-attestation-time 90 --mode-cicd-attestation-proportion 0.90
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
          while true; do
            read -r -p "Enter your SSH port. Press Enter to use default '22': " _ssh_port
            _ssh_port=${_ssh_port:-22}
            if ! [[ "$_ssh_port" =~ ^[0-9]+$ ]] || [ "$_ssh_port" -lt 1 ] || [ "$_ssh_port" -gt 65535 ]; then
                 whiptail --title "Error" --msgbox "Invalid port. Try again." 8 78
            else
                if [ "$_ssh_port" -eq 22 ]; then
                  sudo ufw limit 22/tcp comment 'Rate-limit SSH (port 22)'
                else
                  sudo ufw allow "${_ssh_port}/tcp" comment 'Allow SSH port'
                fi
                break
            fi
          done
        fi
        sudo ufw allow 30303 comment 'Allow execution client port'
        sudo ufw allow 9000 comment 'Allow consensus client port'
        getClient
        [[ $CL == "Lighthouse" ]] && sudo ufw allow 9001/udp comment 'Allow consensus client QUIC port'
        [[ $EL == "Reth" ]] && sudo ufw allow 30304/udp comment 'Allow execution client discv5 port'
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

submenuPerformanceTuning(){
while true; do
    getBackTitle
    # Define the options for the submenu
    SUBOPTIONS=(
      1 "Swappiness: Optimize pages between memory and the swap space"
      2 "noatime: Reduced disk I/O and improved performance"
      - ""
      99 "Back to main menu"
    )

    # Display the submenu and get the user's choice
    SUBCHOICE=$(whiptail --clear --cancel-button "Back" \
      --backtitle "$BACKTITLE" \
      --title "Performance Tuning" \
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
        sudo bash -c './helpers/set_swappiness.sh'
        ;;
      2)
        sudo bash -c './helpers/set_noatime.sh'
        ;;
      99)
        break
        ;;
    esac
done
}

submenuPluginSentinel(){
while true; do
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
      🛡️ "Node Checker: Automated security and health checks for your node."
      💧 "Lido CSM Validator: Activate an extra validator service. Re-use this node's EL/CL."
      ⛑️ "CSM-Sentinel: Sends notifications for your CSM Node Operator ID. Self-hosted. Docker. Telegram."
      🔎 "Dora the Explorer: lightweight beaconchain explorer. validator actions. self-hosted. private."
      🔧 "eth-validator-cli by TobiWo: managing validators via execution layer requests"
      🌈 "Prysm client-stats: collects metrics from CL & VC. publishes to beaconcha.in stats service"
      🐼 "Contributoor: powerful monitoring & data-gathering tool. enhances network transparency"
      🦆 "Aztec Sepolia Sequencer: Run a sequencer validating node for privacy first L2 by Aztec Labs"
      - ""
      👋 "Back to main menu"
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
      🛡️)
        sudo bash -c './plugins/node-checker/run.sh'
        ;;
      💧)
        if [[ ! -f /etc/systemd/system/csm_nimbusvalidator.service ]]; then
          if whiptail --title "Install Lido CSM Validator" --yesno "Do you want to install an extra Nimbus validator service for Lido's CSM?" 8 78; then
            runScript plugins/csm/plugin_csm_validator.sh -i
          fi
        fi
        submenuPluginCSMValidator
        ;;
      ⛑️)
        if [[ ! -d /opt/ethpillar/plugin-sentinel ]]; then
            runScript plugins/sentinel/plugin_csm_sentinel.sh -i
        fi
        submenuPluginSentinel
        ;;
      🦆)
        if [[ ! -d /opt/ethpillar/aztec ]]; then
            runScript plugins/aztec/plugin_aztec.sh -i
        fi
        [[ -d /opt/ethpillar/aztec ]] && runScript plugins/aztec/menu.sh
        ;;
      🔎)
        if [[ ! -d /opt/ethpillar/plugin-dora ]]; then
            runScript plugins/dora/plugin_dora.sh -i
        fi
        runScript plugins/dora/menu.sh
        ;;
      🌈)
        if [[ ! -d /opt/ethpillar/plugin-client-stats ]]; then
            runScript plugins/client-stats/plugin_client_stats.sh -i
        fi
        runScript plugins/client-stats/menu.sh
        ;;
      🐼)
        if [[ ! -d /opt/ethpillar/plugin-contributoor ]]; then
            runScript plugins/contributoor/plugin_contributoor.sh -i
        fi
        runScript plugins/contributoor/menu.sh
        ;;
      🔧)
        export BACKTITLE EDITOR _platform _arch
        if [[ ! -d /opt/ethpillar/plugin-eth-validator-cli ]]; then
            runScript plugins/eth-validator-cli/plugin_eth-validator-cli.sh -i
        fi
        runScript plugins/eth-validator-cli/menu.sh
        ;;
      👋)
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
      ⚙️ "eth-duties: Show upcoming block proposals, attestations, sync duties"
      💎 "ethdo: Conduct common validator tasks"
      💾 "NCDU: Find large files. Analyze disk usage."
      🔗 "Beaconcha.in Validator Dashboard: Create a link for my validators"
      🚪 "Beaconcha.in: Check validator entry/exit queue time"
      💻 "EL: Switch execution clients"
      ⌚ "Timezone: Update machine's timezone"
      🌐 "Locales: Fix terminal formatting issues"
      📁 "Swapfile: Use disk space as extra RAM"
      🚄 "Speedtest: Test internet bandwidth using speedtest.net"
      💪 "Yet-Another-Bench-Script: Test node performance. Automated Benchmarking."
      🚀 "Performance Tuning: Optimize your nodes with OS tweaks"
      - ""
      👋 "Back to main menu"
    )

    # Display the submenu and get the user's choice
    SUBCHOICE=$(whiptail --clear --cancel-button "Back" \
      --backtitle "$BACKTITLE" \
      --title "Toolbox" \
      --menu "Choose one of the following options:" \
      0 0 0 \
      "${SUBOPTIONS[@]}" \
      3>&1 1>&2 2>&3)

    if [ $? -gt 0 ]; then # user pressed <Cancel> button
        break
    fi

    # Handle the user's choice from the submenu
    case $SUBCHOICE in
      ⚙️)
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
      💾)
        findLargestDiskUsage
        ;;
      💎)
        installEthdo
        submenuEthdo
        ;;
      🔗)
        createBeaconChainDashboardLink
        ;;
      🚪)
        checkValidatorQueue
        ;;
      💻)
        [[ "${_arch}" == "arm64" ]] && echo "EL Switcher not available for arm64. Press ENTER to continue." && read && break
        [[ "${NETWORK,,}" == "ephemery" ]] && echo "EL Switcher not available for EPHEMERY testnet. To switch, use System Admin > Reinstall node . Press ENTER to continue." && read && break
        sudo /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/coincashew/client-switcher/master/install.sh)"
        ;;
      ⌚)
        sudo dpkg-reconfigure tzdata
        ohai "Timezone updated. Press ENTER to continue."
        read
        ;;
      🌐)
        sudo update-locale "LANG=en_US.UTF-8"
        sudo locale-gen --purge "en_US.UTF-8"
        sudo dpkg-reconfigure --frontend noninteractive locales
        ohai "Updated locale to en_US.UTF-8"
        ohai "Logout and login for terminal locale updates to take effect. Press ENTER to continue."
        read
        ;;
      📁)
        addSwapfile
        ;;
      🚄)
        testBandwidth
        ;;
      💪)
        testYetAnotherBenchScript
        ;;
      🚀)
        submenuPerformanceTuning
        ;;
      👋)
        break
        ;;
    esac
done
}

function getBackTitle(){
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
    export BACKTITLE
}

function checkV1StakingSetup(){
  if [[ -f /etc/systemd/system/eth1.service ]]; then
    echo "EthPillar is only compatible with V2 Staking Setups. Using EthPillar, build a new node in minutes after wiping system or uninstalling V1."
    exit
  fi
}

# If no consensus or validator client service is installed, start install workflow
function installNode(){
  if [[ ! -f /etc/systemd/system/consensus.service && ! -f /etc/systemd/system/validator.service && ! -d /opt/ethpillar/aztec ]]; then
          local _CLIENTCOMBO _file
          _CLIENTCOMBO=$(whiptail --title "⚙️  Node Configuration" --menu \
          "Pick your combination:" 13 78 5 \
          "Nimbus-Nethermind" "lightweight. secure. easy to use. nim and .net" \
          "Lodestar-Besu" "performant. robust. ziglang & javascript & java" \
          "Teku-Besu" "institutional grade. enterprise staking. java" \
          "Lighthouse-Reth" "built in rust. security focused. performance" \
          "Aztec L2 Sequencer" "by Aztec Labs. support privacy. permissionless" \
          3>&1 1>&2 2>&3)
          if [ $? -gt 0 ]; then # user pressed <Cancel> button
            return
          else
            if [ "$_CLIENTCOMBO" == "Aztec L2 Sequencer" ]; then
              runScript plugins/aztec/plugin_aztec.sh -i
              exit 0
            else
              _file="deploy-${_CLIENTCOMBO,,}.py"
              runScript install-node.sh "${_file}" true
            fi
          fi
  fi
}

# Ask to apply patches
function applyPatches(){
  # Add motd to login message
  if ! grep -q "cat.*motd" ~/.profile; then
      echo "cat ~/git/ethpillar/motd" >> ~/.profile
  fi
  # Fix terminal formatting with locale
  current_locale=$(locale | grep '^LANG=' | awk -F= '{print $2}')
  if [[ ! -f /opt/ethpillar/patches/002-locale.completed ]] && [[ ! "$current_locale" == *"UTF"* ]]; then
    if whiptail --title "New Patch Available - Set locale to fix terminal, missing emojis" --yesno "Would you like to apply patch 2?\n\nMore info: https://github.com/coincashew/EthPillar/issues/73" 9 78; then
      runScript patches/002-locale.sh
    fi
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
    NODE_MODE="Full Node"
  elif [[ -f /etc/systemd/system/validator.service ]]; then
    if [[ $(grep --ignore-case -oE "${CSM_FEE_RECIPIENT_ADDRESS_MAINNET}" /etc/systemd/system/validator.service) || $(grep --ignore-case -oE "${CSM_FEE_RECIPIENT_ADDRESS_HOLESKY}" /etc/systemd/system/validator.service) || $(grep --ignore-case -oE "${CSM_FEE_RECIPIENT_ADDRESS_HOODI}" /etc/systemd/system/validator.service) ]]; then
        NODE_MODE="Lido CSM Validator Client Only"
    else
        NODE_MODE="Validator Client Only"
    fi
  elif [[ -d /opt/ethpillar/aztec ]] && [[ ! -f /etc/systemd/system/consensus.service ]]; then
      NODE_MODE="Aztec Node | Remote RPC"
  else
    NODE_MODE="Not Installed"
  fi
  if [[ -d /opt/ethpillar/aztec ]] && [[ -f /etc/systemd/system/consensus.service ]]; then
      NODE_MODE+=" | Aztec Node | Local RPC"
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
initializeNetwork
menuMain
