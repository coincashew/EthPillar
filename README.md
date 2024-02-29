# EthPillar

EthPillar: a simple UI for Ethereum Validator Node Management

Why use EthPillar?
* Fast Updates: Quickly find and download the latest consensus/execution release
* Ease of use: No more remembering CLI commands required. Access common node operations via a simple text menu.
* Compatiblity: Behind the scenes, node commands and file structure are identical to V2 staking setups. 

**NOTE:** [Requires a Coincashew V2 Staking Setup.](https://www.coincashew.com/coins/overview-eth/guide-or-how-to-setup-a-validator-on-eth2-mainnet)

The code is open source.

## Install Unstructions:

There are two ways to install.

*1. One-liner: easiest way for beginners*

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/coincashew/ethpillar/master/install.sh)"
```

*2. Manual Install:*
Paste the following commands into the terminal:

**Install updates and packages:**

```bash
sudo apt-get update && sudo apt-get install git curl ccze
```

**Clone the ethpillar repo and install:**

```bash
mkdir -p ~/git/ethpillar
git clone https://github.com/coincashew/ethpillar.git ~/git/ethpillar
sudo ln -s ~/git/ethpillar/ethpillar.sh /usr/local/bin/ethpillar
```

### Run ethpillar:
```bash
ethpillar
```
