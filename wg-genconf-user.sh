#!/usr/bin/env bash
# usage: wg-genconf-user.sh [Wireguard config file] [Name of client] [Client IP last octet]

echo "Wireguard User Management"
echo "========================="

echo "Working from the $(pwd) directory."
echo "Running with the following parameters:${@}"

server_config=${1}
client_name=${2}
client_ip_octet=${3}
server_private_key=$(cat /etc/wireguard/wg0.conf | grep "PrivateKey = " | sed -r "s/[[:cntrl:]]\[[0-9]{1,3}m//g" | sed "s/PrivateKey = //") 
server_public_key=$(echo "${server_private_key}" | wg pubkey)
# obtaining current IP address to link vpn server
server_ip=$(dig @resolver1.opendns.com ANY myip.opendns.com +short)

for arg in "$@"
do
    if [ "$arg" == "--help" ] || [ "$arg" == "-h" ]
    then
        echo -e "Syntax: wg-genconf-user.sh [Wireguard config file] [Name of client] [Client IP last octet]."
        echo -e "\tWireguard config file: Location of the configuration file to edit."
        echo -e "\tName of the client: Name of the client configuration to include in Wireguard."
        echo -e "\tIP last octet: Unique IP octet to append to a particular client."
        exit #No error
    fi
done

#
# checking for required place
#

if ! test -f "${server_config}"
then
    echo "Wireguard configuration file could not be found or was not provided. Exiting."
    exit #file not found
fi

if [ -z ${client_name} ]
then
    echo "Client name was not provided. Exiting."
    exit #no client name
fi

if [ -z ${client_ip_octet} ]
then
    echo "Client IP octet was not provided. Exiting."
    exit #no octed provided
fi

#
# add configuration for a particular user on Wireguard
#

client_private_key=$(wg genkey)
client_public_key=$(echo "${client_private_key}" | wg pubkey)
client_ip=10.0.0.${client_ip_octet}/32
client_config=${client_name}.conf

#
# writing configuration to file
#

echo -e "Generating client configuration file on:"
echo -e "\t$(pwd)/${client_config}"
cat > "${client_config}" <<EOL
[Interface]
PrivateKey = ${client_private_key}
ListenPort = 51820
Address = ${client_ip}
DNS = 10.0.0.1

[Peer]
PublicKey = ${server_public_key}
AllowedIPs = 0.0.0.0/0
Endpoint = ${server_ip}:51820
PersistentKeepalive = 21
EOL

#
# add client configuration to Wireguard
#
echo -e "Updating wireguard configuration file on:"
echo -e "\t${server_config}"
cat >> "${server_config}" <<EOL
# ${client_name}_START
[Peer]
PublicKey = ${client_public_key}
AllowedIPs = ${client_ip}
# ${client_name}_END
EOL

echo
echo -e "Restart Wireguard for changes to take effect:"
echo -e "\tsystemctl restart wg-quick@wg0"