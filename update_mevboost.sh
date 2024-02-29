# Author: coincashew.eth | coincashew.com
# License: GNU GPL
# Source: https://github.com/coincashew
#
# Made for home and solo stakers 🏠🥩

#!/bin/bash

BASE_DIR=$(pwd)

function getCurrentVersion(){
    INSTALLED=$(mev-boost --version)
    #Find version in format #.#.# 
    if [[ $INSTALLED ]] ; then
        VERSION=$(echo $INSTALLED | sed 's/.*v\([0-9]*\.[0-9]*\).*/\1/')
	else
		VERSION="Client not installed."
	fi
}

function promptYesNo(){
    if whiptail --title "Update mevboost" --yesno "Installed Version is: $VERSION\nLatest Version is:    $TAG\n\nDo you want to update to $TAG?" 10 78; then
  		updateClient
  		promptViewLogs
	fi
}

function promptViewLogs(){
    if whiptail --title "Update complete - $CL" --yesno "Would you like to view logs and confirm everything is running properly?" 8 78; then
  		sudo bash -c 'journalctl -fu mevboost | ccze'
	fi
}

function getLatestVersion(){
    TAG_URL="https://api.github.com/repos/flashbots/mev-boost/releases/latest"
	#Get tag name and remove leading 'v'
	TAG=$(curl -s $TAG_URL | jq -r .tag_name | sed 's/.*v\([0-9]*\.[0-9]*\).*/\1/')
}

function updateClient(){
	RELEASE_URL="https://api.github.com/repos/flashbots/mev-boost/releases/latest"
	BINARIES_URL="$(curl -s $RELEASE_URL | jq -r ".assets[] | select(.name) | .browser_download_url" | grep linux_amd64.tar.gz$)"

	echo Downloading URL: $BINARIES_URL

	cd $HOME
	# Download
	wget -O  mev-boost.tar.gz $BINARIES_URL
	# Untar
	tar -xzvf mev-boost.tar.gz -C $HOME
	# Cleanup
	rm mev-boost.tar.gz LICENSE README.md
	sudo systemctl stop mevboost
	sudo mv $HOME/mev-boost /usr/local/bin
	sudo systemctl start mevboost
}

function setWhiptailColors(){
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

setWhiptailColors
getCurrentVersion
getLatestVersion
promptYesNo