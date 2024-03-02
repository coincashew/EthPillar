# EthPillar

EthPillar: a simple TUI for Validator Node Management

😄 Friendly Node Installer: No node yet? Helps you installs a Ethereum node stack in a jiffy.

💾 Ease of use: No more remembering CLI commands required. Access common node operations via a simple text menu.

🦉 Fast Updates: Quickly find and download the latest consensus/execution release. Less downtime!

🎉Compatibility: Behind the scenes, node commands and file structure are identical to V2 staking setups. {% endhint %}

**NOTE:** [Requires a Coincashew V2 Staking Setup.](https://www.coincashew.com/coins/overview-eth/guide-or-how-to-setup-a-validator-on-eth2-mainnet) If no staking setup is installed, EthPillar offers a quickstart to install a full Nethermind EL/ Nimbus CL node with Nimbus validator and mevboost enabled.

The code is open source. Your Pull requests and suggestions welcome!

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
## Public Goods Support:
👍Are you a EthPillar Enjooyer? [Support this public good by purchasing a limited edition POAP!](https://checkout.poap.xyz/169495)

![Your EthPillar Enjoyoor POAP!](https://github.com/coincashew/coincashew/blob/7c9d3788e191d77810471edb7307637bc7b1726f/.gitbook/assets/3adf69e9-fb1b-4665-8645-60d71dd01a7b.png)

Purchase link: https://checkout.poap.xyz/169495

ETH accepted on Mainnet, Arbitrum, Base, Optimism. 🙏
