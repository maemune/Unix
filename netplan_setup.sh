#!/bin/bash
#wget https://raw.githubusercontent.com/maemune/Unix/main/netplan_setup.sh && nano ./netplan_setup.sh && chmod u+x ./netplan_setup.sh && ./netplan_setup.sh

# =======================================================
# Netplan Wi-Fi フェイルオーバー設定スクリプト
# -------------------------------------------------------
# 目的: 有線LAN (eth0) を優先し、ダウン時に Wi-Fi (wlan0) へ
#       自動的に切り替える設定を Netplan に適用する。
# 
# 必須情報: 実行時にユーザー入力
# =======================================================

# --- SSID とパスワードの入力 ---
read -p "Wi-Fi SSID を入力してください: " WIFI_SSID
read -p "Wi-Fi パスワードを入力してください: " WIFI_PASS

NETPLAN_FILE="/etc/netplan/99-failover.yaml"

echo "--- ネットワーク設定を開始します ---"

# 1. Netplan設定ファイルの作成
echo "1. Netplan設定ファイル (${NETPLAN_FILE}) を作成中..."

# YAML内容を変数に格納 (ヒアドキュメントを使用)
NETPLAN_CONFIG=$(cat <<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    # 有線LAN (eth0) の設定 - 優先
    eth0:
      dhcp4: true
      optional: true
      nameservers:
          addresses: [1.1.1.1, 8.8.8.8]

  wifis:
    # Wi-Fi (wlan0) の設定 - フェイルオーバー
    wlan0:
      dhcp4: true
      optional: true
      access-points:
        "${WIFI_SSID}":
          password: "${WIFI_PASS}"
      nameservers:
          addresses: [1.1.1.1, 8.8.8.8]
EOF
)

# ファイルに書き込み
echo "${NETPLAN_CONFIG}" | sudo tee ${NETPLAN_FILE} > /dev/null

if [ $? -eq 0 ]; then
    echo "  -> ファイル作成成功。"
else
    echo "  -> エラー: ファイルの書き込みに失敗しました。スクリプトを終了します。"
    exit 1
fi

# 2. パーミッションの修正 (セキュリティ確保)
echo "2. ファイルのパーミッションを 600 に設定中..."
sudo chmod 600 ${NETPLAN_FILE}

# 3. 設定の構文チェックと適用
echo "3. Netplan設定の構文チェックと適用..."

# 構文チェック
sudo netplan try
if [ $? -ne 0 ]; then
    echo "  -> 警告: 構文チェックでエラーが発生しました。設定が適用されていません。"
    echo "  -> ${NETPLAN_FILE} の内容を確認してください。"
    exit 1
fi

# 設定の適用
sudo netplan apply
if [ $? -eq 0 ]; then
    echo "  -> 成功: 設定が正常に適用されました。"
    echo "--- 設定完了 ---"
else
    echo "  -> エラー: Netplanの適用に失敗しました。スクリプトを終了します。"
    exit 1
fi

echo "--- 設定完了。有線LANを抜き差ししてフェイルオーバー動作を確認してください ---"
