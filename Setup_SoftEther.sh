#!/bin/bash
#wget https://raw.githubusercontent.com/maemune/Unix/refs/heads/main/Setup_SoftEther.sh && nano ./Setup_SoftEther.sh && chmod u+x ./Setup_SoftEther.sh && ./Setup_SoftEther.sh

set -e

# Install dependencies for scraping and building
sudo apt update
sudo apt install -y wget curl jq make gcc binutils

# Get latest release tag from GitHub API
LATEST_TAG=$(curl -s https://api.github.com/repos/SoftEtherVPN/SoftEtherVPN_Stable/releases/latest | jq -r .tag_name)

# Define download URL for linux-x64-64bit.tar.gz
# Note: The file name structure usually follows softether-vpnserver-[tag]-[date]-linux-x64-64bit.tar.gz
# Fetching the specific browser_download_url that matches the pattern
DOWNLOAD_URL=$(curl -s https://api.github.com/repos/SoftEtherVPN/SoftEtherVPN_Stable/releases/latest \
    | jq -r '.assets[] | select(.name | contains("vpnserver") and contains("linux-x64-64bit.tar.gz")) | .browser_download_url')

INSTALL_DIR="/usr/local/vpnserver"

# Download and extract
cd /tmp
wget -O softether-vpnserver.tar.gz "${DOWNLOAD_URL}"
tar -xzvf softether-vpnserver.tar.gz

# Build
cd vpnserver
make i_read_and_agree_the_license_agreement

# Setup directory
cd ..
sudo mv vpnserver ${INSTALL_DIR}
cd ${INSTALL_DIR}

# Set permissions
sudo chmod 600 *
sudo chmod 700 vpnserver
sudo chmod 700 vpncmd

# Create systemd service unit
cat <<EOF | sudo tee /etc/systemd/system/vpnserver.service
[Unit]
Description=SoftEther VPN Server
After=network.target network-online.target

[Service]
ExecStart=${INSTALL_DIR}/vpnserver start
ExecStop=${INSTALL_DIR}/vpnserver stop
Type=forking
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Start and enable service
sudo systemctl daemon-reload
sudo systemctl enable vpnserver
sudo systemctl start vpnserver

# Verify installation
sudo ${INSTALL_DIR}/vpncmd /tools /cmd check
