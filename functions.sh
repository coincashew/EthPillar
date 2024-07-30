#!/bin/bash

# Author: coincashew.eth | coincashew.com
# License: GNU GPL
# Source: https://github.com/coincashew/ethpillar
# Description: EthPillar is a one-liner setup tool and node management TUI

# Made for home and solo stakers 🏠🥩

set -u

# enable command completion
set -o history -o histexpand

# Load BN and EL ENDPOINTS
source ./env

# Stores validator index
declare -a INDICES

getNetworkConfig() {
    ip_current=$( hostname --all-ip-address | awk '{print $1}')
    interface_current=$(ip route | grep default | head -1 | sed 's/.*dev \([^ ]*\) .*/\1/')
    network_current="$(ip route | grep $interface_current | grep -v default | head -1 | awk '{print $1}')"
}

exit_on_error() {
    exit_code=$1
    last_command="${@:2}"
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
    getNetworkConfig
    sudo ip link set $interface_current down
}

network_up() {
    getNetworkConfig
    sudo ip link set $interface_current up
}

network_isConnected() {
  #check to see if the device is connected to the network
  sudo ip route get 1 2>/dev/null
}

get_arch(){
  machine_arch="$(uname --machine)"
  if [[ "${machine_arch}" = "x86_64" ]]; then
    binary_arch="amd64"
  elif [[ "${machine_arch}" = "aarch64" ]]; then
    binary_arch="arm64"
  else
    echo "Unsupported architecture: ${machine_arch}"
    exit 1
  fi
  echo "${binary_arch}"
}

get_platform(){
  platform="$(uname)"
  if [[ "${platform}" = "Linux" ]]; then
    echo "${platform}"
  else
    echo "Unsupported platform: ${platform}"
    exit 1
  fi
}

print_node_info() {
  current_time=$(date)
  os_descrip=$(grep PRETTY_NAME /etc/os-release | sed 's/PRETTY_NAME=//g')
  os_version=$(grep VERSION_ID /etc/os-release | sed 's/VERSION_ID=//g')
  kernel_version=$(uname -r)
  system_uptime=$(uptime | sed 's/.*up \([^,]*\), .*/\1/')
  chrony_status=$(if systemctl is-active --quiet chronyd ; then printf "Online" ; else printf "Offline" ; fi)
  consensus_status=$(if systemctl is-active --quiet consensus ; then printf "Online" ; elif [ -f /etc/systemd/system/consensus.service ]; then printf "Offline" ; else printf "Not Installed"; fi)
  execution_status=$(if systemctl is-active --quiet execution ; then printf "Online" ; elif [ -f /etc/systemd/system/execution.service ]; then printf "Offline" ; else printf "Not Installed"; fi)
  validator_status=$(if systemctl is-active --quiet validator ; then printf "Online" ; elif [ -f /etc/systemd/system/validator.service ]; then printf "Offline" ; else printf "Not Installed"; fi)
  mevboost_status=$(if systemctl is-active --quiet mevboost ; then printf "Online" ; elif [ -f /etc/systemd/system/mevboost.service ]; then printf "Offline" ; else printf "Not Installed"; fi)
  ethpillar_commit=$(git -C "${BASE_DIR}" rev-parse HEAD)
  ethpillar_version=$(grep EP_VERSION= $BASE_DIR/ethpillar.sh | sed 's/EP_VERSION=//g')
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
    if [[ -z $result ]]; then NETWORK="Network Syncing"; return; fi
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

# Gets software version from binary
getCurrentVersion(){
    case "$CLIENT" in
      Lighthouse)
        VERSION=$(/usr/local/bin/lighthouse --version | head -1 | grep -oE "v[0-9]+.[0-9]+.[0-9]+")
        ;;
      Lodestar)
        VERSION=$(/usr/local/bin/lodestar/lodestar --version | grep -oE "v[0-9]+.[0-9]+.[0-9]+")
        ;;
      Teku)
        VERSION=$(/usr/local/bin/teku/bin/teku --version | head -1 | grep -oE "v[0-9]+.[0-9]+.[0-9]+")
        ;;
      Nimbus)
        test -f /usr/local/bin/nimbus_beacon_node && VERSION=$(nimbus_beacon_node --version | head -1 | grep -oE "v[0-9]+.[0-9]+.[0-9]+") || test -f /usr/local/bin/nimbus_validator_client && VERSION=$(nimbus_validator_client --version | head -1 | grep -oE "v[0-9]+.[0-9]+.[0-9]+")
        ;;
      Prysm)
        test -f /usr/local/bin/beacon-chain && VERSION=$(beacon-chain --version | head -1 | grep -oE "v[0-9]+.[0-9]+.[0-9]+") || test -f /usr/local/bin/validator && VERSION=$(validator --version | head -1 | grep -oE "v[0-9]+.[0-9]+.[0-9]+")
        ;;
      *)
        echo "ERROR: Unable to determine client."
        exit 1
        ;;
      esac
}

# Read clients from systemd config files
getClient(){
    EL=$(test -f /etc/systemd/system/execution.service && grep Description= /etc/systemd/system/execution.service | awk -F'=' '{print $2}' | awk '{print $1}')
    CL=$(test -f /etc/systemd/system/consensus.service && grep Description= /etc/systemd/system/consensus.service | awk -F'=' '{print $2}' | awk '{print $1}')
    VC=$(test -f /etc/systemd/system/validator.service && grep Description= /etc/systemd/system/validator.service | awk -F'=' '{print $2}' | awk '{print $1}')
    if [[ -n $CL  ]]; then
        CLIENT=$CL
    elif [[ -n $VC ]]; then
        CLIENT=$VC
    fi
}

# Get list of validator public keys
getPubKeys(){
   NETWORK=$(echo $NETWORK | tr "[:upper:]" "[:lower:]")
   TEMP=""
   case $VC in
      Lighthouse)
         TEMP=$(/usr/local/bin/lighthouse account validator list --datadir /var/lib/lighthouse | grep -Eo '0x[a-fA-F0-9]{96}')
         convertLIST
      ;;
      Lodestar)
         cd /usr/local/bin/lodestar
         TEMP=$(sudo -u validator /usr/local/bin/lodestar/lodestar validator list --dataDir /var/lib/lodestar/validators --force | grep -Eo '0x[a-fA-F0-9]{96}')
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
         TEMP="${_teku[@]}"
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
         TEMP=$(/usr/local/bin/validator accounts list --wallet-dir=/var/lib/prysm/validators | grep -Eo '0x[a-fA-F0-9]{96}')
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
         if [[ $VALIDATOR_INDEX = null ]]; then
            echo "INFO: $PUBKEY not yet activated."
         else
            INDICES+=($VALIDATOR_INDEX);
         fi
      done
}

# Prints list of pubkeys and indices
viewPubkeyAndIndices(){
   local COUNT=${#LIST[@]}
   if [[ "$COUNT" = "0" ]]; then
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
   if [[ ! ${#INDICES[@]} = "0" ]]; then
      echo ${INDICES[@]}
   else
      echo "No validators currently active. Once a validator is activated, an index is assigned."
   fi
   ohai "Press ENTER to finish."
   read
}

# Checks for open ports. Diagnose peering/router/port-forwarding issues.
checkOpenPorts(){
    clear
    if ! systemctl is-active --quiet execution ; then echo "${tty_red}WARNING: Execution client service not running. Ports will appear NOT open. Start service, then check ports."; fi
    if ! systemctl is-active --quiet consensus ; then echo "${tty_red}WARNING: Consensus client service not running. Ports will appear NOT open. Start service, then check ports."; fi
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
    json=$(curl -s https://eth2-client-port-checker.vercel.app/api/checker?ports=$EL_PORT,$CL_PORT)

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
        local COUNT=$(ls "${KEYSTORE_PATH}"/keystore*.json | wc -l)
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
        for KEYSTORE in "${KEYSTORE_PATH}"/keystore*.json;
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
        local COUNT=$(ls "${VEM_PATH}"/exit*.json | wc -l)
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
            for VEM in "${VEM_PATH}"/exit*.json;
            do
               ethdo --connection ${API_BN_ENDPOINT} validator exit --signed-operations ${VEM}
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
    echo "#############################################################################"
    ohai "Validator Status: Given a validator index #, checks the status with ethdo"
    echo "#############################################################################"
    ohai "Key Points:"
    echo "* Your validator will receive a unique index # after going live."
    echo "* Until then, you'll need to use the public key to access it's status at beaconcha.in directly."
    echo "* A validator can be identified by either its public key or its index #."
    # Get validator index from user
    while true; do
    read -r -p "${tty_blue}Enter your Validator's Index: (Press enter for example)${tty_reset} " _INDEX
    _INDEX=${_INDEX:-1337}
    ethdo --connection ${API_BN_ENDPOINT} validator info --validator=${_INDEX}
    read -r -p "${tty_blue}Check another index? (y/n) ${tty_reset}" yn
    case ${yn} in
      [Nn]*) break ;;
          *) continue ;;
    esac
    done
}

# Takes a validator index # or pubkey and checks attestation inclusion
checkValidatorAttestationInclusion(){
    local _INDEX=""
    clear
    echo "#############################################################################"
    ohai "Attestation Performance: Obtain information about attester inclusion"
    echo "#############################################################################"
    ohai "Key Points:"
    echo "* Timely: Validators are called to attest (or vote) only once every epoch."
    echo "* Correctness: When attesting, validators vote on their version of the perceived state of the chain, namely the source, head and target."
    echo "* Inclusion delay: Ideally, 1. The number of slots separating the block proposal and attestation."
    # Get validator index from user
    while true; do
    read -r -p "${tty_blue}Enter your Validator's Index or public key: (Press enter for example)${tty_reset} " _INDEX
    _INDEX=${_INDEX:-1337}
    read -r -p "${tty_blue}Enter epoch: (Press enter for last epoch)${tty_reset} " _EPOCH
    _EPOCH=${_EPOCH:-"-1"}
    ethdo --connection ${API_BN_ENDPOINT} attester inclusion --validator=${_INDEX} --epoch=${_EPOCH} --verbose
    read -r -p "${tty_blue}Check another validator or epoch? (y/n) ${tty_reset}" yn
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
      else
        break
      fi
    fi
}

# Display peer count information from EL and CL
getPeerCount(){
    declare -A _peer_status=()
    local _warn=""
    # Get peer counts from CL and EL
    _peer_status["Consensus_Layer_Connected_Peer_Count"]="$(curl -s -X GET "${API_BN_ENDPOINT}/eth/v1/node/peer_count" -H  "accept: application/json" | jq -r ".data.connected")"
    _peer_status["Execution_Layer_Connected_Peer_Count"]="$(curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc": "2.0", "method":"net_peerCount", "params": [], "id":1}' ${EL_RPC_ENDPOINT} | jq -r ".result" | mawk '{printf "%d\n",$1}')"
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
    ohai "Requirements: A full node uses at least 10Mbit/s upload and 10Mbit/s download."
    ohai "Starting speedtest ..."
    curl -s https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py | python3 -
    ohai "Press ENTER to continue"
    read
}

testYetAnotherBenchScript(){
    clear
    echo "#######################################################"
    ohai "Yet-Another-Bench-Script - yabs.sh"
    echo "#######################################################"
    ohai "Automated Benchmarking: Runs popular tools to test node performance"
    echo "- Multi-Test Suite: It includes tests for:"
    echo "  * Disk performance using fio"
    echo "  * Network performance using iperf3"
    echo "  * CPU/memory performance using Geekbench"
    echo "- No External Dependencies Required: No additional downloads"
    ohai "Reminder: Full node requirements"
    echo "- Network:"
    echo "  * Bandwidth should be at least 10Mbit/s upload and 10Mbit/s download"
    echo "  * At least 2TB data transfer per month"
    echo "- Disk:"
    echo "  * Capacity at least 2TB Mainnet, 300GB Holesky testnet"
    echo "  * NVME drive preferred, SSD with TLC cache can work"
    echo "  * I/O Per Second on 4k block size test at least 15K IOPS read, 5K IOPS write"
    echo "- CPU:"
    echo "  * At least 2 cores, 4 threads"
    echo "  * Geekbench 6 scores at least 700 single core score, 1400 multi-core score"
    echo "- RAM:"
    echo "  * At least 16GB. 32GB for future-proofing."
    ohai "Testing completes in 30 minutes max, generally around 10 minutes."
    echo "${tty_bold}Do you wish to continue? [y|n]${tty_reset}"
    read -rsn1 yn
    if [[ ${yn} = [Yy]* ]]; then
      curl -sL yabs.sh | bash
      ohai "Press ENTER to continue"
      read
    fi
}

# Allow external validators to connect to this consensus client (port 5052)
exposeRpcCL(){
    _closed='127.0.0.1'
    _exposed='0.0.0.0'
    _service='consensus'
    _file="/etc/systemd/system/${_service}.service"
    getNetworkConfig

    case "${CL}" in
        Nimbus     ) _flag='--rest-address';;
        Lodestar   ) _flag='--rest.address';;
        Lighthouse ) _flag='--http-address';;
        Prysm      ) _flag='--grpc-gateway-host';;
        Teku       ) _flag='--rest-api-interface';;
        * ) echo "Consensus client not detected."; return 0;;
    esac

    clear
    echo "###########################################################################"
    ohai "Expose CL RPC: Allowing External Validator Clients to Connect to this Node"
    echo "###########################################################################"
    ohai "Purpose:"
    echo "To allow attaching an external Validator client to your node's Consensus client, enable this feature."
    echo "This will open up RPC ports (default 5052 for HTTP) on your node, allowing other machines on your local network to connect."
    echo "For example, you can access this node's Consensus client (also called beacon-node) URL at http://${ip_current}:5052"
    echo "When running multiple pairs of execution and consensus clients for client diversity or redundancy purposes, a staker may want to connect their Validator Client to multiple beacon nodes."
    echo ""
    ohai "Result of this operation:"
    echo "- Flag Change:  This will modify ${CL}'s flag: ${_flag}"
    echo "- Restarts ${_service} client for changes to take effect."
    ohai "Next Steps:"
    echo "- Review UFW firewall settings. Whitelist the connecting machine's IP or allow local LAN access."
    echo "${tty_bold}Do you wish to continue? [y|n]${tty_reset}"
    read -rsn1 yn
    if [[ ${yn} = [Nn]* ]]; then return 0; fi

    echo "${tty_bold}Do you wish to expose ${CL} RPC Port? This will modify ${_flag} and restart ${_service} client. Answer n to revoke access.[y|n]${tty_reset}"
    read -rsn1 yn
    if [[ ${yn} = [Yy]* ]]; then
        _value=${_exposed}
        ohai "Exposing $CL RPC Access with flag: ${_flag}"
    else
        _value=${_closed}
        ohai "Closing $CL RPC Access with flag: ${_flag}"
    fi

    _updateFlagAndRestartService
}

# Allow external EL RPC access (port 8545)
exposeRpcEL(){
    _closed='127.0.0.1'
    _exposed='0.0.0.0'
    _service='execution'
    _file="/etc/systemd/system/${_service}.service"
    getNetworkConfig

    case "${EL}" in
        Nethermind ) _flag='--JsonRpc.Host';;
        Besu       ) _flag='--rpc-http-host';;
        Erigon     ) _flag='--http.addr';;
        Geth       ) _flag='--http.addr';;
        Reth       ) _flag='--http.addr';;
        * ) echo "Execution client not detected"; return 0;;
    esac

    clear
    echo "###########################################################################"
    ohai "Expose EL RPC: Allowing External Access to Connect to this Node"
    echo "###########################################################################"
    ohai "Purpose:"
    echo "To allow access from an external service to your node's Execution client, enable this feature."
    echo "This will open up RPC ports (default 8545 for HTTP) on your node, allowing other machines on your local network to connect."
    echo "For example, you can access this node's Execution client URL at http://${ip_current}:8545"
    echo "A common use case is configuring your ETH wallet to use your own node as a RPC endpoint."
    echo ""
    ohai "Result of this operation:"
    echo "- Flag Change:  This will modify ${EL}'s flag: ${_flag}"
    echo "- Restarts ${_service} client for changes to take effect."
    ohai "Next Steps:"
    echo "- Review UFW firewall settings. Whitelist the connecting machine's IP or allow local LAN access."
    echo "${tty_bold}Do you wish to continue? [y|n]${tty_reset}"
    read -rsn1 yn
    if [[ ${yn} = [Nn]* ]]; then return 0; fi

    echo "${tty_bold}Do you wish to expose ${EL} RPC Port? This will modify ${_flag} and restart ${_service} client. Answer n to revoke access. [y|n]${tty_reset}"
    read -rsn1 yn
    if [[ ${yn} = [Yy]* ]]; then
        _value=${_exposed}
        ohai "Exposing $EL RPC Access with flag: ${_flag}"
    else
        _value=${_closed}
        ohai "Closing $EL RPC Access with flag: ${_flag}"
    fi

    _updateFlagAndRestartService
}

# Helper function for Exposing RPC ports
_updateFlagAndRestartService(){
    # Check if multiline configuration file that ends with \
    grep -q 'ExecStart.*\\$' ${_file}

    if [[ $? = 0 ]]; then
      # Multiline config
      # Copy service file to editable location
      cp ${_file} $HOME/_edit
      # Remove multiline configs remove trailing \ and then extra empty lines
      sed -r "s/.*${_flag}[= ]+[0-9.]+.*/&\n/g; s/${_flag}[= ]+[0-9.]+//g" $HOME/_edit | sed 's=^\s*\\==g' | sed '/^[[:space:]]*$/d' > $HOME/_tmp
      # Append new value after ExecStart line. Fix spacing and add \.
      sed -e "/ExecStart.*$/a ${_flag}=${_value}" $HOME/_tmp | sed 's=^--.*$=  & \\=g' > $HOME/_result
      rm $HOME/_tmp
    else
      # All on one line config
      # Copy service file to editable location
      cp ${_file} $HOME/_edit
      # Remove old value
      sed -r "s/.*${_flag}[= ]+[0-9.]+.*/&\n/g; s/${_flag}[= ]+[0-9.]+//g" $HOME/_edit > $HOME/_result
      # Add new value to end of ExecStart line
      sed -i -e "s/^ExecStart.*$/& ${_flag}=${_value}/" $HOME/_result
    fi
    # Install new config
    sudo mv $HOME/_result ${_file}
    # Reload and restart
    sudo systemctl daemon-reload && sudo service ${_service} restart
    ohai "Configuration change complete."
    sleep 5
}

# Returns yield per validator
ethdoYield(){
    ethdo validator --connection ${API_BN_ENDPOINT} yield
    ohai "Current yield per validator (APY). Press ENTER to continue"
    read
}

# Returns expectation between block proposals, sync committee duties
ethdoExpectation(){
    read -r -p "${tty_blue}How many validators do you have? (Press enter for example of 1)${tty_reset} " _NUM
    _NUM=${_NUM:-1}
    ethdo validator --connection ${API_BN_ENDPOINT} expectation --validators=${_NUM}
    ohai "Expectation is based on current # of active validators on the Ethereum network. Press ENTER to continue"
    read
}

# Returns time until next withdrawal sweep for given validator
ethdoNextWithdrawalSweep(){
    read -r -p "${tty_blue}Enter your Validator's Index or pubkey: (Press enter for example)${tty_reset} " _INDEX
    _INDEX=${_INDEX:-1337}
    ethdo validator --connection ${API_BN_ENDPOINT} withdrawal --validator=${_INDEX}
    ohai "Results for Validator # ${_INDEX} ~ Press ENTER to continue"
    read
}

# Returns withdrawal address for given validator
ethdoWithdrawalAddress(){
    read -r -p "${tty_blue}Enter your Validator's Index or pubkey: (Press enter for example)${tty_reset} " _INDEX
    _INDEX=${_INDEX:-1337}
    ethdo validator --connection ${API_BN_ENDPOINT} credentials get --validator=${_INDEX}
    ohai "Results for Validator # ${_INDEX} ~ Press ENTER to continue"
    read
}

# Checks validator queue by querying beaconcha.in
checkValidatorQueue(){
    #Variables
    BEACONCHAIN_VALIDATOR_QUEUE_API_URL="/api/v1/validators/queue"
    declare -A BEACONCHAIN_URLS=()
    BEACONCHAIN_URLS["Mainnet"]="https://beaconcha.in"
    BEACONCHAIN_URLS["Holesky"]="https://holesky.beaconcha.in"
    # Dencun entry churn cap
    CHURN_ENTRY_PER_EPOCH=8
    CHURN_RATE_CONSTANT=65536
    EPOCHS_PER_DAY_CONSTANT=225

    # Query for data
    json=$(curl -s ${BEACONCHAIN_URLS["${NETWORK}"]}${BEACONCHAIN_VALIDATOR_QUEUE_API_URL})

    # Parse JSON using jq and print data
    if $(echo "$json" | jq -e '.data[]' > /dev/null 2>&1); then
        CHURN_ENTRY_PER_DAY=$(echo "scale=0; $CHURN_ENTRY_PER_EPOCH * $EPOCHS_PER_DAY_CONSTANT" | bc)
        CHURN_EXIT_PER_EPOCH=$(echo "scale=0; $(echo "$json" | jq -r '.data.validatorscount') / $CHURN_RATE_CONSTANT" | bc)
        CHURN_EXIT_PER_DAY=$(echo "scale=0; $CHURN_EXIT_PER_EPOCH * $EPOCHS_PER_DAY_CONSTANT" | bc)
        echo "#######################################################"
        ohai "${NETWORK} Validator Entry/Exit Queue Stats"
        echo "#######################################################"
        ohai "Reminder: Important Timing Consideration"
        echo "- Wait for Beacon Node Sync: Before making a deposit, ensure your beacon node is synced to avoid missing rewards."
        echo "- Timing of Validator Activation: After depositing, it takes about 15 hours for a validator to be activated unless there's a long entry queue."
        echo "- Timing of Validator Exiting: After initiating an exit by broadcasting a VEM, it takes validator a minimum of 4 epochs to be exited unless there's a long exit queue."
        ohai "Entry Queue"
        echo "Validators Entering: $(echo $json | jq -r '.data.beaconchain_entering')"
        echo "Estimated wait time: $(echo "scale=1; $(echo "$json" | jq -r '.data.beaconchain_entering') / $CHURN_ENTRY_PER_DAY" | bc) days"
        echo "Churn: ${CHURN_ENTRY_PER_EPOCH} per epoch"
        ohai "Exit Queue"
        echo "Validators Exiting: $(echo $json | jq -r '.data.beaconchain_exiting')"
        echo "Estimated wait time: $(echo "scale=1; $(echo "$json" | jq -r '.data.beaconchain_exiting') / $CHURN_EXIT_PER_DAY" | bc) days"
        echo "Churn: ${CHURN_EXIT_PER_EPOCH} per epoch"
        ohai "Total Active Validator Count: $(echo $json | jq -r '.data.validatorscount')"
    else
      ohai "Unable to query beaconcha.in for $NETWORK validator queue data."
    fi
    ohai "Press ENTER to continue."
    read
}

# Checks local latency of relays found in mevboost.service file
checkRelayLatency(){
    echo "###########################################################"
    ohai "Relay Latency Check: Tests response time to each relay"
    echo "###########################################################"

    # Initialize warning flag
    local _warn=0

    # Check if mevboost service is installed
    if [ ! -f "/etc/systemd/system/mevboost.service" ]; then
      echo "No relays to check. Mevboost service not installed."
      exit 1
    fi

    # Extract relay URLs from mevboost.service, store in array
    RELAYS=( $(cat /etc/systemd/system/mevboost.service | tr -s ' ' '\n' | grep -o "https.*@.*") )

    ohai "Found ${#RELAYS[@]} relays in mevboost.service"

    for (( i=0; i<${#RELAYS[@]}; i++ )); do
      # Get relay domain name
      URL=${RELAYS[i]##*@}
      # Calculate response time in milliseconds using curl and awk
      LATENCY=$(curl -s -w %{time_total} -o /dev/null "https://${URL}/relay/v1/data/bidtraces/proposer_payload_delivered?limit=1")
      # Convert to millisec integer
      LATENCY=$(echo "$LATENCY*1000/1" | bc)
      # Check response time and assign emoji based on latency
      if (( LATENCY < 500 )); then
        EMOJI="✅"
      elif (( LATENCY < 1000 )); then
        EMOJI="⚠️"
        _warn=1
      else
        EMOJI="❌"
        _warn=1
      fi

      # Print relay information with emoji and response time
      echo "Relay $((i+1)) - ${URL}: $LATENCY ms $EMOJI"
    done

    # If any relays have high latency, warn user to consider removing distant relays
    if [[ ${_warn} && ! ${NODE_MODE}=="Lido CSM Staking Node" ]]; then
      echo "${tty_bold}When relays are distant from your node, response times can be high. Consider removing relays with ⚠️ or ❌."
    fi
    ohai "Relay latency check complete."
    ohai "Press ENTER to continue"
    read
}
