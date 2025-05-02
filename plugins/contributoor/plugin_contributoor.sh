#!/bin/bash

# Author: coincashew.eth | coincashew.com
# License: GNU GPL
# Source: https://github.com/coincashew/ethpillar
# Description: Contributoor helper script
#
# Made for home and solo stakers 🏠🥩

SOURCE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Variables
RELEASE_URL="https://api.github.com/repos/ethpandaops/contributoor/releases/latest"
GITHUB_RELEASE_NODES="https://github.com/ethpandaops/contributoor/releases"
DESCRIPTION="🐼 Contributoor: a monitoring and data-gathering tool. improve Ethereum’s network visibility. runs seamlessly alongside your beacon node"
DOCUMENTATION="https://ethpandaops.io/posts/contribute-to-xatu-data"
SOURCE_CODE="https://github.com/ethpandaops/contributoor"
APP_NAME="contributoor"
PLUGIN_INSTALL_PATH="/opt/ethpillar/plugin-contributoor"
PLUGIN_SOURCE_PATH="$SOURCE_DIR"
SERVICE_NAME="contributoor"
SERVICE_ACCOUNT="contributoor"
SERVICE_FILE="/etc/systemd/system/contributoor.service"

# Gets latest tag
function getLatestVersion(){
  TAG=$(curl -s $RELEASE_URL | jq -r .tag_name )
}

# Downloads latest release
function downloadClient(){
  json=$(curl -s $RELEASE_URL) || true
  BINARIES_URL=$(echo "$json" | jq -r ".assets[] | select(.name) | .browser_download_url" | grep --ignore-case "${_platform}"_"${_arch}")
  echo Downloading URL: "$BINARIES_URL"
  # Make temporary directory
  TEMP_DIR=$(mktemp -d)
  # Download
  wget -O "$TEMP_DIR"/$APP_NAME.tar.gz "$BINARIES_URL"
  # Untar
  tar -xzvf "$TEMP_DIR"/$APP_NAME.tar.gz -C "$TEMP_DIR"
  # Install binary
  sudo mv "$TEMP_DIR"/sentry $PLUGIN_INSTALL_PATH/ && sudo chmod +x $PLUGIN_INSTALL_PATH/sentry
  # Store current version
  TAG=$(echo "$json" | jq -r .tag_name )
  echo "$TAG" | sudo tee $PLUGIN_INSTALL_PATH/current_version
  # Cleanup
  rm -rf "$TEMP_DIR"
}

# Upgrade function
function upgrade(){
  getLatestVersion
  VERSION=$(cat $PLUGIN_INSTALL_PATH/current_version)
  [[ "${VERSION#v}" == "${TAG#v}" ]] && whiptail --title "Already updated" --msgbox "You are already on the latest version: $VERSION" 10 78 && return
  if whiptail --title "Update $APP_NAME" --yesno "Installed Version is: $VERSION\nLatest Version is:    $TAG\n\nReminder: Always read the release notes for breaking changes: $GITHUB_RELEASE_NODES\n\nDo you want to update to $TAG?" 12 78; then
      sudo systemctl stop $SERVICE_NAME
      downloadClient
      sudo systemctl start $SERVICE_NAME
  fi
}

# Installation function
function install(){
MSG_ABOUT="🐼 Contributoor by ethpandaops.io is a powerful monitoring and data-gathering tool designed to enhance Ethereum's network transparency
\nFeatures:
\n- A lightweight service that operates with an Ethereum consensus client.
\n- Runs seamlessly alongside your consensus node, gathering data through the client's APIs.
\n- A simplified, user-friendly version of the sentry service from ethpandaops/xatu.
\n- Data is published openly and privately for research and analysis.
\nDocumentation: $DOCUMENTATION
Source Code:   $SOURCE_CODE
\nContinue to install?"

# Intro screen
if ! whiptail --title "Contributoor: Installation" --yesno "$MSG_ABOUT" 26 78; then exit; fi

# Create service user
sudo useradd --no-create-home --shell /bin/false $SERVICE_ACCOUNT

# Install service file
sudo cp "$PLUGIN_SOURCE_PATH"/${SERVICE_NAME}.service.example $SERVICE_FILE
sudo systemctl daemon-reload

# Setup installation directory
sudo mkdir -p $PLUGIN_INSTALL_PATH

# Install binaries
downloadClient

# Install config file
sudo cp "$PLUGIN_SOURCE_PATH"/config.yaml.example $PLUGIN_INSTALL_PATH/config.yaml

# Update permissions
sudo chown $SERVICE_ACCOUNT:$SERVICE_ACCOUNT -R $PLUGIN_INSTALL_PATH

MSG_COMPLETE="Done! Contributoor is now installed.
\nNext Steps:
\n1. Signup for Contributoor credentials > $DOCUMENTATION
\n2. Edit your config.yaml: Add credentials, metrics(optional), healthcheck(optional)
\n3. Start contributoor service"

# Installation complete screen
whiptail --title "Contributoor: Install Complete" --msgbox "$MSG_COMPLETE" 17 78
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
Usage: $(basename "$0") [-i] [-u] [-r]

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
while getopts :iurh opt; do
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
