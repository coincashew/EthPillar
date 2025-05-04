#!/bin/bash

# Author: coincashew.eth | coincashew.com
# License: GNU GPL
# Source: https://github.com/coincashew/ethpillar
# Description: EthPillar is a one-liner setup tool and node management TUI
#
# Made for home and solo stakers 🏠🥩

BASE_DIR=$HOME/git/ethpillar

# Load functions
source $BASE_DIR/functions.sh

# Get machine info
_platform=$(get_platform)
_arch=$(get_arch)

function getCurrentVersion(){
    INSTALLED=$(mev-boost --version 2>&1)
    #Find version in format #.#.#
    if [[ $INSTALLED ]] ; then
        VERSION=$(echo $INSTALLED | sed 's/.*\s\([0-9]*\.[0-9]*\).*/\1/')
	else
		VERSION="Client not installed."
	fi
}

function promptYesNo(){
	# Remove front v if present
	[[ "${VERSION#v}" == "${TAG#v}" ]] && whiptail --title "Already updated" --msgbox "You are already on the latest version: $VERSION" 10 78 && return
    if whiptail --title "Update mevboost" --yesno "Installed Version is: $VERSION\nLatest Version is:    $TAG\n\nReminder: Always read the release notes for breaking changes: $CHANGES_URL\n\nDo you want to update to $TAG?" 15 78; then
  		updateClient
  		promptViewLogs
	fi
}

function promptViewLogs(){
    if whiptail --title "Update complete" --yesno "Would you like to view logs and confirm everything is running properly?" 8 78; then
		sudo bash -c 'journalctl -fu mevboost | ccze -A'
    fi
}

function getLatestVersion(){
    TAG_URL="https://api.github.com/repos/flashbots/mev-boost/releases/latest"
	#Get tag name and remove leading 'v'
	TAG=$(curl -s $TAG_URL | jq -r .tag_name | sed 's/.*v\([0-9]*\.[0-9]*\).*/\1/')
	# Exit in case of null tag
	[[ -z $TAG ]] || [[ $TAG == "null"  ]] && echo "ERROR: Couldn't find the latest version tag" && exit 1
	CHANGES_URL="https://github.com/flashbots/mev-boost/releases"
}

function updateClient(){
	RELEASE_URL="https://api.github.com/repos/flashbots/mev-boost/releases/latest"
	BINARIES_URL="$(curl -s $RELEASE_URL | jq -r ".assets[] | select(.name) | .browser_download_url" | grep --ignore-case ${_platform}_${_arch}.tar.gz$)"

	echo Downloading URL: $BINARIES_URL

	cd $HOME
	# Download
	wget -O mev-boost.tar.gz $BINARIES_URL
	# Untar
	tar -xzvf mev-boost.tar.gz -C $HOME
	# Cleanup
	rm mev-boost.tar.gz LICENSE README.md
	sudo systemctl stop mevboost
	sudo mv $HOME/mev-boost /usr/local/bin
	sudo systemctl start mevboost
}

getCurrentVersion
getLatestVersion
promptYesNo