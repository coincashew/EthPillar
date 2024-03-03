# Author: coincashew.eth | coincashew.com
# License: GNU GPL
# Source: https://github.com/coincashew/ethpillar
#
# Made for home and solo stakers 🏠🥩

#!/bin/bash

function getCurrentVersion(){
    CL_INSTALLED=$(curl -s -X 'GET'   'http://localhost:5052/eth/v1/node/version'   -H 'accept: application/json' | jq '.data.version')
    #Find version in format #.#.# 
    if [[ $CL_INSTALLED ]] ; then
        VERSION=$(echo $CL_INSTALLED | sed 's/.*v\([0-9]*\.[0-9]*\.[0-9]*\).*/\1/')
	else
		VERSION="Client not running or still starting up. Unable to query version."
	fi
}

function getClient(){
    CL=$(cat /etc/systemd/system/consensus.service | grep Description= | awk -F'=' '{print $2}' | awk '{print $1}')
}

function promptYesNo(){
    if whiptail --title "Update Consensus Client - $CL" --yesno "Installed Version is: $VERSION\nLatest Version is:    $TAG\n\nDo you want to update $CL to $TAG?" 10 78; then
  		updateClient
  		promptViewLogs
	fi
}

function promptViewLogs(){
    if whiptail --title "Update complete - $CL" --yesno "Would you like to view logs and confirm everything is running properly?" 8 78; then
  		sudo bash -c 'journalctl -fu consensus | ccze'
	fi
}

function getLatestVersion(){
	case $CL in
	  Lighthouse)
	    TAG_URL="https://api.github.com/repos/sigp/lighthouse/releases/latest"
	    ;;
	  Lodestar)
	    TAG_URL="https://api.github.com/repos/ChainSafe/lodestar/releases/latest"
	    ;;
	  Teku)
	    TAG_URL="https://api.github.com/repos/ConsenSys/teku/releases/latest"
	    ;;
	  Nimbus)
		TAG_URL="https://api.github.com/repos/status-im/nimbus-eth2/releases/latest"
		;;
  	  Prysm)
	    TAG_URL="https://api.github.com/repos/prysmaticlabs/prysm/releases/latest"
	    ;;
	  esac
	#Get tag name and remove leading 'v'
	TAG=$(curl -s $TAG_URL | jq -r .tag_name | sed 's/.*v\([0-9]*\.[0-9]*\.[0-9]*\).*/\1/')
}

function updateClient(){
	case $CL in
	  Lighthouse)
		RELEASE_URL="https://api.github.com/repos/sigp/lighthouse/releases/latest"
		BINARIES_URL="$(curl -s $RELEASE_URL | jq -r ".assets[] | select(.name) | .browser_download_url" | grep x86_64-unknown-linux-gnu.tar.gz$)"
		echo Downloading URL: $BINARIES_URL
		cd $HOME
		wget -O lighthouse.tar.gz $BINARIES_URL
		tar -xzvf lighthouse.tar.gz -C $HOME
		rm lighthouse.tar.gz
		sudo systemctl stop consensus validator
		sudo rm /usr/local/bin/lighthouse
		sudo mv $HOME/lighthouse /usr/local/bin/lighthouse
		sudo systemctl start consensus validator
	    ;;
	  Lodestar)
		cd ~/git/lodestar
		git checkout stable && git pull
		yarn clean:nm && yarn install
		yarn run build
		sudo systemctl stop consensus validator
		sudo rm -rf /usr/local/bin/lodestar
		sudo cp -a $HOME/git/lodestar /usr/local/bin/lodestar
		sudo systemctl start consensus validator
	    ;;
	  Teku)
		RELEASE_URL="https://api.github.com/repos/ConsenSys/teku/releases/latest"
		LATEST_TAG="$(curl -s $RELEASE_URL | jq -r ".tag_name")"
		BINARIES_URL="https://artifacts.consensys.net/public/teku/raw/names/teku.tar.gz/versions/${LATEST_TAG}/teku-${LATEST_TAG}.tar.gz"
		echo Downloading URL: $BINARIES_URL
		cd $HOME
		wget -O teku.tar.gz $BINARIES_URL
		tar -xzvf teku.tar.gz -C $HOME
		mv teku-* teku
		rm teku.tar.gz
		sudo systemctl stop consensus validator
		sudo rm -rf /usr/local/bin/teku
		sudo mv $HOME/teku /usr/local/bin/teku
		sudo systemctl start consensus validator
		;;
	  Nimbus)
		RELEASE_URL="https://api.github.com/repos/status-im/nimbus-eth2/releases/latest"
		BINARIES_URL="$(curl -s $RELEASE_URL | jq -r ".assets[] | select(.name) | .browser_download_url" | grep _Linux_amd64.*.tar.gz$)"
		echo Downloading URL: $BINARIES_URL
		cd $HOME
		wget -O nimbus.tar.gz $BINARIES_URL
		tar -xzvf nimbus.tar.gz -C $HOME
		mv nimbus-eth2_Linux_amd64_* nimbus
		sudo systemctl stop consensus validator
		sudo rm /usr/local/bin/nimbus_beacon_node
		sudo rm /usr/local/bin/nimbus_validator_client
		sudo mv nimbus/build/nimbus_beacon_node /usr/local/bin
		sudo mv nimbus/build/nimbus_validator_client /usr/local/bin
		sudo systemctl start consensus validator
		rm -r nimbus
		rm nimbus.tar.gz
	    ;;
  	  Prysm)
		cd $HOME
		prysm_version=$(curl -f -s https://prysmaticlabs.com/releases/latest)
		file_beacon=beacon-chain-${prysm_version}-linux-amd64
		file_validator=validator-${prysm_version}-linux-amd64
		curl -f -L "https://prysmaticlabs.com/releases/${file_beacon}" -o beacon-chain
		curl -f -L "https://prysmaticlabs.com/releases/${file_validator}" -o validator
		chmod +x beacon-chain validator
		sudo systemctl stop consensus validator
		sudo rm /usr/local/bin/beacon-chain
		sudo rm /usr/local/bin/validator
		sudo mv beacon-chain validator /usr/local/bin
		sudo systemctl start consensus validator
	    ;;
	  esac
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
getClient
getCurrentVersion
getLatestVersion
promptYesNo