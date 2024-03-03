# Author: coincashew.eth | coincashew.com
# License: GNU GPL
# Source: https://github.com/coincashew/ethpillar
#
# Made for home and solo stakers 🏠🥩

#!/bin/bash

# Install btop process monitoring
if ! command -v btop &> /dev/null; then
   sudo apt-get btop -y
fi

# Bool for validator
hasValidator=false

# Check for presense of validator
if [ -f  /etc/systemd/system/validator.service ]; then
   hasValidator=true
fi

# Kill prior session
tmux kill-session -t logs

# Create panes for validator node or non-staking node
if [[ $hasValidator = false ]]; then
   tmux new-session -d -s logs \; \
        send-keys 'journalctl -fu consensus | ccze' C-m \; \
        split-window -v \; \
        split-window -h \; \
        send-keys 'btop' C-m \; \
        select-pane -t 1 \; \
        send-keys 'journalctl -fu execution | ccze' C-m \;
else
   tmux new-session -d -s logs \; \
        send-keys 'journalctl -fu consensus | ccze' C-m \; \
        split-window -h \; \
        send-keys 'btop' C-m \; \
        split-window -v \; \
        send-keys 'journalctl -fu validator | ccze' C-m \; \
        select-pane -t 0 \; \
        split-window -v \; \
        send-keys 'journalctl -fu execution | ccze' C-m \;
fi

# Attach to the tmux session
tmux attach-session -t logs
