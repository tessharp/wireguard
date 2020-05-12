#!/usr/bin/env bash
# usage:
#     wg-ubuntu-server-up.sh -d

function version_gt() { test "$(printf '%s\n' "$@" | sort -V | head -n 1)" != "$1"; }

dns_service="none"
print_help=true
os_name=$(sudo cat /etc/os-release | grep NAME=\" | grep -v _ | sed -e "s/^NAME=\"//" -e "s/\"$//" 2>&1)
os_version=$(sudo cat /etc/os-release | grep VERSION_ID=\" | sed -e "s/^VERSION_ID=\"//" -e "s/\"$//" 2>&1)
os_workaround=18.04
os_forceupgrade=false


while getopts "d:" opt; do
    case ${opt} in
        d) # process proxy
            temp_var=${OPTARG^^}
            if [[ "$temp_var" == "UNBOUND" || "$temp_var" == "PIHOLE" || "$temp_var" == "NONE" ]]
            then
                dns_service=${temp_var}
                print_help=false
            else
                echo "Invalid argument given: $OPTARG" >&2
                print_help=true
            fi
        ;;
        u) # process dist-upgrade
            os_forceupgrade=true
        ;;
        :)
            echo "Option -$OPTARG requires an argument." >&2
            print_help=true
        ;;
        \? )
            print_help=true
        ;;
  esac
done

if (${print_help})
then
    echo "Usage: wg-ubuntu-server-up.sh [-d] <unbound|pihole>"
    echo "-d: Specifies which DNS service to use - Unbound, Pihole or None"
    echo "-u: Force a distribution upgrade: (apt update dist-upgrade)"
    exit 1
fi


working_dir="$HOME/wireguard"

#mkdir -p "${working_dir}"
mkdir -p "/etc/wireguard"

echo ----------------------------------------------update current patch to latest
sudo apt -y update
sudo apt -y upgrade
if $os_forceupgrade
then
 echo ---------------------------------------update current distribution to latest
 sudo apt -y dist-upgrade
fi

echo ------------------------------------------------------install linux headers
sudo apt install -y linux-headers-"$(uname -r)"

echo ------------------------------------------install software-properties-common
sudo apt install -y software-properties-common

echo ------------------------------------------------------------------install bc
sudo apt install -y bc

echo -----------------------------------------------------------install net-tools
sudo apt install -y net-tools

if [[ "${dns_service}" == "PIHOLE" ]]
then
    echo && echo ------------------------------------------install and configure pihole DNS
    # workaround for 127.0.0.53 for installation ONLY in Ubuntu 18.04 and lower (https://www.reddit.com/r/pihole/comments/8sgro3/server_name_resolution_messed_up_when_running/
    # and https://bugs.launchpad.net/ubuntu/+source/systemd/+bug/1624320/comments/8)
    echo "Detecting version..."
    if [[ "${os_name}" == "Ubuntu" ]]
    then
        echo "Ubuntu detected."
        rm -f /etc/resolv.conf
        ln -s /run/systemd/resolve/resolv.conf /etc/resolv.conf
    fi
    # preparing pihole
    wget -O basic-pihole-install.sh https://install.pi-hole.net
    chmod 700 basic-pihole-install.sh

    ./basic-pihole-install.sh --unattended --disable-install-webserver

    # configuring pihole-dns in similar workaround fashion
    if [[ "${os_name}" == "Ubuntu" ]]
    then
        cat > /run/systemd/resolve/pihole-resolv.conf << ENDOFFILE
nameserver 127.0.0.1
ENDOFFILE
        rm -f /etc/resolv.conf
        ln -s /run/systemd/resolve/pihole-resolv.conf /etc/resolv.conf
    fi

    # configure server to use pihole
    sed -i.bak "s/^        static domain_name_servers=.*/        static domain_name_servers=127.0.0.1/" /etc/dhcpcd.conf
    #sed -i '42s/.*/        static domain_name_servers=127.0.0.1/' /etc/dhcpcd.conf
    systemctl restart dhcpcd
fi

if [[ "${os_name}" == "Debian GNU/Linux" ]]
then
    echo ----------------------------------------install software-properties-common
    sudo apt update
    sudo apt install -y software-properties-common
    echo ----------------------------------------enable Debian backports repository
    sudo sh -c "echo 'deb http://deb.debian.org/debian buster-backports main contrib non-free' > /etc/apt/sources.list.d/buster-backports.list"
    sudo apt update
fi

echo ---------------------------------------------------------install wireguard
if [[ "${os_name}" == "Ubuntu" ]]
then
    echo "Adding Wireguard repository."
    sudo add-apt-repository -y ppa:wireguard/wireguard
fi
sudo apt update && sudo apt upgrade -y
echo "Installing Wireguard."
sudo apt install -y wireguard
sudo modprobe wireguard

echo ----------------------------------------------------------install qrencode
sudo apt install -y qrencode

echo ---------------------------------------------- download wg-genconf-user.sh
#cd "${working_dir}" &&
wget -O wg-genconf-user.sh https://raw.githubusercontent.com/tessharp/wireguard/master/wg-genconf-user.sh
chmod +x ./wg-genconf-user.sh

#echo ----------------------generate configurations for "${clients_count}" clients
#./wg-genconf.sh "${clients_count}"


echo ----------------------------------------------generate server configuration

# identify the public IP address of the server
echo "Retrieving public server IP and interface."
server_ip=$(dig @resolver1.opendns.com ANY myip.opendns.com +short)

# configuring the private server
server_private_key=$(wg genkey)
server_public_key=$(echo "${server_private_key}" | wg pubkey)
server_config=wg0.conf

# identifying the public interface of the server
server_public_interface=$(route -n | awk '$1 == "0.0.0.0" {print $8}')

echo "Writing Wireguard server configuration."
echo Generate server \("${server_ip}"\) config:
echo
echo -e "\t//etc//wireguard//${server_config}"

#
# writing server config to file
#
cat > "${server_config}" <<EOL
[Interface]
Address = 10.0.0.1/24
SaveConfig = false
ListenPort = 51820
PrivateKey = ${server_private_key}
PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT; iptables -t nat -A POSTROUTING -o ${server_public_interface} -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -j ACCEPT; iptables -t nat -D POSTROUTING -o ${server_public_interface} -j MASQUERADE
EOL

echo -----------------------------------move server\'s config to /etc/wireguard/
mv -v ./wg0.conf /etc/wireguard/
chown -v root:root /etc/wireguard/wg0.conf
chmod -v 600 /etc/wireguard/wg0.conf

echo ------------------------------------------------------------- run wireguard
wg-quick up wg0
systemctl enable wg-quick@wg0

echo ------------------------------------------------------enable IPv4 forwarding
sysctl net.ipv4.ip_forward=1
echo 'net.ipv4.ip_forward = 1' > /etc/sysctl.d/99-sysctl.conf

echo ---------------------------------------------------configure firewall rules

sudo iptables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
sudo iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
sudo iptables -A INPUT -p udp -m udp --dport 55000 -m conntrack --ctstate NEW -j ACCEPT
sudo iptables -A INPUT -s 10.0.0.0/24 -p tcp -m tcp --dport 53 -m conntrack --ctstate NEW -j ACCEPT
sudo iptables -A INPUT -s 10.0.0.0/24 -p udp -m udp --dport 53 -m conntrack --ctstate NEW -j ACCEPT

# make firewall changes persistent
echo iptables-persistent iptables-persistent/autosave_v4 boolean true | sudo debconf-set-selections
echo iptables-persistent iptables-persistent/autosave_v6 boolean true | sudo debconf-set-selections

sudo apt install -y iptables-persistent

sudo systemctl enable netfilter-persistent
sudo netfilter-persistent save

if [[ "${dns_service}" == "UNBOUND" ]]
then
    echo && echo -----------------------------------------install and configure unbound DNS
    sudo apt install -y unbound unbound-host

    curl -o /var/lib/unbound/root.hints https://www.internic.net/domain/named.cache
    echo 'curl -o /var/lib/unbound/root.hints https://www.internic.net/domain/named.cache' > /etc/cron.monthly/curl_root_hints.sh
    chmod +x /etc/cron.monthly/curl_root_hints.sh
    cat > /etc/unbound/unbound.conf << ENDOFFILE
server:
    num-threads: 4
    # disable logs
    verbosity: 0
    # list of root DNS servers
    root-hints: "/var/lib/unbound/root.hints"
    # use the root server's key for DNSSEC
    auto-trust-anchor-file: "/var/lib/unbound/root.key"
    # respond to DNS requests on all interfaces
    interface: 0.0.0.0
    max-udp-size: 3072
    # IPs authorised to access the DNS Server
    access-control: 0.0.0.0/0                 refuse
    access-control: 127.0.0.1                 allow
    access-control: 10.0.0.0/24             allow
    # not allowed to be returned for public Internet  names
    private-address: 10.0.0.0/24
    #hide DNS Server info
    hide-identity: yes
    hide-version: yes
    # limit DNS fraud and use DNSSEC
    harden-glue: yes
    harden-dnssec-stripped: yes
    harden-referral-path: yes
    # add an unwanted reply threshold to clean the cache and avoid, when possible, DNS poisoning
    unwanted-reply-threshold: 10000000
    # have the validator print validation failures to the log
    val-log-level: 1
    # minimum lifetime of cache entries in seconds
    cache-min-ttl: 1800
    # maximum lifetime of cached entries in seconds
    cache-max-ttl: 14400
    prefetch: yes
    prefetch-key: yes
    # don't use Capitalization randomization as it known to cause DNSSEC issues sometimes
    # see https://discourse.pi-hole.net/t/unbound-stubby-or-dnscrypt-proxy/9378 for further details
    use-caps-for-id: no
    # reduce EDNS reassembly buffer size.
    # suggested by the unbound man page to reduce fragmentation reassembly problems
    edns-buffer-size: 1472
    # ensure kernel buffer is large enough to not lose messages in traffic spikes
    so-rcvbuf: 1m
    # ensure privacy of local IP ranges
    private-address: 10.0.0.0/24
ENDOFFILE
    # give root ownership of the Unbound config
    sudo chown -R unbound:unbound /var/lib/unbound

    # disable systemd-resolved
    sudo systemctl stop systemd-resolved
    sudo systemctl disable systemd-resolved

    # enable Unbound in place of systemd-resovled
    sudo systemctl enable unbound
    sudo systemctl start unbound
fi

# show wg
wg show

echo && echo "You can add new clients by executing the following command:"
echo -e "\twg-genconf-user.sh [Wireguard config file] [Name of client] [Client IP last octet]"
echo && echo "Please check if the interface for Wireguard is currently working by executing the following command upon reboot:"
echo -e "\tip addr show wg0"
echo && echo "If the interface is not available, it may be due to headers/OS upgrade. Please run the following commands:"
echo -e "\tapt install linux-headers-$(uname -r)"
echo -e "\tsudo modprobe wireguard"
echo -e "\treboot"

# reboot to make changes effective
echo All done, reboot...
reboot
