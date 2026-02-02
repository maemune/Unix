#!/bin/bash
#wget https://raw.githubusercontent.com/maemune/Unix/refs/heads/main/RockyLinux_init.sh && chmod u+x ./RockyLinux_init.sh && ./RockyLinux_init.sh
# RockyLinux_init.sh

# User / GitHub
USERNAME="rocky"
GITHUB_KEYS_URL="https://github.com/maemune.keys"

# Package update & install
sudo dnf -y update
sudo dnf -y install epel-release
sudo dnf -y install openssh-server curl unzip qemu-guest-agent firewalld wget

# Enable services
sudo systemctl enable --now sshd
sudo systemctl enable --now firewalld
sudo systemctl enable --now qemu-guest-agent

# Timezone
sudo timedatectl set-timezone Asia/Tokyo

# sudo nopasswd
echo "${USERNAME} ALL=NOPASSWD: ALL" | sudo EDITOR='tee -a' visudo

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

sudo systemctl restart sshd

# SSH key setup
sudo mkdir -p /home/${USERNAME}/.ssh
curl -fsSL "${GITHUB_KEYS_URL}" | sudo tee /home/${USERNAME}/.ssh/authorized_keys >/dev/null
sudo chmod 700 /home/${USERNAME}/.ssh
sudo chmod 600 /home/${USERNAME}/.ssh/authorized_keys
sudo chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}/.ssh

# External scripts
wget -q https://raw.githubusercontent.com/maemune/Unix/main/Generat_SSH.sh
chmod u+x Generat_SSH.sh
./Generat_SSH.sh

wget -q https://raw.githubusercontent.com/maemune/Unix/main/Refresh_host.sh
chmod u+x Refresh_host.sh

wget -q https://raw.githubusercontent.com/maemune/Unix/main/Update.sh
chmod u+x Update.sh
sudo chown ${USERNAME}:${USERNAME} Update.sh
sudo mv Update.sh /home/${USERNAME}/Update.sh

# Cron
TMPFILE="$(mktemp)"
crontab -l 2>/dev/null > "${TMPFILE}"
cat << EOF >> "${TMPFILE}"
*/5 * * * * curl -fsSL ${GITHUB_KEYS_URL} > /home/${USERNAME}/.ssh/authorized_keys && chown ${USERNAME}:${USERNAME} /home/${USERNAME}/.ssh/authorized_keys && chmod 600 /home/${USERNAME}/.ssh/authorized_keys
0 3 */2 * * /home/${USERNAME}/Update.sh
EOF
crontab "${TMPFILE}"
rm -f "${TMPFILE}"

# Storage extend (auto detect LVM)
LV_PATH=$(df / | tail -1 | awk '{print $1}')
sudo lvextend -l +100%FREE "${LV_PATH}"
sudo xfs_growfs /

# Final update & reboot
/home/${USERNAME}/Update.sh
sudo reboot now
