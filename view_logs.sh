#!/bin/bash

# Author: coincashew.eth | coincashew.com
# License: GNU GPL
# Source: https://github.com/coincashew/ethpillar
#
# Made for home and solo stakers 🏠🥩

# Install btop process monitoring
if ! command -v btop &> /dev/null; then
   sudo apt-get install btop -y
fi

# Install tmux
if ! command -v tmux &> /dev/null; then
   sudo apt-get install tmux -y
fi

# Check if the current user belongs to the systemd-journal group
current_user=$(whoami)
group_members=$(getent group systemd-journal | cut -d: -f2-)

if ! echo "$group_members" | grep -qE -o -- "$current_user"; then
  clear
  # Add the user to the systemd-journal group if they're not already a member
  sudo usermod -aG systemd-journal $current_user
  echo -e "\033[1m########## New Terminal Session Required ############"
  echo "To view logs, $current_user has been added to systemd-journal group."
  echo "Open a new terminal, run 'ethpillar', then check logs again."
  echo "Press ENTER to continue"
  read
  exit 0
fi

# Enable truecolor logs for btop
if [[ ! -f ~/.tmux.conf ]]; then
    cat << EOF > ~/.tmux.conf
set-option -g terminal-overrides ",*:Tc"
EOF
fi

# Kill prior session
tmux kill-session -t logs

# Get terminal width
cols=$(tput cols)

# Portrait view for narrow terminals <= 80 col
if [[ $cols -lt 81 ]]; then
   if [[ -f /etc/systemd/system/execution.service ]] && [[ -f /etc/systemd/system/consensus.service ]] && [[ -f /etc/systemd/system/validator.service ]]; then
      # Solo Staking Node
      tmux new-session -d -s logs \; \
           send-keys 'journalctl -fu consensus --no-hostname | ccze -A' C-m \; \
           split-window -v \; \
           send-keys 'journalctl -fu validator --no-hostname | ccze -A' C-m \; \
           select-pane -t 0 \; \
           split-window -v \; \
           send-keys 'journalctl -fu execution --no-hostname | ccze -A' C-m \; \
           select-layout even-vertical \;
   elif [[ -f /etc/systemd/system/execution.service ]] && [[ -f /etc/systemd/system/consensus.service ]]; then
      # Full Node Only
      tmux new-session -d -s logs \; \
           send-keys 'journalctl -fu consensus --no-hostname | ccze -A' C-m \; \
           split-window -h \; \
           select-pane -t 1 \; \
           send-keys 'journalctl -fu execution --no-hostname | ccze -A' C-m \; \
           select-layout even-vertical \;
   elif [[ -f /etc/systemd/system/validator.service ]]; then
      # Validator Client Only
      tmux new-session -d -s logs \; \
           send-keys 'journalctl -fu validator --no-hostname | ccze -A' C-m \; \
           split-window -h \; \
           select-pane -t 1 \; \
           send-keys 'btop --utf-force' C-m \; \
           select-layout even-vertical \;
   fi
else
   # Create full screen panes for validator node or non-staking node
   if [[ -f /etc/systemd/system/execution.service ]] && [[ -f /etc/systemd/system/consensus.service ]] && [[ -f /etc/systemd/system/validator.service ]]; then
      # Solo Staking Node
      tmux new-session -d -s logs \; \
           send-keys 'journalctl -fu consensus --no-hostname | ccze -A' C-m \; \
           split-window -h \; \
           send-keys 'btop --utf-force' C-m \; \
           split-window -v \; \
           send-keys 'journalctl -fu validator --no-hostname | ccze -A' C-m \; \
           select-pane -t 0 \; \
           split-window -v \; \
           send-keys 'journalctl -fu execution --no-hostname | ccze -A' C-m \;
   elif [[ -f /etc/systemd/system/execution.service ]] && [[ -f /etc/systemd/system/consensus.service ]]; then
      # Full Node Only
      tmux new-session -d -s logs \; \
           send-keys 'journalctl -fu consensus --no-hostname | ccze -A' C-m \; \
           split-window -v \; \
           split-window -h \; \
           send-keys 'btop --utf-force' C-m \; \
           select-pane -t 1 \; \
           send-keys 'journalctl -fu execution --no-hostname | ccze -A' C-m \;
   elif [[ -f /etc/systemd/system/validator.service ]]; then
      # Validator Client Only
      tmux new-session -d -s logs \; \
           send-keys 'journalctl -fu validator --no-hostname | ccze -A' C-m \; \
           split-window -h \; \
           select-pane -t 1 \; \
           send-keys 'btop --utf-force' C-m \; \
           select-layout even-vertical \;
   fi
fi

# Attach to the tmux session
tmux attach-session -t logs