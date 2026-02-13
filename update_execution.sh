#!/bin/bash

# Author: coincashew.eth | coincashew.com
# License: GNU GPL
# Source: https://github.com/coincashew/ethpillar
# Description: EthPillar is a one-liner setup tool and node management TUI
#
# Made for home and solo stakers 🏠🥩

BASE_DIR=$HOME/git/ethpillar
__OTHERTAG=""

# Load functions
# shellcheck disable=SC1091
source "$BASE_DIR"/functions.sh

# Get machine info
_platform=$(get_platform)
_arch=$(get_arch)

function getCurrentVersion(){
  EL_INSTALLED=$(curl -s -X POST -H "Content-Type: application/json" \
    --data '{"jsonrpc":"2.0","method":"web3_clientVersion","params":[],"id":2}' \
    "${EL_RPC_ENDPOINT}" | jq -r '.result // empty')
  if [[ -z "$EL_INSTALLED" ]]; then
    VERSION="Client not running or still starting up. Unable to query version."
    return
  fi
  VERSION=$(sed -E 's/.*[v/]([0-9]+\.[0-9]+\.[0-9]+).*/\1/' <<< "$EL_INSTALLED")
}

function getClient(){
    EL=$(cat /etc/systemd/system/execution.service | grep Description= | awk -F'=' '{print $2}' | awk '{print $1}')
    # Handle integrated ELs i.e. Erigon-Caplin
    EL=${EL%-*}
}

function selectCustomTag(){
	case $EL in
	  Nethermind)
	    _repo="NethermindEth/nethermind"
	    ;;
	  Besu)
	    _repo="hyperledger/besu"
	    ;;
	  Erigon)
	    _repo="erigontech/erigon"
	    ;;
	  Geth)
	    _repo="ethereum/go-ethereum"
	    ;;
	  Reth)
	    _repo="paradigmxyz/reth"
	    ;;
	  *)
	    error "❌ Unsupported or unknown client '$EL'."
	    ;;
	esac
	local _listTags _tag
	_listTags=$(curl -fsSL https://api.github.com/repos/"${_repo}"/tags | jq -r '.[].name' | sort -hr)
	if [ -z "$_listTags" ]; then
		error "❌ Could not retrieve tags for ${_repo}. Try again later."
	fi
	info "ℹ️  Select the Version: Type the number to use. For example, 2 (for the 2nd most recent release)"
	select _tag in $_listTags; do
        if [ -n "$_tag" ]; then
			__OTHERTAG=$_tag
            break
        else
            error "❌ Invalid input. Enter the line # corresponding to a tag."
        fi
    done
}

function promptYesNo(){
	# Remove front v if present
	if [[ "${VERSION#v}" == "${TAG#v}" ]]; then
		whiptail --title "Already updated" --msgbox "You are already on the latest version: ${VERSION#v}" 10 78
	    if whiptail --title "Different Version of $EL" --defaultno --yesno "Would you like to install a different version?" 8 78; then
			selectCustomTag
			updateClient "$__OTHERTAG"
			promptViewLogs
		fi
		return
	fi
    __MSG="Installed Version is: ${VERSION#v}\nLatest Version is:    ${TAG#v}\n\nReminder: Always read the release notes for breaking changes: $CHANGES_URL\n\nDo you want to update $EL to ${TAG#v}?"
	__SELECTTAG=$(whiptail --title "🔧 Update Execution Client" --menu \
	      "$__MSG" 18 78 2 \
	      "LATEST" "| Installs ${TAG#v}, the latest release" \
	      "OTHER " "| I will select a different version" \
	      3>&1 1>&2 2>&3)
	if [ -z "$__SELECTTAG" ]; then exit; fi # pressed cancel
	if [[ $__SELECTTAG == "LATEST" ]]; then
		updateClient "LATEST"
		promptViewLogs
	else
		selectCustomTag
		updateClient "$__OTHERTAG"
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
	  *)
	    error "❌ Unsupported or unknown client '$EL'."
	    ;;	    
	esac
	#Get tag name
	TAG=$(curl -s "$TAG_URL" | jq -r .tag_name)
	# Exit in case of null tag
	if [[ -z $TAG ]] || [[ $TAG == "null" ]]; then
		error "❌ Couldn't find the latest version tag"
	fi
}

function updateClient(){
	if [[ "$1" == "LATEST" ]]; then
		_URL_SUFFIX="releases/latest"
	else
		_URL_SUFFIX="releases/tags/$1"
	fi
	case $EL in
	  Nethermind)
		[[ "${_arch}" == "amd64" ]] && _architecture="x64" || _architecture="arm64"

		# Force lowercase platform (important!)
		_platform_lower=$(echo "${_platform}" | tr '[:upper:]' '[:lower:]')

		RELEASE_URL="https://api.github.com/repos/NethermindEth/nethermind/$_URL_SUFFIX"

		BINARIES_URL=$(curl -s "$RELEASE_URL" | \
		jq -r --arg plat "$_platform_lower" --arg arch "${_architecture}" \
		'.assets[] | select(.name | endswith("-\($plat)-\($arch).zip")) | .browser_download_url' | \
		head -n 1 | tr -d '\r\n ')

		if [[ -z "$BINARIES_URL" ]]; then
			curl -s "$RELEASE_URL" | jq -r '.assets[].name' >&2
			error "❌ Could not find download URL for ${_platform_lower}-${_architecture}.zip in release $_URL_SUFFIX"
		fi

		info "✅ Downloading URL: $BINARIES_URL"

		cd "$HOME" || true

		wget -O nethermind.zip "$BINARIES_URL" || error "❌ Unable to wget file"

		unzip -o nethermind.zip -d "$HOME"/nethermind || error "❌ Unable to unzip file"
		rm -f nethermind.zip

		sudo systemctl stop execution
		sudo rm -rf /usr/local/bin/nethermind
		sudo mv "$HOME"/nethermind /usr/local/bin/nethermind || error "❌ Unable to move file"
		sudo systemctl start execution		
		;;
	  Besu)
		updateJRE
		RELEASE_URL="https://api.github.com/repos/hyperledger/besu/$_URL_SUFFIX"
		TAG=$(curl -s "$RELEASE_URL" | jq -r .tag_name)
		BINARIES_URL="https://github.com/hyperledger/besu/releases/download/$TAG/besu-$TAG.tar.gz"
		info "✅ Downloading URL: $BINARIES_URL"
		cd "$HOME" || true
		wget -O besu.tar.gz "$BINARIES_URL" || error "❌ Unable to wget file"
		tar -xzvf besu.tar.gz -C "$HOME" || error "❌ Unable to untar file"
		sudo mv besu-"${TAG}" besu
		sudo systemctl stop execution
		sudo rm -rf /usr/local/bin/besu
		sudo mv "$HOME"/besu /usr/local/bin/besu || error "❌ Unable to move file"
		sudo systemctl start execution
		rm besu.tar.gz
	    ;;
	  Erigon)
		RELEASE_URL="https://api.github.com/repos/erigontech/erigon/$_URL_SUFFIX"
		BINARIES_URL=$(curl -s "$RELEASE_URL" | jq -r ".assets[] | select(.name) | .browser_download_url" | grep --ignore-case "${_platform}"_"${_arch}".tar.gz)
		info "✅ Downloading URL: $BINARIES_URL"
		cd "$HOME" || true
		wget -O erigon.tar.gz "$BINARIES_URL" || error "❌ Unable to wget file"
		tar -xzvf erigon.tar.gz -C "$HOME" || error "❌ Unable to untar file"
		mv erigon_*_"${_arch}" erigon
		sudo systemctl stop execution
		sudo mv "$HOME"/erigon/erigon /usr/local/bin || error "❌ Unable to move file"
		sudo systemctl start execution
		rm -rf erigon erigon.tar.gz
		;;
	  Geth)
		# Convert to lower case
		_platform=${_platform,,}
		RELEASE_URL="https://geth.ethereum.org/downloads"
		#https://gethstore.blob.core.windows.net/builds/geth-linux-386-1.16.3-09786041.tar.gz
		# Remove front v if present
		if [[ "$1" == "LATEST" ]]; then
			_URL_SUFFIX=""
		else
			_URL_SUFFIX="-${1#v}-"
		fi
		FILE="https://gethstore.blob.core.windows.net/builds/geth-${_platform}-${_arch}${_URL_SUFFIX}[a-zA-Z0-9./?=_%:-]*.tar.gz"
		BINARIES_URL=$(curl -s $RELEASE_URL | grep -Eo "$FILE" | head -1)
		info "✅ Downloading URL: $BINARIES_URL"
		cd "$HOME" || true
		wget -O geth.tar.gz "$BINARIES_URL" || error "❌ Unable to wget file"
		tar -xzvf geth.tar.gz -C "$HOME" --strip-components=1 || error "❌ Unable to untar file"
		sudo systemctl stop execution
		sudo mv "$HOME"/geth /usr/local/bin || error "❌ Unable to move file"
		sudo systemctl start execution
		rm geth.tar.gz COPYING
	    ;;
  	  Reth)
		# Convert to lower case
		_platform=${_platform,,}
		[[ "${_arch}" == "amd64" ]] && _architecture="x86_64" || _architecture="aarch64"
		RELEASE_URL="https://api.github.com/repos/paradigmxyz/reth/$_URL_SUFFIX"
		TAG=$(curl -s "$RELEASE_URL" | jq -r .tag_name)
		BINARIES_URL="https://github.com/paradigmxyz/reth/releases/download/$TAG/reth-$TAG-${_architecture}-unknown-${_platform}-gnu.tar.gz"
		info "✅ Downloading URL: $BINARIES_URL"
		cd "$HOME" || true
		wget -O reth.tar.gz "$BINARIES_URL" || error "❌ Unable to wget file"
		tar -xzvf reth.tar.gz -C "$HOME" || error "❌ Unable to untar file"
		rm reth.tar.gz
		sudo systemctl stop execution
		sudo mv "$HOME"/reth /usr/local/bin || error "❌ Unable to move file"
		sudo systemctl start execution
	    ;;
	  esac
}

function updateJRE(){
	# Check if OpenJDK-21-JRE or OpenJDK-21-JDK is already installed
	if dpkg --list | grep -q -E "openjdk-21-jre|openjdk-21-jdk"; then
	   info "✅ OpenJDK-21-JRE or OpenJDK-21-JDK is already installed. Skipping installation."
	else
	   # Install OpenJDK-21-JRE
	   sudo apt-get update
	   sudo apt-get install -y openjdk-21-jre

       # Check if the installation was successful
       # shellcheck disable=SC2181
       if [ $? -eq 0 ]; then
	      info "✅ OpenJDK-21-JRE installed successfully!"
	   else
	      error "❌ Error installing OpenJDK-21-JRE. Please check the error log."
	   fi
	fi
}

getClient
getCurrentVersion
getLatestVersion
promptYesNo