#!/bin/bash
#wget https://raw.githubusercontent.com/maemune/Unix/main/manage_services_clean.sh && nano ./manage_services_clean.sh && chmod u+x ./manage_services_clean.sh && ./manage_services_clean.sh

# =========================================================
# Apache vhost 管理スクリプト（不要 vhost 一括整理 + 追加・削除・一覧）
# BlueMapなど複数サービスを安全に管理
# =========================================================

A2ENMOD_DONE=false

function enable_modules() {
    if [ "$A2ENMOD_DONE" = false ]; then
        echo "必要モジュールを有効化しています..."
        sudo a2enmod proxy proxy_http proxy_wstunnel ssl headers
        A2ENMOD_DONE=true
    fi
}

function cleanup_old_vhosts() {
    echo "----------------------------------------------"
    echo "不要な vhost を自動で整理します"
    echo "例: map.conf, old_bluemap.conf など"
    echo "削除したい vhost をスペース区切りで入力してください"
    read -p "削除対象 vhost ファイル名（拡張子.conf含む）: " DELETE_LIST

    for VHOST in $DELETE_LIST; do
        VHOST_PATH="/etc/apache2/sites-available/$VHOST"
        if [[ -f "$VHOST_PATH" ]]; then
            echo "無効化: $VHOST"
            sudo a2dissite $VHOST
            sudo rm $VHOST_PATH
        else
            echo "存在しません: $VHOST"
        fi
    done
    sudo systemctl reload apache2
    echo "----------------------------------------------"
    echo "不要な vhost 整理完了"
    echo "----------------------------------------------"
}

function add_service() {
    enable_modules

    read -p "サービス名（例: BlueMap, Nextcloud, Wiki）: " SERVICENAME
    read -p "サブドメイン（例: bluemap.goggle.mydns.jp）: " SUBDOMAIN
    read -p "サービスが動作している内部IP（例: 192.168.1.100）: " SERVICE_IP
    read -p "サービスポート（例: 8100）: " SERVICE_PORT
    read -p "このサービスはWebSocketを使用しますか？ (y/n): " USE_WS

    VHOST_FILE="/etc/apache2/sites-available/${SERVICENAME}.conf"

    # vhost作成
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

    if [[ "$USE_WS" == "y" || "$USE_WS" == "Y" ]]; then
        sudo tee -a $VHOST_FILE > /dev/null <<EOF
    ProxyPass "/ws" "ws://$SERVICE_IP:$SERVICE_PORT/ws"
    ProxyPassReverse "/ws" "ws://$SERVICE_IP:$SERVICE_PORT/ws"
EOF
    fi

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

    # Apacheリロード
    sudo systemctl reload apache2

    echo "=============================================="
    echo "$SERVICENAME ($SUBDOMAIN) の設定完了"
    echo "HTTPSアクセス: https://$SUBDOMAIN/"
    echo "=============================================="
}

function remove_service() {
    read -p "削除するサービス名（vhostファイル名）: " SERVICENAME
    read -p "関連サブドメイン（例: bluemap.goggle.mydns.jp）: " SUBDOMAIN

    echo "----------------------------------------------"
    echo "確認: 以下を削除します"
    echo "サービス名: $SERVICENAME"
    echo "サブドメイン: $SUBDOMAIN"
    echo "----------------------------------------------"

    read -p "本当に削除しますか？ (y/n): " CONFIRM
    if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
        echo "削除をキャンセルしました"
        return
    fi

    sudo a2dissite ${SERVICENAME}.conf
    VHOST_FILE="/etc/apache2/sites-available/${SERVICENAME}.conf"
    if [[ -f "$VHOST_FILE" ]]; then
        sudo rm "$VHOST_FILE"
        echo "vhostファイル削除: $VHOST_FILE"
    fi

    sudo certbot delete --cert-name $SUBDOMAIN
    sudo systemctl reload apache2
    echo "=============================================="
    echo "$SERVICENAME ($SUBDOMAIN) の削除完了"
    echo "=============================================="
}

function list_services() {
    echo "=============================================="
    echo "現在有効な vhost 一覧:"
    sudo apache2ctl -S | grep namevhost
    echo "=============================================="
}

# メインループ
while true; do
    echo "----------------------------------------------"
    echo "Apache サービス管理スクリプト"
    echo "1) 不要 vhost 自動整理"
    echo "2) サービス追加"
    echo "3) サービス削除"
    echo "4) 有効サービス一覧"
    echo "5) 終了"
    read -p "選択してください [1-5]: " CHOICE

    case $CHOICE in
        1) cleanup_old_vhosts ;;
        2) add_service ;;
        3) remove_service ;;
        4) list_services ;;
        5) echo "終了します"; break ;;
        *) echo "1-5を入力してください" ;;
    esac
done
