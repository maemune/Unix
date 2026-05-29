#!/bin/bash
#wget https://raw.githubusercontent.com/maemune/Unix/refs/heads/main/RockyLinux/RockyLinux_Update.sh && nano ./RockyLinux_Update.sh && chmod u+x ./RockyLinux_Update.sh
# Setting your info
#PASSWORD=""

# Update
sudo dnf check-update
sudo dnf -y upgrade
sudo dnf -y autoremove
sudo dnf clean all
