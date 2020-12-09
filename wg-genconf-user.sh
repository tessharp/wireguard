#!/usr/bin/env bash
# usage: wg-genconf-user.sh [-ad|-h] [Wireguard config file] [Name of client] [Client IP last octet]

echo "Wireguard User Management"
echo "========================="

echo "Working from the $(pwd) directory."
echo "Running with the following parameters:${@}"

curr_args = $(getopt -n wg-genconf-user -o c:a:d:o:h --long config:,add:,delete:,octet:,help)

server_config=
client_name=
client_ip_octet=
action=

# Syntax of the script
usage()
{
        echo -e "Syntax: wg-genconf-user.sh [<-ad>][Wireguard config file] [Name of client] [<Client IP last octet>]."
        echo "Flags"
        echo -e "\t-a or --add: Add a client to a configuration file. Requires the Client IP last octet."
        echo -e "\t-d or --delete: Delete a client from the configuration file."
        echo "Parameters:"
        echo -e "\tWireguard config file: Location of the configuration file to edit."
        echo -e "\tName of the client: Name of the client configuration to include in Wireguard."
        echo -e "\tIP last octet: Unique IP octet to append to a particular client."
        exit 2 #No error
}

# Add user function
add_user()
{
        #
        # Checking for octet
        #
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
        server_ip=$(dig TXT +short o-o.myaddr.l.google.com @ns1.google.com | awk -F'"' '{ print $2}')

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
}

# Delete user function
deluser()
{
    echo "Removing client ${client_name}"
    line_start = $(grep -nr "# ${client_name}_START" ${server_config} | cut -f1 -d:)
    line_end = $(grep -nr "# ${client_name}_END" ${server_config} | cut -f1 -d:)
    sed '${line_start},${line_end}d' ${server_config}
}


# Main program
valid_args = $?
if ["$valid_args"!= "0"]; then
    usage
fi

eval set -- "$curr_args"
while :
do
    case "$1" in
        -c | --config)
            server_config=$2
            if ! test -f "${server_config}"
            then
                echo "Wireguard configuration file could not be found or was not provided. Exiting."
                exit #file not found
            fi
            shift 2
        ;;
        -a | --add)
            if [-z ${action}]; then
                action="add"
                client_name=$2
                shift 2
            else
                echo "Multiple actions invoked. Aborting."
                usage
            fi
        ;;
        -d | --delete)
            if [-z ${action}]; then
                action="delete"
                client_name=$2
                shift 2
            else
                echo "Multiple actions invoked. Aborting."
                usage
            fi
        ;;
        -o | --octet)
            client_ip_octet=$2
            shift 2
        ;;
        -h | --help)
            usage
        ;;
        --)
            shift
            break
        ;;
        *)
            echo "Unknown flag $1. Aborting."
            usage
        ;;
    esac
done

# Checking for client name
if [ -z ${client_name} ]
then
    echo "Client name was not provided. Exiting."
    exit #no client name
fi



echo
echo -e "Make sure to restart Wireguard for changes to take effect. For example:"
echo -e "\tsystemctl restart wg-quick@wg0"