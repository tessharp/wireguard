# Wireguard

This repository contains scripts that make it easy to configure [WireGuard](https://www.wireguard.com)
on [VPS](https://en.wikipedia.org/wiki/Virtual_private_server).

This script has been updated from its original repository by @drew2a.

Original article is in Medium: [How to deploy WireGuard node on a DigitalOcean's droplet](https://medium.com/@drew2a/replace-your-vpn-provider-by-setting-up-wireguard-on-digitalocean-6954c9279b17)

## Quick Start

```bash
wget https://raw.githubusercontent.com/tessharp/wireguard/master/wg-server-up.sh

chmod +x ./wg-server-up.sh
./wg-server-up.sh -d unbound
# OR
./wg-server-up.sh -d pihole
```

## Roadmap
* Review and fix Pihole deployment (Currently does not resolve appropriately)
* Simplify adding clients - remove requirement for assigning octet if not specified by user

## wg-server-up.sh

This script will:

* Installs al necessary software on an empty Ubuntu DigitalOcean droplet
(it should also work with most modern Ubuntu images)
* Configures IPv4 forwarding and appropriate iptables rules
* Sets up [unbound](https://github.com/NLnetLabs/unbound) or [pihole](https://pi-hole.net/) as a DNS resolver 
* Creates a server and clients configurations
* Installs [qrencode](https://github.com/fukuchi/libqrencode/)
* Runs [WireGuard](https://www.wireguard.com)

### Usage

```bash
wg-server-up.sh -d [unbound|pihole]
```

### Examples

```bash
./wg-server-up.sh -d unbound
```

### Prerequisites

Install [WireGuard](https://www.wireguard.com) if it's not installed through the ``wg-server-up.sh`` script.


## wg-genconf-user.sh

This script will generate clients configs for WireGuard and add or remove the relevant user configuration to the server config. You need to supply the configuration file, client name, and last octet of the IP used to route the WireGuard traffic.

### Usage

```bash
./wg-genconf-user.sh -c [configuration_file] -[a|d] [client_name] -o [IP_last_octet]
```

### Examples

```bash
./wg-genconf-user.sh -c /etc/wireguard/wg0.conf -a client -o 5
./wg-genconf-user.sh -c /etc/wireguard/wg0.conf -d client
```
