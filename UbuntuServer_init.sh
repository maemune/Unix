#!/bin/bash

#wget https://raw.githubusercontent.com/maemune/Unix/main/UbuntuServer_init.sh && nano ./UbuntuServer_init.sh && chmod u+x ./UbuntuServer_init.sh && ./UbuntuServer_init.sh

# Setting you info
GITHUB_KEYS_URL="https://github.com/maemune.keys"
#PASSWORD=""

# Update
#sudo perl -p -i.bak -e 's%(deb(?:-src|)\s+)https?://(?!archive\.canonical\.com|security\.ubuntu\.com)[^\s]+%$1http://ftp.riken.jp/Linux/ubuntu/%' /etc/apt/sources.list
# 24.04
#sudo sed -i.bak -r 's@http://(jp\.)?archive\.ubuntu\.com/ubuntu/?@https://ftp.udx.icscoe.jp/Linux/ubuntu/@g' /etc/apt/sources.list.d/ubuntu.sources
sudo apt-get update
sudo apt -y install openssh-server curl unzip qemu-guest-agent ufw

# Timezone
sudo timedatectl set-timezone Asia/Tokyo

# sudo nopasswd
echo 'ubuntu ALL=NOPASSWD: ALL' | sudo EDITOR='tee -a' visudo

# Firewall
sudo ufw allow OpenSSH
echo 'y' | sudo ufw enable

# SSH setup
SSH_CONFIG="/etc/ssh/sshd_config"
SSH_CONFIG_BACKUP="/etc/ssh/sshd_config.bk"
SSH_PORT_NUMBER="22"

change_setting() {
  TARGET="$1"
  KEYWORD="$2"
  VALUE="$3"

  if grep -q "^${KEYWORD}" "${TARGET}"; then
    sudo sed -i "s|^${KEYWORD}.*|${KEYWORD} ${VALUE}|" "${TARGET}"
  elif grep -q "^#${KEYWORD}" "${TARGET}"; then
    sudo sed -i "s|^#${KEYWORD}.*|${KEYWORD} ${VALUE}|" "${TARGET}"
  else
    echo "${KEYWORD} ${VALUE}" | sudo tee -a "${TARGET}" >/dev/null
  fi
}

if [ ! -f "${SSH_CONFIG_BACKUP}" ]; then
  sudo cp "${SSH_CONFIG}" "${SSH_CONFIG_BACKUP}"

  change_setting "${SSH_CONFIG}" Port "${SSH_PORT_NUMBER}"
  change_setting "${SSH_CONFIG}" PermitRootLogin no
  change_setting "${SSH_CONFIG}" PasswordAuthentication no
  change_setting "${SSH_CONFIG}" ChallengeResponseAuthentication no
  change_setting "${SSH_CONFIG}" PermitEmptyPasswords no
  change_setting "${SSH_CONFIG}" SyslogFacility AUTHPRIV
  change_setting "${SSH_CONFIG}" LogLevel VERBOSE
fi

# SSH key setup
sudo mkdir -p /home/ubuntu/.ssh
curl -fsSL "${GITHUB_KEYS_URL}" | sudo tee /home/ubuntu/.ssh/authorized_keys >/dev/null
sudo chmod 700 /home/ubuntu/.ssh
sudo chmod 600 /home/ubuntu/.ssh/authorized_keys
sudo chown -R ubuntu:ubuntu /home/ubuntu/.ssh

sudo systemctl restart sshd.service

# External scripts
wget -q https://raw.githubusercontent.com/maemune/Unix/main/Generat_SSH.sh
chmod u+x Generat_SSH.sh
./Generat_SSH.sh

wget -q https://raw.githubusercontent.com/maemune/Unix/main/Refresh_host.sh
chmod u+x Refresh_host.sh

wget -q https://raw.githubusercontent.com/maemune/Unix/main/Update.sh
chmod u+x Update.sh
sudo chown ubuntu:ubuntu Update.sh
sudo mv Update.sh /home/ubuntu/Update.sh

# Cron
TMPFILE="$(mktemp)"
crontab -l 2>/dev/null > "${TMPFILE}"
cat << EOF >> "${TMPFILE}"
*/5 * * * * curl -fsSL ${GITHUB_KEYS_URL} > /home/ubuntu/.ssh/authorized_keys && chown ubuntu:ubuntu /home/ubuntu/.ssh/authorized_keys && chmod 600 /home/ubuntu/.ssh/authorized_keys
0 3 */2 * * /home/ubuntu/Update.sh
EOF
crontab "${TMPFILE}"
rm -f "${TMPFILE}"

# Storage extend
sudo lvextend -l +100%FREE /dev/ubuntu-vg/ubuntu-lv
sudo resize2fs /dev/mapper/ubuntu--vg-ubuntu--lv

# Final update & reboot
/home/ubuntu/Update.sh
sudo reboot now
