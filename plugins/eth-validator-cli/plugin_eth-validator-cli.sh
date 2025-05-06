#!/bin/bash

# Author: coincashew.eth | coincashew.com
# License: GNU GPL
# Source: https://github.com/coincashew/ethpillar
# Description: Contributoor helper script
#
# Made for home and solo stakers 🏠🥩

SOURCE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Variables
RELEASE_URL="https://api.github.com/repos/TobiWo/eth-validator-cli/releases/latest"
GITHUB_RELEASE_NODES="https://github.com/TobiWo/eth-validator-cli/releases"
DESCRIPTION="🔧 eth-validator-cli: CLI tool for managing Ethereum validators via execution layer requests."
DOCUMENTATION="https://github.com/TobiWo/eth-validator-cli"
SOURCE_CODE="https://github.com/TobiWo/eth-validator-cli"
APP_NAME="eth-validator-cli"
PLUGIN_INSTALL_PATH="/opt/ethpillar/plugin-eth-validator-cli"
PLUGIN_SOURCE_PATH="$SOURCE_DIR"

# Gets latest tag
function getLatestVersion(){
  TAG=$(curl -s $RELEASE_URL | jq -r .tag_name )
  if [[ -z "$TAG" ]]; then echo "Failed to fetch latest version"; exit 1; fi
}

# Downloads latest release
function downloadClient(){
  local _custom
  # Handle custom naming convention
  [[ "$_arch" == "amd64" ]] && _custom="x64"
  if [[ -z "$_custom" ]]; then
    echo "Unsupported architecture: $_arch"
    exit 1
  fi
  json=$(curl -s $RELEASE_URL) || true
  BINARIES_URL=$(echo "$json" | jq -r ".assets[] | select(.name) | .browser_download_url" | grep --ignore-case "${_platform}"-"${_custom}")
  if [[ -z "$BINARIES_URL" ]]; then
    echo "Error: No download URL found for ${_platform}-${_custom}"
    exit 1
  fi
  echo Downloading URL: "$BINARIES_URL"
  # Make temporary directory
  TEMP_DIR=$(mktemp -d)
  # Download
  wget -O "$TEMP_DIR"/"$APP_NAME".tar.gz "$BINARIES_URL"
  # Untar
  tar -xzvf "$TEMP_DIR"/"$APP_NAME".tar.gz -C "$TEMP_DIR"
  # Install binary
  sudo mv "$TEMP_DIR"/"$APP_NAME" $PLUGIN_INSTALL_PATH/ && sudo chmod +x $PLUGIN_INSTALL_PATH/$APP_NAME
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
      downloadClient
  fi
}

# Installation function
function install(){
MSG_ABOUT="🔧 eth-validator-cli by TobiWo: CLI tool for managing validators via execution layer requests
\nFeatures:
- Consolidate one or multiple source validators to one target validator
- Switch withdrawal credentials from type 0x01 to 0x02 (compounding) for one or multiple validators
- Partially withdraw ETH from one or many validators
- Exit one or many validators
- This cli currently only supports validator related features included in the Pectra hardfork. 
- The tool is especially useful if you need to manage multiple validators at once.
- Currently it only supports private keys as secret. This will change soon with e.g. hardware ledger support.
- ⚠️ Tool is very early. Use on Hoodi only. Not recommend to use it on mainnet yet!
\nDocumentation: $DOCUMENTATION
Source Code:   $SOURCE_CODE
\nContinue to install?"

# Intro screen
if ! whiptail --title "$APP_NAME: Installation" --yesno "$MSG_ABOUT" 28 78; then exit; fi

# Setup installation directory
sudo mkdir -p $PLUGIN_INSTALL_PATH

# Install binaries
downloadClient

# Install env file
sudo cp "$PLUGIN_SOURCE_PATH"/env.example $PLUGIN_INSTALL_PATH/env

# Update permissions
sudo chmod -R 755 "$PLUGIN_SOURCE_PATH"

MSG_COMPLETE="Done! $APP_NAME is now installed.
\nNext Steps:
\n1. Study the documentation > $DOCUMENTATION
\n2. Review env configuration, change if needed
\n3. Practice on hoodi testnet before mainnet"

# Installation complete screen
whiptail --title "$APP_NAME: Install Complete" --msgbox "$MSG_COMPLETE" 17 78
}

# Uninstall
function removeAll() {
  if whiptail --title "Uninstall $APP_NAME" --defaultno --yesno "Are you sure you want to remove $APP_NAME" 9 78; then
    sudo rm -rf "$PLUGIN_INSTALL_PATH"
    whiptail --title "Uninstall finished" --msgbox "You have uninstalled $APP_NAME." 8 78
  fi
}

# Displays usage info
function usage() {
cat << EOF
Usage: $(basename "$0") [-i] [-u] [-r]

$APP_NAME Helper Script

Options:
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
