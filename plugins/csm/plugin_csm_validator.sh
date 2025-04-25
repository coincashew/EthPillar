#!/bin/bash

# Author: coincashew.eth | coincashew.com
# License: GNU GPL
# Source: https://github.com/coincashew/ethpillar
# Description: eth-duties helper script
#
# Made for home and solo stakers 🏠🥩

# Base directory with scripts
BASE_DIR=$HOME/git/ethpillar

# Load functions
source $BASE_DIR/functions.sh

# Load environment variables, Lido CSM withdrawal address and fee recipient
source $BASE_DIR/env

# Get machine info
_platform=$(get_platform)
_arch=$(get_arch)

# Variables
DESCRIPTION="Lido CSM Validator Plugin: Activate an extra NIMBUS validator client to join Lido's CSM. Reuses existing EL/CL and installs a separate systemd validator service file."
DOCUMENTATION="http://eth.coincashew.com"
SOURCE_CODE="https://github.com/coincashew/ethpillar"
PLUGIN_NAME="Lido CSM Validator Plugin"
PLUGIN_SOURCE_PATH="$BASE_DIR/plugins/csm"
export PLUGIN_INSTALL_PATH="/opt/ethpillar/plugin-csm"
PLUGIN_ENV_VARS_FILE="csm_env_vars"
PLUGIN_BINARY="nimbus_validator_client"
PLUGIN_BINARY2="nimbus_beacon_node"
export SERVICE_NAME="csm_nimbusvalidator"
export SERVICE_ACCOUNT="csm_nimbus_validator"
SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME.service"

# Load environment variables overrides
[[ -f "$PLUGIN_INSTALL_PATH"/"$PLUGIN_ENV_VARS_FILE" ]] && source "$PLUGIN_INSTALL_PATH"/"$PLUGIN_ENV_VARS_FILE"

# Gets software version from binary
function _getCurrentVersion(){
	VERSION=""
  test -f $PLUGIN_INSTALL_PATH/$PLUGIN_BINARY && VERSION=$($PLUGIN_INSTALL_PATH/$PLUGIN_BINARY --version | head -1 | grep -oE "v[0-9]+.[0-9]+.[0-9]+")
}

function _getLatestVersion(){
  TAG_URL="https://api.github.com/repos/status-im/nimbus-eth2/releases/latest"
  CHANGES_URL="https://github.com/status-im/nimbus-eth2/releases"
  #Get tag name and remove leading 'v'
  TAG=$(curl -s $TAG_URL | jq -r .tag_name | sed 's/.*\(v[0-9]*\.[0-9]*\.[0-9]*\).*/\1/')
  # Exit in case of null tag
  [[ -z $TAG ]] || [[ $TAG == "null"  ]] && echo "ERROR: Couldn't find the latest version tag" && exit 1
}

function _promptYesNo(){
  if whiptail --title "Update ${CLIENT}" --yesno "Installed Version is: $VERSION\nLatest Version is:    $TAG\n\nReminder: Always read the release notes for breaking changes: $CHANGES_URL\n\nDo you want to update $CLIENT to $TAG?" 15 78; then
  		_downloadBinaries
  		_promptViewLogs
	fi
}

function _promptViewLogs(){
  if whiptail --title "Update complete" --yesno "Would you like to view logs and confirm everything is running properly?" 8 78; then
			sudo bash -c "journalctl -fu $SERVICE_NAME | ccze -A"
  fi
}

# Asks to update
function _upgradeBinaries(){
	CLIENT="Nimbus"
	_getCurrentVersion
	_getLatestVersion
	_promptYesNo
}

# Uninstall
function _removeAll() {
	if whiptail --title "Uninstall $PLUGIN_NAME" --defaultno --yesno "Are you sure you want to remove $PLUGIN_NAME" 9 78; then
	  sudo rm -rf "$PLUGIN_INSTALL_PATH"
	  sudo systemctl stop $SERVICE_NAME
	  sudo systemctl disable $SERVICE_NAME
	  sudo rm $SERVICE_FILE
		sudo userdel $SERVICE_ACCOUNT
  	whiptail --title "Uninstall finished" --msgbox "You have uninstalled $PLUGIN_NAME." 8 78
	fi
}
function _downloadBinaries(){
		#Download and installbinaries
		RELEASE_URL="https://api.github.com/repos/status-im/nimbus-eth2/releases/latest"
		BINARIES_URL="$(curl -s $RELEASE_URL | jq -r ".assets[] | select(.name) | .browser_download_url" | grep --ignore-case "_${_platform}_${_arch}.*.tar.gz$")"
		echo Downloading URL: $BINARIES_URL
		cd $HOME
		wget -O nimbus.tar.gz $BINARIES_URL
		if [ ! -f nimbus.tar.gz ]; then
			echo "Error: Downloading nimbus archive failed!"
			exit 1
		fi
		tar -xzvf nimbus.tar.gz -C $HOME
		mv nimbus-eth2_${_platform}_${_arch}* nimbus
		test -f "$SERVICE_FILE" && sudo service $SERVICE_NAME stop
		test -f ${PLUGIN_INSTALL_PATH}/${PLUGIN_BINARY} && sudo rm ${PLUGIN_INSTALL_PATH}/${PLUGIN_BINARY}
		test -f ${PLUGIN_INSTALL_PATH}/${PLUGIN_BINARY2} && sudo rm ${PLUGIN_INSTALL_PATH}/${PLUGIN_BINARY2}
		sudo mv nimbus/build/${PLUGIN_BINARY}  ${PLUGIN_INSTALL_PATH}
		sudo mv nimbus/build/${PLUGIN_BINARY2} ${PLUGIN_INSTALL_PATH}
		test -f "$SERVICE_FILE" && sudo service $SERVICE_NAME start
		rm -r nimbus
		rm nimbus.tar.gz
}

# Install logic
function _installPlugin(){
	function _doInstall(){
	  # Create service user
	  sudo useradd --no-create-home --shell /bin/false csm_nimbus_validator

		# Install env file and service file
		sudo mkdir -p $PLUGIN_INSTALL_PATH
	  sudo cp "$PLUGIN_SOURCE_PATH/$PLUGIN_ENV_VARS_FILE".example $PLUGIN_INSTALL_PATH/$PLUGIN_ENV_VARS_FILE
	  sudo cp "$PLUGIN_SOURCE_PATH/$SERVICE_NAME".service.example $SERVICE_FILE
		sudo chown $USER:$USER -R $PLUGIN_INSTALL_PATH
		sudo systemctl enable $SERVICE_NAME

	  # Setup validator
	  # Load values
	  source $PLUGIN_INSTALL_PATH/$PLUGIN_ENV_VARS_FILE
	  sudo mkdir -p $DATA_DIR
		sudo chown -R $SERVICE_ACCOUNT:$SERVICE_ACCOUNT $DATA_DIR
		sudo chmod 700 $DATA_DIR

	  # Download binaries
		_downloadBinaries

	  # Update ENV values
  	sed -i "s/FEE_RECIPIENT=\"\"/FEE_RECIPIENT=${CSM_FEE_RECIPIENT_ADDRESS}/g" "$PLUGIN_INSTALL_PATH"/"$PLUGIN_ENV_VARS_FILE" || true
  	whiptail --msgbox "✅ Success: Lido CSM Validator Plugin Installed.\nYou can now generate or load validator keys from the menu." 8 78
	}

  # Prompt user for config values
  NETWORK=$(whiptail --title "Network" --menu \
          "For which network are running CSM Validators?" 10 78 4 \
          "mainnet" "Ethereum - Real ETH. Real staking rewards." \
          "hoodi" "Long term Testnet - Ideal for CSM experimentation" \
          "ephemery" "Short term Testnet - Good for testing setups. Monthly resets." \
          "holesky" "deprecated Testnet" \
          3>&1 1>&2 2>&3)
  
  case $NETWORK in
      mainnet)
        CSM_FEE_RECIPIENT_ADDRESS=${CSM_FEE_RECIPIENT_ADDRESS_MAINNET}
        CSM_WITHDRAWAL_ADDRESS=${CSM_WITHDRAWAL_ADDRESS_MAINNET}
      ;;
      hoodi)
        CSM_FEE_RECIPIENT_ADDRESS=${CSM_FEE_RECIPIENT_ADDRESS_HOODI}
        CSM_WITHDRAWAL_ADDRESS=${CSM_WITHDRAWAL_ADDRESS_HOODI}
      ;;
      holesky)
        CSM_FEE_RECIPIENT_ADDRESS=${CSM_FEE_RECIPIENT_ADDRESS_HOLESKY}
        CSM_WITHDRAWAL_ADDRESS=${CSM_WITHDRAWAL_ADDRESS_HOLESKY}
      ;;
      ephemery)
        CSM_FEE_RECIPIENT_ADDRESS=${CSM_FEE_RECIPIENT_ADDRESS_HOLESKY}
        CSM_WITHDRAWAL_ADDRESS=${CSM_WITHDRAWAL_ADDRESS_HOLESKY}
      ;;
  esac

  MSG_ETHADDRESS="\nSet this to Lido's CSM Fee Recipient Address.
\n${NETWORK}: ${CSM_FEE_RECIPIENT_ADDRESS}
\nIn checksum format, ether the fee recipient address:"
	
  while true; do
      ETHADDRESS=$(whiptail --title "Fee Recipient Address" --inputbox "$MSG_ETHADDRESS" 15 78 --ok-button "Submit" 3>&1 1>&2 2>&3)
      if [ -z "$ETHADDRESS" ]; then exit; fi #pressed cancel
      if [[ "${ETHADDRESS}" =~ ^0x[a-fA-F0-9]{40}$ ]]; then
          break
      else
          whiptail --title "Error" --msgbox "Invalid ETH address. Try again." 8 78
      fi
  done

  MSG_CONFIRM="\nFor Lido CSM, I am installing a separate NIMBUS VALIDATOR client.
\nThis validator client re-uses my current node's EL/CL and MEV relays.
\n✅ ${NETWORK} fee recipient: ${CSM_FEE_RECIPIENT_ADDRESS}
✅ Service file: ${SERVICE_FILE}
✅ Config file: $PLUGIN_INSTALL_PATH/$PLUGIN_ENV_VARS_FILE"

  if whiptail --title "Confirm Install" --defaultno --yesno "$MSG_CONFIRM" 15 78; then
      _doInstall
  fi  
}

function __viewPubkeyAndIndices(){
  VC="Nimbus"
  #source ${BASE_DIR}/functions.sh
  getPubKeys "plugin_csm_validator"
  getIndices
  viewPubkeyAndIndices
}

function __generateKeys(){
  source $BASE_DIR/manage_validator_keys.sh true
  export DATA_DIR
  generateNewValidatorKeys "plugin_csm_validator"
}

function __importKeys(){
  source $BASE_DIR/manage_validator_keys.sh true
  export DATA_DIR
  importValidatorKeys "plugin_csm_validator"
}

function __addRestoreKeys(){
  source $BASE_DIR/manage_validator_keys.sh true
  export DATA_DIR
  addRestoreValidatorKeys "plugin_csm_validator"
}

# Displays usage info
function usage() {
cat << EOF
Usage: $(basename "$0") [-i] [-u] [-r]

$PLUGIN_NAME Helper Script

Options)
-i    Install $PLUGIN_NAME
-u    Upgrade $PLUGIN_NAME
-r    Remove $PLUGIN_NAME
-h    Display help

About $PLUGIN_NAME)
- $DESCRIPTION
- Source code: $SOURCE_CODE
- Documentation: $DOCUMENTATION
EOF
}

setWhiptailColors

# Process command line options
while getopts :iurgmdhp opt; do
  case ${opt} in
    i ) _installPlugin ;;
    u ) _upgradeBinaries ;;
    r ) _removeAll ;;
    g ) __generateKeys ;;
    m ) __importKeys ;;
    d ) __addRestoreKeys ;;
	  p ) __viewPubkeyAndIndices ;;
    h )
      usage
      exit 0
      ;;
    \?)
      echo "Invalid option: -${OPTARG}" >&2
      usage
      exit 1
      ;;
    :)
      echo "Option -${OPTARG} requires an argument." >&2
      usage
      exit 1
      ;;
  esac
done
