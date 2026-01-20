#!/bin/bash
#wget https://raw.githubusercontent.com/maemune/Unix/main/setup_webserver.sh && nano ./setup_webserver.sh && chmod u+x ./setup_webserver.sh && ./setup_webserver.sh

# --- ユーザー定義変数 ---
DOMAIN="goggle.mydns.jp"
EMAIL="maemune0515@gmail.com" # Certbot用の連絡先メールアドレス
USERNAME="maemune"
GITHUB_INDEX_URL="https://raw.githubusercontent.com/maemune/Unix/refs/heads/main/index.html"
# PASSWORD 変数は以下で動的に設定されます

# ログ出力関数
log() {
    echo -e "\n\033[1;34m[INFO]\033[0m $1"
}

log_error() {
    echo -e "\n\033[1;31m[ERROR]\033[0m $1"
    exit 1
}

# --- パスワード入力と検証 ---
while true; do
    read -sp "🔐 ベーシック認証用のパスワードを入力してください: " PASSWORD
    echo
    read -sp "🔐 確認のため、もう一度入力してください: " PASSWORD_CONFIRM
    echo
    
    if [ "$PASSWORD" = "$PASSWORD_CONFIRM" ]; then
        if [ -z "$PASSWORD" ]; then
            log_error "パスワードを空白にすることはできません。"
            continue
        fi
        log "パスワードの入力が確認されました。"
        break
    else
        log_error "パスワードが一致しません。再度入力してください。"
    fi
done

# --- 1. システムの準備とパッケージインストール ---
log "システムのアップデートと必要なパッケージのインストールを開始します..."
sudo apt update || log_error "apt updateに失敗しました。"
# ufw と openssl を追加インストールします
sudo apt install -y apache2 certbot python3-certbot-apache wget ufw openssl || log_error "パッケージのインストールに失敗しました。"

# 必要なモジュールの有効化
sudo a2enmod ssl rewrite auth_basic authn_file

# --- 2. ファイアウォール (UFW) の設定と有効化 ---
log "ファイアウォール (UFW) の設定を開始します..."

# Apache Full (HTTP 80番と HTTPS 443番) を許可
# Certbotが認証を通るため、80番の開放は必須です
sudo ufw allow 'Apache Full'

# UFWを有効化（対話形式にならないように強制的に 'y' を渡す）
echo "y" | sudo ufw enable || log_error "UFWの有効化に失敗しました。"

log "UFWが有効になり、SSH(22)とApache Full(80/443)が開放されました。"
sudo ufw status verbose

# Apacheの再起動
sudo systemctl restart apache2

# --- 3. Webサイトコンテンツとベーシック認証のセットアップ ---
log "Webサイトコンテンツとベーシック認証ファイルの準備を開始します..."

# GitHubから index.html をダウンロード
log "GitHub ($GITHUB_INDEX_URL) から index.html をダウンロードします..."
sudo wget -O /var/www/html/index.html "$GITHUB_INDEX_URL"

if [ $? -ne 0 ]; then
    log_error "エラー: index.htmlのダウンロードに失敗しました。URLまたはネットワーク接続を確認してください。"
fi

# ベーシック認証ユーザー ($USERNAME) を設定 (パスワードはopensslでハッシュ化)
log "ベーシック認証ユーザー ($USERNAME) を設定します..."
# ユーザーが入力した $PASSWORD を使用
HASH=$(echo "$PASSWORD" | openssl passwd -stdin -apr1)
echo "$USERNAME:$HASH" | sudo tee /etc/apache2/.htpasswd > /dev/null

# ファイルの所有者をroot、グループをwww-dataにし、権限を制限
sudo chown root:www-data /etc/apache2/.htpasswd
sudo chmod 640 /etc/apache2/.htpasswd

# --- 4. CertbotによるSSL証明書の取得 ---
log "CertbotによるSSL証明書の取得を開始します ($DOMAIN)..."
# Certbotが自動でApacheのルールを調整します
sudo certbot --apache -d "$DOMAIN" --non-interactive --agree-tos --email "$EMAIL" --redirect --hsts --staple-ocsp --no-eff-email

if [ $? -ne 0 ]; then
    log_error "Certbotによる証明書の取得に失敗しました。ポート転送とDNS設定を確認してください。"
fi

# --- 5. HTTPS設定ファイル (000-default-le-ssl.conf) の修正 ---
log "HTTPS設定ファイルにベーシック認証を追加します..."

SSL_CONF="/etc/apache2/sites-enabled/000-default-le-ssl.conf"

# 以前の設定の残骸（ベーシック認証ブロック）を削除
sudo sed -i '/<Directory \/var\/www\/html>/,/<\/Directory>/d' "$SSL_CONF"

# 認証設定を DocumentRoot /var/www/html の直後に追加
sudo sed -i '/DocumentRoot \/var\/www\/html/a \ \ \ \ \ \ \ \ <Directory \/var\/www\/html>\n\ \ \ \ \ \ \ \ \ \ \ \ AuthType Basic\n\ \ \ \ \ \ \ \ \ \ \ \ AuthName \"Private Web Area\"\n\ \ \ \ \ \ \ \ \ \ \ \ AuthUserFile \/etc\/apache2\/.htpasswd\n\ \ \ \ \ \ \ \ \ \ \ \ Require valid-user\n\ \ \ \ \ \ \ \ <\/Directory>' "$SSL_CONF"

# --- 6. Apache の設定確認と再起動 ---
log "Apacheの設定確認と再起動を実行します..."
sudo apache2ctl configtest

if [ $? -ne 0 ]; then
    log_error "Apacheの設定に構文エラーがあります。手動で確認してください。"
fi

sudo systemctl restart apache2
log "\033[1;32m=== ✅ セットアップ完了 ===\033[0m"
echo "アクセスURL: https://$DOMAIN/"
echo "ユーザー名: $USERNAME"
echo "パスワードは入力されたものです。"
echo "サーバーの準備ができました。ブラウザでアクセスし、ベーシック認証が機能するか確認してください。"
