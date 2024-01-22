#!/bin/bash
#wget https://raw.githubusercontent.com/maemune/Unix/main/Ubuntu_Update.sh && nano ./Ubuntu_Update.sh && chmod u+x ./Ubuntu_Update.sh && ./Ubuntu_Update.sh

# Setting you info
#PASSWORD=""

# Update
sudo apt-get update
sudo apt -y full-upgrade
sudo apt -y autoremove
