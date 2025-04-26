#!/bin/bash

# Author: coincashew.eth | coincashew.com
# License: GNU GPL
# Source: https://github.com/coincashew/ethpillar
# Description: Dora the Explorer helper script
#
# Made for home and solo stakers 🏠🥩

SOURCE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Variables
RELEASE_URL="https://api.github.com/repos/ethpandaops/dora/releases/latest"
GITHUB_RELEASE_NODES="https://github.com/ethpandaops/dora/releases"
DESCRIPTION="Dora the Explorer is a tool for exploring ethereum execution and consensus clients. It provides insights into client behavior, performance, and network metrics."
DOCUMENTATION="https://github.com/ethpandaops/dora/wiki"
SOURCE_CODE="https://github.com/ethpandaops/dora"
APP_NAME="dora"
PLUGIN_NAME="Dora the Explorer Plugin"
PLUGIN_INSTALL_PATH="/opt/ethpillar/plugin-dora"
PLUGIN_SOURCE_PATH="$SOURCE_DIR"
SERVICE_NAME="dora"
SERVICE_ACCOUNT="dora"
SERVICE_FILE="/etc/systemd/system/dora.service"

# Load functions
source $SOURCE_DIR/../../functions.sh

# Get machine info
_platform=$(get_platform)
_arch=$(get_arch)

# Gets latest tag
function getLatestVersion(){
  TAG=$(curl -s $RELEASE_URL | jq -r .tag_name )
  # Exit in case of null tag
  [[ -z $TAG ]] || [[ $TAG == "null"  ]] && echo "ERROR: Couldn't find the latest version tag" && exit 1
}

# Downloads latest release
function downloadClient(){
  BINARIES_URL="$(curl -s $RELEASE_URL | jq -r ".assets[] | select(.name) | .browser_download_url" | grep --ignore-case ${_platform}_${_arch})"
  echo Downloading URL: $BINARIES_URL
  cd $HOME
  # Download
  wget -O $APP_NAME.tar.gz $BINARIES_URL
  # Untar
  tar -xzvf $APP_NAME.tar.gz -C $HOME
  # Cleanup
  rm $APP_NAME.tar.gz
  # Install binary
  sudo mv $HOME/dora-explorer $PLUGIN_INSTALL_PATH
  sudo mv $HOME/dora-utils $PLUGIN_INSTALL_PATH
  sudo chmod +x $PLUGIN_INSTALL_PATH/dora*
  # Store current version
  getLatestVersion
  sudo echo "$TAG" > $PLUGIN_INSTALL_PATH/current_version
}

#Asks to update
function upgrade(){
  getLatestVersion
  if whiptail --title "Update $APP_NAME" --yesno "Installed Version is: $(cat $PLUGIN_INSTALL_PATH/current_version)\nLatest Version is:    $TAG\n\nReminder: Always read the release notes for breaking changes: $GITHUB_RELEASE_NODES\n\nDo you want to update to $TAG?" 12 78; then
      sudo systemctl stop $SERVICE_NAME
      downloadClient
      sudo systemctl start $SERVICE_NAME
  fi
}

# Installs latest release and creates config file
function install(){
MSG_ABOUT="Dora the Explorer is a lightweight beaconchain explorer
\nFeatures:
\n- Validator Activities: Submit deposits, consolidation, withdrawals, exits
\n- Block Explorer: Block and transaction explorer
\n- Data: Real-time metrics and statistics
\n- Privacy: Dora will run locally using your node
\nSource Code: https://github.com/ethpandaops/dora
\nContinue to install?"

# Intro screen
if ! whiptail --title "Dora the Explorer: Installation" --yesno "$MSG_ABOUT" 20 78; then exit; fi

# Get network
_LISTENING_IP=$(whiptail --title "Set Dora's HTTP listening IP" --menu \
      "For which IP should Dora run on?" 10 78 2 \
      "localhost" "localhost only (local access only)" \
      "${ip_current}" "machine's IP (allow external access)" \
      3>&1 1>&2 2>&3)

# Open firewall port 8080 for local network
[[ $_LISTENING_IP = ${ip_current} ]] && sudo ufw allow from ${network_current} to any port 8080 comment 'Allow local network to access dora'

# Create service user
sudo useradd --no-create-home --shell /bin/false $SERVICE_ACCOUNT

# Install service file
sudo cp ${PLUGIN_SOURCE_PATH}/${SERVICE_NAME}.service.example $SERVICE_FILE

# Setup installation directory
sudo mkdir -p $PLUGIN_INSTALL_PATH

# Create config
sudo cp $PLUGIN_SOURCE_PATH/explorer-config.yaml.example $PLUGIN_SOURCE_PATH/explorer-config.yaml.tmp

# Update config values
sed -i "s/__NETWORK/${NETWORK}/g" $PLUGIN_SOURCE_PATH/explorer-config.yaml.tmp || true
sed -i "s/__IP/${_LISTENING_IP}/g" $PLUGIN_SOURCE_PATH/explorer-config.yaml.tmp || true
sudo mv $PLUGIN_SOURCE_PATH/explorer-config.yaml.tmp $PLUGIN_INSTALL_PATH/explorer-config.yaml

# Install binaries
downloadClient

# Update permissions
sudo chown $SERVICE_ACCOUNT:$SERVICE_ACCOUNT -R $PLUGIN_INSTALL_PATH

# Enable and start service
sudo systemctl enable $SERVICE_NAME
sudo systemctl start $SERVICE_NAME

MSG_COMPLETE="Done! Dora the Explorer is now running.
\nAccess the dashboard at: http://localhost:8080 or http://$ip_current:8080
\nNote: It may take a few minutes for data to appear as Dora indexes your node."

# Installation complete screen
whiptail --title "Dora the Explorer: Install Complete" --msgbox "$MSG_COMPLETE" 15 78
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
