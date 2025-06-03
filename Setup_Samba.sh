#!/bin/bash
#https://github.com/maemune/Unix/blob/main/Setup_Samba.sh
sudo apt install -y samba
sudo cp /etc/samba/smb.conf /etc/samba/smb.conf.bak
sudo nano /etc/samba/smb.conf

FILE_TO_EDIT="/etc/samba/smb.conf"

sudo cat << EOF >> "$FILE_TO_EDIT"
[maemune]
    path = /home/maemune/
    browsable = yes
    writable = yes
    guest ok = no
    read only = no
EOF

echo "Lines added to $FILE_TO_EDIT"
sudo smbpasswd -a maemune
