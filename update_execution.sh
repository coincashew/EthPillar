# Author: coincashew.eth | coincashew.com
# License: GNU GPL
# Source: https://github.com/coincashew
#
# Made for home and solo stakers 🏠🥩

#!/bin/bash

BASE_DIR=$(pwd)

function getCurrentVersion(){
	 EL_INSTALLED=$(curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"web3_clientVersion","params":[],"id":2}' localhost:8545 | jq '.result')
    #Find version in format #.#.# 
    if [[ $EL_INSTALLED ]] ; then
        VERSION=$(echo $EL_INSTALLED | sed 's/.*v\([0-9]*\.[0-9]*\.[0-9]*\).*/\1/')
	else
		VERSION="Client not running or still starting up. Unable to query version."
	fi
}

function getClient(){
    EL=$(cat /etc/systemd/system/execution.service | grep Description= | awk -F'=' '{print $2}' | awk '{print $1}')
}

function promptYesNo(){
    if whiptail --title "Update Execution Client - $EL" --yesno "Installed Version is: $VERSION\nLatest Version is:    $TAG\n\nDo you want to update $EL to $TAG?" 10 78; then
  		updateClient
  		promptViewLogs
	fi
}

function promptViewLogs(){
    if whiptail --title "Update complete - $EL" --yesno "Would you like to view logs and confirm everything is running properly?" 8 78; then
  		sudo bash -c 'journalctl -fu execution | ccze'
	fi
}

function getLatestVersion(){
	case $EL in
	  Nethermind)
	    TAG_URL="https://api.github.com/repos/NethermindEth/nethermind/releases/latest"
	    ;;
	  Besu)
	    TAG_URL="https://api.github.com/repos/hyperledger/besu/releases/latest"
	    ;;
	  Erigon)
	    TAG_URL="https://api.github.com/repos/ledgerwatch/erigon/releases/latest"
	    ;;
	  Geth)
		TAG_URL="https://api.github.com/repos/ethereum/go-ethereum/releases/latest"
		;;
  	  Reth)
	    TAG_URL="https://api.github.com/repos/paradigmxyz/reth/releases/latest"
	    ;;
	  esac
	#Get tag name and remove leading 'v'
	TAG=$(curl -s $TAG_URL | jq -r .tag_name | sed 's/.*v\([0-9]*\.[0-9]*\.[0-9]*\).*/\1/')
}

function updateClient(){
	case $EL in
	  Nethermind)
	    RELEASE_URL="https://api.github.com/repos/NethermindEth/nethermind/releases/latest"
		BINARIES_URL="$(curl -s $RELEASE_URL | jq -r ".assets[] | select(.name) | .browser_download_url" | grep linux-x64)"
		echo Downloading URL: $BINARIES_URL
		cd $HOME
		wget -O nethermind.zip $BINARIES_URL
		unzip -o nethermind.zip -d $HOME/nethermind
		rm nethermind.zip
		sudo systemctl stop execution
		sudo mv $HOME/nethermind /usr/local/bin/nethermind
		sudo systemctl start execution
	    ;;
	  Besu)
	    RELEASE_URL="https://api.github.com/repos/hyperledger/besu/releases/latest"
		TAG=$(curl -s $RELEASE_URL | jq -r .tag_name)
		BINARIES_URL="https://hyperledger.jfrog.io/hyperledger/besu-binaries/besu/$TAG/besu-$TAG.tar.gz"
		echo Downloading URL: $BINARIES_URL
		cd $HOME
		wget -O besu.tar.gz $BINARIES_URL
		tar -xzvf besu.tar.gz -C $HOME
		
		sudo mv $HOME/besu-* besu
		sudo systemctl stop execution
		sudo rm -rf /usr/local/bin/besu
		sudo mv $HOME/besu /usr/local/bin/besu
		sudo systemctl start execution
		rm besu.tar.gz
	    ;;
	  Erigon)
	    RELEASE_URL="https://api.github.com/repos/ledgerwatch/erigon/releases/latest"
		BINARIES_URL="$(curl -s $RELEASE_URL | jq -r ".assets[] | select(.name) | .browser_download_url" | grep linux_amd64)"
		echo Downloading URL: $BINARIES_URL
		cd $HOME
		wget -O erigon.tar.gz $BINARIES_URL
		tar -xzvf erigon.tar.gz -C $HOME
		sudo systemctl stop execution
		sudo mv $HOME/erigon /usr/local/bin/erigon
		sudo systemctl start execution
		rm erigon.tar.gz README.md
		;;
	  Geth)
		RELEASE_URL="https://geth.ethereum.org/downloads"
		FILE="https://gethstore.blob.core.windows.net/builds/geth-linux-amd64[a-zA-Z0-9./?=_%:-]*.tar.gz"
		BINARIES_URL="$(curl -s $RELEASE_URL | grep -Eo $FILE | head -1)"
		echo Downloading URL: $BINARIES_URL
		cd $HOME
		wget -O geth.tar.gz $BINARIES_URL
		tar -xzvf geth.tar.gz -C $HOME --strip-components=1
		sudo systemctl stop execution
		sudo mv $HOME/geth /usr/local/bin
		sudo systemctl start execution
		rm geth.tar.gz COPYING
	    ;;
  	  Reth)
	    RELEASE_URL="https://api.github.com/repos/paradigmxyz/reth/releases/latest"
		BINARIES_URL="$(curl -s $RELEASE_URL | jq -r ".assets[] | select(.name) | .browser_download_url" | grep x86_64-unknown-linux-gnu.tar.gz$)"
		echo Downloading URL: $BINARIES_URL
		cd $HOME
		wget -O reth.tar.gz $BINARIES_URL
		tar -xzvf reth.tar.gz -C $HOME
		rm reth.tar.gz
		sudo systemctl stop execution
		sudo mv $HOME/reth /usr/local/bin
		sudo systemctl start execution
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