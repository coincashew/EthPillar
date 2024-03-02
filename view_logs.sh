# Author: coincashew.eth | coincashew.com
# License: GNU GPL
# Source: https://github.com/coincashew
#
# Made for home and solo stakers 🏠🥩

#!/bin/bash

# Install btop process monitoring
if  ! command -v btop &> /dev/null; then
    sudo apt-get install btop -y
fi

# Kill prior session
tmux kill-session -t logs

# Create session called logs
tmux new-session -d -s logs

# Split window horizontally
tmux split-window -h -t logs

# Split window vertically
tmux split-window -v -t logs:0.0

# Split 2nd window vertically
tmux split-window -h -t logs:0.1

# Spread out panes evenly
tmux select-layout -t logs tiled

# Run commands in each pane
tmux send-keys -t logs:0.0 'journalctl -fu consensus | ccze' Enter
tmux send-keys -t logs:0.1 'btop' Enter
tmux send-keys -t logs:0.2 'journalctl -fu execution | ccze ' Enter
tmux send-keys -t logs:0.3 'journalctl -fu validator | ccze' Enter

# Attach to the tmux session
tmux attach-session -t logs
