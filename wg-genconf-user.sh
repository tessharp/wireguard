#!/usr/bin/env bash
# usage: wg-genconf-user.sh [-ad|-h] [Wireguard config file] [Name of client] [Client IP last octet]

echo "Wireguard User Management"
echo "========================="

echo "Working from the $(pwd) directory."
echo "Running with the following parameters:${@}"

server_config=${2}
client_name=${3}
client_ip_octet=${4}

for arg in "$@"
do
    if [ "$arg" == "--help" ] || [ "$arg" == "-h" ]
    then
        echo -e "Syntax: wg-genconf-user.sh [<-ad>][Wireguard config file] [Name of client] [<Client IP last octet>]."
        echo "Flags"
        echo -e "\t-a or --add: Add a client to a configuration file. Requires the Client IP last octet."
        echo -e "\t-d or --delete: Delete a client from the configuration file."
        echo "Parameters:"
        echo -e "\tWireguard config file: Location of the configuration file to edit."
        echo -e "\tName of the client: Name of the client configuration to include in Wireguard."
        echo -e "\tIP last octet: Unique IP octet to append to a particular client."
        exit #No error
    fi
done
#
# checking for configuration file in place
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

case "${1}" in
    "-a"|"--add")
        if [ -z ${client_ip_octet} ]
            then
                echo "Client IP octet was not provided. Exiting."
                exit #no octed provided
        fi

        #
        # assign parameters
        #
        server_private_key=$(cat /etc/wireguard/wg0.conf | grep "PrivateKey = " | sed -r "s/[[:cntrl:]]\[[0-9]{1,3}m//g" | sed "s/PrivateKey = //") 
        server_public_key=$(echo "${server_private_key}" | wg pubkey)

        #
        # obtaining current IP address to link vpn server
        #
        server_ip=$(dig @resolver1.opendns.com ANY myip.opendns.com +short)

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
ListenPort = 1194
Address = ${client_ip}
DNS = 10.0.0.1

[Peer]
PublicKey = ${server_public_key}
AllowedIPs = 0.0.0.0/0
Endpoint = ${server_ip}:1194
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
    ;;
    "-d"|"--delete")
        echo "Removing client ${client_name}"
        line_start = $(grep -nr "# ${client_name}_START" ${server_config} | cut -f1 -d:)
        line_end = $(grep -nr "# ${client_name}_END" ${server_config} | cut -f1 -d:)
        sed '${line_start},${line_end}d' ${server_config}
    ;;
    *)
        echo "Unknown flag ${1}. Aborting."
        exit
    ;;
esac

echo
echo -e "Make sure to restart Wireguard for changes to take effect. For example:"
echo -e "\tsystemctl restart wg-quick@wg0"