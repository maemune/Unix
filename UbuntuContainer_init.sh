#!/bin/bash

#wget https://raw.githubusercontent.com/maemune/Unix/main/UbuntuContainer_init.sh && nano ./UbuntuContainer_init.sh && chmod u+x ./UbuntuContainer_init.sh && ./UbuntuContainer_init.sh

# Setting you info
GITHUB_KEYS_URL="https://github.com/maemune.keys"
#PASSWORD=""

# Update
#sudo perl -p -i.bak -e 's%(deb(?:-src|)\s+)https?://(?!archive\.canonical\.com|security\.ubuntu\.com)[^\s]+%$1http://ftp.riken.jp/Linux/ubuntu/%' /etc/apt/sources.list
# 24.04
#sudo sed -i.bak -r 's@http://(jp\.)?archive\.ubuntu\.com/ubuntu/?@https://ftp.udx.icscoe.jp/Linux/ubuntu/@g' /etc/apt/sources.list.d/ubuntu.sources
set -e

# Update & install
apt-get update
apt -y install openssh-server curl unzip qemu-guest-agent ufw

# Timezone
timedatectl set-timezone Asia/Tokyo

# sudo nopasswd
echo 'ubuntu ALL=NOPASSWD: ALL' | EDITOR='tee -a' visudo

# Firewall
ufw allow 22
echo 'y' | ufw enable

# SSH Setup
SSH_CONFIG="/etc/ssh/sshd_config"
SSH_CONFIG_BACKUP="/etc/ssh/sshd_config.bk"
SSH_PORT_NUMBER="22"

change_setting() {
  TARGET="$1"
  KEYWORD="$2"
  VALUE="$3"

  if grep -q "^${KEYWORD}" "${TARGET}"; then
    sed -i "s|^${KEYWORD}.*|${KEYWORD} ${VALUE}|" "${TARGET}"
  elif grep -q "^#${KEYWORD}" "${TARGET}"; then
    sed -i "s|^#${KEYWORD}.*|${KEYWORD} ${VALUE}|" "${TARGET}"
  else
    echo "${KEYWORD} ${VALUE}" >> "${TARGET}"
  fi
}

if [ ! -f "${SSH_CONFIG_BACKUP}" ]; then
  cp "${SSH_CONFIG}" "${SSH_CONFIG_BACKUP}"

  change_setting "${SSH_CONFIG}" Port "${SSH_PORT_NUMBER}"
  change_setting "${SSH_CONFIG}" PermitRootLogin no
  change_setting "${SSH_CONFIG}" PasswordAuthentication no
  change_setting "${SSH_CONFIG}" ChallengeResponseAuthentication no
  change_setting "${SSH_CONFIG}" PermitEmptyPasswords no
  change_setting "${SSH_CONFIG}" SyslogFacility AUTHPRIV
  change_setting "${SSH_CONFIG}" LogLevel VERBOSE
fi

# UserCreate
adduser -q --gecos "" --disabled-password ubuntu
usermod -aG sudo ubuntu
echo -e "${PASSWORD}\n${PASSWORD}\n" | passwd ubuntu

# SSH key setup
mkdir -p /home/ubuntu/.ssh
curl -fsSL "${GITHUB_KEYS_URL}" > /home/ubuntu/.ssh/authorized_keys
chmod 700 /home/ubuntu/.ssh
chmod 600 /home/ubuntu/.ssh/authorized_keys
chown -R ubuntu:ubuntu /home/ubuntu/.ssh

systemctl restart sshd.service

# Update script
cat << 'EOF' > /home/ubuntu/Update.sh
#!/bin/bash
sudo apt-get update
sudo apt -y full-upgrade
sudo apt -y autoremove
EOF
chmod u+x /home/ubuntu/Update.sh
chown ubuntu:ubuntu /home/ubuntu/Update.sh

# Cron
TMPFILE="$(mktemp)"
crontab -u ubuntu -l 2>/dev/null > "${TMPFILE}" || true
cat << EOF >> "${TMPFILE}"
*/5 * * * * curl -fsSL ${GITHUB_KEYS_URL} > /home/ubuntu/.ssh/authorized_keys && chown ubuntu:ubuntu /home/ubuntu/.ssh/authorized_keys && chmod 600 /home/ubuntu/.ssh/authorized_keys
0 3 */2 * * /home/ubuntu/Update.sh
EOF
crontab -u ubuntu "${TMPFILE}"
rm -f "${TMPFILE}"

# Reboot
reboot now
