#!/bin/bash
#wget https://raw.githubusercontent.com/maemune/Unix/refs/heads/main/Setup_Samba.sh && nano ./Setup_Samba.sh && chmod u+x ./Setup_Samba.sh && ./Setup_Samba.sh

sudo apt install -y samba
sudo cp /etc/samba/smb.conf /etc/samba/smb.conf.bak
sudo nano /etc/samba/smb.conf
"""
[ubuntu]
    path = /home/ubuntu/
    browsable = yes
    writable = yes
    guest ok = no
    read only = no
"""
sudo ufw allow Samba
sudo smbpasswd -a maemune
