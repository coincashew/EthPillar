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
  bash -c "$SOURCE_DIR/../../helpers/install_docker.sh"
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
  sudo touch "$PLUGIN_INSTALL_PATH/.cast_installed_by_plugin" || true
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

# Allow EL RPC access (port 8545) to docker
exposeETHRPC(){
    _exposed='0.0.0.0'
    _service='execution'
    _file="/etc/systemd/system/${_service}.service"
    test -f /etc/systemd/system/execution.service || return 0
    EL=$(grep Description= /etc/systemd/system/execution.service | awk -F'=' '{print $2}' | awk '{print $1}')
    case "${EL}" in
        Nethermind ) _flag='JsonRpc.Host';;
        Besu       ) _flag='rpc-http-host';;
        Erigon     ) _flag='http.addr';;
        Geth       ) _flag='http.addr';;
        Reth       ) _flag='http.addr';;
        * ) echo "Execution client not detected"; return 0;;
    esac
    if ! grep -q "${_flag}=${_exposed}" $_file; then
      info "🔧 Updating execution client RPC access..."
      cp ${_file} "$HOME"/_edit
      # Remove old value
      sed -r "s/.*--${_flag}[= ]+[0-9.]+.*/&\n/g; s/--${_flag}[= ]+[0-9.]+//g" "$HOME"/_edit > "$HOME"/_result
      # Add new value to end of ExecStart line
      sed -i -e "s/^ExecStart.*$/& --${_flag}=${_exposed}/" "$HOME"/_result
      # Install new config
      sudo mv "$HOME"/_result ${_file}
      sudo chown execution:execution ${_file}
      # Reload and restart
      sudo systemctl daemon-reload && sudo service ${_service} restart
    else
      info "✅ Execution client RPC access already accessible..."
    fi
}

# Installation function
function install_plugin(){
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
  while true; do
      ETH_RPC=$(whiptail --title "Ethereum RPC URL(s) (ETHEREUM_HOSTS)" --inputbox "🔗 Enter one or more URLs, comma-separated (e.g. https://sepolia.rpc.url,http://192.168.1.123:8545):" 9 78 --ok-button "Submit" 3>&1 1>&2 2>&3)
      if [ -z "$ETH_RPC" ]; then exit; fi #pressed cancel
      # sanitize: strip spaces
      ETH_RPC=$(echo "$ETH_RPC" | tr -d '[:space:]')
      if [[ "$ETH_RPC" =~ ^https?:// ]]; then
          break
      else
          whiptail --title "Error" --msgbox "ETHEREUM_HOSTS must start with http(s)://" 8 78
      fi
  done
  while true; do
      BEACON_RPC=$(whiptail --title "Beacon RPC URL(s) (L1_CONSENSUS_HOST_URLS)" --inputbox "🔗 Enter one or more URLs, comma-separated (e.g. https://beacon.rpc.url,http://192.168.1.123:5052):" 9 78 --ok-button "Submit" 3>&1 1>&2 2>&3)
      if [ -z "$BEACON_RPC" ]; then exit; fi #pressed cancel
      # sanitize: strip spaces
      BEACON_RPC=$(echo "$BEACON_RPC" | tr -d '[:space:]')
      if [[ "$BEACON_RPC" =~ ^https?:// ]]; then
        break
      else
          whiptail --title "Error" --msgbox "L1_CONSENSUS_HOST_URLS must start with http(s)://" 8 78
      fi
  done
else
  # Install EL/CL
  if [[ ! -f /etc/systemd/system/execution.service ]] && [[ ! -f /etc/systemd/system/consensus.service ]]; then
    sudo bash -c "$SOURCE_DIR/../../install-node.sh deploy-nimbus-nethermind.py true"
  fi
fi

# Install packages
sudo apt-get update
sudo apt-get upgrade -y

info "🔧 Setup installation directory"
sudo mkdir -p $PLUGIN_INSTALL_PATH || error "Unable to setup installation directory"
sudo chmod -R 755 "$PLUGIN_INSTALL_PATH" || error "Unable to chmod installation directory permissions"

info "🔧 Install env file and compose file..."
sudo cp "$PLUGIN_SOURCE_PATH"/.env.example $PLUGIN_INSTALL_PATH/.env || error "Unable to create .env"
sudo cp "$PLUGIN_SOURCE_PATH"/docker-compose.yml.example $PLUGIN_INSTALL_PATH/docker-compose.yml || error "Unable to create docker-compose.yml"

TAG=$(grep "^DOCKER_TAG" $PLUGIN_INSTALL_PATH/.env | sed "s/^DOCKER_TAG=\(.*\)/\1/")
#TAG=$(docker inspect aztec-sequencer |  jq -r '.[0].Config.Image')
echo "$TAG" | sudo tee $PLUGIN_INSTALL_PATH/current_version
info "✏️  Storing current version... $TAG"

if ! command -v cast &> /dev/null; then
   info "🔧 Installing foundry for cast..."
   install_foundry
fi

info "🔐 Generating new Ethereum private key for validator with cast..."
# shellcheck disable=SC2033
sudo install -d -m 755 "$PLUGIN_INSTALL_PATH" || true
tmp_seed=$(mktemp)
umask 077
cast wallet new-mnemonic > "$tmp_seed" || error "Unable to generate new cast wallet"
ADDRESS=$(grep "Address: " "$tmp_seed" | awk '{print $2}')
PRIVATE_KEY=$(grep "Private key: " "$tmp_seed" | awk '{print $3}')
# shellcheck disable=SC2033
sudo install -m 600 "$tmp_seed" "$PLUGIN_INSTALL_PATH/aztec_seed_phrase"
rm -f "$tmp_seed"

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

if [[ $RPC_CONFIG == "LOCAL" ]]; then
  info "🔧 Checking ETH L1/Execution client RPC access"
  exposeETHRPC
fi

# sanitize with grep
P2P_IP=$(grep -m1 -oE '^[0-9]{1,3}(\.[0-9]{1,3}){3}$' <<< "$(
  curl -fsS --max-time 5 https://ipv4.icanhazip.com \
  || curl -fsS --max-time 5 https://api.ipify.org \
  || curl -fsS --max-time 5 http://ip1.dynupdate.no-ip.com
)")

# shellcheck disable=SC2015
[[ -n $P2P_IP ]] && sudo sed -i "s/^P2P_IP.*$/P2P_IP=${P2P_IP}/" $PLUGIN_INSTALL_PATH/.env || error "Unable to get and set P2P_IP"
info "🔧 Configuring and updating P2P_IP to $P2P_IP"

#info "📁 Downloading aztec snapshot, minimizes syncing issues and faster sync..."
#download_snapshot
#[[ -f /opt/ethpillar/aztec/data/archiver/data.mdb ]] && info "✅ Verfied snapshot extract exists" || error "Unable to verify snapshot extract"

info "🔧 Configuring UFW firewall"
sudo ufw allow 40400 comment 'Allow aztec node p2p port' || error "Unable to configure ufw"
if [[ $RPC_CONFIG == "LOCAL" ]]; then
  info "🔧 Configuring UFW firewall to allow access from host.docker.internal"
  docker_bridge_subnet=$(docker network inspect bridge --format '{{(index .IPAM.Config 0).Subnet}}' 2>/dev/null || echo '172.16.0.0/12')
  if [[ -z "$docker_bridge_subnet" || "$docker_bridge_subnet" == "<no value>" ]]; then
    docker_bridge_subnet='172.16.0.0/12'
  fi  
  sudo ufw allow from "$docker_bridge_subnet" to any port 8545 comment 'Allow host.docker.internal to ETH RPC'
  sudo ufw allow from "$docker_bridge_subnet" to any port 5052 comment 'Allow host.docker.internal to BEACON RPC'
fi

info "🔧 Updating ownership of $PLUGIN_INSTALL_PATH to current user: $USER"
sudo chown -R "$USER":"$USER" "$PLUGIN_INSTALL_PATH"

info "🎉  INSTALL COMPLETE :: To run, type \"ethpillar\""

MSG_COMPLETE="✅ Done! $APP_NAME is now installed.
\nNext Steps:
\n1. Review .env configuration: Update values if desired
\n2. Start aztec-sequencer: Ensure Sepolia RPC Node is fully synced first!
\n3. Backup aztec validator key: Use the 🔐 menu option

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
    sudo docker rm -f $APP_NAME 2>/dev/null || true
    TAG=$(grep "DOCKER_TAG" $PLUGIN_INSTALL_PATH/.env | sed "s/^DOCKER_TAG=\(.*\)/\1/")
    sudo docker rmi -f $DOCKER_IMAGE:"$TAG"
    if [[ -f "$PLUGIN_INSTALL_PATH/.cast_installed_by_plugin" && -f /usr/local/bin/cast ]]; then
      sudo rm /usr/local/bin/cast
    fi
    sudo rm -rf "$PLUGIN_INSTALL_PATH"
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

# Install docker, prompt to relog if not root user
if ! command -v docker &> /dev/null; then
  info "🔧 Installing docker..."
  install_docker
  # Except root, user account requires re-log for new docker permissions
  if [ "$(id -u)" -ne 0 ]; then
      whiptail --title "Docker Install Complete" --msgbox "Log off and log in again for new docker permissions and then try again." 8 78
      exit 0
  fi
fi

# Process command line options
while getopts :irh opt; do
  case ${opt} in
    i ) install_plugin ;;
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
