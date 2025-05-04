#!/bin/bash

# Author: coincashew.eth | coincashew.com
# License: GNU GPL
# Source: https://github.com/coincashew/ethpillar
# Description: csm-sentinel installer script
#
# Made for home and solo stakers 🏠🥩

set -e

MSG_ABOUT="About: CSM Sentinel is a telegram bot that sends you notifications for your CSM Node Operator events.
\nMaintainer: This bot was developed and is maintained by @skhomuti, a member of the Lido Protocol community, to simplify the process of subscribing to the important events for CSM.
\nLocally ran instance: This bot will run on your node, self-hosted for your own improved reliability and privacy.
\nSource Code: https://github.com/skhomuti/csm-sentinel
\nContinue to install?"

# Intro screen
if ! whiptail --title "CSM Sentinel: Running your own instance" --yesno "$MSG_ABOUT" 20 78; then exit; fi

# Get network
_NETWORK=$(whiptail --title "Set Network" --menu \
      "For which network are you running CSM Sentinel?" 10 78 2 \
      "mainnet" "ethereum" \
      "hoodi" "testnet" \
      3>&1 1>&2 2>&3)

MSG_TOKEN="First, you need to create a bot on Telegram.
\nTo create a bot, initiate a conversation with @BotFather (https://t.me/botfather), select the 'New Bot' option, and follow the prompts to set up your bot's name, username, and initial settings.
\nEnter the token you received from the BotFather.
\nExample: 270485614:AAHfiqksKZ8WmR2zSjiQ7_v4TMAKdiHm9T0"

# Get token
while true; do
    _TOKEN=$(whiptail --title "Set Token from BotFather" --inputbox "$MSG_TOKEN" 17 78 --ok-button "Submit" 3>&1 1>&2 2>&3)
    if [ -z "$_TOKEN" ]; then exit; fi #pressed cancel
    if [[ "${_TOKEN}" =~ [0-9]+:.* ]]; then
        break
    else
        whiptail --title "Error" --msgbox "Invalid TOKEN. Try again." 8 78
    fi
done

MSG_WEB3_SOCKET_PROVIDER="The websocket provider for your node.
\nPreferably, use your own local execution client node e.g. you already have for CSM validators.
\nDefault example: ws://127.0.0.1:8545"

# Get token
_WEB3_SOCKET_PROVIDER=$(whiptail --title "Set WEB3_SOCKET_PROVIDER" --inputbox "$MSG_WEB3_SOCKET_PROVIDER" 15 78 "ws://127.0.0.1:8545" --ok-button "Submit" 3>&1 1>&2 2>&3)
if [ -z "$_WEB3_SOCKET_PROVIDER" ]; then exit; fi #pressed cancel

# Install packages
apt-get update
apt-get upgrade -y

install_docker() {
  # Install Docker
  sudo apt-get install --yes docker.io
  # Verify that we can at least get version output
  if ! docker --version; then
    echo "ERROR: Is Docker installed?"
    exit 1
    fi
}

if ! command -v docker &> /dev/null; then
   install_docker
fi

# Setup files
mkdir -p /opt/ethpillar/plugin-sentinel
cd /opt/ethpillar/plugin-sentinel
if [[ ! -d /opt/ethpillar/plugin-sentinel/csm-sentinel ]]; then
    git clone https://github.com/skhomuti/csm-sentinel
    cd csm-sentinel
else
    cd csm-sentinel && git pull
fi

# Build image
docker build -t csm-sentinel .
docker volume create csm-sentinel-persistent

# Create env file
case $_NETWORK in
      mainnet)
cat << EOF > /opt/ethpillar/plugin-sentinel/csm-sentinel/.env
FILESTORAGE_PATH=.storage
TOKEN=${_TOKEN}
WEB3_SOCKET_PROVIDER=${_WEB3_SOCKET_PROVIDER}
CSM_ADDRESS=0xdA7dE2ECdDfccC6c3AF10108Db212ACBBf9EA83F
ACCOUNTING_ADDRESS=0x4d72BFF1BeaC69925F8Bd12526a39BAAb069e5Da
FEE_DISTRIBUTOR_ADDRESS=0xD99CC66fEC647E68294C6477B40fC7E0F6F618D0
VEBO_ADDRESS=0x0De4Ea0184c2ad0BacA7183356Aea5B8d5Bf5c6e
CSM_STAKING_MODULE_ID=3
ETHERSCAN_URL=https://etherscan.io
BEACONCHAIN_URL=https://beaconcha.in
CSM_UI_URL=https://csm.lido.fi/?ref=ethpillar
EOF
      ;;
      holesky)
cat << EOF > /opt/ethpillar/plugin-sentinel/csm-sentinel/.env
FILESTORAGE_PATH=.storage
TOKEN=${_TOKEN}
WEB3_SOCKET_PROVIDER=${_WEB3_SOCKET_PROVIDER}
CSM_ADDRESS=0x79CEf36D84743222f37765204Bec41E92a93E59d
ACCOUNTING_ADDRESS=0xA54b90BA34C5f326BC1485054080994e38FB4C60
FEE_DISTRIBUTOR_ADDRESS=0xaCd9820b0A2229a82dc1A0770307ce5522FF3582
VEBO_ADDRESS=0x8664d394C2B3278F26A1B44B967aEf99707eeAB2
CSM_STAKING_MODULE_ID=4
ETHERSCAN_URL=https://hoodi.etherscan.io
BEACONCHAIN_URL=https://hoodi.beaconcha.in
CSM_UI_URL=https://csm.testnet.fi/?ref=ethpillar
EOF
      ;;
      *)
        echo "Unsupported network"
        exit 1
      ;;
esac

# Start docker container
cd /opt/ethpillar/plugin-sentinel/csm-sentinel
sudo docker run -d --env-file=.env --name csm-sentinel -v csm-sentinel-persistent:/app/.storage csm-sentinel

MSG_COMPLETE="Done! Congratulations on your new locally hosted CSM Sentinel bot.
\nYou will find it at t.me/[YOUR-BOT-NAME].
Follow your Node Operator id."

# Intro screen
whiptail --title "CSM Sentinel: Install Complete" --msgbox "$MSG_COMPLETE" 10 78
