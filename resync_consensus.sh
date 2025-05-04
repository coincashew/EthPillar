#!/bin/bash

# Author: coincashew.eth | coincashew.com
# License: GNU GPL
# Source: https://github.com/coincashew/ethpillar
#
# Made for home and solo stakers 🏠🥩

# Load functions
BASE_DIR=$(pwd)
source $BASE_DIR/functions.sh

function getClient(){
	CL=$(cat /etc/systemd/system/consensus.service | grep Description= | awk -F'=' '{print $2}' | awk '{print $1}')
}

function promptYesNo(){
	if whiptail --title "Resync Consensus - $CL" --yesno "This will only take a minute or two.\nAre you sure you want to resync $CL?" 9 78; then
		resyncClient
		promptViewLogs
	fi
}

function promptViewLogs(){
	if whiptail --title "Resync $CL complete" --yesno "Would you like to view logs and confirm everything is running properly?" 8 78; then
		sudo bash -c 'journalctl -fu consensus | ccze -A'
	fi
}

function resyncClient(){
	case $CL in
	  Lighthouse)
		sudo systemctl stop consensus
		sudo rm -rf /var/lib/lighthouse/beacon
		sudo systemctl restart consensus
		;;
	  Lodestar)
		sudo systemctl stop consensus
		sudo rm -rf /var/lib/lodestar/chain-db
		sudo systemctl restart consensus
		;;
	  Teku)
		sudo systemctl stop consensus
		sudo rm -rf /var/lib/teku/beacon
		sudo systemctl restart consensus
		;;
	  Nimbus)
		getNetwork
		case $NETWORK in
		Holesky)
			_checkpointsync="--network=holesky --trusted-node-url=https://holesky.beaconstate.ethstaker.cc"
			;;
		Mainnet)
			_checkpointsync="--network=mainnet --trusted-node-url=https://beaconstate.ethstaker.cc"
			;;
		Sepolia)
			_checkpointsync="--network=sepolia --trusted-node-url=https://sepolia.beaconstate.info"
			;;
		Ephemery)
			_checkpointsync="--network=/opt/ethpillar/testnet --trusted-node-url=https://ephemery.beaconstate.ethstaker.cc"
			;;
		Hoodi)
			_checkpointsync="--network=hoodi --trusted-node-url=https://checkpoint-sync.hoodi.ethpandaops.io"
			;;
		esac

		sudo systemctl stop consensus
		sudo rm -rf /var/lib/nimbus/db

		sudo -u consensus /usr/local/bin/nimbus_beacon_node trustedNodeSync \
		${_checkpointsync} \
		--data-dir=/var/lib/nimbus \
		--backfill=false

		sudo systemctl restart consensus
		;;
	  Prysm)
		sudo systemctl stop consensus
		sudo rm -rf /var/lib/prysm/beacon/beaconchaindata
		sudo systemctl restart consensus
		;;
	  esac
}

getClient
promptYesNo