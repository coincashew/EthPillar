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

# Get machine info
_platform=$(get_platform)
_arch=$(get_arch)

# Binaries only available for amd64
if [[ ! "${_arch}" == "amd64" ]]; then
	echo "eth-duties binaries are only available for amd64 architecture"
	sleep 5
	exit 1
fi

# Variables
GITHUB_URL=https://api.github.com/repos/TobiWo/eth-duties/releases/latest
GITHUB_RELEASE_NODES=https://github.com/TobiWo/eth-duties/releases
RELEASE_SUFFIX="ubuntu22.04-${_arch}.tar.gz"
DESCRIPTION="eth-duties logs upcoming validator duties to the console. Developed mainly for home stakers."
DOCUMENTATION=https://tobiwo.github.io/eth-duties
SOURCE_CODE=https://github.com/TobiWo/eth-duties
APP_NAME=eth-duties
APP_INSTALL_PATH="/usr/local/bin"

# Asks to update
function upgradeBinaries(){
	getLatestVersion
  if whiptail --title "Update $APP_NAME" --yesno "Latest Version of $APP_NAME is:    $TAG\n\nReminder: Always read the release notes for breaking changes: $GITHUB_RELEASE_NODES\n\nDo you want to update to $TAG?" 10 78; then
  		downloadClient
	fi
}

# Gets latest tag
function getLatestVersion(){
	TAG=$(curl -s $GITHUB_URL | jq -r .tag_name )
	# Exit in case of null tag
	[[ -z $TAG ]] || [[ $TAG == "null"  ]] && echo "ERROR: Couldn't find the latest version tag" && exit 1
}

# Downloads latest release
function downloadClient(){
	BINARIES_URL="$(curl -s $GITHUB_URL | jq -r ".assets[] | select(.name) | .browser_download_url" | grep ${RELEASE_SUFFIX})"
	echo Downloading URL: $BINARIES_URL
	cd $HOME
	# Download
	wget -O $APP_NAME.tar.gz $BINARIES_URL
	# Untar
	tar -xzvf $APP_NAME.tar.gz -C $HOME --strip-components=2
	# Cleanup
	rm $APP_NAME.tar.gz
	# Install binary
	sudo mv $HOME/$APP_NAME $APP_INSTALL_PATH
}

# Uninstall
function removeAll() {
	if whiptail --title "Uninstall $APP_NAME" --defaultno --yesno "Are you sure you want to remove $APP_NAME" 9 78; then
	  sudo rm $APP_INSTALL_PATH/$APP_NAME
  	whiptail --title "Uninstall finished" --msgbox "You have uninstalled $APP_NAME." 8 78
	fi
}

# Displays usage info
function usage() {
cat << EOF
Usage: $(basename "$0") [-i] [-u] [-r]

$APP_NAME Helper Script

Options)
-i    Install $APP_NAME binary
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
    i ) downloadClient ;;
    u ) upgradeBinaries ;;
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
