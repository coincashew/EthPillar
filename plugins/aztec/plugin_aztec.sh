#!/bin/bash

# Author: coincashew.eth | coincashew.com
# License: GNU GPL
# Source: https://github.com/coincashew/ethpillar
# Description: Aztec plugin inspired by https://github.com/cryptocattelugu/Aztec-Network
#
# Made for home and solo stakers 🏠🥩
set -euo pipefail

SOURCE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Variables
RELEASE_URL="https://api.github.com/repos/AztecProtocol/aztec-packages/releases/latest"
DESCRIPTION="🥷 Aztec Sequencer Node: a privacy first L2 on Ethereum by Aztec Labs"
DOCUMENTATION="https://aztec.network/network"
SOURCE_CODE="https://github.com/AztecProtocol/aztec-packages"
APP_NAME="aztec-sequencer"
PLUGIN_INSTALL_PATH="/opt/ethpillar/aztec"
PLUGIN_SOURCE_PATH="$SOURCE_DIR"
DOCKER_IMAGE=aztecprotocol/aztec

# Colors
g="\033[32m" # Green
r="\033[31m" # Red
nc="\033[0m" # No-color
bold="\033[1m"

function info {
  echo -e "${g}INFO: $1${nc}"
}

function error {
  echo -e "${r}${bold}ERROR: ❌ $1${nc}"
  exit 1
}

function get_arch(){
  machine_arch="$(uname --machine)"
  if [[ "${machine_arch}" = "x86_64" ]]; then
    binary_arch="amd64"
  elif [[ "${machine_arch}" = "aarch64" ]]; then
    binary_arch="arm64"
  else
    echo "Unsupported architecture: ${machine_arch}"
    exit 1
  fi
  echo "${binary_arch}"
}

# Gets latest tag
function getLatestVersion(){
  TAG=$(curl -s $RELEASE_URL | jq -r .tag_name )
  if [[ -z "$TAG" ]]; then error "Failed to fetch latest version"; fi
}

# Install cli binaries
function downloadClient(){
  export NON_INTERACTIVE=1; export SKIP_PULL=1; bash -i <(curl -s https://install.aztec.network)
}

function install_docker() {
  sudo bash -c "$SOURCE_DIR/../../helpers/install_docker.sh"
  info "Adding current user to docker group..."
  sudo usermod -aG docker "$USER"
}

function install_foundry() {
  _architecture=$(get_arch)
  RELEASE_URL="https://api.github.com/repos/foundry-rs/foundry/releases/latest"
  BINARIES_URL="$(curl -s "$RELEASE_URL" | jq -r ".assets[] | select(.name) | .browser_download_url" | grep --ignore-case alpine_"${_architecture}".tar.gz$)"
  echo Downloading URL: "$BINARIES_URL"
  cd "$HOME" || true
  tmpdir=$(mktemp -d)
  cd "$tmpdir" || error "Unable to change to tmpdir"
  wget -O foundry.tar.gz "$BINARIES_URL"
  if [ ! -f foundry.tar.gz ]; then
    echo "Error: Downloading foundry archive failed!"
    exit 1
  fi
  sudo tar -xzvf foundry.tar.gz -C "$tmpdir" || error "Unable to untar foundry.tar.gz"
  # shellcheck disable=SC2015
  [[ -f "$tmpdir"/cast ]] && sudo mv "$tmpdir"/cast /usr/local/bin || error "Unable to install cast to /usr/local/bin"
  # shellcheck disable=SC2015
  rm -rf "$tmpdir" || error "Unable to cleanup temp foundry files"
}

function download_snapshot() {
  # Install dependency
  if ! command -v lz4 &> /dev/null; then
   sudo apt-get install lz4 -y
  fi

  # Create directory structure
  mkdir -p $PLUGIN_INSTALL_PATH || error "Unable to create directory structure for snapshot"
   
  # Download the snapshot
  wget https://files5.blacknodes.net/aztec/aztec-alpha-testnet.tar.lz4 -O "$HOME"/aztec-alpha-testnet.tar.lz4 || error "Unable to download snapshot"
   
  # Extract the snapshot
  lz4 -d "$HOME"/aztec-alpha-testnet.tar.lz4 | sudo tar -x -C $PLUGIN_INSTALL_PATH || error "Unable to extract snapshot"
   
  # Cleanup the downloaded file
  rm "$HOME"/aztec-alpha-testnet.tar.lz4 || error "Unable cleanup tar file"
}

# Installation function
function install(){
MSG_ABOUT="🥷 Aztec Sepolia Sequencer: a privacy first L2 on Ethereum by Aztec Labs
\nBackground:
Aztec is the first fully decentralized L2, thanks to its permissionless network of sequencers and provers.

Your sequencer node takes part in three key actions:
-Assemble unprocessed transactions and propose the next block
-Attest to correct execution of txs in the proposed block
-Submit the successfully attested block to L1

Requirements:
- Synced Nimbus + Nethermind Full Node (uses ~750GB) for Sepolia Testnet
- 2 core / 4 vCPU                 - 16 GB RAM
- 100GB NVMe SDD for Aztec Node   - 25 Mbps network connection
- 850GB+ for Full Node Setup (execution L1 RPC + consensus beacon RPC + aztec L2)
- Validator Private Key (for attesting, proposals), Coinbase Address (for block rewards)

Documentation: $DOCUMENTATION
\nContinue to install?"

# Intro screen
if ! whiptail --title "$APP_NAME: Installation" --yesno "$MSG_ABOUT" 29 78; then exit; fi

# Local or remote RPC
RPC_CONFIG=$(whiptail --title "🔧 RPC Configuration" --menu \
      "Where's the RPCs?" 10 78 2 \
      "LOCAL" "| Installs full node on this machine. Requires 850GB+ disk space" \
      "REMOTE" "| I will provide Ethereum RPC and Beacon RPC URLs" \
      3>&1 1>&2 2>&3)
if [ -z "$RPC_CONFIG" ]; then exit; fi # pressed cancel
if [[ $RPC_CONFIG == "REMOTE" ]]; then
  ETH_RPC=$(whiptail --title "Ethereum RPC URL (ETHEREUM_HOSTS)" --inputbox "🔗 Enter Ethereum RPC URL (e.g. https://sepolia.rpc.url):" 9 78 --ok-button "Submit" 3>&1 1>&2 2>&3)
  BEACON_RPC=$(whiptail --title "Beacon RPC URL (L1_CONSENSUS_HOST_URLS)" --inputbox "🔗 Enter Beacon RPC URL (e.g. https://beacon.rpc.url):" 9 78 --ok-button "Submit" 3>&1 1>&2 2>&3)
else
  # Install EL/CL
  if [[ ! -f /etc/systemd/system/execution.service ]] && [[ ! -f /etc/systemd/system/consensus.service ]]; then
    sudo bash -c "$SOURCE_DIR/../../install-node.sh deploy-nimbus-nethermind.py true"
  fi
fi

# Install packages
sudo apt-get update
sudo apt-get upgrade -y

# Install Docker
if ! command -v docker &> /dev/null; then
   info "🔧 Installing docker..."
   install_docker
fi

info "🔧 Setup installation directory"
sudo mkdir -p $PLUGIN_INSTALL_PATH || error "Unable to setup installation directory"
sudo chmod -R 655 "$PLUGIN_INSTALL_PATH" || error "Unable to chmod installation directory permissions"

info "🔧 Install env file and compose file..."
sudo cp "$PLUGIN_SOURCE_PATH"/.env.example $PLUGIN_INSTALL_PATH/.env || error "Unable to create .env"
sudo cp "$PLUGIN_SOURCE_PATH"/docker-compose.yml.example $PLUGIN_INSTALL_PATH/docker-compose.yml || error "Unable to create docker-compose.yml"

TAG=$(grep "DOCKER_TAG" $PLUGIN_INSTALL_PATH/.env | sed "s/^DOCKER_TAG=\(.*\)/\1/")
#TAG=$(docker inspect aztec-sequencer |  jq -r '.[0].Config.Image')
echo "$TAG" | sudo tee $PLUGIN_INSTALL_PATH/current_version
info "✏️  Storing current version... $TAG"

if ! command -v cast &> /dev/null; then
   info "🔧 Installing foundry for cast..."
   install_foundry
fi

info "🔐 Generating new Ethereum private key for validator with cast..."
cast wallet new-mnemonic > "$HOME"/aztec_seed_phrase || error "Unable to generate new cast wallet"
ADDRESS=$(grep "Address: " "$HOME"/aztec_seed_phrase | awk '{print $2}')
PRIVATE_KEY=$(grep "Private key: " "$HOME"/aztec_seed_phrase | awk '{print $3}')
sudo mv "$HOME"/aztec_seed_phrase $PLUGIN_INSTALL_PATH

info "🔧 Update config values in .env..."
# shellcheck disable=SC2015
[[ -n $PRIVATE_KEY ]] && sudo sed -i "s/^VALIDATOR_PRIVATE_KEYS.*$/VALIDATOR_PRIVATE_KEYS=${PRIVATE_KEY}/" $PLUGIN_INSTALL_PATH/.env || error "Unable to set VALIDATOR_PRIVATE_KEYS"
# shellcheck disable=SC2015
[[ -n $ADDRESS ]] && sudo sed -i "s/^VALIDATOR_ADDRESS.*$/VALIDATOR_ADDRESS=${ADDRESS}/" $PLUGIN_INSTALL_PATH/.env || error "Unable to set VALIDATOR_ADDRESS"
# shellcheck disable=SC2015
# COINBASE is block reward recipient. On mainnet, use a unique hardware wallet secured ETH address.
[[ -n $ADDRESS ]] && sudo sed -i "s/^COINBASE.*$/COINBASE=${ADDRESS}/" $PLUGIN_INSTALL_PATH/.env || error "Unable to set COINBASE"

if [[ $RPC_CONFIG == "REMOTE" ]]; then
  sudo sed -i "s|^ETHEREUM_HOSTS.*$|ETHEREUM_HOSTS=${ETH_RPC}|" $PLUGIN_INSTALL_PATH/.env || error "Unable to set ETHEREUM_HOSTS"
  sudo sed -i "s|^L1_CONSENSUS_HOST_URLS.*$|L1_CONSENSUS_HOST_URLS=${BEACON_RPC}|" $PLUGIN_INSTALL_PATH/.env || error "Unable to set L1_CONSENSUS_HOST_URLS"
fi 

# sanitize with grep
P2P_IP=$(grep -m 1 -oE '^[0-9]{1,3}(\.[0-9]{1,3}){3}$' <<< "$(wget -T 10 -t 1 -4qO- "ipv4.icanhazip.com" || curl -m 10 -4Ls "http://ip1.dynupdate.no-ip.com")")    

# shellcheck disable=SC2015
[[ -n $P2P_IP ]] && sudo sed -i "s/^P2P_IP.*$/P2P_IP=${P2P_IP}/" $PLUGIN_INSTALL_PATH/.env || error "Unable to get and set P2P_IP"
info "🔧 Configuring and updating P2P_IP to $P2P_IP"

#info "📁 Downloading aztec snapshot, minimizes syncing issues and faster sync..."
#download_snapshot
#[[ -f /opt/ethpillar/aztec/data/archiver/data.mdb ]] && info "✅ Verfied snapshot extract exists" || error "Unable to verify snapshot extract"

info "🔧 Configuring UFW firewall"
sudo ufw allow 40400 comment 'Allow aztec node p2p port' || error "Unable to configure ufw"
#sudo ufw allow 8080 comment 'Allow aztec rpc port'

MSG_COMPLETE="✅ Done! $APP_NAME is now installed.
\nNext Steps:
\n1. Backup aztec validator key created by cast:
   Location > $PLUGIN_INSTALL_PATH/aztec_seed_phrase
\n2. Review .env configuration: update values if desired   
\n3. Start aztec-sequencer: Ensure Sepolia Full Node is fully synced first!

Port forwarding: Forward the p2p port (default: 40400) to your local node ip address. Configure in your router.
\nRead documentation: $DOCUMENTATION

Join the Discord to connect with the community and get help with your setup.
- Aztec: https://discord.gg/aztec
- EthPillar: https://discord.gg/WS8E3PMzrb
\nHappy private sequencing!
"

# Installation complete screen
whiptail --title "$APP_NAME: Install Complete" --msgbox "$MSG_COMPLETE" 28 78
}

# Uninstall
function removeAll() {
  if whiptail --title "Uninstall $APP_NAME" --defaultno --yesno "Are you sure you want to remove $APP_NAME" 9 78; then
    cd $PLUGIN_INSTALL_PATH 2>/dev/null && docker compose down || true
    sudo docker rm -f $APP_NAME
    TAG=$(grep "DOCKER_TAG" $PLUGIN_INSTALL_PATH/.env | sed "s/^DOCKER_TAG=\(.*\)/\1/")
    sudo docker rmi -f $DOCKER_IMAGE:"$TAG"
    sudo rm -rf "$PLUGIN_INSTALL_PATH"
    sudo rm /usr/local/bin/cast
    whiptail --title "Uninstall finished" --msgbox "You have uninstalled $APP_NAME." 8 78
  fi
}

# Displays usage info
function usage() {
cat << EOF
Usage: $(basename "$0") [-i] [-u] [-r]

$APP_NAME Helper Script

Options:
-i    Install $APP_NAME
-r    Remove $APP_NAME
-h    Display help

About $APP_NAME)
- $DESCRIPTION
- Source code: $SOURCE_CODE
- Documentation: $DOCUMENTATION
EOF
}

# Process command line options
while getopts :irh opt; do
  case ${opt} in
    i ) install ;;
    r ) removeAll ;;
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
