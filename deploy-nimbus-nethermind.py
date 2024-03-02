# Author: coincashew.eth | coincashew.com
# License: GNU GPL
# Source: https://github.com/coincashew/ethpillar
#
# Validator-Install: Standalone Nimbus BN + Standalone Nimbus VC + Nethermind EL + MEVboost
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
from consolemenu import *
from consolemenu.items import *
import argparse
from dotenv import load_dotenv, dotenv_values

# Valid configurations
valid_networks = ['MAINNET', 'HOLESKY', 'SEPOLIA']
valid_exec_clients = ['NETHERMIND']
valid_consensus_clients = ['NIMBUS']

# MEV Relay Data
mainnet_relay_options = [
    {'name': 'Aestus', 'url': 'https://0xa15b52576bcbf1072f4a011c0f99f9fb6c66f3e1ff321f11f461d15e31b1cb359caa092c71bbded0bae5b5ea401aab7e@aestus.live'},
    {'name': 'Agnostic Gnosis', 'url': 'https://0xa7ab7a996c8584251c8f925da3170bdfd6ebc75d50f5ddc4050a6fdc77f2a3b5fce2cc750d0865e05d7228af97d69561@agnostic-relay.net'},
    {'name': 'bloXroute Max Profit', 'url': 'https://0x8b5d2e73e2a3a55c6c87b8b6eb92e0149a125c852751db1422fa951e42a09b82c142c3ea98d0d9930b056a3bc9896b8f@bloxroute.max-profit.blxrbdn.com'},
    {'name': 'bloXroute Regulated', 'url': 'https://0xb0b07cd0abef743db4260b0ed50619cf6ad4d82064cb4fbec9d3ec530f7c5e6793d9f286c4e082c0244ffb9f2658fe88@bloxroute.regulated.blxrbdn.com'},
    {'name': 'Eden Network', 'url': 'https://0xb3ee7afcf27f1f1259ac1787876318c6584ee353097a50ed84f51a1f21a323b3736f271a895c7ce918c038e4265918be@relay.edennetwork.io'},
    {'name': 'Flashbots', 'url': 'https://0xac6e77dfe25ecd6110b8e780608cce0dab71fdd5ebea22a16c0205200f2f8e2e3ad3b71d3499c54ad14d6c21b41a37ae@boost-relay.flashbots.net'},
    {'name': 'Ultra Sound', 'url': 'https://0xa1559ace749633b997cb3fdacffb890aeebdb0f5a3b6aaa7eeeaf1a38af0a8fe88b9e4b1f61f236d2e64d95733327a62@relay.ultrasound.money'},
    {'name': 'Wenmerge', 'url': 'https://0x8c7d33605ecef85403f8b7289c8058f440cbb6bf72b055dfe2f3e2c6695b6a1ea5a9cd0eb3a7982927a463feb4c3dae2@relay.wenmerge.com'}
]

holesky_relay_options = [
    {'name': 'Flashbots', 'url': 'https://0xafa4c6985aa049fb79dd37010438cfebeb0f2bd42b115b89dd678dab0670c1de38da0c4e9138c9290a398ecd9a0b3110@boost-relay-holesky.flashbots.net'},
    {'name': 'bloXroute', 'url': 'https://0x821f2a65afb70e7f2e820a925a9b4c80a159620582c1766b1b09729fec178b11ea22abb3a51f07b288be815a1a2ff516@bloxroute.holesky.blxrbdn.com'},
    {'name': 'Eden Network', 'url': 'https://0xb1d229d9c21298a87846c7022ebeef277dfc321fe674fa45312e20b5b6c400bfde9383f801848d7837ed5fc449083a12@relay-holesky.edennetwork.io'},
    {'name': 'Titan Relay', 'url': 'https://0xaa58208899c6105603b74396734a6263cc7d947f444f396a90f7b7d3e65d102aec7e5e5291b27e08d02c50a050825c2f@holesky.titanrelay.xyz'}
]

sepolia_relay_options = [
    {'name': 'Flashbots', 'url': 'https://0x845bd072b7cd566f02faeb0a4033ce9399e42839ced64e8b2adcfc859ed1e8e1a5a293336a49feac6d9a5edb779be53a@boost-relay-sepolia.flashbots.net'}
]

# Checkpoint-Sync Data
mainnet_sync_urls = [
    ("ETHSTAKER", "https://beaconstate.ethstaker.cc"),
    ("BEACONCHA.IN", "https://sync-mainnet.beaconcha.in"),
    ("ATTESTANT", "https://mainnet-checkpoint-sync.attestant.io"),
    ("SIGMA PRIME", "https://mainnet.checkpoint.sigp.io"),
    ("Lodestar", "https://beaconstate-mainnet.chainsafe.io"),
    ("BeaconState.info", "https://beaconstate.info"),
    ("PietjePuk", "https://checkpointz.pietjepuk.net"),
]

holesky_sync_urls = [
    ("ETHSTAKER", "https://holesky.beaconstate.ethstaker.cc"),
    ("BEACONSTATE", "https://holesky.beaconstate.info"),
    ("EF DevOps", "https://checkpoint-sync.holesky.ethpandaops.io"),
    ("Lodestar", "https://beaconstate-holesky.chainsafe.io"),
]

sepolia_sync_urls = [
    ("Beaconstate", "https://sepolia.beaconstate.info"),
    ("Lodestar", "https://beaconstate-sepolia.chainsafe.io"),
    ("EF DevOps", "https://checkpoint-sync.sepolia.ethpandaops.io"),
]

# Load environment variables from env file
load_dotenv("env")

# Set options to parsed arguments
EL_P2P_PORT=os.getenv('EL_P2P_PORT')
EL_RPC_PORT=os.getenv('EL_RPC_PORT')
EL_MAX_PEER_COUNT=os.getenv('EL_MAX_PEER_COUNT')
CL_P2P_PORT=os.getenv('CL_P2P_PORT')
CL_REST_PORT=os.getenv('CL_REST_PORT')
CL_MAX_PEER_COUNT=os.getenv('CL_MAX_PEER_COUNT')
JWTSECRET_PATH=os.getenv('JWTSECRET_PATH')
GRAFFITI=os.getenv('GRAFFITI')
FEE_RECIPIENT_ADDRESS=os.getenv('FEE_RECIPIENT_ADDRESS')

# Create argparse options
parser = argparse.ArgumentParser(description='Validator Install Options :: CoinCashew.com',formatter_class=argparse.ArgumentDefaultsHelpFormatter)
parser.add_argument("--network", type=str, help="Sets the Ethereum network", choices=valid_networks, default="MAINNET")
parser.add_argument("--jwtsecret", type=str,help="Sets the jwtsecret file", default=JWTSECRET_PATH)
parser.add_argument("--graffiti", type=str, help="Sets the validator graffiti message", default=GRAFFITI)
parser.add_argument("--fee_address", type=str, help="Sets the fee recipient address", default="")
parser.add_argument("--el_p2p_port", type=int, help="Sets the Execution Client's P2P Port", default=EL_P2P_PORT)
parser.add_argument("--el_rpc_port", type=int, help="Sets the Execution Client's RPC Port", default=EL_RPC_PORT)
parser.add_argument("--el_max_peers", type=int, help="Sets the Execution Client's max peer count", default=EL_MAX_PEER_COUNT)
parser.add_argument("--cl_p2p_port",  type=int, help="Sets the Consensus Client's P2P Port", default=CL_P2P_PORT)
parser.add_argument("--cl_rest_port", type=int, help="Sets the Consensus Client's REST Port", default=CL_REST_PORT)
parser.add_argument("--cl_max_peers", type=int, help="Sets the Consensus Client's max peer count", default=CL_MAX_PEER_COUNT)
parser.add_argument("-v", "--version", action="version", version="%(prog)s 1.0.0")
args = parser.parse_args()
print(args)

# Change to the home folder
os.chdir(os.path.expanduser("~"))

# Ask the user for Ethereum network
index = SelectionMenu.get_selection(valid_networks,title='Validator Install Quickstart :: CoinCashew.com',subtitle='Installs Nethermind EL / Nimbus BN / Nimbus VC / MEVboost\nSelect Ethereum network:')

# Exit selected
if index == 3:
    exit(0)

# Set network
eth_network=valid_networks[index]

# Set clients to nethermind and nimbus
execution_client=valid_exec_clients[0]
consensus_client=valid_consensus_clients[0]

# Set to lowercase
consensus_client = consensus_client.lower()
execution_client = execution_client.lower()
eth_network = eth_network.lower()

Screen().clear()

# Ask if wants to install a validator
answer=PromptUtils(Screen()).prompt_for_yes_or_no(f"Install a Validator? If no, this will install a node only.")
if not answer:
    NODE_ONLY=True
    MEVBOOST_ENABLED=False
    VALIDATOR_ENABLED=False
else:
    NODE_ONLY=False
    MEVBOOST_ENABLED=True
    VALIDATOR_ENABLED=True

def is_valid_eth_address(address):
    pattern = re.compile("^0x[a-fA-F0-9]{40}$")
    return bool(pattern.match(address))

if not NODE_ONLY and FEE_RECIPIENT_ADDRESS == "":
    # Prompt User for validator tips address
    while True:
        FEE_RECIPIENT_ADDRESS = Screen().input(f'Enter your Ethereum address (aka Fee Recipient Address)\n Hints: \n - Use ETH adddress from a hardware wallet.\n - Do not use an exchange address.\n > ')
        if is_valid_eth_address(FEE_RECIPIENT_ADDRESS):
            print("Valid Ethereum address")
            break
        else:
            print("Invalid Ethereum address. Try again.")

Screen().clear()
if NODE_ONLY == False:
    answer=PromptUtils(Screen()).prompt_for_yes_or_no(f"Confirmation: Verify your settings\n\nNetwork: {eth_network.upper()}\nFee Recipient Address: {FEE_RECIPIENT_ADDRESS}\n\nIs this correct?")
else:
    answer=PromptUtils(Screen()).prompt_for_yes_or_no(f"Confirmation: Verify your settings\n\nNetwork: {eth_network.upper()}\nInstall Node Only (Not a validator): {NODE_ONLY}\n\nIs this correct?")    

if not answer:
    file_name =  os.path.basename(sys.argv[0])
    print(f'\nInstall cancelled by user. \n\nWhen ready, re-run install command:\npython3 {file_name}')
    exit(0)

# Initialize sync urls for selected network
if eth_network == "mainnet":
    sync_urls = mainnet_sync_urls
elif eth_network == "holesky":
    sync_urls = holesky_sync_urls
elif eth_network == "sepolia":
    sync_urls = sepolia_sync_urls

# Use a random sync url
sync_url = random.choice(sync_urls)[1]
print(f'Using Sync URL: {sync_url}')

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

############ MEVBOOST ##################
if MEVBOOST_ENABLED == True:
    # Step 1: Create mevboost service account
    os.system("sudo useradd --no-create-home --shell /bin/false mevboost")

    # Step 2: Install mevboost
    # Change to the home folder
    os.chdir(os.path.expanduser("~"))

    # Define the Github API endpoint to get the latest release
    url = 'https://api.github.com/repos/flashbots/mev-boost/releases/latest'

    # Send a GET request to the API endpoint
    response = requests.get(url)
    mevboost_version = response.json()['tag_name']

    # Search for the asset with the name that ends in linux_amd64.tar.gz
    assets = response.json()['assets']
    download_url = None
    for asset in assets:
        if asset['name'].endswith('linux_amd64.tar.gz'):
            download_url = asset['browser_download_url']
            break

    if download_url is None:
        print("Error: Could not find the download URL for the latest release.")
        exit(1)

    # Download the latest release binary
    print(f"Download URL: {download_url}")
    response = requests.get(download_url)

    # Save the binary to the home folder
    with open('mev-boost.tar.gz', 'wb') as f:
        f.write(response.content)

    # Extract the binary to the home folder
    with tarfile.open('mev-boost.tar.gz', 'r:gz') as tar:
        tar.extractall()

    # Move the binary to /usr/local/bin using sudo
    os.system(f"sudo mv mev-boost /usr/local/bin")

    # Remove files
    os.system(f"rm mev-boost.tar.gz LICENSE README.md")

############ NETHERMIND ##################
if execution_client == 'nethermind':
    # Create User and directories
    subprocess.run(["sudo", "useradd", "--no-create-home", "--shell", "/bin/false", "execution"])
    subprocess.run(["sudo", "mkdir", "-p", "/var/lib/nethermind"])
    subprocess.run(["sudo", "chown", "-R", "execution:execution", "/var/lib/nethermind"])
    subprocess.run(["sudo", "apt-get", '-qq', "install", "libsnappy-dev", "libc6-dev", "libc6", "unzip", "-y"], check=True)

    # Define the Github API endpoint to get the latest release
    url = 'https://api.github.com/repos/NethermindEth/nethermind/releases/latest'

    # Send a GET request to the API endpoint
    response = requests.get(url)
    nethermind_version = response.json()['tag_name']

    # Search for the asset with the name that ends in linux-x64.zip
    assets = response.json()['assets']
    download_url = None
    zip_filename = None
    for asset in assets:
        if asset['name'].endswith('linux-x64.zip'):
            download_url = asset['browser_download_url']
            zip_filename = asset['name']
            break

    if download_url is None or zip_filename is None:
        print("Error: Could not find the download URL for the latest release.")
        exit(1)

    # Download the latest release binary
    print(f"Download URL: {download_url}")
    response = requests.get(download_url)

    # Save the binary to a temporary file
    with tempfile.NamedTemporaryFile('wb', suffix='.zip', delete=False) as temp_file:
        temp_file.write(response.content)
        temp_path = temp_file.name

    # Create a temporary directory for extraction
    with tempfile.TemporaryDirectory() as temp_dir:
        # Extract the binary to the temporary directory
        with zipfile.ZipFile(temp_path, 'r') as zip_ref:
            zip_ref.extractall(temp_dir)

        # Copy the contents of the temporary directory to /usr/local/bin/nethermind using sudo
        subprocess.run(["sudo", "cp", "-a", f"{temp_dir}/.", "/usr/local/bin/nethermind"])

    # chmod a+x /usr/local/bin/nethermind/nethermind and change ownership
    subprocess.run(["sudo", "chmod", "a+x", "/usr/local/bin/nethermind/nethermind"])
    subprocess.run(['sudo', 'chown', '-R', 'execution:execution', '/usr/local/bin/nethermind'])

    # Remove the temporary zip file
    os.remove(temp_path)

################ NIMBUS ##################

if consensus_client == 'nimbus':
    # Create data paths, service user, assign ownership permissions
    subprocess.run(['sudo', 'mkdir', '-p', '/var/lib/nimbus'])
    subprocess.run(['sudo', 'chmod', '700', '/var/lib/nimbus'])
    subprocess.run(['sudo', 'useradd', '--no-create-home', '--shell', '/bin/false', 'consensus'])
    subprocess.run(['sudo', 'chown', '-R', 'consensus:consensus', '/var/lib/nimbus'])

    # Change to the home folder
    os.chdir(os.path.expanduser("~"))

    # Define the Github API endpoint to get the latest release
    url = 'https://api.github.com/repos/status-im/nimbus-eth2/releases/latest'

    # Send a GET request to the API endpoint
    response = requests.get(url)
    nimbus_version = response.json()['tag_name']

    # Search for the asset with the name that ends in _Linux_amd64.tar.gz
    assets = response.json()['assets']
    download_url = None
    for asset in assets:
        if '_Linux_amd64' in asset['name'] and asset['name'].endswith('.tar.gz'):
            download_url = asset['browser_download_url']
            break

    if download_url is None:
        print("Error: Could not find the download URL for the latest release.")
        exit(1)

    # Download the latest release binary
    print(f"Download URL: {download_url}")
    response = requests.get(download_url)


    # Save the binary to the home folder
    with open('nimbus.tar.gz', 'wb') as f:
        f.write(response.content)

    # Extract the binary to the home folder
    with tarfile.open('nimbus.tar.gz', 'r:gz') as tar:
        tar.extractall()

    # Find the extracted folder
    extracted_folder = None
    for item in os.listdir():
        if item.startswith("nimbus-eth2_Linux_amd64"):
            extracted_folder = item
            break

    if extracted_folder is None:
        print("Error: Could not find the extracted folder.")
        exit(1)

    # Copy the binary to /usr/local/bin using sudo
    os.system(f"sudo cp {extracted_folder}/build/nimbus_beacon_node /usr/local/bin")
    os.system(f"sudo cp {extracted_folder}/build/nimbus_validator_client /usr/local/bin")

    # Remove the nimbus.tar.gz file and extracted folder
    os.remove('nimbus.tar.gz')
    os.system(f"rm -r {extracted_folder}")

##### NETHERMIND SERVICE FILE ###########

if execution_client == 'nethermind':
    nethermind_service_file = f'''[Unit]
Description=Nethermind Execution Layer Client service for {eth_network.upper()}
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
WorkingDirectory=/var/lib/nethermind
Environment="DOTNET_BUNDLE_EXTRACT_BASE_DIR=/var/lib/nethermind"
ExecStart=/usr/local/bin/nethermind/nethermind --config {eth_network} --datadir="/var/lib/nethermind" --Network.DiscoveryPort {EL_P2P_PORT} --Network.P2PPort {EL_P2P_PORT} --Network.MaxActivePeers {EL_MAX_PEER_COUNT} --JsonRpc.Port {EL_RPC_PORT} --Metrics.Enabled true --Metrics.ExposePort 6060 --JsonRpc.JwtSecretFile {JWTSECRET_PATH}

[Install]
WantedBy=multi-user.target
    '''

    nethermind_temp_file = 'execution_temp.service'
    nethermind_service_file_path = '/etc/systemd/system/execution.service'

    with open(nethermind_temp_file, 'w') as f:
        f.write(nethermind_service_file)

    os.system(f'sudo cp {nethermind_temp_file} {nethermind_service_file_path}')

    os.remove(nethermind_temp_file)

########### NIMBUS SERVICE FILE #############
if MEVBOOST_ENABLED == True:
    _mevparameters='--payload-builder=true --payload-builder-url=http://127.0.0.1:18550'
else:
    _mevparameters=''

if VALIDATOR_ENABLED == True and FEE_RECIPIENT_ADDRESS:
    _feeparameters=f'--suggested-fee-recipient={FEE_RECIPIENT_ADDRESS}'
else:
    _feeparameters=''

if consensus_client == 'nimbus':
    nimbus_service_file = f'''[Unit]
Description=Nimbus Beacon Node Consensus Client service for {eth_network.upper()}
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
ExecStart=/usr/local/bin/nimbus_beacon_node --network={eth_network} --data-dir=/var/lib/nimbus --tcp-port={CL_P2P_PORT} --udp-port={CL_P2P_PORT} --max-peers={CL_MAX_PEER_COUNT} --rest-port={CL_REST_PORT} --web3-url=http://127.0.0.1:8551 --rest --metrics --metrics-port=8008 --jwt-secret={JWTSECRET_PATH} --non-interactive --status-bar=false --in-process-validators=false {_feeparameters} {_mevparameters}

[Install]
WantedBy=multi-user.target
    '''

    # Checkpoint sync
    if sync_url is not None:
        print("Running Checkpoint Sync")
        db_path = "/var/lib/nimbus/db"
        os.system(f'sudo rm -rf {db_path}')
        subprocess.run([
            'sudo', '/usr/local/bin/nimbus_beacon_node', 'trustedNodeSync',
            f'--network={eth_network}', '--data-dir=/var/lib/nimbus',
            f'--trusted-node-url={sync_url}', '--backfill=false'
        ])
        os.system(f'sudo chown -R consensus:consensus {db_path}')

    nimbus_temp_file = 'consensus_temp.service'
    nimbus_service_file_path = '/etc/systemd/system/consensus.service'

    with open(nimbus_temp_file, 'w') as f:
        f.write(nimbus_service_file)

    os.system(f'sudo cp {nimbus_temp_file} {nimbus_service_file_path}')
    os.remove(nimbus_temp_file)

########### NIMBUS VALIDATOR SERVICE FILE #############
if MEVBOOST_ENABLED == True:
    _mevparameters='--payload-builder=true'
else:
    _mevparameters=''

if consensus_client == 'nimbus' and VALIDATOR_ENABLED == True:
    # Create data paths, service user, assign ownership permissions
    subprocess.run(['sudo', 'mkdir', '-p', '/var/lib/nimbus_validator'])
    subprocess.run(['sudo', 'chmod', '700', '/var/lib/nimbus_validator'])
    subprocess.run(['sudo', 'useradd', '--no-create-home', '--shell', '/bin/false', 'validator'])
    subprocess.run(['sudo', 'chown', '-R', 'validator:validator', '/var/lib/nimbus_validator'])

    nimbus_validator_file = f'''[Unit]
Description=Nimbus Validator Client service for {eth_network.upper()}
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
ExecStart=/usr/local/bin/nimbus_validator_client --data-dir=/var/lib/nimbus_validator --metrics --metrics-port=8009 --beacon-node=http://127.0.0.1:{CL_REST_PORT} --non-interactive --graffiti={GRAFFITI} {_feeparameters} {_mevparameters}
    '''

    nimbus_temp_file = 'validator_temp.service'
    nimbus_validator_file_path = '/etc/systemd/system/validator.service'

    with open(nimbus_temp_file, 'w') as f:
        f.write(nimbus_validator_file)

    os.system(f'sudo cp {nimbus_temp_file} {nimbus_validator_file_path}')
    os.remove(nimbus_temp_file)

##### MEV Boost Service File
if MEVBOOST_ENABLED == True:
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
        '    -min-bid 0.05 \\',
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
    mev_boost_service_file_path = '/etc/systemd/system/mevboost.service'

    with open(mev_boost_temp_file, 'w') as f:
        f.write(mev_boost_service_file)

    os.system(f'sudo cp {mev_boost_temp_file} {mev_boost_service_file_path}')
    os.remove(mev_boost_temp_file)

# Reload the systemd daemon
subprocess.run(['sudo', 'systemctl', 'daemon-reload'])

print(f'##########################\n')
print(f'## Installation Summary ##\n')
print(f'##########################\n')

if execution_client == 'nethermind':
    print(f'Nethermind Version: \n{nethermind_version}\n')

if consensus_client == 'nimbus':
    print(f'Nimbus Version: \n{nimbus_version}\n')

if MEVBOOST_ENABLED==True:
    print(f'Mevboost Version: \n{mevboost_version}\n')

print(f'Network: {eth_network.upper()}\n')
print(f'CheckPointSyncURL: {sync_url}\n')
if NODE_ONLY == False:
    print(f'Validator Fee Recipient Address: {FEE_RECIPIENT_ADDRESS}\n')
print(f'Systemd service files created: \n{nimbus_service_file_path}\n{nethermind_service_file_path}')
if NODE_ONLY == False:
    print(f'{nimbus_validator_file_path}\n{mev_boost_service_file_path}')

answer=PromptUtils(Screen()).prompt_for_yes_or_no(f"\nInstallation successful!\nSyncing a Nimbus/Nethermind node for validator duties can be as quick as a few hours.\nWould you like to start syncing now?")

if answer:
    os.system(f'sudo systemctl start execution consensus')