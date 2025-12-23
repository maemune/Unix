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

# --- MySQL セキュリティ設定 (mysql_secure_installation の自動化) ---
echo "Configuring MySQL Security..."
sudo mysql <<EOF
-- rootパスワードの設定と認証プラグインの変更
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${DB_ROOT_PASSWORD}';
-- 匿名ユーザーの削除
DELETE FROM mysql.user WHERE User='';
-- rootのリモートログイン禁止
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
-- テストデータベースの削除
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
-- 設定の反映
FLUSH PRIVILEGES;
EOF

# --- データベースとSSHトンネル用ユーザーの作成 ---
echo "Creating Database and User..."
sudo mysql -u root -p"${DB_ROOT_PASSWORD}" <<EOF
CREATE DATABASE IF NOT EXISTS ${DB_NAME};
-- SSHトンネル経由（localhost）からの接続のみを許可するユーザー
CREATE USER '${DB_USER}'@'127.0.0.1' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'127.0.0.1';
FLUSH PRIVILEGES;
EOF

# --- MySQL 設定ファイルの編集 (外部接続を拒否しlocalhostに縛る) ---
echo "Hardening MySQL Configuration..."
CONF_FILE="/etc/mysql/mysql.conf.d/mysqld.cnf"

# bind-addressを127.0.0.1に固定（外部からの3306直接アクセスを遮断）
sudo sed -i 's/^bind-address.*/bind-address = 127.0.0.1/' $CONF_FILE
sudo sed -i 's/^mysqlx-bind-address.*/mysqlx-bind-address = 127.0.0.1/' $CONF_FILE

# MySQL再起動
sudo systemctl restart mysql
sudo systemctl enable mysql

echo "----------------------------------------------------------"
echo "Setup Complete."
echo "Database: ${DB_NAME}"
echo "User: ${DB_USER} (Allowed from 127.0.0.1 only)"
echo "----------------------------------------------------------"
echo "To connect via SSH Tunnel from your local machine:"
echo "ssh -L 3306:127.0.0.1:3306 $(whoami)@$(hostname -I | awk '{print $1}')"
echo "----------------------------------------------------------"
