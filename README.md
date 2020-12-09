# Wireguard

This repository contains scripts that make it easy to configure [WireGuard](https://www.wireguard.com)
on [VPS](https://en.wikipedia.org/wiki/Virtual_private_server).

This script has been updated from its original repository by @drew2a.

Original article is in Medium: [How to deploy WireGuard node on a DigitalOcean's droplet](https://medium.com/@drew2a/replace-your-vpn-provider-by-setting-up-wireguard-on-digitalocean-6954c9279b17)

## Quick Start

```bash
wget https://raw.githubusercontent.com/tessharp/wireguard/master/wg-server-up.sh

chmod +x ./wg-ubuntu-server-up.sh
./wg-ubuntu-server-up.sh
```

To get a full instruction, please follow to the article above.

## wg-ubuntu-server-up.sh

This script:

* Installs all necessary software on an empty Ubuntu DigitalOcean droplet
(it should also work with most modern Ubuntu images)
* Configures IPv4 forwarding and iptables rules
* Sets up [unbound](https://github.com/NLnetLabs/unbound) DNS resolver 
* Creates a server and clients configurations
* Installs [qrencode](https://github.com/fukuchi/libqrencode/)
* Runs [WireGuard](https://www.wireguard.com)

### Usage

```bash
wg-ubuntu-server-up.sh
```

### Example of usage

```bash
./wg-ubuntu-server-up.sh
```

```bash
./wg-ubuntu-server-up.sh 10
```

## wg-genconf-user.sh

This script generate server and clients configs for WireGuard.

### Prerequisites

Install [WireGuard](https://www.wireguard.com) if it's not installed.

### Usage

```bash
./wg-genconf-user.sh [<number_of_clients> [<server_public_ip>]]
```
