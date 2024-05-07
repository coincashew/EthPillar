#!/bin/bash

# Author: coincashew.eth | coincashew.com
# License: GNU GPL
# Source: https://github.com/coincashew/ethpillar
# Description: EthPillar is a one-liner setup tool and node management TUI

# Made for home and solo stakers 🏠🥩

set -u

# enable command completion
set -o history -o histexpand

# VARIABLES
BASE_DIR=$HOME/git/ethpillar
ip_current=$(hostname --ip-address)
interface_current=$(ip route | grep default | sed 's/.*dev \([^ ]*\) .*/\1/')
network_current="$(ip route | grep $interface_current | grep -v default | head -1 | awk '{print $1}')"
# Consensus client or beacon node HTTP Endpoint
API_BN_ENDPOINT=http://127.0.0.1:5052
# Execution layer RPC API
EL_RPC_ENDPOINT=localhost:8545

# Stores validator index
declare -a INDICES

exit_on_error() {
    exit_code=$1
    last_command=${@:2}
    if [ $exit_code -ne 0 ]; then
        >&2 echo "\"${last_command}\" command failed with exit code ${exit_code}."
        exit $exit_code
    fi
}

# string formatters
if [[ -t 1 ]]; then
  tty_escape() { printf "\033[%sm" "$1"; }
else
  tty_escape() { :; }
fi
tty_mkbold() { tty_escape "1;$1"; }
tty_underline="$(tty_escape "4;39")"
tty_blue="$(tty_mkbold 34)"
tty_red="$(tty_mkbold 31)"
tty_bold="$(tty_mkbold 39)"
tty_reset="$(tty_escape 0)"

shell_join() {
  local arg
  printf "%s" "$1"
  shift
  for arg in "$@"; do
    printf " "
    printf "%s" "${arg// /\ }"
  done
}

ohai() {
  printf "${tty_blue}==>${tty_bold} %s${tty_reset}\n" "$(shell_join "$@")"
}

network_down() {
    sudo ip link set $interface_current down
}

network_up() {
    sudo ip link set $interface_current up
}

network_isConnected() {
  #check to see if the device is connected to the network
  sudo ip route get 1 2>/dev/null
}

print_node_info() {
  current_time=$(date)
  os_descrip=$(grep PRETTY_NAME /etc/os-release | sed 's/PRETTY_NAME=//g')
  os_version=$(grep VERSION_ID /etc/os-release | sed 's/VERSION_ID=//g')
  kernel_version=$(uname -r)
  system_uptime=$(uptime | sed 's/.*up \([^,]*\), .*/\1/')
  chrony_status=$(if systemctl is-active --quiet chronyd ; then printf "Online" ; else printf "Offline" ; fi)
  consensus_status=$(if systemctl is-active --quiet consensus ; then printf "Online" ; else printf "Offline" ; fi)
  execution_status=$(if systemctl is-active --quiet execution ; then printf "Online" ; else printf "Offline" ; fi)
  validator_status=$(if systemctl is-active --quiet validator ; then printf "Online" ; elif [ -f /etc/systemd/system/validator.service ]; then printf "Offline" ; else printf "Not Installed"; fi)
  mevboost_status=$(if systemctl is-active --quiet mevboost ; then printf "Online" ; elif [ -f /etc/systemd/system/mevboost.service ]; then printf "Offline" ; else printf "Not Installed"; fi)
  ethpillar_commit=$(git -C "${BASE_DIR}" rev-parse HEAD)
  ethpillar_version=$(grep VERSION= $BASE_DIR/ethpillar.sh | sed 's/VERSION=//g')
  SERVICES=(execution consensus validator mevboost)
  autostart_status=()
  for UNIT in ${SERVICES[@]}
      do
        if [[ -f /etc/systemd/system/${UNIT}.service ]]; then
          autostart_status+=("${UNIT}: $(if systemctl is-enabled --quiet ${UNIT}; then printf "✔"; else printf "❌"; fi)")
        fi
      done

  info_txt=$(cat <<EOF
Current time     :  $current_time
OS Description   :  $os_descrip
OS Version       :  $os_version
Kernel Version   :  $kernel_version
Uptime           :  $system_uptime
Chrony           :  $chrony_status

Consensus Status :  $consensus_status
Execution Status :  $execution_status
Validator Status :  $validator_status
Mevboost Status  :  $mevboost_status
Autostart at Boot:  ${autostart_status[@]}

EthPillar Version:  $ethpillar_version
EthPillar Commit :  $ethpillar_commit
EOF
)
whiptail --title "General Node Information" --msgbox "$info_txt" 22 78
}

setWhiptailColors(){
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

# Runs a script
runScript() {
    SCRIPT_NAME="$1"
    SCRIPT_PATH="$BASE_DIR/$SCRIPT_NAME"

    if [[ ! -x $SCRIPT_PATH ]]; then
        chmod +x $SCRIPT_PATH
    fi

    shift
    ARGUMENTS="$*"

    if [[ -f $SCRIPT_PATH && -x $SCRIPT_PATH ]]; then
        bash -c "$SCRIPT_PATH $ARGUMENTS"
    else
        echo "Error: $SCRIPT_PATH not run. Check permissions or path."
        exit 1
    fi
}

getNetwork(){
    # Get network name from execution client
    result=$(curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"net_version","params":[],"id":67}' ${EL_RPC_ENDPOINT} | jq -r '.result')
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
    *)
      NETWORK="Custom Network"
    esac
}

# Read clients from systemd config files
getClient(){
    EL=$(test -f /etc/systemd/system/execution.service  && grep Description= /etc/systemd/system/execution.service | awk -F'=' '{print $2}' | awk '{print $1}')
    CL=$(test -f /etc/systemd/system/consensus.service  && grep Description= /etc/systemd/system/consensus.service | awk -F'=' '{print $2}' | awk '{print $1}')
    VC=$(test -f /etc/systemd/system/validator.service  && grep Description= /etc/systemd/system/validator.service | awk -F'=' '{print $2}' | awk '{print $1}')
}

# Get list of validator public keys
getPubKeys(){
   NETWORK=$(echo $NETWORK | tr "[:upper:]" "[:lower:]")
   TEMP=""
   case $VC in
      Lighthouse)
         TEMP=$(/usr/local/bin/lighthouse account validator list --network $NETWORK --datadir /var/lib/lighthouse | grep -Eo '0x[a-fA-F0-9]{96}')
         convertLIST
      ;;
      Lodestar)
         cd /usr/local/bin/lodestar
         TEMP=$(sudo -u validator /usr/local/bin/lodestar/lodestar validator list --network $NETWORK  --dataDir /var/lib/lodestar/validators | grep -Eo '0x[a-fA-F0-9]{96}')
         convertLIST
      ;;
      Teku)
         _teku=()
         # Command if combined CL+VC
         teku_cmd="ls /var/lib/teku/validator_keys/*.json"
         # Command if standalone VC
         test -f /etc/systemd/system/validator.service && teku_cmd="ls /var/lib/teku_validator/validator_keys/*.json"
         for json in $(sudo -u validator bash -c "$teku_cmd")
         do
            _teku+=(0x$(sudo -u validator bash -c "cat $json | jq -r '.pubkey'"))
         done
         # Convert to string
         TEMP=${_teku[@]}
         convertLIST
      ;;
      Nimbus)
         # Command if combined CL+VC
         nimbus_cmd="ls /var/lib/nimbus/validators | grep -Eo '0x[a-fA-F0-9]{96}'"
         # Command if standalone VC
         test -f /etc/systemd/system/validator.service && nimbus_cmd="ls /var/lib/nimbus_validator/validators | grep -Eo '0x[a-fA-F0-9]{96}'"
         TEMP=$(sudo -u validator bash -c "$nimbus_cmd")
         convertLIST
      ;;
      Prysm)
         TEMP=$(/usr/local/bin/validator accounts list --$NETWORK --wallet-dir=/var/lib/prysm/validators | grep -Eo '0x[a-fA-F0-9]{96}')
         convertLIST
      ;;
   esac
}

convertLIST(){
# Reset var
LIST=()
for key in $TEMP
do
   LIST+=($key)
done
}

# Convert pubkeys to index
getIndices(){
   # API URL Path for duties
   local API_URL_DUTIES=$API_BN_ENDPOINT/eth/v1/
   # API URL Path for indices
   local API_URL_INDICES=$API_BN_ENDPOINT/eth/v1/beacon/states/head/validators
   # Reset var
   INDICES=()

   for PUBKEY in ${LIST[@]}
      do
         VALIDATOR_INDEX=$(curl -s -X GET $API_URL_INDICES/$PUBKEY | jq -r .data.index)
         INDICES+=($VALIDATOR_INDEX)
      done
}

# Prints list of pubkeys and indices
viewPubkeyAndIndices(){
   local COUNT=${#LIST[@]}
   if [ "$COUNT" = "0" ]; then
      echo "No validators keys loaded. Press ENTER to finish."
      read
      return
   fi
   ohai "==========================================="
   ohai "Total # Validator Keys: $COUNT"
   ohai "==========================================="
   ohai "Pubkeys:"
   for i in "${LIST[@]}"; do
      echo $i
   done
   ohai "==========================================="
   ohai "Indices:"
   echo ${INDICES[@]}
   ohai "Press ENTER to finish."
   read
}

# Checks for open ports. Diagnose peering/router/port-forwarding issues.
checkOpenPorts(){
    clear
    ohai "Checking for Open Ports:"
    ohai "- Properly configuring open ports will improve validator performance and network health."
    ohai "- Test if ports (e.g. 30303, 9000) are accessible from the Internet."
    ohai "- Test if port forwarding and/or firewalls are properly configured."
    ohai "- Replace 30303 and 9000 with custom or client-specific port numbers as needed."

    # Read the ports from user input
    read -r -p "Enter your Consensus Client's P2P port (press Enter to use default 9000): " CL_PORT
    CL_PORT=${CL_PORT:-9000}
    ohai "Using port ${CL_PORT} for Consensus Client's P2P port."
    read -r -p "Enter your Execution Client's P2P port (press Enter to use default 30303): " EL_PORT
    EL_PORT=${EL_PORT:-30303}
    ohai "Using port ${EL_PORT} for Execution Client's P2P port."

    # Call port checker
    ohai "Calling https://eth2-client-port-checker.vercel.app/api/checker?ports=$EL_PORT,$CL_PORT"
    json=$(curl https://eth2-client-port-checker.vercel.app/api/checker?ports=$EL_PORT,$CL_PORT)

    # Parse JSON using jq and print requester IP
    ohai "Your IP: $(echo "$json" | jq -r .requester_ip)"

    # Parse JSON using jq and check if any open ports exist
    if $(echo "$json" | jq -e '.open_ports[]' > /dev/null 2>&1); then
      ohai "Open ports found:"
      echo "$json" | jq -r '.open_ports[]' | while read port; do echo $port; done
    else
      ohai "No open ports found."
    fi
    ohai "Press ENTER to finish."
    read
}

# Find largest disk usage
findLargestDiskUsage(){
  # Install ncdu if not installed
  if ! command -v ncdu >/dev/null 2>&1 ; then sudo apt-get install ncdu; fi
  clear
  # Explain ncdu's purpose
  ohai "ncdu (NCurses Disk Usage) is a disk usage analysis tool that runs on the Linux command line interface (CLI)."
  echo "- Provides an interactive, graphical display of your file system's directory content and their respective sizes."
  echo "- Navigate through your directories to see a detailed breakdown of file and folder sizes in a tree-like hierarchy."
  echo "- This tool is particularly useful for finding large files or folders that are consuming excessive storage space on your Linux systems."
  ohai "Press ENTER to run ncdu."
  read
  # Run ncdu on root directory
  ncdu /
}
 
# Configure autostart of services
configureAutoStart(){
    clear
    echo "${tty_bold}Enable node to autostart when system boots up? [y|n]${tty_reset}" 
    read -rsn1 yn
    if [[ ${yn} = [Yy]* ]]; then
        sudo systemctl enable execution.service
        sudo systemctl enable consensus.service
        if [[ -f /etc/systemd/system/validator.service ]]; then
          sudo systemctl enable validator.service
        fi
        if [[ -f /etc/systemd/system/mevboost.service ]]; then
          sudo systemctl enable mevboost.service
        fi
        ohai "Enabled node's systemd services. Node will autostart at boot."
    else
        sudo systemctl disable execution.service
        sudo systemctl disable consensus.service
        if [[ -f /etc/systemd/system/validator.service ]]; then
          sudo systemctl disable validator.service
        fi
        if [[ -f /etc/systemd/system/mevboost.service ]]; then
          sudo systemctl disable mevboost.service
        fi
        ohai "Disabled node's systemd services. Node will not autostart at boot."
    fi
    ohai "Press ENTER to continue"
    read
}

# Checks whether a validator pubkey is registered on all relays found in mevboost.service
checkRelayRegistration(){
    #Variables
    URL_PATH="relay/v1/data/validator_registration?pubkey="

    # Check for mevboost installation
    if [ ! -f /etc/systemd/system/mevboost.service ]; then echo "No relays to check. Mevboost service not installed."; exit 1; fi;

    # Extract relay urls from mevboost.service, store in array
    RELAYS=($(cat /etc/systemd/system/mevboost.service  | sed "s/ /\n/g" | sed -n "/https.*@/p"))
    ohai "Found # of relays in mevboost.service:  ${#RELAYS[@]}"

    # Populate pubkeys into LIST
    getPubKeys
    if [ ${#LIST[@]} -gt 0 ]; then
        # Query checks with the first pubkey
        VALIDATOR_KEY=${LIST[0]}
    else
        echo "No validator pubkeys detected."
        exit 1
    fi
    ohai "To check for relay registration, using the first pubkey: $VALIDATOR_KEY"

    for INDEX in ${!RELAYS[@]}
       do
          # Strip out the relays domain name
          URL_BASE=$(echo ${RELAYS[INDEX]} | sed 's/.*@\(.*\)/https:\/\/\1/')
          # Build relay registration check url
          URL_CHECK=${URL_BASE}/${URL_PATH}${VALIDATOR_KEY}
          # Print out if registered to relay or not
          if [ "$(curl --max-time 10 -Ls ${URL_CHECK} | jq .code)"  = null ]; then
             echo "Relay $((INDEX+1)): $URL_BASE ✅"
          else
             echo "Relay $((INDEX+1)): $URL_BASE ❌"
          fi
       done
    ohai "Relay check complete"
    ohai "Press ENTER to continue"
    read
}

addSwapfile(){
    # Check if there is already an active swap file
    if [ "$(swapon --show | wc -l)" -eq "0" ]; then
        # Prompt the user for the swap file size
        read -r -p "Enter the size of the swap file (e.g. '8G' for 8GB). Press Enter to use default, 8G: " SWAP_SIZE
        SWAP_SIZE=${SWAP_SIZE:-8G}

        # Prompt the user for the swap path
        read -r -p "Enter the path of the swap file (e.g. /swapfile). Press Enter to use default '/swapfile': " SWAP_PATH
        SWAP_PATH=${SWAP_PATH:-/swapfile}

        # Create the swap file in /swapfile with the given size
        sudo fallocate -l "${SWAP_SIZE}" ${SWAP_PATH}

        # Change the permissions to read and write for root
        sudo chmod 600 ${SWAP_PATH}

        # Make /swapfile
        sudo mkswap ${SWAP_PATH}

        # Enable swapping on the new file and remember the setting persistently across reboots
        sudo swapon ${SWAP_PATH}
        echo "${SWAP_PATH} swap swap defaults 0 0" | sudo tee -a /etc/fstab > /dev/null
        echo "Swap file created."

        # Update Swappiness
        echo "Lower RAM Swappiness to 10"
        # Temporarily change the swappiness value
        sudo sysctl vm.swappiness=10
        # Make the change permanent
        sudo bash -c 'echo "vm.swappiness = 10" >> /etc/sysctl.conf'
    else
        echo "Swap is already enabled."
    fi
    ohai "Press ENTER to continue"
    read
}

generateVoluntaryExitMessage(){
    local VEM_PATH=$HOME/voluntary-exit-messages
    clear
    echo "################################################################"
    ohai "Generate a Voluntary Exit Message (VEM) for each validator."
    echo "################################################################"
    ohai "Before starting: Validators must be currently active and assigned a validator index."
    echo ""
    ohai "Requirements: To generate voluntary exit messages, have the following ready:"
    echo "1) A path to the directory containing your keystore-m_####.json file(s)"
    echo "2) The keystore's passphrase"
    echo ""
    echo "Note: “passphrase” is NOT your mnemonic or secret recovery phrase!"
    echo ""
    ohai "Result of this operation:"
    echo "- One VEM file (e.g. exit_validator_index_#.json) per validator is generated."
    echo "- VEMs do not expire and are valid throughout future forks/upgrades."
    echo "- This operation does NOT broadcast your VEM and consequently, exit your validator."
    echo ""
    ohai "Next steps:"
    echo "- When it's time to exit your validator, broadcast the VEM locally or with beaconcha.in tool"
    echo "- Backup and save VEMs to external storage. (e.g. USB drive)"
    echo "- Share with your heirs."
    echo "- For more information on what happens AFTER broadcasting a VEM with detailed timelines, see:"
    echo "  https://www.coincashew.com/coins/overview-eth/guide-or-how-to-setup-a-validator-on-eth2-mainnet/part-iii-tips/voluntary-exiting-a-validator"
    echo ""
    echo "${tty_bold}Do you wish to continue? [y|n]${tty_reset}"
    read -rsn1 yn
    if [[ ${yn} = [Yy]* ]]; then
        # Create path to store VEMs
        [[ -d $HOME/voluntary-exit-messages ]] || mkdir -p $VEM_PATH

        # Prompt user for path to keystores
        read -r -p "Enter path to your keystore-m_##.json file(s): " KEYSTORE_PATH
        # Check number of keystores
        local COUNT=$(ls ${KEYSTORE_PATH}/keystore*.json | wc -l)
        if [[ $COUNT -gt 0 ]]; then
            echo "INFO: Found $COUNT keystore files"
            echo "INFO: Using keystore path: $KEYSTORE_PATH"
        else
            echo "No keystores found at $KEYSTORE_PATH"
            ohai "Press ENTER to continue"
            read
            exit 1
        fi

        # Prompt user for keystore passphrase
        read -r -p "Enter keystore passphrase: " KEYSTORE_PASSPHRASE
        echo "INFO: Using keystore passphrase: $KEYSTORE_PASSPHRASE"

        # Iterate through each file and create the VEM
        for KEYSTORE in $(ls ${KEYSTORE_PATH}/keystore*.json);
        do
           ethdo validator exit --validator=${KEYSTORE} "--passphrase=${KEYSTORE_PASSPHRASE}" --json > $VEM_PATH/exit_tmp.json
           INDEX=$(cat $VEM_PATH/exit_tmp.json | jq -r .message.validator_index)
           # Rename exit file with validator index
           mv $VEM_PATH/exit_tmp.json $VEM_PATH/exit_validator_index_${INDEX}.json
           echo "INFO: Generated voluntary exit message for index ${INDEX}"
        done
        echo "${tty_bold}${COUNT} Voluntary exit message(s) saved at: $VEM_PATH${tty_reset}"
    else
        echo "Cancelled."
    fi
    ohai "Press ENTER to continue"
    read
}

broadcastVoluntaryExitMessageLocally(){
    local VEM_PATH_DEFAULT=$HOME/voluntary-exit-messages
    clear
    echo "################################################################"
    ohai "Broadcast Voluntary Exit Message (VEM)"
    echo "################################################################"
    ohai "Requirements: To broadcast voluntary exit messages, have the following ready:"
    echo "1) A path to the directory containing your VEM file(s) e.g. exit_validator_index_#####.json"
    echo ""
    ohai "Result of this operation:"
    echo "- Exit Queue: Your validator(s) will soon no longer be responsible for attesting/proposing duties."
    echo "- Irreversible: This operation exits your validator permanently."
    echo ""
    ohai "Next steps:"
    echo "- Status: Keep validator processes running until a validator has fully exited the exit queue."
    echo "- Verification: Using ethdo or beaconcha.in, check your validator's status to confirm exiting status. e.g. Status: active_exiting"
    echo "- Balances: Validator's balance will be swept to your withdrawal address."
    echo "- Wait time: Check estimated exit queue wait times at https://www.validatorqueue.com"
    echo "- Timelines: For more detailed sequence of events, see:"
    echo "  https://www.coincashew.com/coins/overview-eth/guide-or-how-to-setup-a-validator-on-eth2-mainnet/part-iii-tips/voluntary-exiting-a-validator"
    echo ""
    echo "${tty_bold}Do you wish to continue? [y|n]${tty_reset}"
    read -rsn1 yn
    if [[ ${yn} = [Yy]* ]]; then
        # Prompt user for path to VEMs
        read -r -p "Enter path to your VEM file(s) (Press enter to use default: $VEM_PATH_DEFAULT):" VEM_PATH
        VEM_PATH=${VEM_PATH:-$VEM_PATH_DEFAULT}
        # Check number of keystores
        local COUNT=$(ls ${VEM_PATH}/exit*.json | wc -l)
        if [[ $COUNT -gt 0 ]]; then
            echo "INFO: Found $COUNT VEM files"
            echo "INFO: Using VEM path: $VEM_PATH"
        else
            echo "No VEMs found at $VEM_PATH"
            ohai "Press ENTER to continue"
            read
            exit 1
        fi

        # Final confirmation
        if whiptail --title "Broadcast Voluntary Exit Messages" --defaultno --yesno "This will voluntary exit ${COUNT} validator(s).\nAre you sure you want to continue?" 9 78; then
            # Iterate through each file and broadcast the VEM
            for VEM in $(ls ${VEM_PATH}/exit*.json);
            do
               ethdo --connection ${API_BN_ENDPOINT} validator exit --signed-operation ${VEM}
               INDEX=$(cat $VEM | jq -r .message.validator_index)
               echo "INFO: Broadcast VEM for index ${INDEX}"
            done
            echo "${tty_bold}${COUNT} Voluntary exit message(s) broadcasted.${tty_reset}"
        fi
    else
        echo "Cancelled."
    fi
    ohai "Press ENTER to continue"
    read
}

# Takes a validator index # and checks status with ethdo
checkValidatorStatus(){
    local _INDEX=""
    clear
    # Get validator index from user
    while true; do
    read -r -p "${tty_blue}Enter your Validator's Index: ${tty_reset}" _INDEX
    ethdo --connection ${API_BN_ENDPOINT} validator info --validator=${_INDEX}
    read -r -p "${tty_blue}Check another index? (y/n) ${tty_reset}" yn
    case ${yn} in
      [Nn]*) break ;;
          *) continue ;;
    esac
    done
}

# Install ethdo if not yet installed
installEthdo(){
    if [[ ! -f /usr/local/bin/ethdo ]]; then
      if whiptail --title "Install ethdo" --yesno "Do you want to install ethdo?\n\nethdo helps you check validator status, generate and broadcast exit messages." 10 78; then
        runScript ethdo.sh -i
      fi
    fi
}

# Display peer count information from EL and CL
getPeerCount(){
    declare -A _peer_status=()
    local _warn=""
    # Get peer counts from CL and EL
    _peer_status["Consensus_Layer_Connected_Peer_Count"]="$(curl -s -X GET "${API_BN_ENDPOINT}/eth/v1/node/peer_count" -H  "accept: application/json" | jq -r ".data.connected")"
    _peer_status["Execution_Layer_Connected_Peer_Count"]="$(curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc": "2.0", "method":"net_peerCount", "params": [], "id":1}' ${EL_RPC_ENDPOINT} | jq -r ".result" | awk '{ printf "%d\n",$1 }')"
    # Get CL peers by direction
    _json_cl=$(curl -s ${API_BN_ENDPOINT}/eth/v1/node/peers | jq -c '.data')
    _peer_status["Consensus_Layer_Known_Inbound_Peers"]=$(jq -c '.[] | select(.direction == "inbound")' <<< "$_json_cl" | wc -l)
    _peer_status["Consensus_Layer_Known_Outbound_Peers"]=$(jq -c '.[] | select(.direction == "outbound")' <<< "$_json_cl" | wc -l)

    # Print each peer status
    for _key in ${!_peer_status[@]}
      do
        if [[ ${_peer_status[$_key]} -gt 0 ]]; then printf "[${tty_blue}✔${tty_reset}]"; else printf "[${tty_red}✗${tty_reset}]" && _warn=1; fi
        echo " ${tty_blue}[$_key]${tty_bold}: ${_peer_status[$_key]} peers${tty_reset}"
      done
    [[ ! -z ${_warn} ]] && echo "Suboptimal connectivity may affect validating nodes. To resolve, restart the service and check port forwarding, firewall-router settings, public IP, ENR."
    ohai "Press ENTER to continue"
    read
}

# Create Beaconcha.in Validator Dashboard Link
createBeaconChainDashboardLink(){
    getPubKeys
    getIndices
    local _ids=$(echo ${INDICES[@]} | sed  's/ /,/g')
    case $NETWORK in
       holesky)
          _link="https://holesky.beaconcha.in/dashboard?validators=" ;;
       mainnet)
          _link="https://beaconcha.in/dashboard?validators=" ;;
       *)
          echo "Unsupported Network: ${NETWORK}" && exit 1
    esac
    _linkresult=${_link}${_ids}
    ohai "Beaconcha.in Validator Dashboard: Copy and paste your link into a web browser. Bookmark."
    echo ${_linkresult}
    ohai "Press ENTER to continue"
    read
}

testBandwidth(){
    clear
    echo "################################################################"
    ohai "Test internet bandwidth using speedtest.net"
    echo "################################################################"
    ohai "Requirements: A full node uses at least 10MBbit/s upload and 10Mbit/s download."
    ohai "Starting speedtest ..."
    curl -s https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py | python3 -
    ohai "Press ENTER to continue"
    read
}
