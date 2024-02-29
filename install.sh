# Author: coincashew.eth | coincashew.com
# License: GNU GPL
# Source: https://github.com/coincashew/ethpillar
#
# Made for home and solo stakers 🏠🥩

# 🫶 Make improvements and suggestions on GitHub:
#    * https://github.com/coincashew/ethpillar
# 🙌 Ask questions on Discord:
#    * https://discord.gg/w8Bx8W2HPW

#!/bin/bash
set -u

# enable  command completion
set -o history -o histexpand

abort() {
  printf "%s\n" "$1"
  exit 1
}

getc() {
  local save_state
  save_state=$(/bin/stty -g)
  /bin/stty raw -echo
  IFS= read -r -n 1 -d '' "$@"
  /bin/stty "$save_state"
}

exit_on_error() {
    exit_code=$1
    last_command=${@:2}
    if [ $exit_code -ne 0 ]; then
        >&2 echo "\"${last_command}\" command failed with exit code ${exit_code}."
        exit $exit_code
    fi
}

wait_for_user() {
  local c
  echo
  echo "Press RETURN to continue or any other key to abort"
  getc c
  # we test for \r and \n because some stuff does \r instead
  if ! [[ "$c" == $'\r' || "$c" == $'\n' ]]; then
    exit 1
  fi
}

shell_join() {
  local arg
  printf "%s" "$1"
  shift
  for arg in "$@"; do
    printf " "
    printf "%s" "${arg// /\ }"
  done
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

ohai() {
  printf "${tty_blue}==>${tty_bold} %s${tty_reset}\n" "$(shell_join "$@")"
}

linux_install_pre() {
    sudo apt-get update
    sudo apt-get install --no-install-recommends --no-install-suggests -y curl git ccze
    exit_on_error $?
}

linux_install_client-installer() {
    ohai "Cloning ethpillar into ~/git/ethpillar"
    mkdir -p ~/git/ethpillar
    git clone https://github.com/coincashew/ethpillar.git ~/git/ethpillar/ 2> /dev/null || (cd ~/git/ethpillar ; git fetch origin main ; git checkout main ; git pull --ff-only ; git reset --hard ; git clean -xdf)
    chmod +x ~/git/ethpillar/*.sh
    ohai "Installing ethpillar"
    sudo ln -s ~/git/ethpillar/ethpillar.sh /usr/local/bin/ethpillar
    exit_on_error $?
}

# Do install.
OS="$(uname)"
if [[ "$OS" == "Linux" ]]; then
    echo """
███████╗████████╗██╗  ██╗██████╗ ██╗██╗     ██╗      █████╗ ██████╗ 
██╔════╝╚══██╔══╝██║  ██║██╔══██╗██║██║     ██║     ██╔══██╗██╔══██╗
█████╗     ██║   ███████║██████╔╝██║██║     ██║     ███████║██████╔╝
██╔══╝     ██║   ██╔══██║██╔═══╝ ██║██║     ██║     ██╔══██║██╔══██╗
███████╗   ██║   ██║  ██║██║     ██║███████╗███████╗██║  ██║██║  ██║
╚══════╝   ╚═╝   ╚═╝  ╚═╝╚═╝     ╚═╝╚══════╝╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝
                                                          
                                   - Menu for your node
                                   - coincashew.com
    """
    ohai "This script will install a menu called 'ethpillar' for your node:"
    echo "curl"
    echo "git"
    echo "ccze"
    echo "ethpillar"

    wait_for_user
    linux_install_pre
    linux_install_client-installer

    echo ""
    echo ""
    echo "######################################################################"
    echo "##                                                                  ##"
    echo "##           INSTALL COMPLETE - To run, type "ethpillar"            ##"
    echo "##                                                                  ##"
    echo "######################################################################"
    echo ""
    echo ""
fi