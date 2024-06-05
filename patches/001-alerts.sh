#!/bin/bash

# Author: coincashew.eth | coincashew.com
# License: GNU GPL
# Source: https://github.com/coincashew/ethpillar
#
# Made for home and solo stakers 🏠🥩

######################################################################
# Patch 1 : Adding Grafana Alerts
# If you installed ethpillar before v1.7.0, run this to enable alerts
######################################################################

# Step 1: Backup and then update prometheus.yml file
sudo mv /etc/prometheus/prometheus.yml /etc/prometheus/prometheus.yml.backup
sudo bash -c "cat << 'EOF' > /etc/prometheus/prometheus.yml
rule_files:
  - alert.rules.yml

global:
  scrape_interval:     15s # By default, scrape targets every 15 seconds.

# A scrape configuration containing exactly one endpoint to scrape:
# Here it's Prometheus itself.
scrape_configs:
   - job_name: 'ethereum-metrics-exporter'
     static_configs:
       - targets: ['localhost:9099']
   - job_name: 'node_exporter'
     static_configs:
       - targets: ['localhost:9100']
EOF"

# Step 2: Install default alert rules and restart prometheus
sudo cp ~/git/ethpillar/alert.rules.yml /etc/prometheus
sudo systemctl restart prometheus

# Step 3: Show instructions
whiptail --title "Configure Alerting with Grafana" --msgbox "Grafana enables users to create custom alert systems that notify them via multiple channels, including email, messaging apps like Telegram and Discord.
\nWith the default install, basic alerts for CPU/DISK/RAM are configured.
\nTo receive these alerts:
\n- Navigate to Grafana in your web browser
\n- Click "Alerting" (the alert bell icon) on the left-hand side menu
\n- Create contact points and notification policies" 20 78
