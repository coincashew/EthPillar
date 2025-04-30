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
p2p_processes=("geth" "besu" "teku" "lighthouse" "prysm" "nimbus" "erigon" "nethermind" "reth" "mev-boost")
services=("consensus" "execution" "validator" "mevboost")
API_BN_ENDPOINT="http://localhost:5052"
EL_RPC_ENDPOINT="http://localhost:8545"

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

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${YELLOW}Warning: Some checks require root privileges${NC}"
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

check_firewall() {
    ((total_checks++))
    if sudo ufw status | grep -q "Status: active"; then
        echo -e "${GREEN}[PASS] Firewall is active${NC}"
    else
        echo -e "${RED}[FAIL] Firewall is not active. Install found in Toolbox.${NC}"
        ((failed_checks++))
    fi
}

check_ssh_keys() {
    ((total_checks++))
    if grep -q "^PasswordAuthentication no" /etc/ssh/sshd_config; then
        echo -e "${GREEN}[PASS] SSH key authentication enforced${NC}"
    else
        echo -e "${YELLOW}[WARN] Password authentication allowed. SSH key authentication is best.${NC}"
    fi
}

check_fail2ban() {
    ((total_checks++))
    if systemctl is-active --quiet fail2ban; then
        echo -e "${GREEN}[PASS] Fail2ban is running${NC}"
    else
        echo -e "${RED}[FAIL] Fail2ban not active. Install found in Toolbox.${NC}"
        ((failed_checks++))
    fi
}

check_updates() {
    ((total_checks++))
    updates=$(apt list --upgradable 2>/dev/null | wc -l)
    if [ "$updates" -gt 1 ]; then
        echo -e "${RED}[FAIL] $((updates-1)) pending system updates. Go to System Admin > Update system${NC}"
        ((failed_checks++))
    else
        echo -e "${GREEN}[PASS] System up to date${NC}"
    fi
}

check_unattended_upgrades() {
    ((total_checks++))
    if dpkg -l | grep -q unattended-upgrades; then
        if grep -q "Unattended-Upgrade::Allowed-Origins" /etc/apt/apt.conf.d/50unattended-upgrades; then
            echo -e "${GREEN}[PASS] Unattended upgrades configured${NC}"
        else
            echo -e "${YELLOW}[WARN] Unattended upgrades installed but not configured${NC}"
        fi
    else
        echo -e "${RED}[FAIL] Unattended upgrades not installed. Install found in Toolbox.${NC}"
        ((failed_checks++))
    fi
}

check_reboot_required() {
    ((total_checks++))
    if [ -f /var/run/reboot-required ]; then
        echo -e "${RED}[FAIL] Restart needed to apply updates${NC}"
        ((failed_checks++))
    else
        echo -e "${GREEN}[PASS] System reboot not required${NC}"
    fi
}

check_listening_ports() {
    ((total_checks++))
    open_ports=$(sudo ss -tunlp | grep -c -E 'LISTEN|UNCONN')
    if [ "$open_ports" -gt 0 ]; then
        echo -e "${BLUE}${BOLD}[INFO] Listening ports:${NC}"
        sudo ss -tunlp | grep -E 'LISTEN|UNCONN'
    else
        echo -e "${YELLOW}[WARN] No listening ports.${NC}"
    fi
}

check_resources() {
    # Memory check
    ((total_checks++))
    memory_usage=$(free | awk '/Mem/{printf("%.2f"), $3/$2*100}')
    if (( $(echo "$memory_usage > $MEMORY_WARN" | bc -l) )); then
        echo -e "${RED}[FAIL] High memory usage: ${memory_usage}%${NC}"
        ((failed_checks++))
    else
        echo -e "${GREEN}[PASS] Memory usage: ${memory_usage}%${NC}"
    fi

    # CPU check
    ((total_checks++))
    cpu_usage=$(top -bn1 | grep load | awk '{printf "%.2f", $(NF-2)}')
    cpu_cores=$(nproc)
    if (( $(echo "$cpu_usage > $cpu_cores * $CPU_WARN / 100" | bc -l) )); then
        echo -e "${RED}[FAIL] High CPU load: ${cpu_usage}${NC}"
        ((failed_checks++))
    else
        echo -e "${GREEN}[PASS] CPU load: ${cpu_usage}${NC}"
    fi

    # Disk check
    ((total_checks++))
    disk_usage=$(df / | awk '/\// {print $5}' | tr -d '%')
    if [ "$disk_usage" -gt $DISK_WARN ]; then
        echo -e "${RED}[FAIL] High disk usage: ${disk_usage}%${NC}"
        ((failed_checks++))
    else
        echo -e "${GREEN}[PASS] Disk usage: ${disk_usage}%${NC}"
    fi
}

check_ssh_2fa() {
    ((total_checks++))
    if grep -q "auth required pam_google_authenticator.so" /etc/pam.d/sshd; then
        echo -e "${GREEN}[PASS] SSH 2FA configured${NC}"
    else
        echo -e "${YELLOW}[WARN] SSH 2FA not configured. Install found in Toolbox.${NC}"
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
                echo -e "${RED}[FAIL] Root SSH key has insecure permissions: ${perms}${NC}. Change to 600."
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
                    echo -e "${RED}[FAIL] Insecure permissions (${perms}) on ${auth_file}. Change to 600.${NC}"
                    ((problematic_perms++))
                fi
            else
                echo -e "${RED}[FAIL] Empty authorized_keys file in ${user_dir}/.ssh${NC}"
                ((failed_checks++))
            fi
        fi
    done < <(find /home -maxdepth 1 -type d)

    if [ $found_keys -eq 1 ]; then
        if [ $problematic_perms -eq 0 ]; then
            echo -e "${GREEN}[PASS] SSH keys present with proper permissions${NC}"
        else
            ((failed_checks+=problematic_perms))
        fi
    else
        echo -e "${RED}[FAIL] No SSH keys found in the authorized_keys file. Add your SSH public key to the file${NC}"
        ((failed_checks++))
    fi
}

check_chrony() {
    ((total_checks++))
    chrony_installed=0
    conflicts_found=0

    # Check Chrony installation
    if command -v chronyc &> /dev/null; then
        chrony_installed=1
        echo -e "${GREEN}[PASS] Chrony is installed${NC}"
    else
        echo -e "${RED}[FAIL] Chrony not installed${NC}"
        ((failed_checks++))
    fi

    if [ $chrony_installed -eq 1 ]; then
        # Service status check
        ((total_checks++))
        if systemctl is-active --quiet chrony; then
            echo -e "${GREEN}[PASS] Chrony service is running${NC}"
        else
            echo -e "${RED}[FAIL] Chrony service is not running${NC}"
            ((failed_checks++))
        fi

        # Service enabled check
        ((total_checks++))
        if systemctl is-enabled --quiet chrony; then
            echo -e "${GREEN}[PASS] Chrony service is enabled${NC}"
        else
            echo -e "${RED}[FAIL] Chrony service is not enabled on boot${NC}"
            ((failed_checks++))
        fi

        # Time sync status check
        ((total_checks++))
        if chronyc tracking | grep -q "Leap status\s*:\s*Normal"; then
            echo -e "${GREEN}[PASS] Chrony time synchronization active${NC}"
        else
            echo -e "${RED}[FAIL] Chrony not synchronized${NC}"
            ((failed_checks++))
        fi
    fi

    # Check for conflicting time services
    conflicting_services=("ntpd" "systemd-timesyncd")
    for service in "${conflicting_services[@]}"; do
        ((total_checks++))
        if systemctl is-active --quiet "$service" &> /dev/null; then
            echo -e "${RED}[FAIL] Conflicting time service running: ${service}${NC}"
            ((failed_checks++))
            conflicts_found=1
        fi
        ((total_checks++))
        if systemctl is-enabled --quiet "$service" &> /dev/null; then
            echo -e "${RED}[FAIL] Conflicting time service enabled: ${service}${NC}"
            ((failed_checks++))
            conflicts_found=1
        fi
    done

    if [ $conflicts_found -eq 0 ] && [ $chrony_installed -eq 1 ]; then
        echo -e "${GREEN}[PASS] No conflicting time services detected${NC}"
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
        echo -e "${BLUE}${BOLD}[INFO] Checking consensus service on ports 12000 udp, 13000 tcp, and execution service on port 30303 tcp/udp${NC}"
        # Check Prysm specific ports
        for port in "12000" "13000"; do
            proto="tcp"
            if [ "$port" = "12000" ]; then
                proto="udp"
            fi
            if sudo ss -lntu | grep -qE "${proto}.*:${port}"; then
                echo -e "${GREEN}[PASS] Detected ${proto^^} service on port ${port}${NC}"
                ((detected++))
                if [ "$EUID" -eq 0 ]; then
                    pid=$(sudo ss -lntup "sport = :${port}" | awk -Fpid= '/users:/ {print $2}' | cut -d, -f1 | head -1)
                    if [ -n "$pid" ]; then
                        process=$(ps -p "$pid" -o comm=)
                        echo -e "${YELLOW}     Process: ${process} (PID ${pid})${NC}"
                    fi
                else
                    echo -e "${YELLOW}     Run as root to identify process${NC}"
                fi
            fi
        done
    else
        echo -e "${BLUE}${BOLD}[INFO] Checking for execution & consensus services on ports 9000 tcp and 30303 tcp/udp${NC}"
        # Check standard ports for other clients
        for port in "${p2p_ports[@]}"; do
            for proto in "${p2p_protocols[@]}"; do
                if sudo ss -lntu | grep -qE "${proto}.*:${port}"; then
                    echo -e "${GREEN}[PASS] Detected ${proto^^} service on port ${port}${NC}"
                    ((detected++))
                    if [ "$EUID" -eq 0 ]; then
                        pid=$(sudo ss -lntup "sport = :${port}" | awk -Fpid= '/users:/ {print $2}' | cut -d, -f1 | head -1)
                        if [ -n "$pid" ]; then
                            process=$(ps -p "$pid" -o comm=)
                            echo -e "${YELLOW}     Process: ${process} (PID ${pid})${NC}"
                        fi
                    else
                        echo -e "${YELLOW}     Run as root to identify process${NC}"
                    fi
                fi
            done
        done
    fi

    # Always check Execution client port 30303
    for proto in "${p2p_protocols[@]}"; do
        if sudo ss -lntu | grep -qE "${proto}.*:30303"; then
            echo -e "${GREEN}[PASS] Detected ${proto^^} service on port 30303${NC}"
            ((detected++))
            if [ "$EUID" -eq 0 ]; then
                pid=$(sudo ss -lntup "sport = :30303" | awk -Fpid= '/users:/ {print $2}' | cut -d, -f1 | head -1)
                if [ -n "$pid" ]; then
                    process=$(ps -p "$pid" -o comm=)
                    echo -e "${YELLOW}     Process: ${process} (PID ${pid})${NC}"
                fi
            else
                echo -e "${YELLOW}     Run as root to identify process${NC}"
            fi
        fi
    done

    if [ $detected -gt 0 ]; then
        echo -e "${GREEN}[PASS] Found ${detected} execution & consensus listening p2p ports${NC}"
    else
        echo -e "${RED}[FAIL] No execution & consensus services detected on expected ports${NC}"
        ((failed_checks++))
    fi

    # Additional check for running processes
    running_p2p=0
    for process in "${p2p_processes[@]}"; do
        if pgrep -f "$process" >/dev/null; then
            echo -e "${BLUE}${BOLD}[INFO] Detected Ethereum node process: ${process}${NC}"
            ((running_p2p++))
        fi
    done

    if [ $running_p2p -gt 0 ]; then
        echo -e "${GREEN}[PASS] Found ${running_p2p} Ethereum node processes running${NC}"
    else
        echo -e "${PASS}[FAILED] No Ethereum node processes detected${NC}"
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

    # Parse JSON using jq and check if any open ports exist
    echo -e "${BLUE}${BOLD}[INFO] Open ports found:${NC}"
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
        echo -e "${RED}[FAIL] Ports ${tcp_ports} (TCP) and ${udp_ports} (UDP) not all open or reachable. Expected ${expected_ports}. Actual $open_ports. Check port forwarding on router.${NC}"
        ((failed_checks++))
    else
        echo -e "${GREEN}[PASS] P2P Ports fully open on ${tcp_ports} (TCP) and ${udp_ports} (UDP)${NC}"
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
    # Print each peer status
    echo -e "${BLUE}${BOLD}[INFO] Peer counts:${NC}"
    for _key in ${!_peer_status[*]}; do
        if [[ ${_peer_status[$_key]} -gt 0 ]]; then
            echo -e "[${GREEN}✔${NC}]${BLUE}${BOLD}[$_key]: ${_peer_status[$_key]} peers${NC}"
        else
            echo -e "[${RED}✗${NC}]${BLUE}${BOLD}[$_key]: ${_peer_status[$_key]} peers${NC}"
            _warn="1";
        fi
    done
     if [ -n "${_warn}" ]; then
        echo -e "${RED}[FAIL] Suboptimal connectivity may affect validating nodes. To resolve, restart the service and check port forwarding, firewall-router settings, public IP, ENR.${NC}"
        ((failed_checks++))
    else
        echo -e "${GREEN}[PASS] Consensus and execution client's peer count appear healthy.${NC}"
    fi
}

check_systemd_services() {
    echo -e "\n${YELLOW}=== Checking Systemd Services ===${NC}"
    for service in "${services[@]}"; do
        service_installed=0
        ((total_checks+=3))  # Three checks per service (installed + active + enabled)
        # Check installation
        if [ -f /etc/systemd/system/"${service}".service ]; then
            service_installed=1
            echo -e "${GREEN}[PASS] ${service} is installed${NC}"
        else
            echo -e "${BLUE}${BOLD}[INFO] ${service} not installed${NC}"
        fi

        if [ $service_installed -eq 1 ]; then
            # Check if service is active
            if systemctl is-active --quiet "$service"; then
                echo -e "${GREEN}[PASS] ${service} is running${NC}"
            else
                echo -e "${BLUE}${BOLD}[INFO] ${service} is not running${NC}"
            fi

            # Check if service is enabled
            if systemctl is-enabled --quiet "$service"; then
                echo -e "${GREEN}[PASS] ${service} is enabled${NC}"
            else
                echo -e "${BLUE}${BOLD}[INFO] ${service} is not enabled, will not autostart at boot. To change, go to System Administration.${NC}"
            fi
        fi
    done
}

check_noatime() {
    ((total_checks++))
    if grep -q "noatime" /etc/fstab; then
        echo -e "${GREEN}[PASS] noatime is active${NC}"
    else
        echo -e "${RED}[FAIL] noatime is not active. To change, use Toolbox.${NC}"
        ((failed_checks++))
    fi
}

check_swappiness() {
    ((total_checks++))
    swappiness=$(cat /proc/sys/vm/swappiness)
    if [ "$swappiness" -le 10 ] ; then
        echo -e "${GREEN}[PASS] swappiness is good. value is $swappiness ${NC}"
    else
        echo -e "${RED}[FAIL] swappiness is not optimized. value is $swappiness. To change, use Toolbox.${NC}"
        ((failed_checks++))
    fi
}

print_system_information() {
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

    # Output Display
    cat << EOF
OS Name:        $os_name
Hostname:       $hostname
Kernel Version: $kernel
Uptime:         $uptime (since $uptime_since)
CPU Model:      $cpu_name
CPU Cores:      $cores
CPU Speed:      $freq
Architecture:   $arch
Load Average:   $load
IP Address:     $ip
Total RAM:      $ram_total
Swap:           $swap
Disk Space:     $disk_total
I/O Speed:      $io
EOF
}

start_time=$(date +%s)
echo -e "\n${YELLOW}=== Starting Node Security Scanner and Health Checkup ===${NC}\n"
display_banner
# Execute checks
echo -e "\n${YELLOW}=== Security Checks ===${NC}"
check_firewall
check_ssh_keys
check_fail2ban
check_updates
check_unattended_upgrades
check_reboot_required

echo -e "\n${YELLOW}=== Node Health Checks ===${NC}"
check_listening_ports
check_open_ports
check_peer_count
check_resources
check_ssh_2fa
check_ssh_key_presence
check_chrony
check_elcl_listening_ports
check_systemd_services

echo -e "\n${YELLOW}=== Performance Tuning Checks ===${NC}"
check_swappiness
check_noatime

echo -e "\n${YELLOW}=== System Information ===${NC}"
print_system_information

# Summary
echo -e "\n${YELLOW}=== Summary ===${NC}"
echo -e "${BLUE}${BOLD}Total checks: ${total_checks}${NC}"
echo -e "${GREEN}Passed checks: $((total_checks - failed_checks))${NC}"
echo -e "${RED}Failed checks: ${failed_checks}${NC}"

# Duration
end_time=$(date +%s)
duration=$((end_time - start_time))
echo -e "\n${YELLOW}=== Duration: $duration seconds  ===${NC}"
echo -e "\n${GREEN}=== Node Checker Complete: Press enter to exit  ===${NC}"
read -r
