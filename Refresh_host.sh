#!/bin/bash

get_input_with_confirmation() {
    local input_var=$1
    local prompt=$2

    while true; do
        echo -n "$prompt: "
        read -r input
        eval $input_var=\$input

        echo "Entered $prompt: ${!input_var}"

        echo -n "Is this correct? (y/n): "
        read confirmation

        if [ "$confirmation" == "y" ]; then
            break
        elif [ "$confirmation" != "n" ]; then
            echo "Invalid input. Please enter 'y' or 'n'."
        fi
    done
}

get_input_with_confirmation hostname "Please enter your new hostname"
get_input_with_confirmation ip_address "Please enter your new IP address (e.g. 192.168.1.111)"
get_input_with_confirmation gateway "Please enter your gateway (e.g. 192.168.1.1)"
get_input_with_confirmation dns "Please enter your DNS servers (comma separated, e.g. 8.8.8.8,1.1.1.1)"

if [[ ! "$ip_address" =~ /[0-9]+$ ]]; then
    ip_address="$ip_address/24"
fi

sudo hostnamectl set-hostname "$hostname"

netplan_file="/etc/netplan/50-cloud-init.yaml"
iface=$(ip -o -4 route show to default | awk '{print $5}')

if grep -q "dhcp4: true" "$netplan_file"; then
    echo "Current config: DHCP. Switching to static..."
    sudo tee "$netplan_file" > /dev/null <<EOF
network:
  version: 2
  ethernets:
    $iface:
      dhcp4: false
      addresses:
        - $ip_address
      gateway4: $gateway
      nameservers:
        addresses: [$dns]
EOF
else
    echo "Current config: Static. Updating IP..."
    sudo sed -i "s|addresses:.*|addresses:\n        - $ip_address|" "$netplan_file"
    sudo sed -i "s|gateway4:.*|gateway4: $gateway|" "$netplan_file"
    sudo sed -i "s|addresses: \[.*\]|addresses: [$dns]|" "$netplan_file"
fi

sudo netplan apply
echo "Rebooting in 1 seconds..."
sleep 1
sudo reboot now
