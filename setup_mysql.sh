#!/bin/bash

#wget https://raw.githubusercontent.com/maemune/Unix/main/setup_mysql.sh && nano ./setup_mysql.sh && chmod u+x ./setup_mysql.sh && ./setup_mysql.sh

# ==========================================================
# MySQL Setup Script (SSH Tunneling Focused)
# ==========================================================

# --- 設定変数 ---
DB_ROOT_PASSWORD="bq#CLsCa&.e(Q*|RV6s2iuqZ" #"YourSecureRootPassword"
DB_USER="ubuntu" #"ssh_tunnel_user"
DB_PASSWORD="bq#CLsCa&.e(Q*|RV6s2iuqZ" #"YourSecureUserPassword"
DB_NAME="mysql" #"my_application_db"

# --- スクリプト開始 ---
set -e

echo "Updating system packages..."
sudo apt update && sudo apt upgrade -y

echo "Installing MySQL Server..."
sudo apt install -y mysql-server

# --- MySQL セキュリティ設定 ---
echo "Configuring MySQL Security..."
sudo mysql <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${DB_ROOT_PASSWORD}';
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%%';
FLUSH PRIVILEGES;
EOF

# --- データベースとユーザー作成 ---
echo "Creating Database and User..."
sudo mysql -u root -p"${DB_ROOT_PASSWORD}" <<EOF
CREATE DATABASE IF NOT EXISTS ${DB_NAME};
CREATE USER '${DB_USER}'@'127.0.0.1' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'127.0.0.1';
FLUSH PRIVILEGES;
EOF

# --- メモリ・パフォーマンス・ネットワーク設定の書き込み ---
echo "Tuning MySQL Configuration..."
CONF_FILE="/etc/mysql/mysql.conf.d/mysqld.cnf"

# 設定ファイルのバックアップ
sudo cp $CONF_FILE "${CONF_FILE}.bak"

# 既存の設定を置換または追記するためのヒアドキュメント
sudo tee $CONF_FILE <<EOF
[mysqld]
# --- Network & Security ---
user            = mysql
bind-address    = 127.0.0.1
mysqlx-bind-address = 127.0.0.1
key_buffer_size         = 16M
max_allowed_packet      = 64M
thread_stack            = 256K
thread_cache_size       = 8

# --- InnoDB Memory Tuning ---
# 搭載メモリの約50%~70%を推奨。ここでは汎用的な2GB設定
innodb_buffer_pool_size         = 8G
innodb_log_file_size            = 512M
innodb_log_buffer_size          = 16M
innodb_flush_log_at_trx_commit  = 1
innodb_flush_method             = O_DIRECT
innodb_file_per_table           = 1

# --- Connection & Buffer Tuning ---
max_connections         = 150
tmp_table_size          = 64M
max_heap_table_size     = 64M
join_buffer_size        = 256K
sort_buffer_size        = 512K
read_buffer_size        = 256K
read_rnd_buffer_size    = 512K

# --- Logs ---
log_error = /var/log/mysql/error.log
slow_query_log = 1
slow_query_log_file = /var/log/mysql/mysql-slow.log
long_query_time = 2

# --- Binary Log ---
binlog_expire_logs_seconds = 2592000
EOF

# MySQL再起動
echo "Restarting MySQL Service..."
sudo systemctl restart mysql
sudo systemctl enable mysql

echo "----------------------------------------------------------"
echo "Setup & Tuning Complete."
echo "InnoDB Buffer Pool: 8GB (Adjust in ${CONF_FILE} if needed)"
echo "----------------------------------------------------------"
