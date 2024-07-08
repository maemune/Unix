#!/bin/bash
#wget https://raw.githubusercontent.com/maemune/Unix/main/Generat_SSH.sh && nano ./Generat_SSH.sh && chmod u+x ./Generat_SSH.sh && ./Generat_SSH.sh
file_name=$(hostname)
echo "y" | ssh-keygen -t ed25519 -f ~/.ssh/$file_name -N "" -C "" -q
