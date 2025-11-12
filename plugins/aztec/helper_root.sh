#!/bin/bash

# Author: coincashew.eth | coincashew.com
# License: GNU GPL
# Source: https://github.com/coincashew/ethpillar
# Description: Aztec plugin inspired by https://github.com/cryptocattelugu/Aztec-Network
#
# Made for home and solo stakers 🏠🥩

# Colors
g="\033[32m" # Green
r="\033[31m" # Red
nc="\033[0m" # No-color
bold="\033[1m"

function info {
  echo -e "${g}INFO: $1${nc}"
}

function error {
  echo -e "${r}${bold}ERROR: $1${nc}"
  exit 1
}

PLUGIN_INSTALL_PATH=/opt/ethpillar/aztec
source "$PLUGIN_INSTALL_PATH"/.env

function installAztecCli() {
  info "🔧 Installing Aztec CLI, please wait ..."
  yes | bash -i <(curl -s https://install.aztec.network)
  # shellcheck disable=SC2016
  echo 'export PATH="$HOME/.aztec/bin:$PATH"' >> ~/.bashrc
  export PATH="$HOME/.aztec/bin:$PATH"
  # shellcheck disable=SC1090
  source ~/.bashrc >/dev/null 2>&1
  aztec-up >/dev/null 2>&1
}

# Runs as root. Workaround for aztec issue: Due to how we containerize our applications, we require your working directory to be somewhere within /root.
info "🚦 Enabling and starting Docker service..."
systemctl enable --now docker || error "Failed to enable/start Docker service"

# Generate new keys
rm -f /root/.aztec/keystore/key1.json
cd /root || true

if ! command -v aztec &>/dev/null; then
  installAztecCli
  if ! command -v aztec &>/dev/null; then
    error "Aztec CLI installation failed. Try again."
  fi
  info "✅ Aztec CLI installed."
fi

aztec validator-keys new --fee-recipient 0x0000000000000000000000000000000000000000000000000000000000000000 && echo " "
KEYSTORE_FILE=~/.aztec/keystore/key1.json
KEYSTORE_FILE_TARGET=/opt/ethpillar/aztec/keystore/key1.json

echo "🔧 Update keystore location and permissions"
mkdir -p /opt/ethpillar/aztec/keystore
mv "$KEYSTORE_FILE" "$KEYSTORE_FILE_TARGET" || echo "Unable to move key1.json"
chmod 644 "$KEYSTORE_FILE_TARGET" || echo "Unable update keystore permissions"
info "⚠️  Backup this keystore file: /opt/ethpillar/aztec/keystore/key1.json"
info "🔐  Contains private keys:"
echo "======START OF FILE====="
cat /opt/ethpillar/aztec/keystore/key1.json
echo "======END OF FILE======="

KEYSTORE_FILE_TARGET=/opt/ethpillar/aztec/keystore/key1.json
NEW_ETH_PRIVATE_KEY=$(jq -r '.validators[0].attester.eth' "$KEYSTORE_FILE_TARGET")
NEW_BLS_PRIVATE_KEY=$(jq -r '.validators[0].attester.bls' "$KEYSTORE_FILE_TARGET")
NEW_PUBLIC_ADDRESS=$(cast wallet address "$NEW_ETH_PRIVATE_KEY")

info "🔧 Update ETH address values in .env..."
# shellcheck disable=SC2015
[[ -n $NEW_ETH_PRIVATE_KEY ]] && sed -i "s/^VALIDATOR_PRIVATE_KEYS.*$/VALIDATOR_PRIVATE_KEYS=${NEW_ETH_PRIVATE_KEY}/" $PLUGIN_INSTALL_PATH/.env || error "Unable to set VALIDATOR_PRIVATE_KEYS"
# shellcheck disable=SC2015
[[ -n $NEW_PUBLIC_ADDRESS ]] && sed -i "s/^VALIDATOR_ADDRESS.*$/VALIDATOR_ADDRESS=${NEW_PUBLIC_ADDRESS}/" $PLUGIN_INSTALL_PATH/.env || error "Unable to set VALIDATOR_ADDRESS"
# shellcheck disable=SC2015
# COINBASE is block reward recipient. On mainnet, use a unique hardware wallet secured ETH address.
[[ -n $NEW_PUBLIC_ADDRESS ]] && sed -i "s/^COINBASE.*$/COINBASE=${NEW_PUBLIC_ADDRESS}/" $PLUGIN_INSTALL_PATH/.env || error "Unable to set COINBASE"

if [[ $__SELECT == "EXISTING" ]]; then
  echo "⚠️ Please provide your old validator info."
  # shellcheck disable=SC2162
  read -sp "   Enter your OLD Sequencer Private Key (will not be shown): " PRIVATE_KEY
else
  echo "⚠️ You need to send 200k STAKES to your new address:"
  echo "   $NEW_PUBLIC_ADDRESS"
  # shellcheck disable=SC2162
  read -p "   After the funding transaction is confirmed, press [Enter] to continue.." && echo " "
  PRIVATE_KEY="$NEW_ETH_PRIVATE_KEY"
fi

echo "⚠️ You need to send 0.2 to 0.5 Sepolia ETH to your new address:"
echo "   $NEW_PUBLIC_ADDRESS"
# shellcheck disable=SC2162
read -p "   After the funding transaction is confirmed, press [Enter] to continue.." && echo " "

ROLLUP_ADDRESS="0xebd99ff0ff6677205509ae73f93d0ca52ac85d67"
STAKE_CONTRACT="0x139d2a7a0881e16332d7D1F8DB383A4507E1Ea7A"
STAKE_AMOUNT="200000ether"

echo "Approving STAKE spending..."
cast send "$STAKE_CONTRACT" "approve(address,uint256)" "$ROLLUP_ADDRESS" "$STAKE_AMOUNT" --private-key "$PRIVATE_KEY" --rpc-url "$ETHEREUM_HOSTS"

aztec add-l1-validator \
  --l1-rpc-urls "$ETHEREUM_HOSTS" \
  --network testnet \
  --private-key "$PRIVATE_KEY" \
  --attester "$NEW_PUBLIC_ADDRESS" \
  --withdrawer "$NEW_PUBLIC_ADDRESS" \
  --bls-secret-key "$NEW_BLS_PRIVATE_KEY" \
  --rollup "$ROLLUP_ADDRESS"

# shellcheck disable=SC2181
if [ $? -ne 0 ]; then
  error "aztec add-l1-validator failed. Unable to register validator $NEW_PUBLIC_ADDRESS. Try again later."
fi

exit 0
