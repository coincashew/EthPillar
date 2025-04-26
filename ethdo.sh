#!/bin/bash

# Author: coincashew.eth | coincashew.com
# License: GNU GPL
# Source: https://github.com/coincashew/ethpillar
# Description: ethdo helper script
#
# Made for home and solo stakers 🏠🥩

# Base directory with scripts
BASE_DIR=$HOME/git/ethpillar

# Load functions
source $BASE_DIR/functions.sh

# Get machine info
_platform=$(get_platform)
_arch=$(get_arch)

# Variables
GITHUB_URL=https://api.github.com/repos/wealdtech/ethdo/releases/latest
GITHUB_RELEASE_NODES=https://github.com/wealdtech/ethdo/releases
RELEASE_SUFFIX="${_platform}-${_arch}.tar.gz$"
DESCRIPTION="A command-line tool for managing common tasks in Ethereum"
DOCUMENTATION=https://github.com/wealdtech/ethdo/blob/master/docs/howto.md
SOURCE_CODE=https://github.com/wealdtech/ethdo
APP_NAME=ethdo
APP_INSTALL_PATH="/usr/local/bin"
VERSION=v$([[ -e ${APP_INSTALL_PATH}/ethdo ]] && ethdo version)

# Asks to update
function upgradeBinaries(){
	getLatestVersion
  if whiptail --title "Update $APP_NAME" --yesno "Installed Version is:       $VERSION\nLatest Version of $APP_NAME is: $TAG\n\nReminder: Always read the release notes for breaking changes: $GITHUB_RELEASE_NODES\n\nDo you want to update to $TAG?" 10 78; then
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
	BINARIES_URL="$(curl -s $GITHUB_URL | jq -r ".assets[] | select(.name) | .browser_download_url" | grep --ignore-case ${RELEASE_SUFFIX})"
	echo Downloading URL: $BINARIES_URL
	cd $HOME
	# Download
	wget -O $APP_NAME.tar.gz $BINARIES_URL
	# Untar
	tar -xzvf $APP_NAME.tar.gz -C $HOME
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
