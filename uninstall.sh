# Author: coincashew.eth | coincashew.com
# License: GNU GPL
# Source: https://github.com/coincashew
#
# Made for home and solo stakers 🏠🥩

#!/bin/bash

function promptYesNo(){
    if whiptail --title "Uninstall Staking Node" --yesno "This will remove all data and files related to this staking node.\nAre you sure you want to remove all files?\n(consensus/execution/validator/mevboost)" 9 78; then
  		uninstallCL
  		uninstallEL
  		uninstallVC
  		uninstallMevboost
  		whiptail --title "Uninstall finished" --msgbox "You have uninstalled this staking node and all validator keys." 8 78
  	fi
}

function uninstallCL(){
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
}

function uninstallEL(){
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
}

function uninstallVC(){
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
}

function uninstallMevboost(){
	sudo systemctl stop mevboost
	sudo systemctl disable mevboost
	sudo rm /etc/systemd/system/mevboost.service
	sudo rm /usr/local/bin/mev-boost
	sudo userdel mevboost
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