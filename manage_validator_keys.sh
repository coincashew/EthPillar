#!/bin/bash

# Author: coincashew.eth | coincashew.com
# License: GNU GPL
# Source: https://github.com/coincashew/ethpillar
#
# Made for home and solo stakers 🏠🥩

# Dir to install staking-deposit-cli
STAKING_DEPOSIT_CLI_DIR=$HOME
# Path to validator_keys, contains validator_key folder with keystore*.json files
KEYPATH=$STAKING_DEPOSIT_CLI_DIR/staking-deposit-cli
# Initialize variable
OFFLINE_MODE=false
# Base directory with scripts
BASE_DIR=$HOME/git/ethpillar
# Load functions
source $BASE_DIR/functions.sh
# Load Lido CSM withdrawal address and fee recipient
source $BASE_DIR/env

# Get machine info
_platform=$(get_platform)
_arch=$(get_arch)

function downloadStakingDepositCLI(){
    if [ -d $STAKING_DEPOSIT_CLI_DIR/staking-deposit-cli ]; then
        ohai "staking-deposit-tool already downloaded."
        return
    fi
    ohai "Installing staking-deposit-tool"
    #Install dependencies
    sudo apt install jq curl -y

    #Setup variables
    RELEASE_URL="https://api.github.com/repos/ethereum/staking-deposit-cli/releases/latest"
    BINARIES_URL="$(curl -s $RELEASE_URL | jq -r ".assets[] | select(.name) | .browser_download_url" | grep --ignore-case ${_platform}-${_arch}.tar.gz$)"
    BINARY_FILE="staking-deposit-cli.tar.gz"
    [[ -z $BINARIES_URL ]] && echo "Error: Unable to determine BINARIES URL" && exit 1
    ohai "Downloading URL: $BINARIES_URL"
    # Dir to install staking-deposit-cli
    cd $STAKING_DEPOSIT_CLI_DIR
    # Download binary
    wget -O $BINARY_FILE $BINARIES_URL
    # Extract archive
    tar -xzvf $BINARY_FILE -C $STAKING_DEPOSIT_CLI_DIR
    # Cleanup
    rm staking-deposit-cli.tar.gz
    # Rename
    mv staking_deposit-cli*${_arch} staking-deposit-cli
    cd staking-deposit-cli
}

function generateNewValidatorKeys(){
    if network_isConnected; then
        if whiptail --title "Offline Key Generation" --defaultno --yesno "$MSG_OFFLINE" 20 78; then
            network_down
            OFFLINE_MODE=true
            ohai "Network is offline mode"
        fi
    fi

    _getNetwork

    if [ -z "$NETWORK" ]; then exit; fi # pressed cancel
    if ! whiptail --title "Information on Secret Recovery Phrase Mnemonic" --yesno "$MSG_INTRO" 24 78; then exit; fi
    if network_isConnected; then whiptail --title "Warning: Internet Connection Detected" --msgbox "$MSG_INTERNET" 18 78; fi
    setConfig
    _getEthAddy

    NUMBER_NEW_KEYS=$(whiptail --title "# of New Keys" --inputbox "How many keys to generate?" 8 78 --ok-button "Submit" 3>&1 1>&2 2>&3)
    _setKeystorePassword

    cd $STAKING_DEPOSIT_CLI_DIR/staking-deposit-cli
    KEYFOLDER="${KEYPATH}/$(date +%F-%H%M%S)"
    mkdir -p "$KEYFOLDER"
    ./deposit --non_interactive new-mnemonic --chain "$NETWORK" --execution_address "$ETHADDRESS" --num_validators "$NUMBER_NEW_KEYS" --keystore_password "$_KEYSTOREPASSWORD" --folder "$KEYFOLDER"
    if [ $? -eq 0 ]; then
        loadKeys
        if [ $OFFLINE_MODE == true ]; then
            network_up
            ohai "Network is online"
        fi
    else
        ohai "Error with staking-deposit-cli. Try again."
        exit
    fi

}

function _getEthAddy(){
    while true; do
        ETHADDRESS=$(whiptail --title "Ethereum Withdrawal Address" --inputbox "$MSG_ETHADDRESS" 15 78 --ok-button "Submit" 3>&1 1>&2 2>&3)
        if [ -z "$ETHADDRESS" ]; then exit; fi #pressed cancel
        if [[ "${ETHADDRESS}" =~ ^0x[a-fA-F0-9]{40}$ ]]; then
            break
        else
            whiptail --title "Error" --msgbox "Invalid ETH address. Try again." 8 78
        fi
    done
}

function _getNetwork(){
    NETWORK=$(whiptail --title "Network" --menu \
          "For which network are you generating validator keys?" 10 78 2 \
          "mainnet" "Ethereum - Real ETH. Real staking rewards." \
          "holesky" "Testnet  - Practice your staking setup here." \
          3>&1 1>&2 2>&3)
}

function importValidatorKeys(){
    KEYPATH=$(whiptail --title "Import Validator Keys from Offline Generation or Backup" --inputbox "$MSG_PATH" 16 78 --ok-button "Submit" 3>&1 1>&2 2>&3)
    if [ -d "$KEYPATH" ]; then
        _getNetwork

        if [ -z "$NETWORK" ]; then exit; fi # pressed cancel
        setConfig

        if whiptail --title "Important Information" --defaultno --yesno "$MSG_IMPORT" 20 78; then
            loadKeys
        fi
    else
        ohai "$KEYPATH does not exist. Try again."
        exit
    fi
}

function addRestoreValidatorKeys(){
    if whiptail --title "Offline Key Generation" --defaultno --yesno "$MSG_OFFLINE" 20 78; then
        network_down
        OFFLINE_MODE=true
        ohai "Network is down"
    fi
    _getNetwork

    if [ -z "$NETWORK" ]; then exit; fi # pressed cancel
    if ! whiptail --title "Information on Secret Recovery Phrase Mnemonic" --yesno "$MSG_INTRO" 24 78; then exit; fi
    if network_isConnected; then whiptail --title "Warning: Internet Connection Detected" --msgbox "$MSG_INTERNET" 18 78; fi
    setConfig
    _getEthAddy

    NUMBER_NEW_KEYS=$(whiptail --title "# of New Keys" --inputbox "How many keys to generate?" 8 78 --ok-button "Submit" 3>&1 1>&2 2>&3)
    START_INDEX=$(whiptail --title "# of Existing Keys" --inputbox "How many validator keys were previously made? Also known as the starting index." 10 78 --ok-button "Submit" 3>&1 1>&2 2>&3)
    whiptail --title "Keystore Password" --msgbox "Reminder to use the same keystore password as existing validators." 10 78
    _setKeystorePassword

    cd $STAKING_DEPOSIT_CLI_DIR/staking-deposit-cli
    KEYFOLDER="${KEYPATH}/$(date +%F-%H%M%S)"
    mkdir -p "$KEYFOLDER"
    ./deposit --non_interactive existing-mnemonic --chain "$NETWORK" --execution_address "$ETHADDRESS" --folder "$KEYFOLDER" --keystore_password "$_KEYSTOREPASSWORD" --validator_start_index "$START_INDEX" --num_validators "$NUMBER_NEW_KEYS"
    if [ $? -eq 0 ]; then
        loadKeys
        if [ $OFFLINE_MODE == true ]; then
            network_up
            ohai "Network is online"
        fi
    else
        ohai "Error with staking-deposit-cli. Try again."
        exit
    fi
}

function _setKeystorePassword(){
    while true; do
        # Get keystore password
        _KEYSTOREPASSWORD=$(whiptail --title "Keystore Password" --inputbox "Enter your validator's keystore password, must be at least 8 chars. " 12 78 --ok-button "Submit" 3>&1 1>&2 2>&3)
        if [[ ${#_KEYSTOREPASSWORD} -ge 8 ]]; then
            _VERIFY_PASS=$(whiptail --title "Verify Password" --inputbox "Confirm your keystore password" 12 78 --ok-button "Submit" 3>&1 1>&2 2>&3)
            if [[ "${_KEYSTOREPASSWORD}" = "${_VERIFY_PASS}" ]]; then
                ohai "Password is same."
                break
            else
                whiptail --title "Error" --msgbox "Passwords not the same. Try again." 8 78
            fi
        else
            whiptail --msgbox "The keystore password must be at least 8 characters long." 8 78
        fi
    done
}

function setConfig(){
    case $NETWORK in
          mainnet)
            LAUNCHPAD_URL="https://launchpad.ethereum.org"
            LAUNCHPAD_URL_LIDO="https://csm.lido.fi"
            CSM_FEE_RECIPIENT_ADDRESS=${CSM_FEE_RECIPIENT_ADDRESS_MAINNET}
            CSM_WITHDRAWAL_ADDRESS=${CSM_WITHDRAWAL_ADDRESS_MAINNET}
          ;;
          holesky)
            LAUNCHPAD_URL="https://holesky.launchpad.ethstaker.cc"
            LAUNCHPAD_URL_LIDO="https://csm.testnet.fi"
            CSM_FEE_RECIPIENT_ADDRESS=${CSM_FEE_RECIPIENT_ADDRESS_HOLESKY}
            CSM_WITHDRAWAL_ADDRESS=${CSM_WITHDRAWAL_ADDRESS_HOLESKY}
          ;;
    esac

    # Check if Lido CSM Validator
    if [[ $(grep --ignore-case -oE "${CSM_FEE_RECIPIENT_ADDRESS_MAINNET}" /etc/systemd/system/validator.service) || $(grep --ignore-case -oE "${CSM_FEE_RECIPIENT_ADDRESS_HOLESKY}" /etc/systemd/system/validator.service) ]]; then
        # Update message for Lido
        MSG_ETHADDRESS="\nSet this to Lido's CSM Withdrawal Vault Address.
\n${NETWORK}: ${CSM_WITHDRAWAL_ADDRESS}
\nIn checksum format, ether the Withdrawal Address:"
    fi
}

# Load validator keys into validator client
function loadKeys(){
   getClientVC
   ohai "Loading PubKeys into $VC Validator"
   sudo systemctl stop validator
   ohai "Stopping validator to import keys"
   case $VC in
      Lighthouse)
        sudo lighthouse account validator import \
          --datadir /var/lib/lighthouse \
          --directory=$KEYPATH \
          --reuse-password
        sudo chown -R validator:validator /var/lib/lighthouse/validators
        sudo chmod 700 /var/lib/lighthouse/validators
      ;;
     Lodestar)
        sudo mkdir -p /var/lib/lodestar/validators
        cd /usr/local/bin/lodestar
        sudo ./lodestar validator import \
          --dataDir="/var/lib/lodestar/validators" \
          --keystore=$KEYPATH
        sudo chown -R validator:validator /var/lib/lodestar/validators
        sudo chmod 700 /var/lib/lodestar/validators
      ;;
     Teku)
        while true; do
            # Get keystore password
            TEKU_PASS=$(whiptail --title "Teku Keystore Password" --inputbox "Enter your keystore password" 10 78 --ok-button "Submit" 3>&1 1>&2 2>&3)
            VERIFY_PASS=$(whiptail --title "Verify Password" --inputbox "Confirm your keystore password" 10 78 --ok-button "Submit" 3>&1 1>&2 2>&3)
            if [[ "${TEKU_PASS}" = "${VERIFY_PASS}" ]]; then
                ohai "Password is same."
                break
            else
                whiptail --title "Error" --msgbox "Passwords not the same. Try again." 8 78
            fi
        done
        echo $TEKU_PASS > $HOME/validators-password.txt
        # Create password file for each keystore
        for f in $KEYPATH/keystore*.json; do sudo cp $HOME/validators-password.txt $KEYPATH/$(basename $f .json).txt; done
        sudo mkdir -p /var/lib/teku_validator/validator_keys
        sudo cp $KEYPATH/keystore* /var/lib/teku_validator/validator_keys
        sudo chown -R validator:validator /var/lib/teku_validator
        sudo chmod -R 700 /var/lib/teku_validator
        rm $HOME/validators-password.txt
      ;;
     Nimbus)
        sudo /usr/local/bin/nimbus_beacon_node deposits import \
            --data-dir=/var/lib/nimbus_validator $KEYPATH
        sudo chown -R validator:validator /var/lib/nimbus_validator
        sudo chmod -R 700 /var/lib/nimbus_validator
      ;;
     Prysm)
        sudo /usr/local/bin/validator accounts import \
          --accept-terms-of-use \
          --wallet-dir=/var/lib/prysm/validators \
          --keys-dir=$KEYPATH
        sudo chown -R validator:validator /var/lib/prysm/validators
        sudo chmod 700 /var/lib/prysm/validators
      ;;
     esac
     sudo systemctl start validator
     ohai "Starting validator"
     queryValidatorQueue
     setLaunchPadMessage
     whiptail --title "Next Steps: Upload JSON Deposit Data File" --msgbox "$MSG_LAUNCHPAD" 20 78
     whiptail --title "Tips: Things to Know" --msgbox "$MSG_TIPS" 24 78
     ohai "Finished loading keys. Press enter to continue."
     read
     promptViewLogs
}

function setLaunchPadMessage(){
    MSG_LAUNCHPAD="1) Visit the Launchpad: $LAUNCHPAD_URL
\n2) Upload your deposit_data-#########.json found in the directory:
\n$KEYFOLDER/validator_keys
\n3) Connect the Launchpad with your wallet, review and accept terms.
\n4) Complete the 32 ETH deposit transaction(s). One transaction per validator.
\n5) Wait for validators to become active. $MSG_VALIDATOR_QUEUE"

    MSG_TIPS="Tips:
\n   - Wait for Node Sync: Before making a deposit, ensure your EL/CL client is synced to avoid missing rewards.
\n   - Timing of Validator Activation: After depositing, it takes about 15 hours for a validator to be activated unless there's a long entry queue.
\n   - Backup Keystores: For faster recovery, keep copies of the keystore files on offline USB storage.
\n Location: ~/staking-deposit-cli/$(basename $KEYFOLDER)/validator_keys
\n   - Cleanup Keystores: Delete keystore files from node after backup."

    MSG_LAUNCHPAD_LIDO="1) Visit Lido CSM: $LAUNCHPAD_URL_LIDO
\n2) Connect your wallet on the correct network, review and accept terms.
\n3) Copy JSON from your deposit_data-#########.json
\nTo view JSON, run command:
cat ~/staking-deposit-cli/$(basename $KEYFOLDER)/validator_keys/deposit*json
\n4) Provide the ~2 ETH/stETH bond per validator.
\n5) Lido will deposit the 32ETH. Wait for your validators to become active. $MSG_VALIDATOR_QUEUE"

    MSG_TIPS_LIDO="Tips:
\n   - DO NOT DEPOSIT 32ETH YOURSELF: Lido will handle the validator deposit for you.
\n   - Wait for Node Sync: Before making the ~2ETH bond deposit, ensure your EL/CL client is synced to avoid missing rewards.
\n   - Timing of Validator Activation: After depositing, it takes about 15 hours for a validator to be activated unless there's a long entry queue.
\n   - Backup Keystores: For faster recovery, keep copies of the keystore files on offline USB storage.
\n Location: ~/staking-deposit-cli/$(basename $KEYFOLDER)/validator_keys
\n   - Cleanup Keystores: Delete keystore files from node after backup."

    if [[ $(grep --ignore-case -oE "${CSM_FEE_RECIPIENT_ADDRESS_MAINNET}" /etc/systemd/system/validator.service) || $(grep --ignore-case -oE "${CSM_FEE_RECIPIENT_ADDRESS_HOLESKY}" /etc/systemd/system/validator.service) ]]; then
       # Update message for Lido
       MSG_LAUNCHPAD="${MSG_LAUNCHPAD_LIDO}"
       MSG_TIPS="$MSG_TIPS_LIDO"
    fi
}

function queryValidatorQueue(){
    #Variables
    BEACONCHAIN_VALIDATOR_QUEUE_API_URL="/api/v1/validators/queue"
    declare -A BEACONCHAIN_URLS=()
    BEACONCHAIN_URLS["mainnet"]="https://beaconcha.in"
    BEACONCHAIN_URLS["holesky"]="https://holesky.beaconcha.in"
    # Dencun entry churn cap
    CHURN_ENTRY_PER_EPOCH=8
    EPOCHS_PER_DAY_CONSTANT=225

    # Query for data
    json=$(curl -s ${BEACONCHAIN_URLS["${NETWORK}"]}${BEACONCHAIN_VALIDATOR_QUEUE_API_URL})

    # Parse JSON using jq and print data
    if $(echo "$json" | jq -e '.data[]' > /dev/null 2>&1); then
        CHURN_ENTRY_PER_DAY=$(echo "scale=0; $CHURN_ENTRY_PER_EPOCH * $EPOCHS_PER_DAY_CONSTANT" | bc)
        _val_joining=$(echo $json | jq -r '.data.beaconchain_entering')
        _val_wait_days=$(echo "scale=1; $(echo "$json" | jq -r '.data.beaconchain_entering') / $CHURN_ENTRY_PER_DAY" | bc)
        MSG_VALIDATOR_QUEUE="For ${NETWORK}, currently ${_val_joining} validators waiting to join. ETA: ${_val_wait_days} days."
    else
      echo "DEBUG: Unable to query beaconcha.in for $NETWORK validator queue data."
    fi
}

function getClientVC(){
    VC=$(cat /etc/systemd/system/validator.service | grep Description= | awk -F'=' '{print $2}' | awk '{print $1}')
}

function promptViewLogs(){
    if whiptail --title "Validator Keys Imported - $VC" --yesno "Would you like to view logs and confirm everything is running properly?" 8 78; then
        sudo bash -c 'journalctl -fu validator | ccze -A'
    fi
}

function setMessage(){
    MSG_INTRO="During this step, your Secret Recovery Phrase (also known as a "mnemonic") and an accompanying set of validator keys will be generated specifically for you. For comprehensive information regarding these keys, please refer to: https://kb.beaconcha.in/ethereum-staking/ethereum-2-keys
\nThe importance of safeguarding both the Secret Recovery Phrase and the validator keys cannot be overstated, as they are essential for accessing your funds. Exposure of these keys may lead to theft. To learn how to securely store them, visit: https://www.ledger.com/blog/how-to-protect-your-seed-phrase
\nFor enhanced security, it is strongly recommended that you create the Wagyu Key Gen (https://wagyu.gg) application on an entirely disconnected offline machine. A viable approach to this includes transferring the application onto a USB stick, connecting it to an isolated offline computer, and running it from there. Afterwards, copy your keys back to this machine and import. Continue?"
    MSG_OFFLINE="To ensure maximum security of your secret recovery phrase, it's important to operate this tool in an offline environment.
\nBe certain that your secret recovery phrase remains offline from the internet throughout the process.
\nDisconnecting from the internet might cut off computer access. Ensure you can recover access to this machine or VPS.
\nWould you like to disable the internet while generating keys for enhanced security?"
    MSG_INTERNET="Being connected to the internet while using this tool drastically increases the risk of exposing your Secret Recovery Phrase.
\nYou can avoid this risk by having a live OS such as Tails installed on a USB drive and run on a computer with network capabilities disabled.
\nYou can visit https://tails.net/install/ for instructions on how to download, install, and run Tails on a USB device.
\nIf you have any questions you can get help at https://dsc.gg/ethstaker"
    MSG_PATH="Enter the path to your keystore files.
\nDirectory contains keystore-m.json file(s).
\nExample: $KEYPATH/YYYY-MM-DD-NNNNNN/validator_keys"
    MSG_ETHADDRESS="Ensure that you have control over this address.
\nETH address secured by a hardware wallet is recommended.
\nIn checksum format, enter your Withdrawal Address:"
    MSG_IMPORT="Importing validator keys:
\n1) I acknowledge that if migrating from another node, I must wait for at least two epochs (12 mins 48 sec) before continuing.
\n2) I acknowledge that if migrating from another node, I have deleted the keys from the previous machine. This ensures that the keys will NOT inadvertently restart and run in two places.
\n3) Lastly, these validator keys are NOT operational on any other machine (such as a cloud hosting service or DVT).
\nContinue?"
}

menuMain(){
# Define the options for the main menu
OPTIONS=(
  1 "Generate new validator keys"
  2 "Import validator keys from offline key generation or backup"
  3 "Add new or regenerate existing validator keys from Secret Recovery Phrase"
  - ""
  99 "Exit"
)

while true; do
    # Display the main menu and get the user's choice
    CHOICE=$(whiptail --clear --cancel-button "Back"\
      --backtitle "Public Goods by Coincashew.eth" \
      --title "EthPillar - Validator Key Management" \
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
        generateNewValidatorKeys
        ;;
      2)
        importValidatorKeys
       ;;
      3)
        addRestoreValidatorKeys
        ;;
      99)
        break
        ;;
    esac
done
}

setWhiptailColors
setMessage
downloadStakingDepositCLI
menuMain
