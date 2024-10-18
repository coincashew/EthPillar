#!/bin/bash

# Author: coincashew.eth | coincashew.com
# License: GNU GPL
# https: //github.com/coincashew/ethpillar
#
# Acknowledgments
# validator-install is branched from validator-install written by Accidental-green: https: //github.com/accidental-green/validator-install

set -u

# enable  command completion
set -o history -o histexpand

python="python3"

skip_prompt=""
if [[ $# -eq 1 ]]; then
   skip_prompt="$1"
fi

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
    last_command="${@:2}"
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

requirements_check() {
  # Check CPU architecture
  if ! [[ $(lscpu | grep -oE 'x86') || $(lscpu | grep -oE 'aarch64') ]]; then
    echo "This machine's CPU architecture is not yet unsuppported."
    echo "Recommend using Intel-AMD x86 or arm64 systems for best experience."
    exit 1
  fi

  # Check operating system
  if ! [[ "$(uname)" == "Linux" ]]; then
    echo "This operating system is not yet unsuppported."
    echo "Recommend installing Ubuntu Desktop 24.04+ LTS or Ubuntu Server 24.04+ LTS for best experience."
    exit 1
  fi
}

linux_install_pre() {
    sudo apt-get update
    sudo apt-get install --no-install-recommends --no-install-suggests -y curl git ccze jq tmux bc
    exit_on_error $?
}

linux_install_python() {
    which $python
    if [[ $? != 0 ]] ; then
        ohai "Installing python"
        sudo apt-get install --no-install-recommends --no-install-suggests -y $python
    else
        ohai "Updating python"
        sudo apt-get install --only-upgrade -y $python
    fi
    exit_on_error $?
    ohai "Installing python tools"
    sudo apt-get install --no-install-recommends --no-install-suggests -y $python-pip $python-tk $python-venv
    ohai "Creating venv"
    $python -m venv ~/.local --system-site-packages
    ohai "Installing pip requirements"
    ~/.local/bin/pip install requests console-menu python-dotenv
    exit_on_error $?
}

linux_update_pip() {
    PYTHONPATH=$(which $python)
    ohai "You are using python@ $PYTHONPATH$"
    ohai "Installing python tools"
    $python -m pip install --upgrade pip
}

linux_install_validator-install() {
    ohai "Cloning ethpillar into ~/git/ethpillar"
    mkdir -p ~/git/ethpillar
    git clone https://github.com/coincashew/ethpillar.git ~/git/ethpillar 2> /dev/null || (cd ~/git/ethpillar ; git fetch origin main ; git checkout main ; git pull)
    ohai "Installing validator-install"
    $python ~/git/ethpillar/deploy-teku-besu.py
    ohai "Allowing user to view journalctl logs"
    sudo usermod -a -G systemd-journal $USER
    ohai "Install complete!"
    exit_on_error $?
}

# Check OS and CPU requirements
requirements_check

# Do install.
OS="$(uname)"
if [[ "$OS" == "Linux" ]]; then
    echo """
██╗   ██╗ █████╗ ██╗     ██╗██████╗  █████╗ ████████╗ ██████╗ ██████╗ 
██║   ██║██╔══██╗██║     ██║██╔══██╗██╔══██╗╚══██╔══╝██╔═══██╗██╔══██╗
██║   ██║███████║██║     ██║██║  ██║███████║   ██║   ██║   ██║██████╔╝
╚██╗ ██╔╝██╔══██║██║     ██║██║  ██║██╔══██║   ██║   ██║   ██║██╔══██╗
 ╚████╔╝ ██║  ██║███████╗██║██████╔╝██║  ██║   ██║   ╚██████╔╝██║  ██║
  ╚═══╝  ╚═╝  ╚═╝╚══════╝╚═╝╚═════╝ ╚═╝  ╚═╝   ╚═╝    ╚═════╝ ╚═╝  ╚═╝
                                                                      
██╗███╗   ██╗███████╗████████╗ █████╗ ██╗     ██╗                     
██║████╗  ██║██╔════╝╚══██╔══╝██╔══██╗██║     ██║                     
██║██╔██╗ ██║███████╗   ██║   ███████║██║     ██║                     
██║██║╚██╗██║╚════██║   ██║   ██╔══██║██║     ██║                     
██║██║ ╚████║███████║   ██║   ██║  ██║███████╗███████╗                
╚═╝╚═╝  ╚═══╝╚══════╝   ╚═╝   ╚═╝  ╚═╝╚══════╝╚══════╝                
                                                                                                                                         
                                   - Deploy a node, in a flash
                                   - coincashew.com
    """
    ohai "This script will install a Teku-Besu Ethereum node:"
    echo "git jq curl ccze tmux bc"
    echo "python3-tk python3-pip python3-venv"
    echo "validator-install"

    if [[ -z $skip_prompt ]]; then wait_for_user; fi
    linux_install_pre
    linux_install_python
    linux_update_pip
    linux_install_validator-install
    echo ""
    echo ""
    echo "######################################################################"
    echo "##                                                                  ##"
    echo "##      VALIDATOR INSTALL COMPLETE   To manage, use \"ethpillar\"     ##"
    echo "##                                                                  ##"
    echo "######################################################################"
    echo ""
    echo ""
fi