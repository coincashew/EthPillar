#!/bin/bash

# Author: coincashew.eth | coincashew.com
# License: GNU GPL
# Source: https://github.com/coincashew
#
# Made for home and solo stakers 🏠🥩

BASE_DIR=$(pwd)

function getClient(){
    EL=$(cat /etc/systemd/system/execution.service | grep Description= | awk -F'=' '{print $2}' | awk '{print $1}')
}

function promptYesNo(){
	case $EL in
	  Nethermind)
		MSG="This will take a few hours."
	    ;;
	  *)
		MSG="This will about a day or so."
	    ;;
	  esac
    if whiptail --title "Resync Execution - $EL" --yesno "$MSG\nConsider configuring a RescueNode to minimize downtime.\nAre you sure you want to resync $EL?" 10 78; then
  		resyncClient
  		promptViewLogs
	fi
}

function promptViewLogs(){
    if whiptail --title "Resync $EL started" --yesno "Would you like to view logs and confirm everything is running properly?" 8 78; then
		sudo bash -c 'journalctl -fu execution | ccze -A'
    fi
}

function resyncClient(){
	clear
	case $EL in
	  Nethermind)
		sudo systemctl stop execution
		sudo rm -rf /var/lib/nethermind/*
		sudo systemctl restart execution
	    ;;
	  Besu)
		sudo systemctl stop execution
		sudo rm -rf /var/lib/besu/*
		sudo systemctl restart execution
	    ;;
	  Geth)
		sudo systemctl stop execution
		sudo rm -rf /var/lib/geth/*
		sudo systemctl restart execution
		;;
	  Erigon)
		sudo systemctl stop execution
		sudo rm -rf /var/lib/erigon/*
		sudo systemctl restart execution
	    ;;
  	  Reth)
		sudo systemctl stop execution
		sudo rm -rf /var/lib/reth/*
		sudo systemctl restart execution
	    ;;
	  esac
}

getClient
promptYesNo