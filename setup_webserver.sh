#!/bin/bash
#wget https://raw.githubusercontent.com/maemune/Unix/main/setup_webserver.sh && nano ./setup_webserver.sh && chmod u+x ./setup_webserver.sh && ./setup_webserver.sh

# --- ユーザー定義変数 ---
DOMAIN="goggle.mydns.jp"
EMAIL="maemune1999@gmail.com" # Certbot用の連絡先メールアドレス
USERNAME="maemune"
# PASSWORD 変数は以下で動的に設定されます

# ログ出力関数 (以前と同じ)
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
sudo apt install -y apache2 certbot python3-certbot-apache libapache2-mod-auth-basic || log_error "パッケージのインストールに失敗しました。"

# 必要なモジュールの有効化
sudo a2enmod ssl rewrite auth_basic authn_file
sudo systemctl restart apache2

# --- 2. Webサイトコンテンツとベーシック認証のセットアップ ---
log "Webサイトコンテンツとベーシック認証ファイルの準備を開始します..."

# 添付された index.html を /var/www/html/ にコピー (このスクリプトと同じディレクトリにある前提)
if [ -f "index.html" ]; then
    sudo cp index.html /var/www/html/
    log "index.html を /var/www/html/ に配置しました。"
else
    log_error "エラー: 'index.html' ファイルが見つかりません。スクリプトと同じディレクトリに配置してください。"
fi

# ベーシック認証ユーザー ($USERNAME) を設定 (パスワードはopensslでハッシュ化)
log "ベーシック認証ユーザー ($USERNAME) を設定します..."
# ユーザーが入力した $PASSWORD を使用
HASH=$(echo "$PASSWORD" | openssl passwd -stdin -apr1)
echo "$USERNAME:$HASH" | sudo tee /etc/apache2/.htpasswd > /dev/null

# ファイルの所有者をroot、グループをwww-dataにし、権限を制限
sudo chown root:www-data /etc/apache2/.htpasswd
sudo chmod 640 /etc/apache2/.htpasswd

# --- 3. CertbotによるSSL証明書の取得 ---
log "CertbotによるSSL証明書の取得を開始します ($DOMAIN)..."
sudo certbot --apache -d "$DOMAIN" --non-interactive --agree-tos --email "$EMAIL" --redirect --hsts --staple-ocsp --no-eff-email

if [ $? -ne 0 ]; then
    log_error "Certbotによる証明書の取得に失敗しました。ポート転送とDNS設定を確認してください。"
fi

# --- 4. HTTPS設定ファイル (000-default-le-ssl.conf) の修正 ---
log "HTTPS設定ファイルにベーシック認証を追加します..."

SSL_CONF="/etc/apache2/sites-enabled/000-default-le-ssl.conf"

# 以前の設定の残骸（ベーシック認証ブロック）を削除
sudo sed -i '/<Directory \/var\/www\/html>/,/<\/Directory>/d' "$SSL_CONF"

# 認証設定を DocumentRoot /var/www/html の直後に追加
sudo sed -i '/DocumentRoot \/var\/www\/html/a \ \ \ \ \ \ \ \ <Directory \/var\/www\/html>\n\ \ \ \ \ \ \ \ \ \ \ \ AuthType Basic\n\ \ \ \ \ \ \ \ \ \ \ \ AuthName \"Private Web Area\"\n\ \ \ \ \ \ \ \ \ \ \ \ AuthUserFile \/etc\/apache2\/.htpasswd\n\ \ \ \ \ \ \ \ \ \ \ \ Require valid-user\n\ \ \ \ \ \ \ \ <\/Directory>' "$SSL_CONF"

# --- 5. Apache の設定確認と再起動 ---
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
