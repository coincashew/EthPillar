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
	EL_INSTALLED=$(curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"web3_clientVersion","params":[],"id":2}' ${EL_RPC_ENDPOINT} | jq '.result')
    #Find version in format #.#.#
    if [[ $EL_INSTALLED ]] ; then
        VERSION=$(echo $EL_INSTALLED | sed 's/.*[v\/]\([0-9]\+\.[0-9]\+\.[0-9]\+\).*/\1/')
	else
		VERSION="Client not running or still starting up. Unable to query version."
	fi
}

function getClient(){
    EL=$(cat /etc/systemd/system/execution.service | grep Description= | awk -F'=' '{print $2}' | awk '{print $1}')
}

function promptYesNo(){
	# Remove front v if present
	[[ "${VERSION#v}" == "${TAG#v}" ]] && whiptail --title "Already updated" --msgbox "You are already on the latest version: $VERSION" 10 78 && return
    if whiptail --title "Update Execution Client - $EL" --yesno "Installed Version is: $VERSION\nLatest Version is:    $TAG\n\nReminder: Always read the release notes for breaking changes: $CHANGES_URL\n\nDo you want to update $EL to $TAG?" 15 78; then
  		updateClient
  		promptViewLogs
	fi
}

function promptViewLogs(){
    if whiptail --title "Update complete - $EL" --yesno "Would you like to view logs and confirm everything is running properly?" 8 78; then
		sudo bash -c 'journalctl -fu execution | ccze -A'
    fi
}

function getLatestVersion(){
	case $EL in
	  Nethermind)
	    TAG_URL="https://api.github.com/repos/NethermindEth/nethermind/releases/latest"
	    CHANGES_URL="https://github.com/NethermindEth/nethermind/releases"
	    ;;
	  Besu)
	    TAG_URL="https://api.github.com/repos/hyperledger/besu/releases/latest"
	    CHANGES_URL="https://github.com/hyperledger/besu/releases"
	    ;;
	  Erigon)
	    TAG_URL="https://api.github.com/repos/erigontech/erigon/releases/latest"
	    CHANGES_URL="https://github.com/erigontech/erigon/releases"
	    ;;
	  Geth)
	    TAG_URL="https://api.github.com/repos/ethereum/go-ethereum/releases/latest"
	    CHANGES_URL="https://github.com/ethereum/go-ethereum/releases"
		;;
  	  Reth)
	    TAG_URL="https://api.github.com/repos/paradigmxyz/reth/releases/latest"
	    CHANGES_URL="https://github.com/paradigmxyz/reth/releases"
	    ;;
	  esac
	#Get tag name
	TAG=$(curl -s $TAG_URL | jq -r .tag_name)
	# Exit in case of null tag
	[[ -z $TAG ]] || [[ $TAG == "null"  ]] && echo "ERROR: Couldn't find the latest version tag" && exit 1
}

function updateClient(){
	case $EL in
	  Nethermind)
		[[ "${_arch}" == "amd64" ]] && _architecture="x64" || _architecture="arm64"
	    RELEASE_URL="https://api.github.com/repos/NethermindEth/nethermind/releases/latest"
		BINARIES_URL="$(curl -s $RELEASE_URL | jq -r ".assets[] | select(.name) | .browser_download_url" | grep --ignore-case ${_platform}-${_architecture})"
		echo Downloading URL: $BINARIES_URL
		cd $HOME
		wget -O nethermind.zip $BINARIES_URL
		unzip -o nethermind.zip -d $HOME/nethermind
		rm nethermind.zip
		sudo systemctl stop execution
		sudo rm -rf /usr/local/bin/nethermind
		sudo mv $HOME/nethermind /usr/local/bin/nethermind
		sudo systemctl start execution
	    ;;
	  Besu)
		updateJRE
		RELEASE_URL="https://api.github.com/repos/hyperledger/besu/releases/latest"
		TAG=$(curl -s $RELEASE_URL | jq -r .tag_name)
		BINARIES_URL="https://github.com/hyperledger/besu/releases/download/$TAG/besu-$TAG.tar.gz"
		echo Downloading URL: $BINARIES_URL
		cd $HOME
		wget -O besu.tar.gz $BINARIES_URL
		tar -xzvf besu.tar.gz -C $HOME
		sudo mv besu-${TAG} besu
		sudo systemctl stop execution
		sudo rm -rf /usr/local/bin/besu
		sudo mv $HOME/besu /usr/local/bin/besu
		sudo systemctl start execution
		rm besu.tar.gz
	    ;;
	  Erigon)
	    RELEASE_URL="https://api.github.com/repos/erigontech/erigon/releases/latest"
		BINARIES_URL="$(curl -s $RELEASE_URL | jq -r ".assets[] | select(.name) | .browser_download_url" | grep --ignore-case ${_platform}_${_arch}.tar.gz)"
		echo Downloading URL: $BINARIES_URL
		cd $HOME
		wget -O erigon.tar.gz $BINARIES_URL
		tar -xzvf erigon.tar.gz -C $HOME
		mv erigon_*_${_arch} erigon
		sudo systemctl stop execution
		sudo mv $HOME/erigon/erigon /usr/local/bin
		sudo systemctl start execution
		rm -rf erigon erigon.tar.gz
		;;
	  Geth)
		# Convert to lower case
		_platform=${_platform,,}
		RELEASE_URL="https://geth.ethereum.org/downloads"
		FILE="https://gethstore.blob.core.windows.net/builds/geth-${_platform}-${_arch}[a-zA-Z0-9./?=_%:-]*.tar.gz"
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
		# Convert to lower case
		_platform=${_platform,,}
		[[ "${_arch}" == "amd64" ]] && _architecture="x86_64" || _architecture="aarch64"
	    RELEASE_URL="https://api.github.com/repos/paradigmxyz/reth/releases/latest"
		TAG=$(curl -s $RELEASE_URL | jq -r .tag_name)
		BINARIES_URL="https://github.com/paradigmxyz/reth/releases/download/$TAG/reth-$TAG-${_architecture}-unknown-${_platform}-gnu.tar.gz"
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

function updateJRE(){
	# Check if OpenJDK-21-JRE or OpenJDK-21-JDK is already installed
	if dpkg --list | grep -q -E "openjdk-21-jre|openjdk-21-jdk"; then
	   echo "OpenJDK-21-JRE or OpenJDK-21-JDK is already installed. Skipping installation."
	else
	   # Install OpenJDK-21-JRE
	   sudo apt-get update
	   sudo apt-get install -y openjdk-21-jre

       # Check if the installation was successful
       if [ $? -eq 0 ]; then
	      echo "OpenJDK-21-JRE installed successfully!"
	   else
	      echo "Error installing OpenJDK-21-JRE. Please check the error log."
	   fi
	fi
}

getClient
getCurrentVersion
getLatestVersion
promptYesNo