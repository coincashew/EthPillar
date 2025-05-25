# Author: coincashew.eth | coincashew.com
# License: GNU GPL
# Source: https://github.com/coincashew/ethpillar
#
# Node-Install: Standalone Lighthouse BN + Standalone Lighthouse VC + Reth EL + MEVboost
# Quickstart :: Rust Lang Clients :: Docker-free
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
import tempfile
import yaml
from consolemenu import *
from consolemenu.items import *
import argparse
from dotenv import load_dotenv, dotenv_values
from config import *
from tqdm import tqdm

def clear_screen():
    if os.name == 'posix':  # Unix-based systems (e.g., Linux, macOS)
        os.system('clear')
    elif os.name == 'nt':   # Windows
        os.system('cls')

clear_screen()  # Call the function to clear the screen

# Valid configurations
valid_networks = ['MAINNET','HOODI','EPHEMERY', 'HOLESKY', 'SEPOLIA']
valid_exec_clients = ['RETH']
valid_consensus_clients = ['LIGHTHOUSE']
valid_install_configs = ['Solo Staking Node', 'Full Node Only', 'Lido CSM Staking Node', 'Lido CSM Validator Client Only' ,'Validator Client Only', 'Failover Staking Node']

# Load environment variables from env file
load_dotenv("env")

# Set options to parsed arguments
EL_P2P_PORT=os.getenv('EL_P2P_PORT')
EL_P2P_PORT_2=os.getenv('EL_P2P_PORT_2')
EL_RPC_PORT=os.getenv('EL_RPC_PORT')
EL_MAX_PEER_COUNT=int(os.getenv('EL_MAX_PEER_COUNT', '50'))
CL_P2P_PORT=os.getenv('CL_P2P_PORT')
CL_P2P_PORT_2=os.getenv('CL_P2P_PORT_2')
CL_REST_PORT=os.getenv('CL_REST_PORT')
CL_MAX_PEER_COUNT=os.getenv('CL_MAX_PEER_COUNT')
CL_IP_ADDRESS=os.getenv('CL_IP_ADDRESS')
JWTSECRET_PATH=os.getenv('JWTSECRET_PATH')
GRAFFITI=os.getenv('GRAFFITI')
FEE_RECIPIENT_ADDRESS=os.getenv('FEE_RECIPIENT_ADDRESS')
MEV_MIN_BID=os.getenv('MEV_MIN_BID')
CSM_FEE_RECIPIENT_ADDRESS_MAINNET=os.getenv('CSM_FEE_RECIPIENT_ADDRESS_MAINNET')
CSM_FEE_RECIPIENT_ADDRESS_HOLESKY=os.getenv('CSM_FEE_RECIPIENT_ADDRESS_HOLESKY')
CSM_FEE_RECIPIENT_ADDRESS_HOODI=os.getenv('CSM_FEE_RECIPIENT_ADDRESS_HOODI')
CSM_GRAFFITI=os.getenv('CSM_GRAFFITI')
CSM_MEV_MIN_BID=os.getenv('CSM_MEV_MIN_BID')
CSM_WITHDRAWAL_ADDRESS_MAINNET=os.getenv('CSM_WITHDRAWAL_ADDRESS_MAINNET')
CSM_WITHDRAWAL_ADDRESS_HOLESKY=os.getenv('CSM_WITHDRAWAL_ADDRESS_HOLESKY')
CSM_WITHDRAWAL_ADDRESS_HOODI=os.getenv('CSM_WITHDRAWAL_ADDRESS_HOODI')
LAUNCHPAD_URL_LIDO_MAINNET=os.getenv('LAUNCHPAD_URL_LIDO_MAINNET')
LAUNCHPAD_URL_LIDO_HOODI=os.getenv('LAUNCHPAD_URL_LIDO_HOODI')
LAUNCHPAD_URL_LIDO_HOLESKY=os.getenv('LAUNCHPAD_URL_LIDO_HOLESKY')

# Create argparse options
parser = argparse.ArgumentParser(description='Node Install Options :: CoinCashew.com',formatter_class=argparse.ArgumentDefaultsHelpFormatter)
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
    index = SelectionMenu.get_selection(valid_networks,title='Node Install Quickstart :: CoinCashew.com',subtitle='Installs Reth EL / Lighthouse BN / Lighthouse VC / MEVboost\nSelect Ethereum network:')

    # Exit selected
    if index == len(valid_networks):
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
        index = SelectionMenu.get_selection(valid_install_configs,title='Node Install Quickstart :: CoinCashew.com',subtitle='What type of installation would you like?\nSelect your type:',show_exit_option=False)
        # Set install configuration
        install_config=valid_install_configs[index]
else:
    install_config=args.install_config

# Defaults to all false
MEVBOOST_ENABLED=False
VALIDATOR_ENABLED=False
VALIDATOR_ONLY=False
NODE_ONLY=False

# Sepolia is a permissioned validator set, default to NODE_ONLY
if eth_network == "sepolia":
    NODE_ONLY=True
else:
    match install_config:
       case "Solo Staking Node":
           MEVBOOST_ENABLED=True
           VALIDATOR_ENABLED=True
       case "Full Node Only":
           NODE_ONLY=True
       case "Lido CSM Staking Node":
           MEVBOOST_ENABLED=True
           VALIDATOR_ENABLED=True
       case "Lido CSM Validator Client Only":
           MEVBOOST_ENABLED=True
           VALIDATOR_ENABLED=True
           VALIDATOR_ONLY=True
       case "Validator Client Only":
           MEVBOOST_ENABLED=True
           VALIDATOR_ENABLED=True
           VALIDATOR_ONLY=True
       case "Failover Staking Node":
           MEVBOOST_ENABLED=True

# Apply Lido CSM configs
if install_config == "Lido CSM Staking Node" or install_config == "Lido CSM Validator Client Only":
    GRAFFITI=CSM_GRAFFITI
    MEV_MIN_BID=CSM_MEV_MIN_BID
    if eth_network == "mainnet":
        FEE_RECIPIENT_ADDRESS=CSM_FEE_RECIPIENT_ADDRESS_MAINNET
        CSM_WITHDRAWAL_ADDRESS=CSM_WITHDRAWAL_ADDRESS_MAINNET
        LAUNCHPAD_URL_LIDO=LAUNCHPAD_URL_LIDO_MAINNET
    elif eth_network == "holesky":
        FEE_RECIPIENT_ADDRESS=CSM_FEE_RECIPIENT_ADDRESS_HOLESKY
        CSM_WITHDRAWAL_ADDRESS=CSM_WITHDRAWAL_ADDRESS_HOLESKY
        LAUNCHPAD_URL_LIDO=LAUNCHPAD_URL_LIDO_HOLESKY
    elif eth_network == "hoodi":
        FEE_RECIPIENT_ADDRESS=CSM_FEE_RECIPIENT_ADDRESS_HOODI
        CSM_WITHDRAWAL_ADDRESS=CSM_WITHDRAWAL_ADDRESS_HOODI
        LAUNCHPAD_URL_LIDO=LAUNCHPAD_URL_LIDO_HOODI
    elif eth_network == "ephemery":
        FEE_RECIPIENT_ADDRESS=CSM_FEE_RECIPIENT_ADDRESS_HOLESKY
        CSM_WITHDRAWAL_ADDRESS=CSM_WITHDRAWAL_ADDRESS_HOLESKY
        LAUNCHPAD_URL_LIDO=LAUNCHPAD_URL_LIDO_HOLESKY
    else:
        print(f'Unsupported Lido CSM Staking Node network: {eth_network}')
        exit(1)

# Ephemery override, turn off mevboost
if eth_network == "ephemery":
    MEVBOOST_ENABLED=False

execution_client=""
consensus_client=""

if not VALIDATOR_ONLY:
    # Set clients to reth
    execution_client = valid_exec_clients[0]
    execution_client = execution_client.lower()

# Set clients to lighthouse
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
    elif install_config == "Validator Client Only" or install_config == "Lido CSM Validator Client Only" :
        message=f'\nConfirmation: Verify your settings\n\nNetwork: {eth_network.upper()}\nInstallation configuration: {install_config}\nFee Recipient Address: {FEE_RECIPIENT_ADDRESS}\n\nConsensus client (beacon node) address: {BN_ADDRESS}\n\nIs this correct?'
    else:
        print(f"\nError: Unknown install_config")
        exit(1)

    answer=PromptUtils(Screen()).prompt_for_yes_or_no(f'{message}')

    if not answer:
        file_name = os.path.basename(sys.argv[0])
        print(f'\nInstall cancelled by user. \n\nWhen ready, re-run install command:\npython3 {file_name}')
        exit(0)

def setup_ephemery_network(genesis_repository):
    testnet_dir = "/opt/ethpillar/testnet"

    def get_github_release(repo):
        url = f"https://api.github.com/repos/{repo}/releases/latest"
        response = requests.get(url)
        if response.status_code == 200:
            data = json.loads(response.text)
            return data.get('tag_name')
        else:
            return None

    def download_genesis_release(genesis_release):
        # remove old genesis and setup dir
        if os.path.exists(testnet_dir):
            subprocess.run(['sudo', 'rm', '-rf', testnet_dir], check=True)
        subprocess.run(['sudo', 'mkdir', '-p', testnet_dir], check=True)
        subprocess.run(['sudo', 'chmod', '-R', '755', testnet_dir], check=True)

        # get latest genesis
        url = f"https://github.com/{genesis_repository}/releases/download/{genesis_release}/testnet-all.tar.gz"
        print(f">> Downloading {genesis_release} genesis files > URL: {url}")
        response = requests.get(url, stream=True)
        if response.status_code == 200:
            temp_dir = tempfile.mkdtemp()
            with tarfile.open(fileobj=response.raw, mode='r|gz') as tar:
                tar.extractall(f"{temp_dir}")
            os.system(f"sudo mv {temp_dir}/* {testnet_dir}")
            print(f">> Successfully downloaded {genesis_release} genesis files")
        else:
            print("Failed to download genesis release")

    genesis_release = get_github_release(genesis_repository)
    if genesis_release:
        download_genesis_release(genesis_release)
    else:
        print(f"Failed to retrieve genesis release for {genesis_repository}")

# Initialize sync urls for selected network
if eth_network == "mainnet":
    sync_urls = mainnet_sync_urls
elif eth_network == "holesky":
    sync_urls = holesky_sync_urls
elif eth_network == "sepolia":
    sync_urls = sepolia_sync_urls
elif eth_network == "hoodi":
    sync_urls = hoodi_sync_urls
elif eth_network == "ephemery":
    sync_urls = ephemery_sync_urls
    setup_ephemery_network("ephemery-testnet/ephemery-genesis")

sync_url = random.choice(sync_urls)[1]

def setup_node():
    if not VALIDATOR_ONLY:
        # Create JWT directory
        subprocess.run(f"sudo mkdir -p \"$(dirname \"{JWTSECRET_PATH}\")\"", shell=True, check=True)

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
    if MEVBOOST_ENABLED and not VALIDATOR_ONLY:
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
            total_size = int(response.headers.get('content-length', 0))
            block_size = 1024
            t = tqdm(total=total_size, unit='B', unit_scale=True)

            tar_filename = "mev-boost.tar.gz"
            # Save the binary to the home folder
            with open(tar_filename, "wb") as f:
                for chunk in response.iter_content(block_size):
                    if chunk:
                        t.update(len(chunk))
                        f.write(chunk)
            t.close()
            print(f">> Successfully downloaded: {asset['name']}")

        except requests.exceptions.RequestException as e:
            print(f"Error: Unable to download file. Try again later. {e}")
            exit(1)

        # Extract the binary to the home folder
        with tarfile.open(tar_filename, "r:gz") as tar:
            def is_within_directory(directory, target):
                abs_directory=os.path.abspath(directory)
                abs_target=os.path.abspath(target)
                return os.path.commonpath([abs_directory]) == os.path.commonpath([abs_directory, abs_target])

            for member in tar.getmembers():
                member_path = os.path.join(os.getcwd(), member.name)
                if not is_within_directory(os.getcwd(), member_path):
                    raise Exception("Attempted Path Traversal in Tar File")
            tar.extractall()

        # Move the binary to /usr/local/bin using sudo
        os.system(f"sudo mv mev-boost /usr/local/bin")

        # Remove files
        os.system(f"rm {tar_filename} LICENSE README.md")

        ##### MEV Boost Service File
        mev_boost_service_file_lines = [
        '[Unit]',
        f'Description=MEV-Boost Service for {eth_network.upper()}',
        'Wants=network-online.target',
        'After=network-online.target',
        'Documentation=https://docs.coincashew.com',
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
        elif eth_network == 'hoodi':
            relay_options=hoodi_relay_options
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

def download_and_install_reth():
    if execution_client == 'reth':
        # Create User and directories
        subprocess.run(["sudo", "useradd", "--no-create-home", "--shell", "/bin/false", "execution"])
        subprocess.run(["sudo", "mkdir", "-p", "/var/lib/reth"])
        subprocess.run(["sudo", "chown", "-R", "execution:execution", "/var/lib/reth"])

        # Define the Github API endpoint to get the latest release
        url = 'https://api.github.com/repos/paradigmxyz/reth/releases/latest'

        # Send a GET request to the API endpoint
        response = requests.get(url)
        global reth_version
        reth_version = response.json()['tag_name']

        # Search for the asset
        assets = response.json()['assets']
        download_url = None
        tar_filename = None
        for asset in assets:
            if asset['name'].endswith(f'{platform.machine().lower()}-unknown-{platform_arch.lower()}-gnu.tar.gz') and asset['name'].startswith(f"reth-{reth_version}"):
                download_url = asset['browser_download_url']
                tar_filename = asset['name']
                break

        if download_url is None or tar_filename is None:
            print("Error: Could not find the download URL for the latest release.")
            exit(1)

        # Download the latest release binary
        print(f">> Downloading Reth > URL: {download_url}")

        try:
            # Download the file
            response = requests.get(download_url, stream=True)
            response.raise_for_status()  # Raise an exception for HTTP errors
            total_size = int(response.headers.get('content-length', 0))
            block_size = 1024
            t = tqdm(total=total_size, unit='B', unit_scale=True)

            # Save the binary to the home folder
            with open(f"{tar_filename}", "wb") as f:
                for chunk in response.iter_content(block_size):
                    if chunk:
                        t.update(len(chunk))
                        f.write(chunk)
            t.close()
            print(f">> Successfully downloaded: {asset['name']}")

        except requests.exceptions.RequestException as e:
            print(f"Error: Unable to download file. Try again later. {e}")
            exit(1)

        # Extract the binary to the home folder
        with tarfile.open(tar_filename, "r:gz") as tar:
            def is_within_directory(directory, target):
                abs_directory=os.path.abspath(directory)
                abs_target=os.path.abspath(target)
                return os.path.commonpath([abs_directory]) == os.path.commonpath([abs_directory, abs_target])

            for member in tar.getmembers():
                member_path = os.path.join(os.getcwd(), member.name)
                if not is_within_directory(os.getcwd(), member_path):
                    raise Exception("Attempted Path Traversal in Tar File")
            tar.extractall()

        # Move the binary to /usr/local/bin using sudo
        os.system(f"sudo mv reth /usr/local/bin")

        # Remove the downloaded .tar.gz file
        os.remove(f"{tar_filename}")

        # Ensure +x permissions, update owner
        subprocess.run(["sudo", "chmod", "a+x", "/usr/local/bin/reth"])
        subprocess.run(["sudo", "chown", "execution:execution", "/usr/local/bin/reth"])

        # Process custom testnet configuration
        if eth_network=="ephemery":
            file_path = f"/opt/ethpillar/testnet/bootnode.txt"
            with open(file_path, "r") as file:
                bootnodes = ",".join(file.read().splitlines())
            _network=f"--chain /opt/ethpillar/testnet/genesis.json --bootnodes {bootnodes}"
        else:
            _network=f"--chain {eth_network}"

        # Half peers for reth
        global EL_MAX_PEER_COUNT
        EL_MAX_PEER_COUNT = max(1, int(EL_MAX_PEER_COUNT) // 2)
        ##### RETH SERVICE FILE ###########
        reth_service_file = f'''[Unit]
Description=Reth Execution Layer Client service for {eth_network.upper()}
After=network-online.target
Wants=network-online.target
Documentation=https://docs.coincashew.com

[Service]
Type=simple
User=execution
Group=execution
Restart=on-failure
RestartSec=3
KillSignal=SIGINT
TimeoutStopSec=900
Environment=RUST_LOG=info
ExecStart=/usr/local/bin/reth node {_network} --datadir=/var/lib/reth --log.file.directory=/var/lib/reth/logs --metrics 127.0.0.1:6060 --port {EL_P2P_PORT} --discovery.port {EL_P2P_PORT} --enable-discv5-discovery --discovery.v5.port {EL_P2P_PORT_2} --max-outbound-peers {EL_MAX_PEER_COUNT} --max-inbound-peers {EL_MAX_PEER_COUNT} --http --http.port {EL_RPC_PORT} --http.api="rpc,eth,web3,net,debug" --authrpc.jwtsecret {JWTSECRET_PATH}

[Install]
WantedBy=multi-user.target
'''

        reth_temp_file = 'execution_temp.service'
        global reth_service_file_path
        reth_service_file_path = '/etc/systemd/system/execution.service'

        with open(reth_temp_file, 'w') as f:
            f.write(reth_service_file)

        os.system(f'sudo cp {reth_temp_file} {reth_service_file_path}')

        os.remove(reth_temp_file)

def download_lighthouse():
    if consensus_client == 'lighthouse':
        # Change to the home folder
        os.chdir(os.path.expanduser("~"))

        # Define the Github API endpoint to get the latest release
        url = 'https://api.github.com/repos/sigp/lighthouse/releases/latest'

        # Send a GET request to the API endpoint
        response = requests.get(url)
        global lighthouse_version
        lighthouse_version = response.json()['tag_name']

        # Adjust binary name
        if binary_arch == "amd64":
          _arch="x86_64"
        elif binary_arch == "arm64":
          _arch="aarch64"
        else:
           print("Error: Unknown binary architecture.")
           exit(1)

        # Search for the asset appropriate for this system architecture and platform
        assets = response.json()['assets']
        download_url = None
        tar_filename = None
        for asset in assets:
            if f'{_arch}-unknown-{platform_arch.lower()}' in asset['name'] and asset['name'].endswith('gnu.tar.gz'):
                if asset['name'].startswith('lighthouse'):
                    download_url = asset['browser_download_url']
                    tar_filename = asset['name']
                    break

        if download_url is None or tar_filename is None:
            print("Error: Could not find the download URL for the latest release.")
            exit(1)

        # Download the latest release binary
        print(f">> Downloading Lighthouse > URL: {download_url}")

        try:
            # Download the file
            response = requests.get(download_url, stream=True)
            response.raise_for_status()  # Raise an exception for HTTP errors
            total_size = int(response.headers.get('content-length', 0))
            block_size = 1024
            t = tqdm(total=total_size, unit='B', unit_scale=True)

            # Save the binary to the home folder
            with open(f"{tar_filename}", "wb") as f:
                for chunk in response.iter_content(block_size):
                    if chunk:
                        t.update(len(chunk))
                        f.write(chunk)
            t.close()
            print(f">> Successfully downloaded: {asset['name']}")

        except requests.exceptions.RequestException as e:
            print(f"Error: Unable to download file. Try again later. {e}")
            exit(1)

        # Extract the binary to the home folder
        with tarfile.open(tar_filename, "r:gz") as tar:
            def is_within_directory(directory, target):
                abs_directory=os.path.abspath(directory)
                abs_target=os.path.abspath(target)
                return os.path.commonpath([abs_directory]) == os.path.commonpath([abs_directory, abs_target])

            for member in tar.getmembers():
                member_path = os.path.join(os.getcwd(), member.name)
                if not is_within_directory(os.getcwd(), member_path):
                    raise Exception("Attempted Path Traversal in Tar File")
            tar.extractall()

        # Move the binary to /usr/local/bin using sudo
        os.system(f"sudo mv lighthouse /usr/local/bin")

        # Ensure +x permissions
        subprocess.run(["sudo", "chmod", "a+x", "/usr/local/bin/lighthouse"])

        # Remove the downloaded .tar.gz file
        os.remove(f"{tar_filename}")

def install_lighthouse():
    if consensus_client == 'lighthouse' and not VALIDATOR_ONLY:
        # Create data paths, service user, assign ownership permissions
        subprocess.run(['sudo', 'mkdir', '-p', '/var/lib/lighthouse'])
        subprocess.run(['sudo', 'chmod', '700', '/var/lib/lighthouse'])
        subprocess.run(['sudo', 'useradd', '--no-create-home', '--shell', '/bin/false', 'consensus'])
        subprocess.run(['sudo', 'chown', '-R', 'consensus:consensus', '/var/lib/lighthouse'])

        if MEVBOOST_ENABLED:
            _mevparameters='--builder http://127.0.0.1:18550'
        else:
            _mevparameters=''

        # Process custom testnet configuration
        if eth_network=="ephemery":
            file_path = f"/opt/ethpillar/testnet/bootstrap_nodes.txt"
            with open(file_path, "r") as file:
                bootnodes = ",".join(file.read().splitlines())
            _network=f"--testnet-dir=/opt/ethpillar/testnet --boot-nodes={bootnodes}"
        else:
            _network=f"--network={eth_network}"

        ########### LIGHTHOUSE SERVICE FILE #############
        lighthouse_service_file = f'''[Unit]
Description=Lighthouse Consensus Client service for {eth_network.upper()}
Wants=network-online.target
After=network-online.target
Documentation=https://docs.coincashew.com

[Service]
Type=simple
User=consensus
Group=consensus
Restart=on-failure
RestartSec=3
KillSignal=SIGINT
TimeoutStopSec=900
ExecStart=/usr/local/bin/lighthouse bn {_network} --datadir=/var/lib/lighthouse --gui --port={CL_P2P_PORT} --quic-port={CL_P2P_PORT_2} --target-peers={CL_MAX_PEER_COUNT} --http-port={CL_REST_PORT} --staking --validator-monitor-auto --checkpoint-sync-url={sync_url} --execution-endpoint=http://127.0.0.1:8551 --metrics --metrics-address=127.0.0.1 --metrics-port=8008 --execution-jwt={JWTSECRET_PATH} {_mevparameters}

[Install]
WantedBy=multi-user.target
'''
        lighthouse_temp_file = 'consensus_temp.service'
        global lighthouse_service_file_path
        lighthouse_service_file_path = '/etc/systemd/system/consensus.service'

        with open(lighthouse_temp_file, 'w') as f:
            f.write(lighthouse_service_file)

        os.system(f'sudo cp {lighthouse_temp_file} {lighthouse_service_file_path}')
        os.remove(lighthouse_temp_file)

def install_lighthouse_validator():
    if MEVBOOST_ENABLED:
        _mevparameters='--builder-proposals'
    else:
        _mevparameters=''

    if VALIDATOR_ENABLED and FEE_RECIPIENT_ADDRESS:
        _feeparameters=f'--suggested-fee-recipient={FEE_RECIPIENT_ADDRESS}'
    else:
        _feeparameters=''

    if BN_ADDRESS:
        _beaconnodeparameters=f'--beacon-nodes={BN_ADDRESS}'
    else:
        _beaconnodeparameters = (
            f'--beacon-nodes=http://{CL_IP_ADDRESS}:{CL_REST_PORT}'
            if CL_IP_ADDRESS
            else '--beacon-nodes=http://127.0.0.1:5052'
        )

    # Process custom testnet configuration
    if eth_network=="ephemery":
        _network=f"--testnet-dir=/opt/ethpillar/testnet"
    else:
        _network=f"--network={eth_network}"        

    if consensus_client == 'lighthouse' and VALIDATOR_ENABLED:
        # Create data paths, service user, assign ownership permissions
        subprocess.run(['sudo', 'mkdir', '-p', '/var/lib/lighthouse_validator'])
        subprocess.run(['sudo', 'useradd', '--no-create-home', '--shell', '/bin/false', 'validator'])
        subprocess.run(['sudo', 'chown', '-R', 'validator:validator', '/var/lib/lighthouse_validator'])
        subprocess.run(['sudo', 'chmod', '700', '/var/lib/lighthouse_validator'])

        lighthouse_validator_file = f'''[Unit]
Description=Lighthouse Validator Client service for {eth_network.upper()}
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
ExecStart=/usr/local/bin/lighthouse vc {_network} --datadir=/var/lib/lighthouse_validator --http --metrics --metrics-address=127.0.0.1 --metrics-port=8009 --graffiti={GRAFFITI} {_beaconnodeparameters} {_feeparameters} {_mevparameters}

[Install]
WantedBy=multi-user.target
'''
        lighthouse_temp_file = 'validator_temp.service'
        global lighthouse_validator_file_path
        lighthouse_validator_file_path = '/etc/systemd/system/validator.service'

        with open(lighthouse_temp_file, 'w') as f:
            f.write(lighthouse_validator_file)

        os.system(f'sudo cp {lighthouse_temp_file} {lighthouse_validator_file_path}')
        os.remove(lighthouse_temp_file)

def finish_install():
    # Reload the systemd daemon
    subprocess.run(['sudo', 'systemctl', 'daemon-reload'])

    print(f'##########################\n')
    print(f'## Installation Summary ##\n')
    print(f'##########################\n')

    print(f'Installation Configuration: \n{install_config}\n')

    if execution_client == 'reth':
        print(f'Reth Version: \n{reth_version}\n')

    if consensus_client == 'lighthouse':
        print(f'Lighthouse Version: \n{lighthouse_version}\n')

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
        print(f'\n{lighthouse_service_file_path}\n{reth_service_file_path}')
    if VALIDATOR_ENABLED:
        print(f'{lighthouse_validator_file_path}')
    if MEVBOOST_ENABLED and not VALIDATOR_ONLY:
        print(f'{mev_boost_service_file_path}')

    if args.skip_prompts:
        print(f'\nNon-interactive install successful! Skipped prompts.')
        exit(0)

    # Prompt to start services
    if not VALIDATOR_ONLY:
        answer=PromptUtils(Screen()).prompt_for_yes_or_no(f"\nInstallation successful!\nSyncing a Lighthouse/Reth node for validator duties can be as quick as a few hours.\nWould you like to start syncing now?")
        if answer:
            os.system(f'sudo systemctl start execution consensus')
            if MEVBOOST_ENABLED:
                os.system(f'sudo systemctl start mevboost')

    # Prompt to enable autostart services
    answer=PromptUtils(Screen()).prompt_for_yes_or_no(f"\nConfigure node to autostart:\nWould you like this node to autostart when system boots up?")
    if answer:
        if not VALIDATOR_ONLY:
            os.system(f'sudo systemctl enable execution consensus')
        if VALIDATOR_ENABLED:
            os.system(f'sudo systemctl enable validator')
        if MEVBOOST_ENABLED and not VALIDATOR_ONLY:
            os.system(f'sudo systemctl enable mevboost')

    # Show Lido CSM Instructions and ask CSM staker if they to manage validator keystores
    if install_config == 'Lido CSM Staking Node' or install_config == 'Lido CSM Validator Client Only':
        os.system(f'whiptail --title "Next Steps: Lido CSM" --msgbox "1. Generate validator keys\n\n2. Upload your keys & bond at {LAUNCHPAD_URL_LIDO}\n\n3. Fully sync your node.\n\nThanks for using Lido CSM and EthPillar!" 15 78')
        answer=PromptUtils(Screen()).prompt_for_yes_or_no(f"\nWould you like to generate or import new Lido CSM validator keys now?\nReminder: Set the Lido withdrawal address to: {CSM_WITHDRAWAL_ADDRESS}")
        if answer:
            os.chdir(os.path.expanduser("~/git/ethpillar"))
            command = './manage_validator_keys.sh'
            subprocess.run(command)

    # Ask solo staker if they to manage validator keystores
    if install_config == 'Solo Staking Node' or install_config == 'Validator Client Only':
        os.system(f'whiptail --title "Next Steps: Staking" --msgbox "1. Generate or import validator keys\n\n2. Let your node fully sync\n\nThanks for using EthPillar!" 13 78')
        answer=PromptUtils(Screen()).prompt_for_yes_or_no(f"\nWould you like to generate or import validator keys now?\nIf not, resume at: ethpillar > Validator Client ")
        if answer:
            os.chdir(os.path.expanduser("~/git/ethpillar"))
            command = './manage_validator_keys.sh'
            subprocess.run(command)

    # Failover staking node reminders
    if install_config == 'Failover Staking Node':
        print(f'\nReminder for Failover Staking Node configurations:\n1. Consensus Client: Expose consensus client RPC port\n2. UFW Firewall: Update to allow incoming traffic on port {CL_REST_PORT}\n3. UFW firewall: Whitelist the validator(s) IP address.')

    # Validator Client Only overrides
    if install_config == 'Validator Client Only' or install_config == 'Lido CSM Validator Client Only':
        answer=PromptUtils(Screen()).prompt_for_yes_or_no(f"\nValidator Client Only:\n1) Be sure to expose your consensus client RPC port {CL_REST_PORT} and open firewall for this port.\n2) Would you like update your EL/CL override settings now?\nYour validator client needs to know EL/CL settings.\nIf not, update later at\nEthPillar > System Administration > Override environment variables.")
        if answer:
            command = ['nano', '~/git/ethpillar/.env.overrides']
            subprocess.run(command)

setup_node()
install_mevboost()
download_and_install_reth()
download_lighthouse()
install_lighthouse()
install_lighthouse_validator()
finish_install()
