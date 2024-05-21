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

# Check if the current user belongs to the systemd-journal group
current_user=$(whoami)
group_members=$(getent group systemd-journal | cut -d: -f2-)

if ! echo "$current_user" | grep -qw "$current_user" <<<"$group_members"; then
  # Add the user to the systemd-journal group if they're not already a member
  sudo usermod -aG systemd-journal $current_user
  echo "To view logs, $current_user has been added to systemd-journal group."
  echo "Open a new terminal, then check logs again."
  sleep 5
  exit 0
fi

# Bool for validator
hasValidator=false

# Check for presence of validator
if systemctl is-active --quiet validator; then
   hasValidator=true
fi

# Enable truecolor logs for btop
if [[ ! -f ~/.tmux.conf ]]; then
    cat << EOF > ~/.tmux.conf
set-option -g terminal-overrides ",*:Tc"
EOF
fi

# Kill prior session
tmux kill-session -t logs

# Create panes for validator node or non-staking node
if [ $hasValidator = false ]; then
   tmux new-session -d -s logs \; \
        send-keys 'journalctl -fu consensus | ccze' C-m \; \
        split-window -v \; \
        split-window -h \; \
        send-keys 'btop --utf-force' C-m \; \
        select-pane -t 1 \; \
        send-keys 'journalctl -fu execution | ccze' C-m \;
else
   tmux new-session -d -s logs \; \
        send-keys 'journalctl -fu consensus | ccze' C-m \; \
        split-window -h \; \
        send-keys 'btop --utf-force' C-m \; \
        split-window -v \; \
        send-keys 'journalctl -fu validator | ccze' C-m \; \
        select-pane -t 0 \; \
        split-window -v \; \
        send-keys 'journalctl -fu execution | ccze' C-m \;
fi

# Attach to the tmux session
tmux attach-session -t logs
