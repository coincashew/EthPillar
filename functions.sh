# Author: coincashew.eth | coincashew.com
# License: GNU GPL
# Source: https://github.com/coincashew/ethpillar
#
# Made for home and solo stakers 🏠🥩

#!/bin/bash
set -u

# enable command completion
set -o history -o histexpand

# VARIABLES
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
