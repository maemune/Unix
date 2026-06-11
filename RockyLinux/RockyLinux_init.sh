#!/bin/bash
#sudo dnf -y install wget nano && wget https://raw.githubusercontent.com/maemune/Unix/refs/heads/main/RockyLinux/RockyLinux_init.sh && nano ./RockyLinux_init.sh && chmod u+x ./RockyLinux_init.sh && ./RockyLinux_init.sh
# User / GitHub
USERNAME="rocky"
GITHUB_KEYS_URL="https://github.com/maemune.keys"

# sudo nopasswd
if ! sudo grep -q "^${USERNAME} ALL=NOPASSWD: ALL" /etc/sudoers; then
  echo "${USERNAME} ALL=NOPASSWD: ALL" | sudo EDITOR='tee -a' visudo
fi

# Package update & install# RockyLinux repository
sudo sed -i 's|^#baseurl=http://dl.rockylinux.org/$contentdir|baseurl=https://ftp.jaist.ac.jp/pub/Linux/rocky|' /etc/yum.repos.d/rocky*.repo
sudo sed -i 's|^baseurl=http://dl.rockylinux.org/$contentdir|baseurl=https://ftp.jaist.ac.jp/pub/Linux/rocky|' /etc/yum.repos.d/rocky*.repo
sudo dnf clean all
sudo dnf makecache

# Package update & install
sudo dnf -y update
sudo dnf -y install epel-release
sudo dnf -y install openssh-server curl unzip firewalld qemu-guest-agent

# Enable services
sudo systemctl enable --now sshd
sudo systemctl enable --now firewalld

# Timezone
sudo timedatectl set-timezone Asia/Tokyo

# Firewall
sudo firewall-cmd --permanent --add-service=ssh
sudo firewall-cmd --reload

# SSH setup
SSH_CONFIG="/etc/ssh/sshd_config"
SSH_CONFIG_BACKUP="/etc/ssh/sshd_config.bk"
SSH_PORT_NUMBER="22"

change_setting() {
  TARGET="$1"
  KEYWORD="$2"
  VALUE="$3"

  if sudo grep -q "^${KEYWORD}" "${TARGET}"; then
    sudo sed -i "s|^${KEYWORD}.*|${KEYWORD} ${VALUE}|" "${TARGET}"
  elif sudo grep -q "^#${KEYWORD}" "${TARGET}"; then
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
  change_setting "${SSH_CONFIG}" KbdInteractiveAuthentication no
  change_setting "${SSH_CONFIG}" PermitEmptyPasswords no
  change_setting "${SSH_CONFIG}" SyslogFacility AUTHPRIV
  change_setting "${SSH_CONFIG}" LogLevel VERBOSE
fi

sudo systemctl restart sshd

# SSH key setup
sudo mkdir -p /home/${USERNAME}/.ssh
curl -fsSL "${GITHUB_KEYS_URL}" | sudo tee /home/${USERNAME}/.ssh/authorized_keys >/dev/null
sudo chmod 700 /home/${USERNAME}/.ssh
sudo chmod 600 /home/${USERNAME}/.ssh/authorized_keys
sudo chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}/.ssh

# External scripts
#wget -q https://raw.githubusercontent.com/maemune/Unix/main/Generat_SSH.sh
#chmod u+x /home/${USERNAME}/Generat_SSH.sh

#wget -q https://raw.githubusercontent.com/maemune/Unix/main/Refresh_host.sh
#chmod u+x /home/${USERNAME}/Refresh_host.sh

wget -q https://raw.githubusercontent.com/maemune/Unix/refs/heads/main/RockyLinux/Update.sh
sudo chmod u+x /home/${USERNAME}/Update.sh

# Cron
TMPFILE="$(mktemp)"
crontab -l 2>/dev/null > "${TMPFILE}"
cat << EOF >> "${TMPFILE}"
0 2 */1 * * curl -fsSL ${GITHUB_KEYS_URL} > /home/${USERNAME}/.ssh/authorized_keys && chown ${USERNAME}:${USERNAME} /home/${USERNAME}/.ssh/authorized_keys && chmod 600 /home/${USERNAME}/.ssh/authorized_keys
0 3 */2 * * /home/${USERNAME}/Update.sh
EOF
crontab "${TMPFILE}"
rm -f "${TMPFILE}"

# Final update & reboot
./Update.sh
sudo reboot now

