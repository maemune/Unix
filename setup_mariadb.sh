#!/bin/bash

#wget https://raw.githubusercontent.com/maemune/Unix/main/setup_mariadb.sh && nano ./setup_mariadb.sh && chmod u+x ./setup_mariadb.sh && ./setup_mariadb.sh

# ==========================================================
# MariaDB Setup Script (0.0.0.0 Access Enabled)
# ==========================================================

# --- 設定変数 ---
DB_ROOT_PASSWORD="bq#CLsCa&.e(Q*|RV6s2iuqZ"
DB_USER="ubuntu"
DB_PASSWORD="bq#CLsCa&.e(Q*|RV6s2iuqZ"
DB_NAME="mariadb"

# --- スクリプト開始 ---
set -e

echo "Updating system packages..."
sudo apt update && sudo apt upgrade -y

echo "Installing MariaDB Server..."
sudo apt install -y mariadb-server

echo "Starting MariaDB..."
sudo systemctl start mariadb
sudo systemctl enable mariadb

# --- MariaDB セキュリティ設定 ---
echo "Configuring MariaDB Security..."
sudo mariadb <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASSWORD}';
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost','127.0.0.1','::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%%';
FLUSH PRIVILEGES;
EOF

# --- データベースとユーザー作成（0.0.0.0許可） ---
echo "Creating Database and User..."
sudo mariadb -u root -p"${DB_ROOT_PASSWORD}" <<EOF
CREATE DATABASE IF NOT EXISTS ${DB_NAME};
DROP USER IF EXISTS '${DB_USER}'@'%';
CREATE USER '${DB_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'%';
FLUSH PRIVILEGES;
EOF

# --- MariaDB 設定 ---
echo "Tuning MariaDB Configuration..."
CONF_FILE="/etc/mysql/mariadb.conf.d/50-server.cnf"

sudo cp $CONF_FILE "${CONF_FILE}.bak"

sudo tee $CONF_FILE <<EOF
[mysqld]
user                    = mariadb

# --- Network ---
bind-address            = 0.0.0.0

# --- Basic ---
key_buffer_size         = 16M
max_allowed_packet      = 64M
thread_stack            = 256K
thread_cache_size       = 8

# --- InnoDB ---
innodb_buffer_pool_size         = 8G
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
log_error               = /var/log/mariadb/error.log
slow_query_log          = 1
slow_query_log_file     = /var/log/mariadb/mariadb-slow.log
long_query_time         = 2
EOF

# --- MariaDB 再起動 ---
echo "Restarting MariaDB Service..."
sudo systemctl restart mariadb

echo "----------------------------------------------------------"
echo "MariaDB Setup Complete"
echo "Bind Address : 0.0.0.0"
echo "User Access  : ${DB_USER}@%"
echo "----------------------------------------------------------"
