#!/bin/bash

# Author: coincashew.eth | coincashew.com
# License: GNU GPL
# Source: https://github.com/coincashew
#
# Made for home and solo stakers 🏠🥩

function promptYesNo(){
    if whiptail --title "Uninstall Staking Node" --defaultno --yesno "This will remove all data and files related to this staking node.\nAre you sure you want to remove all files?\n(consensus/execution/validator/mevboost)" 9 78; then
  		uninstallCL
  		uninstallEL
  		uninstallVC
  		uninstallMevboost
		cleanupMisc
		uninstallPlugins
  		whiptail --title "Uninstall finished" --msgbox "You have uninstalled this staking node and all validator keys." 8 78
	else
		echo "Cancelled uninstall." && return 1
	fi
}

function uninstallPlugins(){
	if [[ -d /opt/ethpillar/plugin-csm ]]; then
		sudo systemctl stop csm_nimbusvalidator
		sudo systemctl disable csm_nimbusvalidator
		sudo rm /etc/systemd/system/csm_nimbusvalidator.service
		sudo userdel csm_nimbus_validator
		sudo rm -rf /opt/ethpillar/plugin-csm;
	fi
	if [[ -d /opt/ethpillar/plugin-sentinel ]]; then
		sudo docker stop csm-sentinel
		sudo docker rm csm-sentinel
		sudo docker rmi csm-sentinel
		sudo docker volume rm csm-sentinel-persistent
		sudo rm -rf /opt/ethpillar/plugin-sentinel
	fi
}

function cleanupMisc(){
	if [[ -f /etc/systemd/system/ethereum-metrics-exporter.service ]]; then
	   sudo rm /etc/apt/sources.list.d/grafana.list
	   sudo systemctl disable ethereum-metrics-exporter
	   sudo systemctl stop ethereum-metrics-exporter
	   sudo rm /etc/systemd/system/ethereum-metrics-exporter.service
	   sudo rm /usr/local/bin/ethereum-metrics-exporter
	   sudo systemctl disable grafana-server prometheus prometheus-node-exporter
	   sudo systemctl stop grafana-server prometheus prometheus-node-exporter
	   sudo apt remove -y grafana prometheus prometheus-node-exporter
	fi
	if [[ -f /usr/local/bin/eth-duties ]]; then sudo rm /usr/local/bin/eth-duties; fi
	if [[ -f /usr/local/bin/ethdo ]]; then sudo rm /usr/local/bin/ethdo; fi
	if [[ -f $BASE_DIR/.env.overrides ]]; then sudo rm $BASE_DIR/.env.overrides; fi
	if [[ -d /opt/ethpillar/testnet ]]; then sudo rm -rf /opt/ethpillar/testnet; fi
}

function uninstallCL(){
	if [[ -f /etc/systemd/system/consensus.service ]]; then
		sudo systemctl stop consensus
		sudo systemctl disable consensus
		sudo rm /etc/systemd/system/consensus.service

		#Lighthouse
		sudo rm -rf /usr/local/bin/lighthouse
		sudo rm -rf /var/lib/lighthouse

		#Lodestar
		sudo rm -rf /usr/local/bin/lodestar
		sudo rm -rf /var/lib/lodestar

		#Teku
		sudo rm -rf /usr/local/bin/teku
		sudo rm -rf /var/lib/teku

		#Nimbus
		sudo rm -rf /usr/local/bin/nimbus_beacon_node
		sudo rm -rf /var/lib/nimbus

		#Prysm from Binaries
		sudo rm -rf /usr/local/bin/beacon-chain
		#Prysm from Build from Source
		sudo rm -rf /usr/local/bin/prysm
		sudo rm -rf /var/lib/prysm

		sudo userdel consensus
	fi
}

function uninstallEL(){
	if [[ -f /etc/systemd/system/execution.service ]]; then
		sudo systemctl stop execution
		sudo systemctl disable execution
		sudo rm /etc/systemd/system/execution.service

		#Nethermind
		sudo rm -rf /usr/local/bin/nethermind
		sudo rm -rf /var/lib/nethermind

		#Besu
		sudo rm -rf /usr/local/bin/besu
		sudo rm -rf /var/lib/besu

		#Geth
		sudo rm -rf /usr/local/bin/geth
		sudo rm -rf /var/lib/geth

		#Erigon
		sudo rm -rf /usr/local/bin/erigon
		sudo rm -rf /var/lib/erigon

		#Reth
		sudo rm -rf /usr/local/bin/reth
		sudo rm -rf /var/lib/reth

		sudo userdel execution
	fi
}

function uninstallVC(){
	if [[ -f /etc/systemd/system/validator.service ]]; then
		sudo systemctl stop validator
		sudo systemctl disable validator
		sudo rm /etc/systemd/system/validator.service

		#Lighthouse
		sudo rm -rf /var/lib/lighthouse/validators

		#Lodestar
		sudo rm -rf /var/lib/lodestar/validators

		#Teku, if running Standalone Teku Validator
		sudo rm -rf /var/lib/teku_validator

		#Nimbus, if running standalone Nimbus Validator
		sudo rm -rf /var/lib/nimbus_validator
		sudo rm -rf /usr/local/bin/nimbus_validator_client

		#Prysm from Binaries
		sudo rm -rf /usr/local/bin/validator
		sudo rm -rf /var/lib/prysm/validators

		sudo userdel validator
	fi
}

function uninstallMevboost(){
	if [[ -f /etc/systemd/system/mevboost.service ]]; then
		sudo systemctl stop mevboost
		sudo systemctl disable mevboost
		sudo rm /etc/systemd/system/mevboost.service
		sudo rm /usr/local/bin/mev-boost
		sudo userdel mevboost
	fi
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
promptYesNo