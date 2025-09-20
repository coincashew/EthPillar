#!/bin/bash

# Author: coincashew.eth | coincashew.com
# License: GNU GPL
# Source: https://github.com/coincashew/ethpillar
# Description: csm-sentinel helper script
#
# Made for home and solo stakers 🏠🥩

# Base directory with scripts
BASE_DIR=$HOME/git/ethpillar

# Source docker wrapper for rootless/rootful compatibility
if [[ -f /opt/ethpillar/helpers/docker_wrapper.sh ]]; then
  # shellcheck disable=SC1091
  source /opt/ethpillar/helpers/docker_wrapper.sh
fi

# Variables
#GITHUB_URL=https://api.github.com/repos/skhomuti/csm-sentinel/releases/latest
#GITHUB_RELEASE_NODES=https://github.com/skhomuti/csm-sentinel/releases
DESCRIPTION="CSM Sentinel is a telegram bot that sends you notifications for your CSM Node Operator events. Self-hosted. Uses docker."
DOCUMENTATION="https://github.com/skhomuti/csm-sentinel"
SOURCE_CODE="https://github.com/skhomuti/csm-sentinel"
APP_NAME="csm-sentinel"
PLUGIN_NAME="CSM Sentinel Plugin"
PLUGIN_SOURCE_PATH="$BASE_DIR/plugins/sentinel"
PLUGIN_INSTALL_PATH="/opt/ethpillar/plugin-sentinel"

#Asks to update
function upgrade(){
  if whiptail --title "Update $PLUGIN_NAME" --yesno "Reminder: Always read the release notes for breaking changes: $SOURCE_CODE\n\nDo you want to update?" 10 78; then
      cd $PLUGIN_INSTALL_PATH/$APP_NAME
  sudo git pull
  ${DOCKER_CMD} stop $APP_NAME || true
  ${DOCKER_CMD} build -t csm-sentinel .    
  __start 
	fi
}

# Installs latest release
function install(){
	exec sudo $PLUGIN_SOURCE_PATH/sentinel-installer.sh
}

# Starts the docker container
function __start(){
  cd $PLUGIN_INSTALL_PATH/$APP_NAME
  if docker ps -aq --filter=name=$APP_NAME > /dev/null 2>&1; then
    ${DOCKER_CMD} rm -f $APP_NAME
  fi
  # Run using bridge network and explicit port mappings to be rootless-compatible.
  ${DOCKER_CMD} run -d --env-file=.env --name csm-sentinel \
    -v csm-sentinel-persistent:/app/.storage \
    --network ethpillar_default \
    csm-sentinel
}

# Uninstall
function removeAll() {
	if whiptail --title "Uninstall $APP_NAME" --defaultno --yesno "Are you sure you want to remove $APP_NAME" 9 78; then
  ${DOCKER_CMD} stop "$APP_NAME" || true
  ${DOCKER_CMD} rm -f $APP_NAME || true
  ${DOCKER_CMD} rmi -f "$APP_NAME" || true
  ${DOCKER_CMD} volume rm csm-sentinel-persistent || true
    sudo rm -rf "$PLUGIN_INSTALL_PATH"
  	whiptail --title "Uninstall finished" --msgbox "You have uninstalled $APP_NAME." 8 78
	fi
}

# Displays usage info
function usage() {
cat << EOF
Usage: $(basename "$0") [-i] [-u] [-r] [-s]

$APP_NAME Helper Script

Options)
-i    Install $APP_NAME
-u    Upgrade $APP_NAME
-r    Remove $APP_NAME
-s    Start $APP_NAME
-h    Display help

About $APP_NAME)
- $DESCRIPTION
- Source code: $SOURCE_CODE
- Documentation: $DOCUMENTATION
EOF
}

# Process command line options
while getopts :iurhs opt; do
  case ${opt} in
    i ) install ;;
    u ) upgrade ;;
    r ) removeAll ;;
    s ) __start ;;
    h)
      usage
      exit 0
      ;;
    \?)
      echo "Invalid option: -${OPTARG}" >&2
      usage
      exit 1
      ;;
    :)
      echo "Option -${OPTARG} requires an argument." >&2
      usage
      exit 1
      ;;
  esac
done
