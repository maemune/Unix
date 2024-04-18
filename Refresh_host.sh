#!/bin/bash

#wget https://raw.githubusercontent.com/maemune/Unix/main/Refresh_host.sh && nano ./Refresh_host.sh && chmod u+x ./Refresh_host.sh && ./Refresh_host.sh

get_input_with_confirmation() {
    local input_var=$1
    local prompt=$2

    while true; do
        echo -n "$prompt: "
        read -r "$input_var"

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
get_input_with_confirmation ip_address "Please enter your new IP address"

sudo hostnamectl set-hostname $hostname

netplan_file="/etc/netplan/00-installer-config.yaml"
cur_ip=$(ip addr show | awk '/inet 192/ {gsub(/\/.*/, "", $2); print $2}')
sudo sed -i "s/$cur_ip/$ip_address/g" "$netplan_file"

sudo netplan apply
sudo reboot now
