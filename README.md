### Do you like this software? Star the project and become a [⭐ Stargazer](https://github.com/coincashew/ethpillar/stargazers)

# 🛡️ EthPillar

**Your Friendly Ethereum Node Installer & Manager**

[![Github release](https://img.shields.io/github/v/release/coincashew/ethpillar)](https://github.com/coincashew/ethpillar/releases)
[![License](https://img.shields.io/github/license/coincashew/EthPillar)](https://github.com/coincashew/EthPillar/blob/main/LICENSE)
[![GitHub Repo stars](https://img.shields.io/github/stars/coincashew/EthPillar?logo=github&color=yellow)](https://github.com/coincashew/EthPillar/stargazers)
[![GitHub forks](https://img.shields.io/github/forks/coincashew/EthPillar?logo=github&color=blue)](https://github.com/coincashew/EthPillar/network/members)
[![GitHub last commit](https://img.shields.io/github/last-commit/coincashew/EthPillar?logo=git)](https://github.com/coincashew/EthPillar/commits/main)
[![Discord](https://img.shields.io/badge/discord-join%20chat-5B5EA6)](https://t.co/lnlom4iImq)
[![Twitter](https://img.shields.io/twitter/follow/coincashew_)](https://x.com/coincashew_)
![CodeRabbit Pull Request Reviews](https://img.shields.io/coderabbit/prs/github/coincashew/EthPillar?utm_source=oss&utm_medium=github&utm_campaign=coincashew%2FEthPillar&labelColor=171717&color=FF570A)

---

## 🚀 What is EthPillar?

EthPillar is a free, open-source tool to set up and manage your Ethereum node with just a few commands. Whether you’re home solo staking, using Lido CSM, defending cypherpunk ethos with Aztec L2 sequencer node, or running your own RPC node, EthPillar makes everything easy—from installing clients to monitoring your system—all via a friendly text user interface (TUI).

**Highlights:**
- Supports ARM64 & AMD64 hardware
- Native [Lido CSM Integration](https://docs.lido.fi/run-on-lido/csm/node-setup/intermediate/ethpillar)
- Native [Aztec L2 Integration](https://docs.coincashew.com/ethpillar/aztec)
- Solo staking, full node, and testnet configurations
- Fast updates and troubleshooting
- Plugins for monitoring and performance

![EthPillar UI Preview](https://github.com/coincashew/coincashew/raw/master/.gitbook/assets/EthPillar.final.png)

---

## 🏁 Quickstart: One-line Ubuntu Install

Open a terminal and run:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/coincashew/EthPillar/main/install.sh)"
```

---

## 🤔 Why use EthPillar?

- **Beginner Friendly**: No need to memorize complex commands
- **Fast Setup**: Deploy minority consensus/execution clients in minutes (Nimbus-Nethermind, Teku-Besu, Lodestar-Besu, Lighthouse-Reth, MEVboost included)
- **Easy Updates**: Find and install the latest releases quickly
- **Compatibility**: Works with Coincashew’s V2 staking setups

Already running a validator? EthPillar works with [Coincashew’s Staking Guide](https://docs.coincashew.com/guides/mainnet).

---

## 🌟 Features

- **Testnet Support**: Ephemery & Hoodi testnets for risk-free practice
- **Lido CSM Integration**: Stake with as little as 2.4 ETH via Lido CSM ([Learn more](https://csm.testnet.fi/?ref=ethpillar))
- **Plugins**: Aztec, Lido CSM, Node-checker, validator tools, monitoring, stats, and more
- **Grafana Dashboards**: Built-in Ethereum node monitoring
- **Troubleshooting Tools**: Built-in checks for common node issues with Node Checker
- **Flexible Deployment Configurations**: Solo staking node, Full Node, CSM, Validator-only, or Failover setups

---

## 👀 Screenshots

_Main Menu_
![Main Menu](https://docs.coincashew.com/img/preview02.png)

---

## 🎬 Demo

[![Watch the demo](https://img.youtube.com/vi/aZLPACj2oPI/maxresdefault.jpg)](https://www.youtube.com/watch?v=aZLPACj2oPI)

---

## 📝 Prerequisites

- Review [Staking for Beginners](https://www.reddit.com/r/ethstaker/wiki/staking_for_beginners/)
- [Learn staking basics & hardware requirements](https://docs.coincashew.com/guides/mainnet/step-1-prerequisites)
- Linux (Ubuntu recommended, tested on 24.04 LTS, also compatible with Armbian, Linux Mint, Debian)
- AMD64 or ARM64 hardware (16GB RAM recommended for ARM64 single-board computers)

---

## 🛠️ Installation

### Option 1: Automated One-Liner

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/coincashew/EthPillar/main/install.sh)"
```

### Option 2: Manual Install

```bash
sudo apt-get update && sudo apt-get install git curl ccze bc tmux
mkdir -p ~/git/ethpillar
git clone https://github.com/coincashew/ethpillar.git ~/git/ethpillar
sudo ln -s ~/git/ethpillar/ethpillar.sh /usr/local/bin/ethpillar
ethpillar
```

---

## 🏃 Next Steps

Congrats! You’ve installed EthPillar and are ready to set up your node.

Recommended next key steps:

- Configure network, port forwarding, and firewall (Security & Node Checks > UFW Firewall)
- Enable monitoring (Logging & Monitoring > Monitoring)
- Benchmark your node (Toolbox > Yet-Another-Bench-Script)
- Set up validator keys (Validator Client > Generate / Import Validator Keys)
- Finally, run the automated Node Checker to verify everything is up to spec (Security & Node Checks > Node Checker)

---

## ❓ FAQ

- Visit the [FAQs](https://docs.coincashew.com/ethpillar/faq)
  
---

## 📞 Support & Community

- Join [Discord](https://discord.gg/dEpAVWgFNB)
- Open issues or pull requests on [GitHub](https://github.com/coincashew/EthPillar)

---

## ❤️ Donate

Support public goods! Find us on [Giveth || Gitcoin Grants](https://giveth.io/project/ethpillar-streamlining-ethereum-staking-for-everyone) or donate to [0xCF83d0c22dd54475cC0C52721B0ef07d9756E8C0](https://etherscan.io/address/0xCF83d0c22dd54475cC0C52721B0ef07d9756E8C0) (coincashew.eth)

---

## 🔄 Update EthPillar

**TUI Update:**  
System Administration > Update EthPillar, then restart.

**Manual Update:**
```bash
cd ~/git/ethpillar
git pull
```

---

## 🌠 Contribute

- Star the project on [GitHub](https://github.com/coincashew/EthPillar)
- Share your experience on X or Reddit
- Give feedback ([GitHub Issues](https://github.com/coincashew/EthPillar/issues))
- Submit PRs to improve EthPillar!

---

## 🙌 Credits

Thanks to [accidental-green](https://github.com/accidental-green/validator-install) for inspiring this tooling!

---

## ⭐ Stargazers over time

[![Stargazers over time](https://starchart.cc/coincashew/EthPillar.svg?variant=adaptive)](https://starchart.cc/coincashew/EthPillar)
