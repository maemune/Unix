#!/bin/bash
#wget https://raw.githubusercontent.com/maemune/Unix/refs/heads/main/setup_mariadb.sh && nano ./setup_mariadb.sh && chmod u+x ./setup_mariadb.sh && ./setup_mariadb.sh

# ==========================================================
# MariaDB Setup Script (UFW & Local Network Access)
# ==========================================================

# --- Configuration Variables ---
DB_ROOT_PASSWORD="bq#CLsCa&.e(Q*|RV6s2iuqZ"
DB_USER="root"
DB_PASSWORD="bq#CLsCa&.e(Q*|RV6s2iuqZ"
DB_NAME="SeaDollar"
# Define your local network range
LOCAL_NETWORK="192.168.1.0/24"
# SQL Host pattern
SQL_HOST="192.168.1.%"

# --- Start Script ---
set -e

echo "Updating system packages..."
sudo apt update && sudo apt upgrade -y

echo "Installing MariaDB Server and UFW..."
sudo apt install -y mariadb-server ufw

echo "Starting MariaDB..."
sudo systemctl start mariadb
sudo systemctl enable mariadb

# --- UFW Configuration ---
echo "Configuring Firewall (UFW)..."
sudo ufw default deny incoming
sudo ufw default allow outgoing
# Allow MariaDB (3306) only from Local Network
sudo ufw allow from ${LOCAL_NETWORK} to any port 3306
# Enable UFW
echo "y" | sudo ufw enable

# --- MariaDB Security Configuration ---
echo "Configuring MariaDB Security..."
sudo mariadb <<EOF
ALTER USER 'root'@'192.168.1.%' IDENTIFIED BY '${DB_ROOT_PASSWORD}';
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost','127.0.0.1','::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%%';
FLUSH PRIVILEGES;
EOF

# --- Create Database and User ---
echo "Creating Database and User..."
sudo mariadb -u root -p"${DB_ROOT_PASSWORD}" <<EOF
CREATE DATABASE IF NOT EXISTS ${DB_NAME};
DROP USER IF EXISTS '${DB_USER}'@'${SQL_HOST}';
CREATE USER '${DB_USER}'@'${SQL_HOST}' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'${SQL_HOST}';
FLUSH PRIVILEGES;
EOF

# --- MariaDB Configuration ---
echo "Tuning MariaDB Configuration..."
CONF_FILE="/etc/mysql/mariadb.conf.d/50-server.cnf"

sudo cp $CONF_FILE "${CONF_FILE}.bak"

sudo tee $CONF_FILE <<EOF
[mysqld]
user                    = mysql
bind-address            = 0.0.0.0

# --- Basic ---
key_buffer_size         = 16M
max_allowed_packet      = 64M
thread_stack            = 256K
thread_cache_size       = 8

# --- InnoDB ---
innodb_buffer_pool_size         = 6G
innodb_log_file_size            = 512M
innodb_log_buffer_size          = 16M
innodb_flush_log_at_trx_commit  = 1
innodb_flush_method             = O_DIRECT
innodb_file_per_table           = 1

# --- Connection ---
max_connections         = 150
tmp_table_size          = 64M
max_heap_table_size     = 64M
join_buffer_size        = 256K
sort_buffer_size        = 512K
read_buffer_size        = 256K
read_rnd_buffer_size   = 512K

# --- Logs ---
log_error               = /var/log/mysql/error.log
slow_query_log          = 1
slow_query_log_file     = /var/log/mysql/mariadb-slow.log
long_query_time         = 2
EOF

sudo mkdir -p /var/log/mysql
sudo chown mysql:adm /var/log/mysql

# --- Restart MariaDB ---
echo "Restarting MariaDB Service..."
sudo systemctl restart mariadb

echo "----------------------------------------------------------"
echo "MariaDB Setup Complete with UFW"
echo "Firewall status: Active"
echo "Allowed Network: ${LOCAL_NETWORK}"
echo "User Access    : ${DB_USER}@${SQL_HOST}"
echo "----------------------------------------------------------"
