#!/bin/bash

# Author: coincashew.eth | coincashew.com
# License: GNU GPL
# Source: https://github.com/coincashew/ethpillar
# Description: Installs ethereum-metrics-exporter, and supporting tools: grafana, prometheus
#
# Made for home and solo stakers 🏠🥩

BASE_DIR="$HOME"/git/ethpillar

# Load functions
source "$BASE_DIR"/functions.sh

# Get machine info
_platform=$(get_platform)
_arch=$(get_arch)

# Variables
GITHUB_URL=https://api.github.com/repos/ethpandaops/ethereum-metrics-exporter/releases/latest
GITHUB_RELEASE_NODES=https://github.com/ethpandaops/ethereum-metrics-exporter/releases
ETHEREUM_METRICS_EXPORTER_OPTIONS=(
  --metrics-port 9099
  --consensus-url=http://localhost:5052
  --execution-url=http://localhost:8545
)
GRAFANA_DIR=/etc/grafana
PROMETHEUS_DIR=/etc/prometheus

# Asks to update
function upgradeBinaries(){
	getLatestVersion
  if whiptail --title "Update ethereum-metrics-exporter, grafana, prometheus, node-exporter" --yesno "Latest Version of ethereum-metrics-exporter is:    $TAG\n\nReminder: Always read the release notes for breaking changes: $GITHUB_RELEASE_NODES\n\nDo you want to update to $TAG?" 10 78; then
  		downloadClient
  		upgradeGrafanaPrometheus
  		promptViewLogs
	fi
}

# Asks to view logs
function promptViewLogs(){
    if whiptail --title "View Logs" --yesno "Would you like to view logs and confirm everything is running properly?" 8 78; then
      sudo bash -c 'journalctl -fu ethereum-metrics-exporter | ccze -A'
    fi
}

# Gets latest tag of ethereum-metrics-exporter
function getLatestVersion(){
  TAG=$(curl -s $GITHUB_URL | jq -r .tag_name )
  # Exit in case of null tag
  [[ -z $TAG ]] || [[ $TAG == "null"  ]] && echo "ERROR: Couldn't find the latest version tag" && exit 1
}

# Downloads latest release of ethereum-metrics-exporter
function downloadClient(){
	BINARIES_URL="$(curl -s "$GITHUB_URL" | jq -r ".assets[] | select(.name) | .browser_download_url" | grep --ignore-case "${_platform}"_"${_arch}".tar.gz$)"
	echo Downloading URL: "$BINARIES_URL"
	cd "$HOME" || true
	# Download
	wget -O ethereum-metrics-exporter.tar.gz "$BINARIES_URL"
	# Untar
	tar -xzvf ethereum-metrics-exporter.tar.gz -C "$HOME"
	# Cleanup
	rm ethereum-metrics-exporter.tar.gz README.md
	# Install binary
	if systemctl is-active --quiet ethereum-metrics-exporter ; then sudo systemctl stop ethereum-metrics-exporter; fi
	sudo mv "$HOME"/ethereum-metrics-exporter-* /usr/local/bin/ethereum-metrics-exporter
	sudo systemctl start ethereum-metrics-exporter
}

# Removes ethereum-metrics-exporter, Grafana and Prometheus
function removeAll() {
	if whiptail --title "Uninstall Monitoring" --defaultno --yesno "Are you sure you want to remove all monitoring tools?\n(grafana/prometheus/ethereum-metrics-exporter/node-exporter)" 9 78; then
	  sudo systemctl disable ethereum-metrics-exporter
	  sudo systemctl stop ethereum-metrics-exporter

	  sudo rm /etc/systemd/system/ethereum-metrics-exporter.service
	  sudo rm /usr/local/bin/ethereum-metrics-exporter

	  sudo systemctl disable grafana-server prometheus prometheus-node-exporter
	  sudo systemctl stop grafana-server prometheus prometheus-node-exporter
	  sudo apt remove -y grafana prometheus prometheus-node-exporter
    sudo rm /etc/apt/sources.list.d/grafana.list
    whiptail --title "Uninstall finished" --msgbox "You have uninstalled all monitoring tools." 8 78
	fi
}

# Installs Grafana, Prometheus, Node-Exporter
function installGrafanaPrometheus(){
	sudo apt-get install -y software-properties-common wget apt-transport-https
	sudo wget -q -O /usr/share/keyrings/grafana.key https://apt.grafana.com/gpg.key
	echo "deb [signed-by=/usr/share/keyrings/grafana.key] https://apt.grafana.com stable main" | sudo tee -a /etc/apt/sources.list.d/grafana.list
	sudo apt-get update && sudo apt-get install -y grafana prometheus prometheus-node-exporter
	sudo systemctl enable grafana-server prometheus prometheus-node-exporter
	sudo systemctl restart grafana-server prometheus prometheus-node-exporter

# Setup prometheus.yml config file
sudo bash -c "cat << 'EOF' > ${PROMETHEUS_DIR}/prometheus.yml
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
}

# Upgrade Grafana, Prometheus, Node-Exporter
function upgradeGrafanaPrometheus(){
  sudo apt-get update && sudo apt-get install --only-upgrade -y grafana prometheus prometheus-node-exporter
  sudo systemctl restart grafana-server prometheus prometheus-node-exporter
}

# Installs ethereum-metrics-exporter as a systemd service
function installSystemd(){
	# Create service user
	sudo adduser --system --no-create-home --group ethereum-metrics-exporter
	# Create systemd service
	sudo bash -c "cat << 'EOF' > /etc/systemd/system/ethereum-metrics-exporter.service
[Unit]
Description=Ethereum Metrics Exporter Service
Wants=network-online.target
After=network-online.target
After=consensus.service
Documentation=https://www.coincashew.com

[Service]
Type=simple
User=ethereum-metrics-exporter
Group=ethereum-metrics-exporter
Restart=on-failure
RestartSec=3
KillSignal=SIGINT
TimeoutStopSec=900
ExecStart=/usr/local/bin/ethereum-metrics-exporter $(echo "${ETHEREUM_METRICS_EXPORTER_OPTIONS[@]}")

[Install]
WantedBy=multi-user.target
EOF"
	sudo systemctl daemon-reload
	sudo systemctl enable ethereum-metrics-exporter
}

# Asks whether to open grafana access to local network
function allowLocalAccessToGrafana(){
  echo -e "\e[32m:: Open firewall to Grafana for local access ::\e[0m"
  echo "Allow access to Grafana from within your local network? [y|n]"
  read -rsn1 yn
  if [[ ${yn} = [Yy]* ]]; then
    sudo ufw allow from "$network_current" to any port 3000 proto tcp comment 'Allow local LAN access to Grafana Port'
  fi
}

# Sets the default Prometheus datasource to http://localhost:9090
function configureDataSource(){
	sudo bash -c "cat << 'EOF' > $GRAFANA_DIR/provisioning/datasources/datasources.yml
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    url: http://localhost:9090
    access: proxy
    isDefault: true
EOF"
}

function showNextSteps(){
cat << EOF

Congrats!
Successfully installed monitoring tools: ethereum-metrics-exporter, grafana, prometheus, node-exporter

Access Grafana at:
http://127.0.0.1:3000
or
http://${ip_current}:3000

Login to Grafana with:
Username: admin
Password: admin

To view dashboards,
1) Click Dashboards in the primary menu.

EOF
echo "Press ENTER to continue"
read
}

function provisionDashboards(){
# Install jq if not installed
if ! command -v jq >/dev/null 2>&1 ; then sudo apt-get install jq; fi

# Create yml file to configure provisioning
sudo bash -c "cat << 'EOF' > $GRAFANA_DIR/provisioning/dashboards/dashboard.yml
apiVersion: 1

providers:
  - name: 'Prometheus'
    orgId: 1
    folder: ''
    folderUid: ''
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: $GRAFANA_DIR/provisioning/dashboards
EOF"

# Download dashboards into provision directory
# Ethereum-Metrics-Exporter Dashboard
ID=16277
REVISION=$(wget -qO - https://grafana.com/api/dashboards/$ID | jq .revision)
URL=https://grafana.com/api/dashboards/$ID/revisions/$REVISION/download
JSON_FILE=$GRAFANA_DIR/provisioning/dashboards/ethereum-metrics-exporter.json
sudo bash -c "wget -qO - $URL | jq 'walk(if . == \"\${DS_PROMETHEUS}\" then \"Prometheus\" else . end)' > $JSON_FILE"

# Node Exporter Dashboard by StarsL
ID=11074
REVISION=$(wget -qO - https://grafana.com/api/dashboards/$ID | jq .revision)
URL=https://grafana.com/api/dashboards/$ID/revisions/$REVISION/download
JSON_FILE=$GRAFANA_DIR/provisioning/dashboards/node-exporter-for-prometheus-dashboard.json
sudo bash -c "wget -qO - $URL | jq 'walk(if . == \"\${DS__VICTORIAMETRICS}\" then \"Prometheus\" else . end)' > $JSON_FILE"

# Delete any failed 0 size dashboards
find $GRAFANA_DIR/provisioning/dashboards -type f -size 0 -delete

# Install default alert rules and restart prometheus
sudo cp "$(dirname "$(realpath "${BASH_SOURCE[0]}")")"/alert.rules.yml $PROMETHEUS_DIR
sudo systemctl restart prometheus
}

# Displays usage info
function usage() {
cat << EOF
Usage: $(basename "$0") [-i] [-u] [-r]

Ethereum-Metrics-Exporter Monitoring Helper Script

Options)
-i    Install ethereum-metrics-exporter, grafana, prometheus, node-exporter as a systemd service
-u    Upgrade ethereum-metrics-exporter, grafana, prometheus, node-exporter
-r    Remove all monitoring tools
-h    Display help
EOF
}

function installMonitoring(){
MSG_ABOUT="🚨 Monitoring with Ethereum Metrics Exporter & Grafana & Prometheus & node-exporter
\nFeatures:
\n- Dashboards: Simplify observation across your node's resources and performance
\n- Alerts: Customize alerts to notify you of any issues
\n- Data: Real-time metrics and statistics
\n- Privacy: Run locally using your node
\nSource Code: https://github.com/ethpandaops/ethereum-metrics-exporter
\nContinue to install?"

  if ! whiptail --title "Monitoring: Installation" --yesno "$MSG_ABOUT" 22 78; then exit; fi
  installGrafanaPrometheus
  installSystemd
  configureDataSource
  provisionDashboards
  downloadClient
  getNetworkConfig
  allowLocalAccessToGrafana
  showNextSteps
  promptViewLogs
}

# Process command line options
while getopts :iurh opt; do
  case ${opt} in
    i ) installMonitoring ;;
    u ) upgradeBinaries ;;
    r ) removeAll ;;
    h)
      usage
      exit 0
      ;;
    \?)
      echo "Invalid option: -${OPTARG}" >&2
      usage
      exit 1
      ;;
    :)
      echo "Option -${OPTARG} requires an argument." >&2
      usage
      exit 1
      ;;
  esac
done
