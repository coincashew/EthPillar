#!/bin/bash

# Author: coincashew.eth | coincashew.com
# License: GNU GPL
# Source: https://github.com/coincashew/ethpillar
# Description: EthPillar is a one-liner setup tool and node management TUI
#
# Made for home and solo stakers 🏠🥩

BASE_DIR=$HOME/git/ethpillar

# Load functions
# shellcheck disable=SC1091
source "$BASE_DIR"/functions.sh

# Get machine info
_platform=$(get_platform)
_arch=$(get_arch)

function getCurrentVersion(){
    INSTALLED=$(mev-boost --version 2>&1)
    #Find version in format #.#.#
    if [[ $INSTALLED ]] ; then
        # shellcheck disable=SC2001
        VERSION=$(echo "$INSTALLED" | sed 's/.*\s\([0-9]*\.[0-9]*\).*/\1/')
	else
		VERSION="Client not installed."
	fi
}

function selectCustomTag(){
	local _listTags _tag
	_listTags=$(curl -fsSL https://api.github.com/repos/flashbots/mev-boost/tags | jq -r '.[].name' | sort -hr)
	if [ -z "$_listTags" ]; then
		error "❌ Could not retrieve tags. Try again later."
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
	    if whiptail --title "Different Version of mevboost" --defaultno --yesno "Would you like to install a different version?" 8 78; then
			selectCustomTag
			updateClient "$__OTHERTAG"
			promptViewLogs
		fi
		return
	fi
    __MSG="Installed Version is: ${VERSION#v}\nLatest Version is:    ${TAG#v}\n\nReminder: Always read the release notes for breaking changes: $CHANGES_URL\n\nDo you want to update mevboost to ${TAG#v}?"
	__SELECTTAG=$(whiptail --title "🔧 Update mevboost" --menu \
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
	if [[ "$1" == "LATEST" ]]; then
		_URL_SUFFIX="releases/latest"
	else
		_URL_SUFFIX="releases/tags/$1"
	fi
	RELEASE_URL="https://api.github.com/repos/flashbots/mev-boost/${_URL_SUFFIX}"
	BINARIES_URL="$(curl -s "$RELEASE_URL" | jq -r ".assets[] | select(.name) | .browser_download_url" | grep --ignore-case "${_platform}"_"${_arch}"\.tar\.gz$)"
	[[ -z "$BINARIES_URL" ]] && error "❌ Could not determine download URL for ${_platform}_${_arch}."	
	info "ℹ️  Downloading URL: $BINARIES_URL"
	cd "$HOME" || true
	# Download
	wget -O mev-boost.tar.gz "$BINARIES_URL" || error "❌ Failed to download mev-boost binary."
	# Untar
	tar -xzvf mev-boost.tar.gz -C "$HOME" || error "❌ Failed to extract mev-boost archive."
	# Cleanup
	rm mev-boost.tar.gz LICENSE README.md
	sudo systemctl stop mevboost
	sudo mv "$HOME"/mev-boost /usr/local/bin || error "❌ Failed to move mev-boost binary to /usr/local/bin."
	sudo systemctl start mevboost
}

getCurrentVersion
getLatestVersion
promptYesNo