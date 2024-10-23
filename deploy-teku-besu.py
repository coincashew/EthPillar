# Author: coincashew.eth | coincashew.com
# License: GNU GPL
# Source: https://github.com/coincashew/ethpillar
#
# Validator-Install: Standalone Teku BN + Standalone Teku VC + Besu EL + MEVboost
# Quickstart :: Minority Client :: Docker-free
#
# Made for home and solo stakers 🏠🥩
#
# Acknowledgments
# Validator-Install is branched from validator-install written by Accidental-green: https://github.com/accidental-green/validator-install
# The groundwork for this project was established through their previous efforts.

import os
import requests
import re
import fnmatch
import random
import json
import tarfile
import shutil
import subprocess
import tempfile
import urllib.request
import zipfile
import random
import sys
import platform
from consolemenu import *
from consolemenu.items import *
import argparse
from dotenv import load_dotenv, dotenv_values
from config import *

def clear_screen():
    if os.name == 'posix':  # Unix-based systems (e.g., Linux, macOS)
        os.system('clear')
    elif os.name == 'nt':   # Windows
        os.system('cls')

clear_screen()  # Call the function to clear the screen

# Valid configurations
valid_networks = ['MAINNET', 'HOLESKY', 'SEPOLIA', 'EPHEMERY']
valid_exec_clients = ['BESU']
valid_consensus_clients = ['TEKU']
valid_install_configs = ['Solo Staking Node', 'Full Node Only', 'Lido CSM Staking Node', 'Lido CSM Validator Client Only', 'Validator Client Only', 'Failover Staking Node']

# Load environment variables from env file
load_dotenv("env")

# Set options to parsed arguments
EL_P2P_PORT=os.getenv('EL_P2P_PORT')
EL_RPC_PORT=os.getenv('EL_RPC_PORT')
EL_MAX_PEER_COUNT=os.getenv('EL_MAX_PEER_COUNT')
CL_P2P_PORT=os.getenv('CL_P2P_PORT')
CL_REST_PORT=os.getenv('CL_REST_PORT')
CL_MAX_PEER_COUNT=os.getenv('CL_MAX_PEER_COUNT')
CL_IP_ADDRESS=os.getenv('CL_IP_ADDRESS')
JWTSECRET_PATH=os.getenv('JWTSECRET_PATH')
GRAFFITI=os.getenv('GRAFFITI')
FEE_RECIPIENT_ADDRESS=os.getenv('FEE_RECIPIENT_ADDRESS')
MEV_MIN_BID=os.getenv('MEV_MIN_BID')
CSM_FEE_RECIPIENT_ADDRESS_MAINNET=os.getenv('CSM_FEE_RECIPIENT_ADDRESS_MAINNET')
CSM_FEE_RECIPIENT_ADDRESS_HOLESKY=os.getenv('CSM_FEE_RECIPIENT_ADDRESS_HOLESKY')
CSM_GRAFFITI=os.getenv('CSM_GRAFFITI')
CSM_MEV_MIN_BID=os.getenv('CSM_MEV_MIN_BID')
CSM_WITHDRAWAL_ADDRESS_MAINNET=os.getenv('CSM_WITHDRAWAL_ADDRESS_MAINNET')
CSM_WITHDRAWAL_ADDRESS_HOLESKY=os.getenv('CSM_WITHDRAWAL_ADDRESS_HOLESKY')

# Create argparse options
parser = argparse.ArgumentParser(description='Validator Install Options :: CoinCashew.com',formatter_class=argparse.ArgumentDefaultsHelpFormatter)
parser.add_argument("--network", type=str, help="Sets the Ethereum network", choices=valid_networks, default="")
parser.add_argument("--jwtsecret", type=str,help="Sets the jwtsecret file", default=JWTSECRET_PATH)
parser.add_argument("--graffiti", type=str, help="Sets the validator graffiti message", default=GRAFFITI)
parser.add_argument("--fee_address", type=str, help="Sets the fee recipient address", default="")
parser.add_argument("--el_p2p_port", type=int, help="Sets the Execution Client's P2P Port", default=EL_P2P_PORT)
parser.add_argument("--el_rpc_port", type=int, help="Sets the Execution Client's RPC Port", default=EL_RPC_PORT)
parser.add_argument("--el_max_peers", type=int, help="Sets the Execution Client's max peer count", default=EL_MAX_PEER_COUNT)
parser.add_argument("--cl_p2p_port", type=int, help="Sets the Consensus Client's P2P Port", default=CL_P2P_PORT)
parser.add_argument("--cl_rest_port", type=int, help="Sets the Consensus Client's REST Port", default=CL_REST_PORT)
parser.add_argument("--cl_max_peers", type=int, help="Sets the Consensus Client's max peer count", default=CL_MAX_PEER_COUNT)
parser.add_argument("--vc_only_bn_address", type=str, help="Sets Validator Only configuration's (beacon node) IP address, e.g. http://192.168.1.123:5052")
parser.add_argument("--skip_prompts", type=str, help="Performs non-interactive installation. Skips any interactive prompts if set to true", default="")
parser.add_argument("--install_config", type=str, help="Sets the node installation configuration", choices=valid_install_configs, default="")
parser.add_argument("-v", "--version", action="version", version="%(prog)s 1.0.0")
args = parser.parse_args()
#print(args)

def get_machine_architecture():
  machine_arch=platform.machine()
  if machine_arch == "x86_64":
    return "amd64"
  elif machine_arch == "aarch64":
    return "arm64"
  else:
    print(f'Unsupported machine architecture: {machine_arch}')
    exit(1)

def get_computer_platform():
  platform_name=platform.system()
  if platform_name == "Linux":
    return platform_name
  else:
    print(f'Unsupported platform: {platform_name}')
    exit(1)

binary_arch=get_machine_architecture()
platform_arch=get_computer_platform()

# Change to the home folder
os.chdir(os.path.expanduser("~"))

if not args.network and not args.skip_prompts:
    # Ask the user for Ethereum network
    index = SelectionMenu.get_selection(valid_networks,title='Validator Install Quickstart :: CoinCashew.com',subtitle='Installs Besu EL / Teku BN / Teku VC / MEVboost\nSelect Ethereum network:')

    # Exit selected
    if index == 4:
        exit(0)

    # Set network
    eth_network=valid_networks[index]
    eth_network=eth_network.lower()
else:
    eth_network=args.network.lower()

if not args.install_config and not args.skip_prompts:
    # Sepolia can only be full node
    if eth_network == "sepolia":
        install_config=valid_install_configs[1]
    else:
        # Ask the user for installation config
        index = SelectionMenu.get_selection(valid_install_configs,title='Validator Install Quickstart :: CoinCashew.com',subtitle='What type of installation would you like?\nSelect your type:',show_exit_option=False)
        # Set install configuration
        install_config=valid_install_configs[index]
else:
    install_config=args.install_config

# Sepolia is a permissioned validator set, default to NODE_ONLY
if eth_network == "sepolia":
    NODE_ONLY=True
    MEVBOOST_ENABLED=False
    VALIDATOR_ENABLED=False
    VALIDATOR_ONLY=False
else:
    match install_config:
       case "Solo Staking Node":
          NODE_ONLY=False
          MEVBOOST_ENABLED=True
          VALIDATOR_ENABLED=True
          VALIDATOR_ONLY=False
       case "Full Node Only":
          NODE_ONLY=True
          MEVBOOST_ENABLED=False
          VALIDATOR_ENABLED=False
          VALIDATOR_ONLY=False
       case "Lido CSM Staking Node":
          NODE_ONLY=False
          MEVBOOST_ENABLED=True
          VALIDATOR_ENABLED=True
          VALIDATOR_ONLY=False
          if eth_network == "mainnet":
              FEE_RECIPIENT_ADDRESS=CSM_FEE_RECIPIENT_ADDRESS_MAINNET
              CSM_WITHDRAWAL_ADDRESS=CSM_WITHDRAWAL_ADDRESS_MAINNET
          elif eth_network == "holesky":
              FEE_RECIPIENT_ADDRESS=CSM_FEE_RECIPIENT_ADDRESS_HOLESKY
              CSM_WITHDRAWAL_ADDRESS=CSM_WITHDRAWAL_ADDRESS_HOLESKY
          elif eth_network == "ephemery":
              FEE_RECIPIENT_ADDRESS=CSM_FEE_RECIPIENT_ADDRESS_HOLESKY
              CSM_WITHDRAWAL_ADDRESS=CSM_WITHDRAWAL_ADDRESS_HOLESKY              
          else:
            print(f'Unsupported Lido CSM Staking Node network: {eth_network}')
            exit(1)
          GRAFFITI=CSM_GRAFFITI
          MEV_MIN_BID=CSM_MEV_MIN_BID
       case "Lido CSM Validator Client Only":
          NODE_ONLY=False
          MEVBOOST_ENABLED=True
          VALIDATOR_ENABLED=True
          VALIDATOR_ONLY=True
          if eth_network == "mainnet":
              FEE_RECIPIENT_ADDRESS=CSM_FEE_RECIPIENT_ADDRESS_MAINNET
              CSM_WITHDRAWAL_ADDRESS=CSM_WITHDRAWAL_ADDRESS_MAINNET
          elif eth_network == "holesky":
              FEE_RECIPIENT_ADDRESS=CSM_FEE_RECIPIENT_ADDRESS_HOLESKY
              CSM_WITHDRAWAL_ADDRESS=CSM_WITHDRAWAL_ADDRESS_HOLESKY
          elif eth_network == "ephemery":
              FEE_RECIPIENT_ADDRESS=CSM_FEE_RECIPIENT_ADDRESS_HOLESKY
              CSM_WITHDRAWAL_ADDRESS=CSM_WITHDRAWAL_ADDRESS_HOLESKY
          else:
              print(f'Unsupported Lido CSM Staking Node network: {eth_network}')
              exit(1)
          GRAFFITI=CSM_GRAFFITI
          MEV_MIN_BID=CSM_MEV_MIN_BID
       case "Validator Client Only":
          NODE_ONLY=False
          MEVBOOST_ENABLED=True
          VALIDATOR_ENABLED=True
          VALIDATOR_ONLY=True
       case "Failover Staking Node":
          NODE_ONLY=False
          MEVBOOST_ENABLED=True
          VALIDATOR_ENABLED=False
          VALIDATOR_ONLY=False

# Ephemery override, always turn off mevboost
if eth_network == "ephemery":
    MEVBOOST_ENABLED=False

execution_client=""
consensus_client=""

if not VALIDATOR_ONLY:
    # Set clients to besu
    execution_client = valid_exec_clients[0]
    execution_client = execution_client.lower()

# Set clients to teku
consensus_client = valid_consensus_clients[0]
# Set to lowercase
consensus_client = consensus_client.lower()


# Validates an eth address
def is_valid_eth_address(address):
    pattern = re.compile("^0x[a-fA-F0-9]{40}$")
    return bool(pattern.match(address))

# Set FEE_RECIPIENT_ADDRESS
if not NODE_ONLY and FEE_RECIPIENT_ADDRESS == "" and not args.skip_prompts:
    # Prompt User for validator tips address
    while True:
        FEE_RECIPIENT_ADDRESS = Screen().input(f'Enter your Ethereum address (aka Fee Recipient Address)\n Hints: \n - Use ETH adddress from a hardware wallet.\n - Do not use an exchange address.\n > ')
        if is_valid_eth_address(FEE_RECIPIENT_ADDRESS):
            print("Valid Ethereum address")
            break
        else:
            print("Invalid Ethereum address. Try again.")


# Validates an CL beacon node address with port
def validate_beacon_node_address(ip_port):
    pattern = r"^(http|https|ws):\/\/((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)(:?\d{1,5})?$"
    if re.match(pattern, ip_port):
        return True
    else:
        return False

BN_ADDRESS=""
# Set BN_ADDRESS
if VALIDATOR_ONLY and args.vc_only_bn_address is None and not args.skip_prompts:
    # Prompt User for beacon node address
    while True:
        BN_ADDRESS = Screen().input(f'\nEnter your consensus client (beacon node) address.\nExample: http://192.168.1.123:5052\n > ')
        if validate_beacon_node_address(BN_ADDRESS):
            print("Valid beacon node address")
            break
        else:
            print("Invalid beacon node address. Try again.")
else:
    BN_ADDRESS=args.vc_only_bn_address



if not args.skip_prompts:
    # Format confirmation message
    if install_config == "Solo Staking Node" or install_config == "Lido CSM Staking Node" or install_config == "Failover Staking Node":
        message=f'\nConfirmation: Verify your settings\n\nNetwork: {eth_network.upper()}\nInstallation configuration: {install_config}\nFee Recipient Address: {FEE_RECIPIENT_ADDRESS}\n\nIs this correct?'
    elif install_config == "Full Node Only":
        message=f'\nConfirmation: Verify your settings\n\nNetwork: {eth_network.upper()}\nInstallation configuration: {install_config}\n\nIs this correct?'
    elif install_config == "Validator Client Only" or install_config == "Lido CSM Validator Client Only":
        message=f'\nConfirmation: Verify your settings\n\nNetwork: {eth_network.upper()}\nInstallation configuration: {install_config}\nFee Recipient Address: {FEE_RECIPIENT_ADDRESS}\nConsensus client (beacon node) address: {BN_ADDRESS}\n\nIs this correct?'
    else:
        print(f"\nError: Unknown install_config")
        exit(1)

    answer=PromptUtils(Screen()).prompt_for_yes_or_no(f'{message}')

    if not answer:
        file_name = os.path.basename(sys.argv[0])
        print(f'\nInstall cancelled by user. \n\nWhen ready, re-run install command:\npython3 {file_name}')
        exit(0)

# Initialize sync urls for selected network
if eth_network == "mainnet":
    sync_urls = mainnet_sync_urls
elif eth_network == "holesky":
    sync_urls = holesky_sync_urls
elif eth_network == "sepolia":
    sync_urls = sepolia_sync_urls
elif eth_network == "ephemery":
    sync_urls = ephemery_sync_urls

# Use a random sync url
sync_url = random.choice(sync_urls)[1]

def setup_node():
    if not VALIDATOR_ONLY:
        # Create JWT directory
        subprocess.run([f'sudo mkdir -p $(dirname {JWTSECRET_PATH})'], shell=True)

        # Generate random hex string and save to file
        rand_hex = subprocess.run(['openssl', 'rand', '-hex', '32'], stdout=subprocess.PIPE)
        subprocess.run([f'sudo tee {JWTSECRET_PATH}'], input=rand_hex.stdout, stdout=subprocess.DEVNULL, shell=True)

    # Update and upgrade packages
    subprocess.run(['sudo', 'apt', '-y', '-qq', 'update'])
    subprocess.run(['sudo', 'apt', '-y', '-qq', 'upgrade'])

    # Autoremove packages
    subprocess.run(['sudo', 'apt', '-y', '-qq' , 'autoremove'])

    # Chrony timesync package
    subprocess.run(['sudo', 'apt', '-y', '-qq', 'install', 'chrony'])

def install_mevboost():
    if MEVBOOST_ENABLED == True and not VALIDATOR_ONLY:
        # Step 1: Create mevboost service account
        os.system("sudo useradd --no-create-home --shell /bin/false mevboost")

        # Step 2: Install mevboost
        # Change to the home folder
        os.chdir(os.path.expanduser("~"))

        # Define the Github API endpoint to get the latest release
        url = 'https://api.github.com/repos/flashbots/mev-boost/releases/latest'

        # Send a GET request to the API endpoint
        response = requests.get(url)
        global mevboost_version
        mevboost_version = response.json()['tag_name']

        # Search for the asset with the name that ends in {platform_arch}_{binary_arch}.tar.gz
        assets = response.json()['assets']
        download_url = None
        for asset in assets:
            if asset['name'].endswith(f'{platform_arch.lower()}_{binary_arch}.tar.gz'):
                download_url = asset['browser_download_url']
                break

        if download_url is None:
            print("Error: Could not find the download URL for the latest release.")
            exit(1)

        # Download the latest release binary
        print(f">> Downloading mevboost > URL: {download_url}")

        try:
            # Download the file
            response = requests.get(download_url, stream=True)
            response.raise_for_status()  # Raise an exception for HTTP errors

            # Save the binary to the home folder
            with open("mev-boost.tar.gz", "wb") as f:
                for chunk in response.iter_content(1024):
                    if chunk:
                        f.write(chunk)

            print(f">> Successfully downloaded: {asset['name']}")

        except requests.exceptions.RequestException as e:
            print(f"Error: Unable to download file. Try again later. {e}")
            exit(1)

        # Extract the binary to the home folder
        with tarfile.open('mev-boost.tar.gz', 'r:gz') as tar:
            tar.extractall()

        # Move the binary to /usr/local/bin using sudo
        os.system(f"sudo mv mev-boost /usr/local/bin")

        # Remove files
        os.system(f"rm mev-boost.tar.gz LICENSE README.md")

        ##### MEV Boost Service File
        mev_boost_service_file_lines = [
        '[Unit]',
        f'Description=MEV-Boost Service for {eth_network.upper()}',
        'Wants=network-online.target',
        'After=network-online.target',
        'Documentation=https://www.coincashew.com',
        '',
        '[Service]',
        'User=mevboost',
        'Group=mevboost',
        'Type=simple',
        'Restart=always',
        'RestartSec=5',
        'ExecStart=/usr/local/bin/mev-boost \\',
        f'    -{eth_network} \\',
        f'    -min-bid {MEV_MIN_BID} \\',
        '    -relay-check \\',
        ]

        if eth_network == 'mainnet':
            relay_options=mainnet_relay_options
        elif eth_network == 'holesky':
            relay_options=holesky_relay_options
        else:
            relay_options=sepolia_relay_options

        for relay in relay_options:
            relay_line = f'    -relay {relay["url"]} \\'
            mev_boost_service_file_lines.append(relay_line)

        # Remove the trailing '\\' from the last relay line
        mev_boost_service_file_lines[-1] = mev_boost_service_file_lines[-1].rstrip(' \\')

        mev_boost_service_file_lines.extend([
            '',
            '[Install]',
            'WantedBy=multi-user.target',
        ])
        mev_boost_service_file = '\n'.join(mev_boost_service_file_lines)

        mev_boost_temp_file = 'mev_boost_temp.service'
        global mev_boost_service_file_path
        mev_boost_service_file_path = '/etc/systemd/system/mevboost.service'

        with open(mev_boost_temp_file, 'w') as f:
            f.write(mev_boost_service_file)

        os.system(f'sudo cp {mev_boost_temp_file} {mev_boost_service_file_path}')
        os.remove(mev_boost_temp_file)

def download_and_install_besu():
    if execution_client == 'besu':
        # Create User and directories
        subprocess.run(["sudo", "useradd", "--no-create-home", "--shell", "/bin/false", "execution"])
        subprocess.run(["sudo", "mkdir", "-p", "/var/lib/besu"])
        subprocess.run(["sudo", "chown", "-R", "execution:execution", "/var/lib/besu"])
        print(f">> Installing dependencies")
        subprocess.run(["sudo", "apt-get", '-qq', "install", "openjdk-21-jdk", "libjemalloc-dev", "-y"], check=True)

        # Define the Github API endpoint to get the latest release
        url = 'https://api.github.com/repos/hyperledger/besu/releases/latest'

        # Send a GET request to the API endpoint
        response = requests.get(url)
        global besu_version
        besu_version = response.json()['tag_name']

        assets = response.json()['assets']
        download_url = None
        for asset in assets:
            if asset['name'].endswith(f'besu-{besu_version}.tar.gz'):
                download_url = asset['browser_download_url']
                break

        if download_url is None:
            print("Error: Could not find the download URL for the latest release.")
            exit(1)

        # Download the latest release binary
        print(f">> Downloading Besu > URL: {download_url}")

        try:
            # Download the file
            response = requests.get(download_url, stream=True)
            response.raise_for_status()  # Raise an exception for HTTP errors

            # Save the binary to the home folder
            with open("besu.tar.gz", "wb") as f:
                for chunk in response.iter_content(1024):
                    if chunk:
                        f.write(chunk)

            print(f">> Successfully downloaded: {asset['name']}")

        except requests.exceptions.RequestException as e:
            print(f"Error: Unable to download file. Try again later. {e}")
            exit(1)

        # Extract the binary to the home folder
        with tarfile.open('besu.tar.gz', 'r:gz') as tar:
            tar.extractall()

        # Find the extracted folder
        extracted_folder = None
        for item in os.listdir():
            if item.startswith(f'besu-{besu_version}'):
                extracted_folder = item
                break

        if extracted_folder is None:
            print("Error: Could not find the extracted folder.")
            exit(1)

        # Move the binary to /usr/local/bin using sudo
        os.system(f"sudo mv {extracted_folder} ~/besu")
        os.system(f"sudo mv ~/besu /usr/local/bin/besu")

        # Remove the besu.tar.gz file
        os.remove('besu.tar.gz')

        ##### BESU SERVICE FILE ###########
        besu_service_file = f'''[Unit]
Description=Besu Execution Layer Client service for {eth_network.upper()}
After=network-online.target
Wants=network-online.target
Documentation=https://www.coincashew.com

[Service]
Type=simple
User=execution
Group=execution
Restart=on-failure
RestartSec=3
KillSignal=SIGINT
TimeoutStopSec=900
Environment="JAVA_OPTS=-Xmx5g"
ExecStart=/usr/local/bin/besu/bin/besu --network={eth_network} --p2p-port={EL_P2P_PORT} --rpc-http-port={EL_RPC_PORT} --engine-rpc-port=8551 --max-peers={EL_MAX_PEER_COUNT} --metrics-enabled=true --metrics-port=6060 --rpc-http-enabled=true --sync-mode=SNAP --data-storage-format=BONSAI --data-path="/var/lib/besu" --engine-jwt-secret={JWTSECRET_PATH}

[Install]
WantedBy=multi-user.target
'''

        besu_temp_file = 'execution_temp.service'
        global besu_service_file_path
        besu_service_file_path = '/etc/systemd/system/execution.service'

        with open(besu_temp_file, 'w') as f:
            f.write(besu_service_file)

        os.system(f'sudo cp {besu_temp_file} {besu_service_file_path}')

        os.remove(besu_temp_file)

def download_teku():
    if consensus_client == 'teku':
        # Change to the home folder
        os.chdir(os.path.expanduser("~"))

        # Define the Github API endpoint to get the latest release
        url = 'https://api.github.com/repos/ConsenSys/teku/releases/latest'

        # Send a GET request to the API endpoint
        response = requests.get(url)
        global teku_version
        teku_version = response.json()['tag_name']
        download_url = f'https://artifacts.consensys.net/public/teku/raw/names/teku.tar.gz/versions/{teku_version}/teku-{teku_version}.tar.gz'

        if download_url is None:
            print("Error: Could not find the download URL for the latest release.")
            exit(1)

        # Download the latest release binary
        print(f">> Downloading Teku > URL: {download_url}")

        try:
            # Download the file
            response = requests.get(download_url, stream=True)
            response.raise_for_status()  # Raise an exception for HTTP errors

            # Save the binary to the home folder
            with open("teku.tar.gz", "wb") as f:
                for chunk in response.iter_content(1024):
                    if chunk:
                        f.write(chunk)

            print(f">> Successfully downloaded: teku-{teku_version}.tar.gz")

        except requests.exceptions.RequestException as e:
            print(f"Error: Unable to download file. Try again later. {e}")
            exit(1)

        # Extract the binary to the home folder
        with tarfile.open('teku.tar.gz', 'r:gz') as tar:
            tar.extractall()

        # Find the extracted folder
        extracted_folder = None
        for item in os.listdir():
            if item.startswith(f'teku-'):
                extracted_folder = item
                break

        if extracted_folder is None:
            print("Error: Could not find the extracted folder.")
            exit(1)

        # Move the binary to /usr/local/bin using sudo
        os.system(f"sudo mv {extracted_folder} ~/teku")
        os.system(f"sudo mv ~/teku /usr/local/bin/teku")

        # Remove the teku.tar.gz file and extracted folder
        os.remove('teku.tar.gz')

def install_teku():
    if consensus_client == 'teku' and not VALIDATOR_ONLY:
        # Create data paths, service user, assign ownership permissions
        subprocess.run(['sudo', 'mkdir', '-p', '/var/lib/teku'])
        subprocess.run(['sudo', 'chmod', '700', '/var/lib/teku'])
        subprocess.run(['sudo', 'useradd', '--no-create-home', '--shell', '/bin/false', 'consensus'])
        subprocess.run(['sudo', 'chown', '-R', 'consensus:consensus', '/var/lib/teku'])
        print(f">> Installing dependencies")
        subprocess.run(["sudo", "apt-get", '-qq', "install", "openjdk-21-jdk", "libsnappy-dev", "libc6-dev", "-y"], check=True)

        if MEVBOOST_ENABLED == True:
            _mevparameters='--validators-builder-registration-default-enabled=true --builder-endpoint=http://127.0.0.1:18550'
        else:
            _mevparameters=''

        if VALIDATOR_ENABLED == True and FEE_RECIPIENT_ADDRESS:
            _feeparameters=f'--validators-proposer-default-fee-recipient={FEE_RECIPIENT_ADDRESS}'
        else:
            _feeparameters=''

        ########### Teku SERVICE FILE #############
        teku_service_file = f'''[Unit]
Description=Teku Beacon Node Consensus Client service for {eth_network.upper()}
Wants=network-online.target
After=network-online.target
Documentation=https://www.coincashew.com

[Service]
Type=simple
User=consensus
Group=consensus
Restart=on-failure
RestartSec=3
KillSignal=SIGINT
TimeoutStopSec=900
Environment=JAVA_OPTS=-Xmx6g
Environment=TEKU_OPTS=-XX:-HeapDumpOnOutOfMemoryError
ExecStart=/usr/local/bin/teku/bin/teku --network={eth_network} --data-path=/var/lib/teku --data-storage-mode=minimal --initial-state={sync_url} --ee-endpoint=http://127.0.0.1:8551 --ee-jwt-secret-file={JWTSECRET_PATH} --rest-api-enabled=true --rest-api-port={CL_REST_PORT} --p2p-port={CL_P2P_PORT} --p2p-peer-upper-bound={CL_MAX_PEER_COUNT} --metrics-enabled=true --metrics-port=8008 {_feeparameters} {_mevparameters}

[Install]
WantedBy=multi-user.target
'''
        teku_temp_file = 'consensus_temp.service'
        global teku_service_file_path
        teku_service_file_path = '/etc/systemd/system/consensus.service'

        with open(teku_temp_file, 'w') as f:
            f.write(teku_service_file)

        os.system(f'sudo cp {teku_temp_file} {teku_service_file_path}')
        os.remove(teku_temp_file)

def install_teku_validator():
    if MEVBOOST_ENABLED == True:
        _mevparameters='--validators-builder-registration-default-enabled=true'
    else:
        _mevparameters=''

    if VALIDATOR_ENABLED == True and FEE_RECIPIENT_ADDRESS:
        _feeparameters=f'--validators-proposer-default-fee-recipient={FEE_RECIPIENT_ADDRESS}'
    else:
        _feeparameters=''

    if BN_ADDRESS:
        _beaconnodeparameters=f'--beacon-node-api-endpoint={BN_ADDRESS}'
    else:
        _beaconnodeparameters=f'--beacon-node-api-endpoint=http://{CL_IP_ADDRESS}:{CL_REST_PORT}'

    if consensus_client == 'teku' and VALIDATOR_ENABLED == True:
        # Create data paths, service user, assign ownership permissions
        subprocess.run(['sudo', 'mkdir', '-p', '/var/lib/teku_validator'])
        subprocess.run(['sudo', 'chmod', '700', '/var/lib/teku_validator'])
        subprocess.run(['sudo', 'useradd', '--no-create-home', '--shell', '/bin/false', 'validator'])
        subprocess.run(['sudo', 'chown', '-R', 'validator:validator', '/var/lib/teku_validator'])

        teku_validator_file = f'''[Unit]
Description=Teku Validator Client service for {eth_network.upper()}
Wants=network-online.target
After=network-online.target
Documentation=https://www.coincashew.com

[Service]
Type=simple
User=validator
Group=validator
Restart=on-failure
RestartSec=3
KillSignal=SIGINT
TimeoutStopSec=900
ExecStart=/usr/local/bin/teku/bin/teku validator-client --network={eth_network} --data-path=/var/lib/teku_validator --validator-keys=/var/lib/teku_validator/validator_keys:/var/lib/teku_validator/validator_keys --metrics-enabled=true --metrics-port=8009 --validators-graffiti={GRAFFITI} {_beaconnodeparameters} {_feeparameters} {_mevparameters}

[Install]
WantedBy=multi-user.target
'''
        teku_temp_file = 'validator_temp.service'
        global teku_validator_file_path
        teku_validator_file_path = '/etc/systemd/system/validator.service'

        with open(teku_temp_file, 'w') as f:
            f.write(teku_validator_file)

        os.system(f'sudo cp {teku_temp_file} {teku_validator_file_path}')
        os.remove(teku_temp_file)

def finish_install():
    # Reload the systemd daemon
    subprocess.run(['sudo', 'systemctl', 'daemon-reload'])

    print(f'##########################\n')
    print(f'## Installation Summary ##\n')
    print(f'##########################\n')

    print(f'Installation Configuration: \n{install_config}\n')

    if execution_client == 'besu':
        print(f'Besu Version: \n{besu_version}\n')

    if consensus_client == 'teku':
        print(f'Teku Version: \n{teku_version}\n')

    if MEVBOOST_ENABLED and not VALIDATOR_ONLY:
        print(f'Mevboost Version: \n{mevboost_version}\n')

    print(f'Network: {eth_network.upper()}\n')

    if not VALIDATOR_ONLY:
        print(f'CheckPointSyncURL: {sync_url}\n')

    if VALIDATOR_ONLY and BN_ADDRESS:
        print(f'Beacon Node Address: {BN_ADDRESS}\n')
        os.chdir(os.path.expanduser("~/git/ethpillar"))
        os.system(f'cp .env.overrides.example .env.overrides')

    if NODE_ONLY == False:
        print(f'Validator Fee Recipient Address: {FEE_RECIPIENT_ADDRESS}\n')

    print(f'Systemd service files created:')
    if not VALIDATOR_ONLY:
        print(f'\n{teku_service_file_path}\n{besu_service_file_path}')
    if VALIDATOR_ENABLED == True:
        print(f'{teku_validator_file_path}')
    if MEVBOOST_ENABLED == True and not VALIDATOR_ONLY:
        print(f'{mev_boost_service_file_path}')

    if args.skip_prompts:
        print(f'\nNon-interactive install successful! Skipped prompts.')
        exit(0)

    # Prompt to start services
    if not VALIDATOR_ONLY:
        answer=PromptUtils(Screen()).prompt_for_yes_or_no(f"\nInstallation successful!\nSyncing a Teku/Besu node for validator duties can be as quick as a few hours.\nWould you like to start syncing now?")
        if answer:
            os.system(f'sudo systemctl start execution consensus')
            if MEVBOOST_ENABLED == True:
                os.system(f'sudo systemctl start mevboost')

    answer=PromptUtils(Screen()).prompt_for_yes_or_no(f"\nConfigure node to autostart:\nWould you like this node to autostart when system boots up?")

    # Prompt to enable autostart services
    if answer:
        if not VALIDATOR_ONLY:
            os.system(f'sudo systemctl enable execution consensus')
        if VALIDATOR_ENABLED == True:
            os.system(f'sudo systemctl enable validator')
        if MEVBOOST_ENABLED == True and not VALIDATOR_ONLY:
            os.system(f'sudo systemctl enable mevboost')

    # Ask CSM staker if they to manage validator keystores
    if install_config == 'Lido CSM Staking Node' or install_config == "Lido CSM Validator Client Only":
        answer=PromptUtils(Screen()).prompt_for_yes_or_no(f"\nWould you like to generate or import new Lido CSM validator keys now?\nReminder: Set the Lido withdrawal address to: {CSM_WITHDRAWAL_ADDRESS}")
        if answer:
            os.chdir(os.path.expanduser("~/git/ethpillar"))
            command = './manage_validator_keys.sh'
            subprocess.run(command)

    # Ask solo staker if they to manage validator keystores
    if install_config == 'Solo Staking Node' or install_config == 'Validator Client Only':
        answer=PromptUtils(Screen()).prompt_for_yes_or_no(f"\nWould you like to generate or import validator keys now?\nIf not, resume at: ethpillar > Validator Client ")
        if answer:
            os.chdir(os.path.expanduser("~/git/ethpillar"))
            command = './manage_validator_keys.sh'
            subprocess.run(command)

    # Failover staking node reminders
    if install_config == 'Failover Staking Node':
        print(f'\nReminder for Failover Staking Node configurations:\n1. Consensus Client: Expose consensus client RPC port\n2. UFW Firewall: Update to allow incoming traffic on port {CL_REST_PORT}\n3. UFW firewall: Whitelist the validator(s) IP address.')

    # Validator Client Only overrides
    if install_config == 'Validator Client Only' or install_config == "Lido CSM Validator Client Only":
        answer=PromptUtils(Screen()).prompt_for_yes_or_no(f"\nValidator Client Only:\n1) Be sure to expose your consensus client RPC port {CL_REST_PORT} and open firewall for this port.\n2) Would you like update your EL/CL override settings now?\nYour validator client needs to know EL/CL settings.\nIf not, update later at\nEthPillar > System Administration > Override environment variables.")
        if answer:
            command = ['nano', '~/git/ethpillar/.env.overrides']
            subprocess.run(command)

setup_node()
install_mevboost()
download_and_install_besu()
download_teku()
install_teku()
install_teku_validator()
finish_install()
