#!/bin/bash

SOURCE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Variables
RELEASE_URL="https://api.github.com/repos/OffchainLabs/prysm/releases/latest"
GITHUB_RELEASE_NODES="https://github.com/OffchainLabs/prysm/releases"
DESCRIPTION="client-stats CLI utility to collect metrics from your Prysm validator or beacon node processes and push them to the beaconcha.in stats service"
DOCUMENTATION="https://www.offchainlabs.com/prysm/docs/prysm-usage/client-stats"
SOURCE_CODE="https://github.com/OffchainLabs/prysm"
APP_NAME="client-stats"
PLUGIN_NAME="Prysm client-stats Plugin"
PLUGIN_INSTALL_PATH="/opt/ethpillar/plugin-client-stats"
PLUGIN_SOURCE_PATH="$SOURCE_DIR"
SERVICE_NAME="client-stats"
SERVICE_ACCOUNT="client-stats"
SERVICE_FILE="/etc/systemd/system/client-stats.service"

# Load functions
source $SOURCE_DIR/../../functions.sh

# Get machine info
_platform=$(get_platform)
_arch=$(get_arch)

# Gets latest tag
function getLatestVersion(){
  TAG=$(curl -f -s https://prysmaticlabs.com/releases/latest)
}

# Gets current installed version
function getCurrentVersion(){
  if [ -f "$PLUGIN_INSTALL_PATH/client-stats" ]; then
    CURRENT_VERSION=$($PLUGIN_INSTALL_PATH/client-stats --version 2>/dev/null | grep -oP 'v\d+\.\d+\.\d+' || echo "unknown")
  else
    CURRENT_VERSION="client-stats not installed"
  fi
}

# Downloads latest release
function downloadClient(){
	cd $HOME
  getLatestVersion
	prysm_version=$TAG
	# Convert to lower case
	_platform=$(echo ${_platform} | tr '[:upper:]' '[:lower:]')	
  # Format files
	file_client_stats=client-stats-${prysm_version}-${_platform}-${_arch}
	curl -f -L "https://prysmaticlabs.com/releases/${file_client_stats}" -o client-stats
	chmod +x client-stats
	sudo mv client-stats $PLUGIN_INSTALL_PATH
}

# Upgrade function
function upgrade(){
  getLatestVersion
  getCurrentVersion
  # Remove front v if present and compare versions
  [[ "${CURRENT_VERSION#v}" == "${TAG#v}" ]] && whiptail --title "Already updated" --msgbox "You are already on the latest version: $CURRENT_VERSION" 10 78 && return
  if whiptail --title "Update $APP_NAME" --yesno "Installed Version is: $CURRENT_VERSION\nLatest Version is:    $TAG\n\nReminder: Always read the release notes for breaking changes: $GITHUB_RELEASE_NODES\n\nDo you want to update to $TAG?" 12 78; then
      sudo systemctl stop $SERVICE_NAME
      downloadClient
      sudo systemctl start $SERVICE_NAME
  fi
}

# Installation function
function install(){
MSG_ABOUT="🌈 Prysm client-stats collects CL & VC metrics and publishes them to the beaconcha.in stats service
\nFeatures:
\n- Monitor your staking node on the beaconcha.in mobile app
\n- Gathers data through the validator and consensus client's metrics APIs.
\n- Free monitoring tool by beaconcha.in to enhance the solo staking experience
\nSignup: https://beaconcha.in/register
\nFind your API Key here:
testnet > https://hoodi.beaconcha.in/user/settings#api
mainnet > https://beaconcha.in/user/settings#api
\nTip: Ensure your metrics are enabled!
Consensus metrics on port 8008, validator metrics on port 8009
\nDownload the mobile app: https://beaconcha.in/mobile
\nContinue to install?"

# Intro screen
if ! whiptail --title "$APP_NAME: Installation" --yesno "$MSG_ABOUT" 30 78; then exit; fi

# Get API_KEY
APIKEY=$(whiptail --title "API-KEY" --inputbox "Enter your beaconcha.in API-KEY" 10 78 --ok-button "Submit" 3>&1 1>&2 2>&3)

# Get MACHINE_NAME
HOSTNAME=$(hostname)
MACHINE_NAME=$(whiptail --title "Machine Name" --inputbox "Enter a name for this machine" 10 78 "$HOSTNAME" --ok-button "Submit" 3>&1 1>&2 2>&3)

# Create service file
sudo cp ${PLUGIN_SOURCE_PATH}/${SERVICE_NAME}.service.example ${PLUGIN_SOURCE_PATH}/${SERVICE_NAME}.service.tmp

# Update values
sed -i "s/__APIKEY/${APIKEY}/g" ${PLUGIN_SOURCE_PATH}/${SERVICE_NAME}.service.tmp || true
sed -i "s/__MACHINE_NAME/${MACHINE_NAME}/g" ${PLUGIN_SOURCE_PATH}/${SERVICE_NAME}.service.tmp || true

# Install service file
sudo mv ${PLUGIN_SOURCE_PATH}/${SERVICE_NAME}.service.tmp $SERVICE_FILE

# Create service user
sudo useradd --no-create-home --shell /bin/false $SERVICE_ACCOUNT

# Setup installation directory
sudo mkdir -p $PLUGIN_INSTALL_PATH

# Install binaries
downloadClient

# Update permissions
sudo chown $SERVICE_ACCOUNT:$SERVICE_ACCOUNT -R $PLUGIN_INSTALL_PATH

# Enable and start service
sudo systemctl enable $SERVICE_NAME
sudo systemctl start $SERVICE_NAME

MSG_COMPLETE="Done! $APP_NAME is now running. View the logs for more details."

# Installation complete screen
whiptail --title "$APP_NAME: Install Complete" --msgbox "$MSG_COMPLETE" 8 78
}

# Uninstall
function removeAll() {
  if whiptail --title "Uninstall $APP_NAME" --defaultno --yesno "Are you sure you want to remove $APP_NAME" 9 78; then
    sudo systemctl stop $SERVICE_NAME
    sudo systemctl disable $SERVICE_NAME
    sudo rm $SERVICE_FILE
    sudo userdel $SERVICE_ACCOUNT
    sudo rm -rf "$PLUGIN_INSTALL_PATH"
    whiptail --title "Uninstall finished" --msgbox "You have uninstalled $APP_NAME." 8 78
  fi
}

# Displays usage info
function usage() {
cat << EOF
Usage: $(basename "$0") [-i] [-u] [-r] [-s]

$APP_NAME Helper Script

Options)
-i    Install $APP_NAME
-u    Upgrade $APP_NAME
-r    Remove $APP_NAME
-h    Display help

About $APP_NAME)
- $DESCRIPTION
- Source code: $SOURCE_CODE
- Documentation: $DOCUMENTATION
EOF
}

# Process command line options
while getopts :iurhs opt; do
  case ${opt} in
    i ) install ;;
    u ) upgrade ;;
    r ) removeAll ;;
    h)
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
