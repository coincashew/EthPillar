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

function selectCustomTag(){
	case $CLIENT in
	  Lighthouse)
	    _repo="sigp/lighthouse"
	    ;;
	  Lodestar)
	    _repo="ChainSafe/lodestar"
	    ;;
	  Teku)
	    _repo="ConsenSys/teku"
	    ;;
	  Nimbus)
	    _repo="status-im/nimbus-eth2"
	    ;;
	  Prysm)
	    _repo="OffchainLabs/prysm"
	    ;;
	  *)
	    error "❌ Unsupported or unknown client '$CLIENT'."
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
	    if whiptail --title "Different Version of ${CLIENT}" --defaultno --yesno "Would you like to install a different version?" 8 78; then
			selectCustomTag
			updateClient "$__OTHERTAG"
			promptViewLogs
		fi
		return
	fi
    __MSG="Installed Version is: ${VERSION#v}\nLatest Version is:    ${TAG#v}\n\nReminder: Always read the release notes for breaking changes: $CHANGES_URL\n\nDo you want to update $CLIENT to ${TAG#v}?"
	__SELECTTAG=$(whiptail --title "🔧 Update ${CLIENT}" --menu \
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
    if whiptail --title "Update complete" --yesno "Would you like to view logs and confirm everything is running properly?" 8 78; then
		if [[ ${NODE_MODE} =~ "Validator Client Only" ]]; then
			sudo bash -c 'journalctl -fu validator | ccze -A'
		else
			sudo bash -c 'journalctl -fu consensus | ccze -A'
		fi
    fi
}

function getLatestVersion(){
	case "$CLIENT" in
	  Lighthouse)
	    TAG_URL="https://api.github.com/repos/sigp/lighthouse/releases/latest"
	    CHANGES_URL="https://github.com/sigp/lighthouse/releases"
	    ;;
	  Lodestar)
	    TAG_URL="https://api.github.com/repos/ChainSafe/lodestar/releases/latest"
	    CHANGES_URL="https://github.com/ChainSafe/lodestar/releases"
	    ;;
	  Teku)
	    TAG_URL="https://api.github.com/repos/ConsenSys/teku/releases/latest"
	    CHANGES_URL="https://github.com/ConsenSys/teku/releases"
	    ;;
	  Nimbus)
	    TAG_URL="https://api.github.com/repos/status-im/nimbus-eth2/releases/latest"
	    CHANGES_URL="https://github.com/status-im/nimbus-eth2/releases"
	    ;;
	  Prysm)
	    TAG_URL="https://api.github.com/repos/OffchainLabs/prysm/releases/latest"
	    CHANGES_URL="https://github.com/OffchainLabs/prysm/releases"
	    ;;
	  *)
	    error "❌ Unsupported or unknown client '$CLIENT'."
	    ;;
	esac
	#Get tag name and remove leading 'v'
	TAG=$(curl -s $TAG_URL | jq -r .tag_name | sed 's/.*\(v[0-9]*\.[0-9]*\.[0-9]*\).*/\1/')
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
	case "$CLIENT" in
	  Lighthouse)
		[[ "${_arch}" == "amd64" ]] && _architecture="x86_64" || _architecture="aarch64"
		RELEASE_URL="https://api.github.com/repos/sigp/lighthouse/$_URL_SUFFIX"
		BINARIES_URL=$(curl -s "$RELEASE_URL" | jq -r ".assets[] | select(.name) | .browser_download_url" | grep --ignore-case "${_architecture}"-unknown-"${_platform}"-gnu.tar.gz$)
		info "✅ Downloading URL: $BINARIES_URL"
		cd "$HOME" || true
		wget -O lighthouse.tar.gz "$BINARIES_URL" || error "❌ Unable to wget file"
		tar -xzvf lighthouse.tar.gz -C "$HOME" || error "❌ Unable to untar file"
		rm lighthouse.tar.gz
		test -f /etc/systemd/system/consensus.service && sudo systemctl stop consensus
		test -f /etc/systemd/system/validator.service && sudo service validator stop
		sudo rm /usr/local/bin/lighthouse
		sudo mv "$HOME"/lighthouse /usr/local/bin/lighthouse || error "❌ Unable to move file"
		test -f /etc/systemd/system/consensus.service && sudo systemctl start consensus
		test -f /etc/systemd/system/validator.service && sudo service validator start
	    ;;
	  Lodestar)
		RELEASE_URL="https://api.github.com/repos/ChainSafe/lodestar/$_URL_SUFFIX"
		LATEST_TAG=$(curl -s "$RELEASE_URL" | jq -r ".tag_name")
		BINARIES_URL="https://github.com/ChainSafe/lodestar/releases/download/${LATEST_TAG}/lodestar-${LATEST_TAG}-${_platform}-${_arch}.tar.gz"
		info "✅ Downloading URL: $BINARIES_URL"
		cd "$HOME" || true
		wget -O lodestar.tar.gz "$BINARIES_URL" || error "❌ Unable to wget file"
		tar -xzvf lodestar.tar.gz -C "$HOME" || error "❌ Unable to untar file"
		rm lodestar.tar.gz
		test -f /etc/systemd/system/consensus.service && sudo systemctl stop consensus
		test -f /etc/systemd/system/validator.service && sudo service validator stop
		sudo rm -rf /usr/local/bin/lodestar
		sudo mkdir -p /usr/local/bin/lodestar
		sudo mv "$HOME"/lodestar /usr/local/bin/lodestar || error "❌ Unable to move file"
		test -f /etc/systemd/system/consensus.service && sudo systemctl start consensus
		test -f /etc/systemd/system/validator.service && sudo service validator start
	    ;;
	  Teku)
		updateJRE
		RELEASE_URL="https://api.github.com/repos/ConsenSys/teku/$_URL_SUFFIX"
		LATEST_TAG=$(curl -s "$RELEASE_URL" | jq -r ".tag_name")
		BINARIES_URL="https://artifacts.consensys.net/public/teku/raw/names/teku.tar.gz/versions/${LATEST_TAG}/teku-${LATEST_TAG}.tar.gz"
		info "✅ Downloading URL: $BINARIES_URL"
		cd "$HOME" || true
		wget -O teku.tar.gz "$BINARIES_URL" || error "❌ Unable to wget file"
		tar -xzvf teku.tar.gz -C "$HOME" || error "❌ Unable to untar file"
		mv teku-"${LATEST_TAG}" teku
		rm teku.tar.gz
		test -f /etc/systemd/system/consensus.service && sudo systemctl stop consensus
		test -f /etc/systemd/system/validator.service && sudo service validator stop
		sudo rm -rf /usr/local/bin/teku
		sudo mv "$HOME"/teku /usr/local/bin/teku || error "❌ Unable to move file"
		test -f /etc/systemd/system/consensus.service && sudo systemctl start consensus
		test -f /etc/systemd/system/validator.service && sudo service validator start
		;;
	  Nimbus)
		RELEASE_URL="https://api.github.com/repos/status-im/nimbus-eth2/$_URL_SUFFIX"
		BINARIES_URL=$(curl -s "$RELEASE_URL" | jq -r ".assets[] | select(.name) | .browser_download_url" | grep --ignore-case "_${_platform}_${_arch}.*.tar.gz$")
		info "✅ Downloading URL: $BINARIES_URL"
		cd "$HOME" || true
		wget -O nimbus.tar.gz "$BINARIES_URL" || error "❌ Unable to wget file"
		tar -xzvf nimbus.tar.gz -C "$HOME" || error "❌ Unable to untar file"
		mv nimbus-eth2_"${_platform}"_"${_arch}"* nimbus
		test -f /etc/systemd/system/consensus.service && sudo systemctl stop consensus
		test -f /etc/systemd/system/validator.service && sudo service validator stop
		sudo rm /usr/local/bin/nimbus_beacon_node
		sudo rm /usr/local/bin/nimbus_validator_client
		sudo mv nimbus/build/nimbus_beacon_node /usr/local/bin || error "❌ Unable to move file"
		sudo mv nimbus/build/nimbus_validator_client /usr/local/bin || error "❌ Unable to move file"
		test -f /etc/systemd/system/consensus.service && sudo systemctl start consensus
		test -f /etc/systemd/system/validator.service && sudo service validator start
		rm -r nimbus
		rm nimbus.tar.gz
	    ;;
  	  Prysm)
		cd "$HOME" || true
		if [[ "$1" == "LATEST" ]]; then
			prysm_version=$(curl -f -s https://prysmaticlabs.com/releases/latest)
		else
			prysm_version="$1"
		fi
		# Convert to lower case
		_platform=${_platform,,}
		file_beacon=beacon-chain-${prysm_version}-${_platform}-${_arch}
		file_validator=validator-${prysm_version}-${_platform}-${_arch}
		file_prysmctl=prysmctl-${prysm_version}-${_platform}-${_arch}
		curl -f -L "https://prysmaticlabs.com/releases/${file_beacon}" -o beacon-chain || error "❌ Unable to download beacon-chain"
		curl -f -L "https://prysmaticlabs.com/releases/${file_validator}" -o validator || error "❌ Unable to download validator"
		curl -f -L "https://prysmaticlabs.com/releases/${file_prysmctl}" -o prysmctl || error "❌ Unable to download prysmctl"
		chmod +x beacon-chain validator prysmctl
		test -f /etc/systemd/system/consensus.service && sudo systemctl stop consensus
		test -f /etc/systemd/system/validator.service && sudo service validator stop
		sudo rm /usr/local/bin/beacon-chain
		sudo rm /usr/local/bin/validator
		sudo rm /usr/local/bin/prysmctl
		sudo mv beacon-chain validator prysmctl /usr/local/bin || error "❌ Unable to move prysm files"
		test -f /etc/systemd/system/consensus.service && sudo systemctl start consensus
		test -f /etc/systemd/system/validator.service && sudo systemctl start validator
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