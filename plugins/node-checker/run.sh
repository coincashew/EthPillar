#!/bin/bash

# Author: coincashew.eth | coincashew.com
# License: GNU GPL
# Source: https://github.com/coincashew/ethpillar
# Description: EthPillar is a one-liner setup tool and node management TUI
#
# Made for home and solo stakers 🏠🥩

SOURCE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Node configuration
p2p_ports=("9000" "30303")
p2p_processes=("geth" "besu" "teku" "lighthouse" "prysm" "nimbus_beacon_node" "nimbus_validator" "lodestar" "erigon" "nethermind" "reth" "mev-boost")
services=("consensus" "execution" "validator" "mevboost")
API_BN_ENDPOINT="http://localhost:5052"
EL_RPC_ENDPOINT="http://localhost:8545"

declare -A client_github_url
client_github_url['Lighthouse']='https://api.github.com/repos/sigp/lighthouse/releases/latest'
client_github_url['Lodestar']='https://api.github.com/repos/ChainSafe/lodestar/releases/latest'
client_github_url['Teku']='https://api.github.com/repos/ConsenSys/teku/releases/latest'
client_github_url['Nimbus']='https://api.github.com/repos/status-im/nimbus-eth2/releases/latest'
client_github_url['Prysm']='https://api.github.com/repos/OffchainLabs/prysm/releases/latest'
client_github_url['Nethermind']='https://api.github.com/repos/NethermindEth/nethermind/releases/latest'
client_github_url['Besu']='https://api.github.com/repos/hyperledger/besu/releases/latest'
client_github_url['Erigon']='https://api.github.com/repos/erigontech/erigon/releases/latest'
client_github_url['Geth']='https://api.github.com/repos/ethereum/go-ethereum/releases/latest'
client_github_url['Reth']='https://api.github.com/repos/paradigmxyz/reth/releases/latest'
client_github_url['mev-boost']='https://api.github.com/repos/flashbots/mev-boost/releases/latest'

# Load environment variables overrides
if [[ -f "$SOURCE_DIR"/../../.env.overrides ]]; then
    # shellcheck source=/dev/null
    source "$SOURCE_DIR"/../../.env.overrides

    # Handle consensus layer endpoint overrides
    if [[ -n "${CL_IP_ADDRESS:-}" || -n "${CL_REST_PORT:-}" ]]; then
        # Use default values if not overridden
        local_cl_ip="${CL_IP_ADDRESS:-localhost}"
        local_cl_port="${CL_REST_PORT:-5052}"
        API_BN_ENDPOINT="http://${local_cl_ip}:${local_cl_port}"
    fi

    # Handle execution layer endpoint overrides
    if [[ -n "${EL_IP_ADDRESS:-}" || -n "${EL_RPC_PORT:-}" ]]; then
        # Use default values if not overridden
        local_el_ip="${EL_IP_ADDRESS:-localhost}"
        local_el_port="${EL_RPC_PORT:-8545}"
        EL_RPC_ENDPOINT="http://${local_el_ip}:${local_el_port}"
    fi
fi

# Thresholds
MEMORY_WARN=90
CPU_WARN=90
DISK_WARN=90

total_checks=0
failed_checks=0
warning_checks=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[35m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    print_check_result "WARN" "Some checks require root privileges"
fi

display_banner() {
cat << 'EOF'
             ,----------------,              ,---------,
        ,-----------------------,          ,"        ,"|
      ,"                      ,"|        ,"        ,"  |
     +-----------------------+  |      ,"        ,"    |
     |  .-----------------.  |  |     +---------+      |
     |  |                 |  |  |     | -==----'|      |
     |  |  Running        |  |  |     |         |      |
     |  |  Node Checker   |  |  |/----|`---=    |      |
     |  |  > ethpillar    |  |  |   ,/|==== ooo |      ;
     |  |                 |  |  |  // |(((( [33]|    ,"
     |  `-----------------'  |," .;'| |((((     |  ,"
     +-----------------------+  ;;  | |         |,"
        /_)______________(_/  //'   | +---------+
   ___________________________/___  `,
  /  oooooooooooooooo  .o.  oooo /,   \,"-----------
 / ==ooooooooooooooo==.o.  ooo= //   ,`\---)B     ,"
/_==__==========__==_ooo__ooo=_/'   /___________,"
`-----------------------------'
EOF
}

print_section_header() {
    local title="$1"
    local width=80
    local padding=$(( (width - ${#title}) / 2 ))
    echo -e "\n${BLUE}${BOLD}╔$(printf '═%.0s' $(seq 1 $((width-2))))╗${NC}"
    echo -e "${BLUE}${BOLD}║$(printf '%*s' $padding '')${YELLOW}${BOLD}$title${BLUE}${BOLD}$(printf '%*s' $((width-2-padding-${#title})) '')║${NC}"
    echo -e "${BLUE}${BOLD}╚$(printf '═%.0s' $(seq 1 $((width-2))))╝${NC}\n"
}

print_check_result() {
    local status="$1"
    local message="$2"
    local icon=""
    local color=""
    local prefix=""

    case "$status" in
        "PASS")
            icon="✓"
            color="$GREEN"
            prefix="[PASS]"
            ;;
        "FAIL")
            icon="✗"
            color="$RED"
            prefix="[FAIL]"
            ;;
        "WARN")
            icon="⚠"
            color="$YELLOW"
            prefix="[WARN]"
            ;;
        "INFO")
            icon="ℹ"
            color="$PURPLE"
            prefix="[INFO]"
            ;;
    esac

    echo -e "${color}${prefix} ${icon} ${message}${NC}"
}

check_firewall() {
    ((total_checks++))
    if sudo ufw status | grep -q "Status: active"; then
        print_check_result "PASS" "Firewall is active"
    else
        print_check_result "FAIL" "Firewall is not active. Install found in Security & Node Checks."
        ((failed_checks++))
    fi
}

check_ssh_keys() {
    ((total_checks++))
    if grep -q "^PasswordAuthentication no" /etc/ssh/sshd_config; then
        print_check_result "PASS" "SSH key authentication enforced"
    else
        print_check_result "WARN" "Password authentication allowed. SSH key authentication is best."
    fi
}

check_ssh_port() {
    ((total_checks++))
    if grep -q "^Port 22" /etc/ssh/sshd_config; then
        print_check_result "WARN" "SSH is using default port 22. Consider changing to a non-standard port for better security."
        ((warning_checks++))
    else
        print_check_result "PASS" "SSH is not using default port 22"
    fi
}

check_fail2ban() {
    ((total_checks++))
    if systemctl is-active --quiet fail2ban; then
        print_check_result "PASS" "Fail2ban is running"
    else
        print_check_result "FAIL" "Fail2ban not active. Install found in Security & Node Checks."
        ((failed_checks++))
    fi
}

check_updates() {
    ((total_checks++))
    updates=$(apt list --upgradable 2>/dev/null | wc -l)
    if [ "$updates" -gt 1 ]; then
        print_check_result "FAIL" "$((updates-1)) pending system updates. Go to System Admin > Update system"
        ((failed_checks++))
    else
         print_check_result "PASS" "System up to date"
    fi
}

check_unattended_upgrades() {
    ((total_checks++))
    if dpkg -l | grep -q unattended-upgrades; then
        if grep -q "Unattended-Upgrade::Allowed-Origins" /etc/apt/apt.conf.d/50unattended-upgrades; then
            print_check_result "PASS" "Unattended upgrades configured"
        else
            print_check_result "WARN" "Unattended upgrades installed but not configured"
            ((warning_checks++))
        fi
    else
        print_check_result "FAIL" "Unattended upgrades not installed. Install found in Security & Node Checks."
        ((failed_checks++))
    fi
}

check_reboot_required() {
    ((total_checks++))
    if [ -f /var/run/reboot-required ]; then
        print_check_result "FAIL" "Restart needed to apply updates"
        ((failed_checks++))
    else
        print_check_result "PASS" "System reboot not required"
    fi
}

check_listening_ports() {
    ((total_checks++))
    open_ports=$(sudo ss -tunlp | grep -c -E 'LISTEN|UNCONN')
    if [ "$open_ports" -gt 0 ]; then
        print_check_result "INFO" "Listening ports:"
        sudo ss -tunlp | grep -E 'LISTEN|UNCONN'
    else
        print_check_result "WARN" "No listening ports."
        ((warning_checks++))
    fi
}

check_resources() {
    print_check_result "INFO" "Resources:"
    # Memory check
    ((total_checks++))
    memory_usage=$(LC_NUMERIC=C free | LC_NUMERIC=C awk '/Mem/{printf("%.2f"), $3/$2*100}')
    if (( $(LC_NUMERIC=C echo "$memory_usage > $MEMORY_WARN" | bc -l) )); then
        print_check_result "WARN" "High memory usage: ${memory_usage}%"
        ((warning_checks++))
    else
        print_check_result "PASS" "Memory usage: ${memory_usage}%"
    fi

    # CPU check
    ((total_checks++))
    cpu_usage=$(LC_NUMERIC=C top -bn1 | LC_NUMERIC=C awk '/load/ {printf "%.2f", $(NF-2)}')
    cpu_cores=$(nproc)
    if (( $(LC_NUMERIC=C echo "$cpu_usage > $cpu_cores * $CPU_WARN / 100" | bc -l) )); then
        print_check_result "WARN" "High CPU load: ${cpu_usage}"
        ((warning_checks++))
    else
        print_check_result "PASS" "CPU load: ${cpu_usage}"
    fi

    # Disk check
    ((total_checks++))
    disk_usage=$(df / | awk '/\// {print $5}' | tr -d '%')
    if [ "$disk_usage" -gt $DISK_WARN ]; then
        print_check_result "WARN" "High disk usage: ${disk_usage}%"
        ((warning_checks++))
    else
        print_check_result "PASS" "Disk usage: ${disk_usage}%"
    fi
}

check_ssh_2fa() {
    ((total_checks++))
    if grep -q "auth required pam_google_authenticator.so" /etc/pam.d/sshd; then
        print_check_result "PASS" "SSH 2FA configured"
    else
        print_check_result "WARN" "SSH 2FA not configured. Install found in Security & Node Checks."
        ((warning_checks++))
    fi
}

check_ssh_key_presence() {
    ((total_checks++))
    found_keys=0
    problematic_perms=0

    # Check for root user's SSH key
    if [ -f /root/.ssh/authorized_keys ]; then
        if [ -s /root/.ssh/authorized_keys ]; then
            found_keys=1
            # Check permissions
            perms=$(stat -c %a /root/.ssh/authorized_keys)
            if [ "$perms" -ne 600 ] && [ "$perms" -ne 644 ]; then
                print_check_result "FAIL" "Root SSH key has insecure permissions: ${perms}. Change to 600."
                ((problematic_perms++))
            fi
        fi
    fi

    # Check all user home directories
    while IFS= read -r user_dir; do
        auth_file="${user_dir}/.ssh/authorized_keys"
        if [ -f "$auth_file" ]; then
            if [ -s "$auth_file" ]; then
                found_keys=1
                # Check permissions
                perms=$(stat -c %a "$auth_file")
                if [ "$perms" -ne 600 ] && [ "$perms" -ne 644 ]; then
                    print_check_result "FAIL" "Insecure permissions (${perms}) on ${auth_file}. Change to 600."
                    ((problematic_perms++))
                fi
            else
                print_check_result "FAIL" "Empty authorized_keys file in ${user_dir}/.ssh"
                ((failed_checks++))
            fi
        fi
    done < <(find /home -maxdepth 1 -type d)

    if [ $found_keys -eq 1 ]; then
        if [ $problematic_perms -eq 0 ]; then
            print_check_result "PASS" "🔑 SSH keys present with proper permissions"
        else
            ((failed_checks+=problematic_perms))
        fi
    else
        print_check_result "FAIL" "No SSH keys found in the authorized_keys file. Add your SSH public key to the file"
        ((failed_checks++))
    fi
}

check_chrony() {
    print_check_result "INFO" "Time synchronization:"
    ((total_checks++))
    chrony_installed=0
    conflicts_found=0

    # Check Chrony installation
    if command -v chronyc &> /dev/null; then
        chrony_installed=1
        print_check_result "PASS" "📥 Chrony is installed"
    else
        print_check_result "FAIL" "❌ Chrony not installed"
        ((failed_checks++))
    fi

    if [ $chrony_installed -eq 1 ]; then
        # Service status check
        ((total_checks++))
        if systemctl is-active --quiet chrony; then
            print_check_result "PASS" "🏃 Chrony service is running"
        else
            print_check_result "FAIL" "🛑 Chrony service is not running"
            ((failed_checks++))
        fi

        # Service enabled check
        ((total_checks++))
        if systemctl is-enabled --quiet chrony; then
            print_check_result "PASS" "⚡ Chrony service is enabled"
        else
            print_check_result "FAIL" "⚠️ Chrony service is not enabled on boot"
            ((failed_checks++))
        fi

        # Time sync status check
        ((total_checks++))
        if chronyc tracking | grep -q "Leap status\s*:\s*Normal"; then
            print_check_result "PASS" "🕺 Chrony time synchronization active"
        else
            print_check_result "FAIL" "⏳ Chrony not synchronized"
            ((failed_checks++))
        fi
    fi

    # Check for conflicting time services
    conflicting_services=("ntpd" "systemd-timesyncd")
    for service in "${conflicting_services[@]}"; do
        ((total_checks++))
        if systemctl is-active --quiet "$service" &> /dev/null; then
            print_check_result "FAIL" "Conflicting time service running: ${service}"
            ((failed_checks++))
            conflicts_found=1
        fi
        ((total_checks++))
        if systemctl is-enabled --quiet "$service" &> /dev/null; then
            print_check_result "FAIL" "Conflicting time service enabled: ${service}"
            ((failed_checks++))
            conflicts_found=1
        fi
    done

    if [ $conflicts_found -eq 0 ] && [ $chrony_installed -eq 1 ]; then
        print_check_result "PASS" "🕒 No conflicting time services detected"
    fi
}

check_elcl_listening_ports() {
    ((total_checks+=2))
    detected=0
    declare -a p2p_protocols=("tcp" "udp")

    # Check if Prysm is running
    prysm_running=0
    if pgrep -f "prysm" >/dev/null; then
        prysm_running=1
        print_check_result "INFO" "Checking consensus service on ports 12000 udp, 13000 tcp, and execution service on port 30303 tcp/udp"
        # Check Prysm specific ports
        declare -a prysm_ports=("12000" "13000" "30303")
        for port in "${prysm_ports[@]}"; do
            if [ "$port" = "12000" ]; then
                proto="udp"
                if sudo ss -lntu | grep -qE "${proto}.*:${port}"; then
                    print_check_result "PASS" "Detected ${proto^^} service on port ${port}"
                    ((detected++))
                    if [ "$EUID" -eq 0 ]; then
                        pid=$(sudo ss -lntup "sport = :${port}" | awk -Fpid= '/users:/ {print $2}' | cut -d, -f1 | head -1)
                        if [ -n "$pid" ]; then
                            process=$(ps -p "$pid" -o comm=)
                            echo -e "${YELLOW}          Process: ${process} (PID ${pid})${NC}"
                        fi
                    else
                        echo -e "${YELLOW}          Run as root to identify process${NC}"
                    fi
                fi
            elif [ "$port" = "13000" ]; then
                proto="tcp"
                if sudo ss -lntu | grep -qE "${proto}.*:${port}"; then
                    print_check_result "PASS" "Detected ${proto^^} service on port ${port}"
                    ((detected++))
                    if [ "$EUID" -eq 0 ]; then
                        pid=$(sudo ss -lntup "sport = :${port}" | awk -Fpid= '/users:/ {print $2}' | cut -d, -f1 | head -1)
                        if [ -n "$pid" ]; then
                            process=$(ps -p "$pid" -o comm=)
                            echo -e "${YELLOW}          Process: ${process} (PID ${pid})${NC}"
                        fi
                    else
                        echo -e "${YELLOW}          Run as root to identify process${NC}"
                    fi
                fi
            elif [ "$port" = "30303" ]; then
                for proto in "${p2p_protocols[@]}"; do
                    if sudo ss -lntu | grep -qE "${proto}.*:${port}"; then
                        print_check_result "PASS" "Detected ${proto^^} service on port ${port}"
                        ((detected++))
                        if [ "$EUID" -eq 0 ]; then
                            pid=$(sudo ss -lntup "sport = :${port}" | awk -Fpid= '/users:/ {print $2}' | cut -d, -f1 | head -1)
                            if [ -n "$pid" ]; then
                                process=$(ps -p "$pid" -o comm=)
                                echo -e "${YELLOW}          Process: ${process} (PID ${pid})${NC}"
                            fi
                        else
                            echo -e "${YELLOW}          Run as root to identify process${NC}"
                        fi
                    fi
                done
            fi
        done
    else
        print_check_result "INFO" "Checking for execution & consensus services on ports 9000 tcp/udp and 30303 tcp/udp"
        # Check standard ports for other clients
        for port in "${p2p_ports[@]}"; do
            for proto in "${p2p_protocols[@]}"; do
                if sudo ss -lntu | grep -qE "${proto}.*:${port}"; then
                    print_check_result "PASS" "Detected ${proto^^} service on port ${port}"
                    ((detected++))
                    if [ "$EUID" -eq 0 ]; then
                        pid=$(sudo ss -lntup "sport = :${port}" | awk -Fpid= '/users:/ {print $2}' | cut -d, -f1 | head -1)
                        if [ -n "$pid" ]; then
                            process=$(ps -p "$pid" -o comm=)
                            echo -e "${YELLOW}          Process: ${process} (PID ${pid})${NC}"
                        fi
                    else
                        echo -e "${YELLOW}          Run as root to identify process${NC}"
                    fi
                fi
            done
        done
    fi

    if [ $detected -gt 0 ]; then
        if [ $prysm_running -eq 1 ]; then
            if [ $detected -eq 4 ]; then
                print_check_result "PASS" "Found all 4 expected ports (12000 udp, 13000 tcp, 30303 tcp/udp) for Prysm and execution services"
            else
                print_check_result "FAIL" "Found ${detected} ports, expected 4 ports (12000 udp, 13000 tcp, 30303 tcp/udp) for Prysm and execution services"
                ((failed_checks++))
            fi
        else
            if [ $detected -eq 4 ]; then
                print_check_result "PASS" "Found all 4 expected ports (9000 tcp/udp, 30303 tcp/udp) for execution & consensus services"
            else
                print_check_result "FAIL" "Found ${detected} ports, expected 4 ports (9000 tcp/udp, 30303 tcp/udp) for execution & consensus services"
                ((failed_checks++))
            fi
        fi
    else
        print_check_result "FAIL" "No execution & consensus services detected on expected ports"
        ((failed_checks++))
    fi
}

check_elcl_processes() {
    print_check_result "INFO" "Ethereum node processes:"
    # Additional check for running processes
    running_p2p=0
    ((total_checks++))
    for process in "${p2p_processes[@]}"; do
        if pgrep -f "$process" >/dev/null; then
            echo -e "${BLUE}${BOLD} 🔍 Detected Ethereum node process: ${process} ${NC}"
            ((running_p2p++))
        fi
    done

    if [ $running_p2p -gt 0 ]; then
        print_check_result "PASS" "Found ${running_p2p} Ethereum node processes running"
    else
        ((failed_checks++))
        print_check_result "FAIL" "No Ethereum node processes detected"
    fi
}

check_open_ports() {
    ((total_checks++))
    open_ports=0
    concat_ports=""

    # Check if Prysm is running
    if pgrep -f "prysm" >/dev/null; then
        tcp_ports="13000,30303"
        udp_ports="12000,30303"
    else
        tcp_ports="9000,30303"
        udp_ports="9000,30303"
    fi

    # Check TCP ports
    checker_url="https://eth2-client-port-checker.vercel.app/api/checker?ports="
    tcp_json=$(curl -s "${checker_url}${tcp_ports}")

    # Check UDP ports using netcat
    udp_open_ports=0
    open_udp_ports=()
    for port in $(echo "$udp_ports" | tr ',' ' '); do
        if nc -z -u localhost "$port" &>/dev/null; then
            ((udp_open_ports++))
            open_udp_ports+=("$port")
        fi
    done

echo

    # Parse JSON using jq and check if any open ports exist
    print_check_result "INFO" "Open ports found:"
    if echo "$tcp_json" | jq -e '.open_ports[]' > /dev/null 2>&1; then
        echo "$tcp_json" | jq -r '.open_ports[]' | while read -r port; do echo "$port(TCP)"; done
        tcp_open_ports=$(echo "$tcp_json" | jq '.open_ports | length')
        open_ports=$((tcp_open_ports + udp_open_ports))
    fi

    # Show UDP ports
    for port in "${open_udp_ports[@]}"; do
        echo "$port(UDP)"
    done

    # Compare expected vs actual number of open ports
    expected_tcp_ports=$(echo "$tcp_ports" | tr ',' '\n' | wc -l)
    expected_udp_ports=$(echo "$udp_ports" | tr ',' '\n' | wc -l)
    expected_ports=$((expected_tcp_ports + expected_udp_ports))

    if [ "$expected_ports" -ne "$open_ports" ]; then
        print_check_result "FAIL" "Ports ${tcp_ports} (TCP) and ${udp_ports} (UDP) not all open or reachable. Expected ${expected_ports}. Actual $open_ports. Check port forwarding on router."
        ((failed_checks++))
    else
        print_check_result "PASS" "P2P Ports fully open on ${tcp_ports} (TCP) and ${udp_ports} (UDP)"
    fi
}

check_peer_count() {
    ((total_checks++))
    declare -A _peer_status=()
    local _warn=""
    # Get peer counts from CL and EL
    _peer_status["Consensus_Layer_Connected_Peer_Count"]="$(curl -m 1 -s -X GET "${API_BN_ENDPOINT}/eth/v1/node/peer_count" -H  "accept: application/json" | jq -r ".data.connected")"
    _peer_status["Execution_Layer_Connected_Peer_Count"]="$(curl -m 1 -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc": "2.0", "method":"net_peerCount", "params": [], "id":1}' "${EL_RPC_ENDPOINT}" | jq -r ".result" | mawk '{printf "%d\n",$1}')"
    # Get CL peers by direction
    _json_cl=$(curl -m 1 -s "${API_BN_ENDPOINT}"/eth/v1/node/peers | jq -c '.data')
    _peer_status["Consensus_Layer_Known_Inbound_Peers"]=$(jq -c '.[] | select(.direction == "inbound")' <<< "$_json_cl" | wc -l)
    _peer_status["Consensus_Layer_Known_Outbound_Peers"]=$(jq -c '.[] | select(.direction == "outbound")' <<< "$_json_cl" | wc -l)

    echo

    # Print each peer status
    print_check_result "INFO" "Peer counts:"
    for _key in ${!_peer_status[*]}; do
        if [[ ${_peer_status[$_key]} -gt 0 ]]; then
            echo -e "[${GREEN}✔${NC}]${BLUE}${BOLD}[$_key]: ${_peer_status[$_key]} peers${NC}"
        else
            echo -e "[${RED}✗${NC}]${BLUE}${BOLD}[$_key]: ${_peer_status[$_key]} peers${NC}"
            _warn="1"
        fi
    done
     if [ -n "${_warn}" ]; then
        print_check_result "FAIL" "Suboptimal connectivity may affect validating nodes. To resolve, restart the service and check port forwarding, firewall-router settings, public IP, ENR."
        ((failed_checks++))
    else
        print_check_result "PASS" "Consensus and execution client's peer count appear healthy."
    fi
}

check_systemd_services() {
check_elcl_processes
echo
    print_check_result "INFO" "Systemd Services:"
    for service in "${services[@]}"; do
        service_installed=0
        ((total_checks+=3))  # Three checks per service (installed + active + enabled)

        # Print service header
        echo -e "\n${BLUE}${BOLD}📦 ${service^} Service${NC}"
        echo -e "${BLUE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

        # Check installation
        if [ -f /etc/systemd/system/"${service}".service ]; then
            service_installed=1
            echo -e "${GREEN}[PASS] 📥 Installed${NC}"
        else
            echo -e "${BLUE}${BOLD}[INFO] ❌ Not installed${NC}"
        fi

        if [ $service_installed -eq 1 ]; then
            # Check if service is active
            if systemctl is-active --quiet "$service"; then
                echo -e "${GREEN}[PASS] 🏃 Running${NC}"
            else
                echo -e "${BLUE}${BOLD}[INFO] 🛑 Not running${NC}"
            fi

            # Check if service is enabled
            if systemctl is-enabled --quiet "$service"; then
                echo -e "${GREEN}[PASS] ⚡ Enabled${NC}"
            else
                echo -e "${BLUE}${BOLD}[INFO] ⚠️ Not enabled, will not autostart at boot. To change, go to System Administration.${NC}"
            fi
        fi
    done
}

check_execution_version() {
    [[ ! -f /etc/systemd/system/execution.service ]] && return
    EL=$(grep "Description=" /etc/systemd/system/execution.service | awk -F'=' '{print $2}' | awk '{print $1}')
    tag_url=${client_github_url["$EL"]}
    name="Execution client ($EL)"

    if [[ -z "$tag_url" ]]; then
      print_check_result "FAIL" "$name no GitHub URL mapping found"
      ((failed_checks++))
      return
    fi
    check_client_version "$name" "$tag_url"
}

check_consensus_version() {
    [[ ! -f /etc/systemd/system/consensus.service ]] && return
    CL=$(grep "Description=" /etc/systemd/system/consensus.service | awk -F'=' '{print $2}' | awk '{print $1}')
    tag_url=${client_github_url["$CL"]}
    name="Consensus client ($CL)"

    check_client_version "$name" "$tag_url"
}

check_validator_version() {
    [[ ! -f /etc/systemd/system/validator.service ]] && return
    VAL=$(grep "Description=" /etc/systemd/system/validator.service | awk -F'=' '{print $2}' | awk '{print $1}')
    tag_url=${client_github_url["$VAL"]}
    name="Validator client ($VAL)"

    check_client_version "$name" "$tag_url"
}

check_client_version() {
  ((total_checks++))
  local name=$1 tag_url=$2
  # Validate mapping
  if [[ -z "$tag_url" ]]; then
    print_check_result "FAIL" "$name no GitHub URL mapping found"
    ((failed_checks++))
    return
  fi

  if [[ "$name" =~ "Consensus" || "$name" =~ "Validator" ]]; then
    version=$(curl -s -X GET "${API_BN_ENDPOINT}/eth/v1/node/version" \
      -H "accept: application/json" \
      | jq -r '.data.version' \
      | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+')
  else
    version=$(curl -s -X POST \
      -H "Content-Type: application/json" \
      --data '{"jsonrpc":"2.0","method":"web3_clientVersion","params":[],"id":2}' \
      "${EL_RPC_ENDPOINT}" \
      | jq -r '.result' \
      | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+')
  fi

  if [[ -z $version ]]; then
    print_check_result "FAIL" "$name not running or unable to query version"
    ((failed_checks++))
    return
  fi

  latest=$(curl -s "$tag_url" \
    | jq -r .tag_name \
    | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')

  if [[ -n "$latest" && "${version#v}" == "${latest#v}" ]]; then
    print_check_result "PASS" "$name version: $version (latest)"
  else
    print_check_result "WARN" "$name version: $version (latest: $latest)"
    ((warning_checks++))
  fi
}

check_mevboost_version() {
    ((total_checks++))
    if command -v mev-boost &> /dev/null; then
        MEV_VERSION=$(mev-boost --version 2>&1 | sed 's/.*\s\([0-9]*\.[0-9]*\).*/\1/')
        if [[ $MEV_VERSION ]]; then
            # Get latest version
            TAG_URL=${client_github_url["mev-boost"]}
            LATEST_VERSION=$(curl -s "$TAG_URL" | jq -r .tag_name | sed 's/.*v\([0-9]*\.[0-9]*\).*/\1/')
            
            if [[ -n "$LATEST_VERSION" && "${MEV_VERSION#v}" == "${LATEST_VERSION#v}" ]]; then
                print_check_result "PASS" "MEV-Boost version: $MEV_VERSION (latest)"
            else
                print_check_result "WARN" "MEV-Boost version: $MEV_VERSION (latest: $LATEST_VERSION)"
                ((warning_checks++))
            fi
        else
            print_check_result "FAIL" "MEV-Boost installed but unable to query version"
            ((failed_checks++))
        fi
    else
        print_check_result "WARN" "MEV-Boost not installed"
        ((warning_checks++))
    fi
}

check_noatime() {
    ((total_checks++))
    if grep -q "noatime" /etc/fstab; then
        print_check_result "PASS" "noatime is active"
    else
        print_check_result "FAIL" "noatime is not active. To change, use Toolbox."
        ((failed_checks++))
    fi
}

check_swappiness() {
    ((total_checks++))
    swappiness=$(cat /proc/sys/vm/swappiness)
    if [ "$swappiness" -le 10 ] ; then
        print_check_result "PASS" "swappiness is good. value is $swappiness "
    else
        print_check_result "FAIL" "swappiness is not optimized. value is $swappiness. To change, use Toolbox."
        ((failed_checks++))
    fi
}

print_system_information() {
    print_section_header "System Information"

    # Get system information
    os_name=$(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)
    hostname=$(uname -n)
    kernel=$(uname -r)
    uptime=$(uptime -p | sed 's/up //')
    uptime_since=$(uptime -s)
    cpu_name=$(grep "model name" /proc/cpuinfo | head -1 | cut -d':' -f2 | xargs)
    cores=$(nproc)
    freq=$(awk -F: ' /cpu MHz/ {freq=$2} END {print freq}' /proc/cpuinfo | xargs)
    load=$(uptime | awk -F'load average:' '{print $2}' | xargs)
    ip=$(hostname -I | awk '{print $1}')
    ram_total=$(free -b | awk '/Mem/{printf "%.2f GB", $2/1024/1024/1024}')
    swap=$(free -b | awk '/Swap/{printf "%.2f GB", $2/1024/1024/1024}')
    disk_total=$(df -h / | awk 'NR==2 {print $2}')
    io=$( (dd if=/dev/zero of=test_$$ bs=64k count=16k conv=fdatasync && rm -f test_$$ ) 2>&1 | awk -F, '{io=$NF} END {print io}' )
    case "$(uname -m)" in
        x86_64|amd64) arch="amd64" ;;
        aarch64|arm64) arch="arm64" ;;
        *) arch="Unknown architecture"
    esac

     # Output Display with better formatting
    printf "${PURPLE}%-20s${NC} %s\n" "OS Name:" "$os_name"
    printf "${PURPLE}%-20s${NC} %s\n" "Hostname:" "$hostname"
    printf "${PURPLE}%-20s${NC} %s\n" "Kernel Version:" "$kernel"
    printf "${PURPLE}%-20s${NC} %s\n" "Uptime:" "$uptime"
    printf "${PURPLE}%-20s${NC} %s\n" "Since:" "$uptime_since"
    printf "${PURPLE}%-20s${NC} %s\n" "CPU Model:" "$cpu_name"
    printf "${PURPLE}%-20s${NC} %s\n" "CPU Cores:" "$cores"
    printf "${PURPLE}%-20s${NC} %s MHz\n" "CPU Speed:" "$freq"
    printf "${PURPLE}%-20s${NC} %s\n" "Architecture:" "$arch"
    printf "${PURPLE}%-20s${NC} %s\n" "Load Average:" "$load"
    printf "${PURPLE}%-20s${NC} %s\n" "IP Address:" "$ip"
    printf "${PURPLE}%-20s${NC} %s\n" "Total RAM:" "$ram_total"
    printf "${PURPLE}%-20s${NC} %s\n" "Swap:" "$swap"
    printf "${PURPLE}%-20s${NC} %s\n" "Disk Space:" "$disk_total"
    printf "${PURPLE}%-20s${NC} %s\n" "I/O Speed:" "$io"
}

start_time=$(date +%s)
echo -e "\n${YELLOW}${BOLD}=== Starting Node Security Scanner and Health Checkup ===${NC}\n"
display_banner

# Execute checks
print_section_header "Security Checks"

# Network Security
print_check_result "INFO" "Network Security:"
check_firewall
check_fail2ban
echo
# SSH Security
print_check_result "INFO" "SSH Security:"
check_ssh_key_presence
check_ssh_keys
check_ssh_port
check_ssh_2fa
echo
# System Updates
print_check_result "INFO" "System Updates:"
check_updates
check_unattended_upgrades
check_reboot_required

print_section_header "Node Health Checks"
check_listening_ports
check_open_ports
echo
check_elcl_listening_ports
check_peer_count
echo
check_systemd_services

print_section_header "Client Version Checks"
check_execution_version
check_consensus_version
check_validator_version
check_mevboost_version

print_section_header "Performance Checks"
check_resources
echo
check_chrony
echo
print_check_result "INFO" "Tuning:"
check_swappiness
check_noatime

print_system_information

# Summary
print_section_header "Summary"
printf "${BLUE}${BOLD}%-20s${NC} %d\n" "Total checks:" "$total_checks"
printf "${GREEN}%-20s${NC} %d\n" "Passed checks:" "$((total_checks - failed_checks - warning_checks))"
printf "${YELLOW}%-20s${NC} %d\n" "Warning checks:" "$warning_checks"
printf "${RED}%-20s${NC} %d\n" "Failed checks:" "$failed_checks"

# Duration
end_time=$(date +%s)
duration=$((end_time - start_time))
echo -e "\n${YELLOW}${BOLD}Duration: $duration seconds${NC}"
echo -e "\n${GREEN}${BOLD}=== Node Checker Complete: Press enter to exit ===${NC}"
read -r
