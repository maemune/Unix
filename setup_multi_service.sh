#!/bin/bash
#wget https://raw.githubusercontent.com/maemune/Unix/main/setup_multi_service.sh && nano ./setup_multi_service.sh && chmod u+x ./setup_multi_service.sh && ./setup_multi_service.sh

# =========================================================
# 複数サービス対応 Apache + SSL + Reverse Proxy 設定スクリプト
# BlueMap や他サービスを順番に設定可能
# =========================================================

# 必須モジュールを有効化（初回のみ）
sudo a2enmod proxy proxy_http proxy_wstunnel ssl headers

echo "=============================================="
echo "複数サービス用 Apache vhost 設定スクリプト"
echo "Ctrl+C で終了、完了後 Enter を押してください"
echo "=============================================="

while true; do
    read -p "サービス名（例: BlueMap, Nextcloud, Wiki）: " SERVICENAME
    read -p "サブドメイン（例: bluemap.goggle.mydns.jp）: " SUBDOMAIN
    read -p "サービスが動作している内部IP（例: 192.168.1.100）: " SERVICE_IP
    read -p "サービスポート（例: 8100）: " SERVICE_PORT
    read -p "このサービスはWebSocketを使用しますか？ (y/n): " USE_WS

    VHOST_FILE="/etc/apache2/sites-available/${SERVICENAME}.conf"

    echo "----------------------------------------------"
    echo "作成する vhost: $VHOST_FILE"
    echo "サブドメイン: $SUBDOMAIN"
    echo "内部IP: $SERVICE_IP"
    echo "ポート: $SERVICE_PORT"
    echo "WebSocket: $USE_WS"
    echo "----------------------------------------------"

    # vhost 作成
    sudo tee $VHOST_FILE > /dev/null <<EOF
<VirtualHost *:443>
    ServerName $SUBDOMAIN

    SSLEngine on
    SSLCertificateFile /etc/letsencrypt/live/$SUBDOMAIN/fullchain.pem
    SSLCertificateKeyFile /etc/letsencrypt/live/$SUBDOMAIN/privkey.pem
    Include /etc/letsencrypt/options-ssl-apache.conf
    SSLUseStapling on
    Header always set Strict-Transport-Security "max-age=31536000"

    ProxyPreserveHost On
    ProxyPass "/" "http://$SERVICE_IP:$SERVICE_PORT/"
    ProxyPassReverse "/" "http://$SERVICE_IP:$SERVICE_PORT/"
EOF

    # WebSocket が必要な場合
    if [[ "$USE_WS" == "y" || "$USE_WS" == "Y" ]]; then
        sudo tee -a $VHOST_FILE > /dev/null <<EOF
    ProxyPass "/ws" "ws://$SERVICE_IP:$SERVICE_PORT/ws"
    ProxyPassReverse "/ws" "ws://$SERVICE_IP:$SERVICE_PORT/ws"
EOF
    fi

    # vhost 続き
    sudo tee -a $VHOST_FILE > /dev/null <<EOF
    ErrorLog \${APACHE_LOG_DIR}/${SERVICENAME}_error.log
    CustomLog \${APACHE_LOG_DIR}/${SERVICENAME}_access.log combined
</VirtualHost>

<VirtualHost *:80>
    ServerName $SUBDOMAIN
    Redirect / https://$SUBDOMAIN/
</VirtualHost>
EOF

    # サイト有効化
    sudo a2ensite ${SERVICENAME}.conf

    # certbot で証明書取得
    sudo certbot certonly --apache -d $SUBDOMAIN

    # Apache 再読み込み
    sudo systemctl reload apache2

    echo "=============================================="
    echo "$SERVICENAME の設定完了: https://$SUBDOMAIN/"
    echo "=============================================="

    # 次のサービス追加確認
    read -p "他のサービスも追加しますか？ (y/n): " MORE
    if [[ "$MORE" != "y" && "$MORE" != "Y" ]]; then
        break
    fi
done

echo "=============================================="
echo "全てのサービス設定完了"
echo "=============================================="
