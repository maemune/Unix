#!/bin/bash
#wget https://raw.githubusercontent.com/maemune/Unix/main/UbuntuServer_update.sh && nano ./Update.sh && chmod u+x ./Update.sh && ./Update.sh

# Setting you info
#PASSWORD=""
# Update
sudo apt-get update
sudo apt -y full-upgrade
sudo apt -y autoremove
