# Author: coincashew.eth | coincashew.com
# License: GNU GPL
# Source: https://github.com/coincashew/ethpillar
# Description: EthPillar is a one-liner setup tool and node management TUI

# Made for home and solo stakers 🏠🥩

#!/bin/bash
set -u

# enable command completion
set -o history -o histexpand

# VARIABLES
BASE_DIR=$HOME/git/ethpillar
ip_current=$(ip route get 1 | awk '{print $7}')
interface_current=$(ip route get 1 | awk '{print $5}')
network_current="$(ip route | grep $interface_current | grep -v default | awk '{print $1}')"

exit_on_error() {
    exit_code=$1
    last_command=${@:2}
    if [ $exit_code -ne 0 ]; then
        >&2 echo "\"${last_command}\" command failed with exit code ${exit_code}."
        exit $exit_code
    fi
}

# string formatters
if [[ -t 1 ]]; then
  tty_escape() { printf "\033[%sm" "$1"; }
else
  tty_escape() { :; }
fi
tty_mkbold() { tty_escape "1;$1"; }
tty_underline="$(tty_escape "4;39")"
tty_blue="$(tty_mkbold 34)"
tty_red="$(tty_mkbold 31)"
tty_bold="$(tty_mkbold 39)"
tty_reset="$(tty_escape 0)"

shell_join() {
  local arg
  printf "%s" "$1"
  shift
  for arg in "$@"; do
    printf " "
    printf "%s" "${arg// /\ }"
  done
}

ohai() {
  printf "${tty_blue}==>${tty_bold} %s${tty_reset}\n" "$(shell_join "$@")"
}

network_down() {
    sudo ip link set $interface_current down
}

network_up() {
    sudo ip link set $interface_current up
}

network_isConnected() {
  #check to see if the device is connected to the network
  sudo ip route get 1 2>/dev/null
}

print_node_info() {
  current_time=$(date)
  os_descrip=$(grep PRETTY_NAME /etc/os-release | sed 's/PRETTY_NAME=//g')
  os_version=$(grep VERSION_ID /etc/os-release | sed 's/VERSION_ID=//g')
  kernel_version=$(uname -r)
  system_uptime=$(uptime | sed 's/.*up \([^,]*\), .*/\1/')
  consensus_status=$(if systemctl is-active --quiet execution ; then printf "Online" ; else printf "Offline" ; fi)
  execution_status=$(if systemctl is-active --quiet execution ; then printf "Online" ; else printf "Offline" ; fi)
  validator_status=$($(test -f /etc/systemd/system/validator.service && if systemctl is-active --quiet validator ; then printf "Online" ; else printf "Offline" ; fi) || printf "Not Installed")
  mevboost_status=$($(test -f /etc/systemd/system/mevboost.service && if systemctl is-active --quiet mevboost ; then printf "Online" ; else printf "Offline" ; fi) || printf "Not Installed")
  ethpillar_commit=$(git -C "${BASE_DIR}" rev-parse HEAD)
  ethpillar_version=$(grep VERSION= $BASE_DIR/ethpillar.sh | sed 's/VERSION=//g')

  info_txt=$(cat <<EOF
Current time     :  $current_time
OS Description   :  $os_descrip
OS Version       :  $os_version
Kernel Version   :  $kernel_version
Uptime           :  $system_uptime
Consensus Status :  $consensus_status
Execution Status :  $execution_status
Validator Status :  $validator_status
Mevboost Status  :  $mevboost_status
EthPillar Version:  $ethpillar_version
EthPillar Commit :  $ethpillar_commit
EOF
)
whiptail --title "General Node Information" --msgbox "$info_txt" 20 78
}

setWhiptailColors(){
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

# Runs a script, name is passed as arg $1
runScript() {
    SCRIPT_PATH="$BASE_DIR/$1"

    if [[ ! -x $SCRIPT_PATH ]]; then
        chmod +x $SCRIPT_PATH
    fi

    if [[ -f $SCRIPT_PATH && -x $SCRIPT_PATH ]]; then
      $SCRIPT_PATH
    else
        echo "Error: $SCRIPT_PATH not run. Check permissions or path."
        exit 1
    fi
}

getNetwork(){
    # Get network name from execution client
    result=$(curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"net_version","params":[],"id":67}' localhost:8545 | jq -r '.result')
    case $result in
    1)
      NETWORK="Mainnet"
      ;;
    17000)
      NETWORK="Holesky"
      ;;
    11155111)
      NETWORK="Sepolia"
      ;;
    *)
      NETWORK="Custom Network"
    esac
}

# Read clients from systemd config files
getClient(){
    EL=$(test -f /etc/systemd/system/execution.service  && grep Description= /etc/systemd/system/execution.service | awk -F'=' '{print $2}' | awk '{print $1}')
    CL=$(test -f /etc/systemd/system/consensus.service  && grep Description= /etc/systemd/system/consensus.service | awk -F'=' '{print $2}' | awk '{print $1}')
    VC=$(test -f /etc/systemd/system/validator.service  && grep Description= /etc/systemd/system/validator.service | awk -F'=' '{print $2}' | awk '{print $1}')
}

# Get list of validator public keys
getPubKeys(){
   case $CL in
      Lighthouse)
        TEMP=$(/usr/local/bin/lighthouse account validator list --network $NETWORK  --datadir /var/lib/lighthouse | grep -Eo '0x[a-fA-F0-9]{96}')
        convertLIST
      ;;
     Lodestar)
        cd /usr/local/bin/lodestar
        LIST=$(sudo -u validator /usr/local/bin/lodestar/lodestar validator list --network $NETWORK  --dataDir /var/lib/lodestar/validators | grep -Eo '0x[a-fA-F0-9]{96}')
        convertLIST
      ;;
     Teku)
        # Command if combined CL+VC
        teku_cmd="ls /var/lib/teku/validator_keys/*.json"
        # Command if standalone VC
        test -f /etc/systemd/system/validator.service && teku_cmd="ls /var/lib/teku_validator/validator_keys/*.json"
        for json in $(sudo -u validator bash -c '$teku_cmd')
        do
          LIST+=(0x$(sudo -u validator bash -c "cat $json | jq -r '.pubkey'"))
        done
      ;;
     Nimbus)
        # Command if combined CL+VC
        nimbus_cmd="ls /var/lib/nimbus/validators | grep -Eo '0x[a-fA-F0-9]{96}'"
        # Command if standalone VC
        test -f /etc/systemd/system/validator.service && nimbus_cmd="ls /var/lib/nimbus_validator/validators | grep -Eo '0x[a-fA-F0-9]{96}'"
        TEMP=$(sudo -u validator bash -c "$nimbus_cmd")
        convertLIST
      ;;
     Prysm)
        TEMP=$(/usr/local/bin/validator accounts list --$NETWORK --wallet-dir=/var/lib/prysm/validators | grep -Eo '0x[a-fA-F0-9]{96}')
        convertLIST
      ;;
     esac
}

convertLIST(){
for key in $TEMP
do
  LIST+=($key)
done
}

# Prints list of pubkeys
showPubkeys(){
   ohai "Total # Validator Keys: ${#LIST[@]}"
   ohai "==================================="
   ohai ${LIST[@]}
}
