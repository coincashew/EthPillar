# 🛡️ EthPillar: a one-liner setup tool and node management TUI

## :new: What is EthPillar?

:smile: **Friendly Node Installer**: No node yet? Helps you installs a Ethereum node (Nimbus+Nethermind) stack in just minutes. MEVboost included. [Review the hardware requirements first.](https://www.coincashew.com/coins/overview-eth/guide-or-how-to-setup-a-validator-on-eth2-mainnet/part-i-installation/prerequisites)

:floppy\_disk: **Ease of use**: No more remembering CLI commands required. Access common node operations via a simple text menu.

:owl: **Fast Updates**: Quickly find and download the latest consensus/execution release. Less downtime!

:tada:**Compatibility**: Behind the scenes, node commands and file structure are identical to V2 staking setups.&#x20;

**NOTE**: Already a running a Validator? EthPillar is compatible with [a Coincashew V2 Staking Setup.](https://www.coincashew.com/coins/overview-eth/guide-or-how-to-setup-a-validator-on-eth2-mainnet)&#x20;

<figure><img src="https://1280931729-files.gitbook.io/~/files/v0/b/gitbook-x-prod.appspot.com/o/spaces%2F-M5KYnWuA6dS_nKYsmfV-887967055%2Fuploads%2F8Qdb4d5VGlCRQgiFqNBO%2Fethpillar.png?alt=media&token=d80174a1-c6ca-44e3-bb96-ff6094cb0d3a" alt=""><figcaption><p>EthPillar Main Menu</p></figcaption></figure>

## Option 1: Automated One-Liner Install

Simply copy and paste the command into your terminal.

Open source source code available here: [https://github.com/coincashew/EthPillar](https://github.com/coincashew/EthPillar)

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/coincashew/ethpillar/master/install.sh)"
```

## Option 2: Manual Install

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

#### Run ethpillar:

```bash
ethpillar
```

## :tada:Next Steps

Congrats on installing a friendly TUI for making node maintenance easier!

<details>

<summary>Additional step for new Node operators</summary>

Step 1: Configure your network, port forwarding and firewall. From the main guide, [click here for detailed network configuration](https://www.coincashew.com/coins/overview-eth/guide-or-how-to-setup-a-validator-on-eth2-mainnet/part-i-installation/step-2-configuring-node#network-configuration).

* Involves setting UFW defaults, opening SSH port, allowing consensus/execution p2p port traffic, enabling the UFW firewall, configuring port forwarding and installing fail2ban.

</details>

<details>

<summary>Additional steps for new Validators</summary>

**Step 1: Setup Validator Keys**

* Familarize yourself with the main guide's section on [setting up your validator keys.](https://www.coincashew.com/coins/overview-eth/guide-or-how-to-setup-a-validator-on-eth2-mainnet/part-i-installation/step-5-installing-validator/setting-up-validator-keys)
* When ready to generate your keys, go to **EthPillar > Validator Client > Generate / Import Validator Keys**

**Step 2: Upload deposit\_data.json to Launchpad**

* To begin staking on Ethereum as a validator, you need to submit to the Launchpad your  deposit\_data.json file, which includes crucial withdrawal address details, and pay the required deposit of 32ETH per validator.

**Step 3: Congrats!**&#x20;

* Now you're waiting in the Entry Queue [https://www.validatorqueue.com](https://www.validatorqueue.com/)

<!---->

* Check out the [next steps from the main guide](https://www.coincashew.com/coins/overview-eth/guide-or-how-to-setup-a-validator-on-eth2-mainnet/part-i-installation/step-5-installing-validator/next-steps) for further knowledge. Especially the FAQ's "Wen staking rewards?"

</details>

## :joy: POAP

Are you a EthPillar Enjooyer? [Support this public good by purchasing a limited edition POAP!](https://checkout.poap.xyz/169495)

<figure><img src="https://1280931729-files.gitbook.io/~/files/v0/b/gitbook-x-prod.appspot.com/o/spaces%2F-M5KYnWuA6dS_nKYsmfV-887967055%2Fuploads%2FT2zUNVSDv5VlDIbekFtZ%2F3adf69e9-fb1b-4665-8645-60d71dd01a7b.png?alt=media&token=97b0d882-61b0-4224-8f6b-66887f141c10" alt=""><figcaption><p>Your EthPillar Enjoyoor's POAP</p></figcaption></figure>

**Purchase link:** [https://checkout.poap.xyz/169495](https://checkout.poap.xyz/169495)

ETH accepted on Mainnet, Arbitrum, Base, Optimism. :pray:

## :telephone: Get in touch

Have questions? Chat with other home stakers on [Discord](https://discord.gg/w8Bx8W2HPW) or open PRs/issues on [Github](https://github.com/coincashew/ethpillar).

## :heart: Donations

If you'd like to support this public goods project, find us on the next Gitcoin Grants.

Our donation address is [0xCF83d0c22dd54475cC0C52721B0ef07d9756E8C0](https://etherscan.io/address/0xCF83d0c22dd54475cC0C52721B0ef07d9756E8C0) or coincashew.eth

## :ballot\_box\_with\_check: How to Update

{% tabs %}
{% tab title="TUI Update" %}
Upon opening EthPillar,

* Navigate to **System Administration > Update EthPillar** and then quit and relaunch.
{% endtab %}

{% tab title="Manual Update" %}
From a terminal, pull the latest updates from git.

```bash
cd ~/git/ethpillar
git pull
```
{% endtab %}
{% endtabs %}
