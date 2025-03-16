#!/bin/bash
#wget https://raw.githubusercontent.com/maemune/Unix/main/Python_Install_312.sh && nano ./Python_Install_312.sh && chmod u+x ./Python_Install_312.sh && ./Python_Install_312.sh

# エラーハンドリングを有効化
set -e

# 必要なパッケージのインストール
sudo apt update && sudo apt install -y software-properties-common

# deadsnakes PPAの追加
sudo add-apt-repository -y ppa:deadsnakes/ppa
sudo apt update

# Python 3.12のインストール
sudo apt install -y python3.12 python3.12-dev python3.12-venv

# 必要な開発ツールのインストール
sudo apt-get install -y libreadline-dev zlib1g-dev libncursesw5-dev libssl-dev libsqlite3-dev libgdbm-dev libc6-dev libbz2-dev
sudo apt-get install -y build-essential libffi-dev libexpat1-dev liblzma-dev python3-testresources

# pipのインストール
curl -sS https://bootstrap.pypa.io/get-pip.py -o get-pip.py
sudo python3.12 get-pip.py
sudo python3.12 -m pip install --upgrade pip
rm get-pip.py

# 必要に応じてpipコマンドを移動
if [ -f /usr/local/bin/pip ]; then
    sudo mv /usr/local/bin/pip /usr/local/bin/pip_
fi
if [ -f /usr/local/bin/pip3.12 ]; then
    sudo mv /usr/local/bin/pip3.12 /usr/local/bin/pip
fi

# 環境変数の更新
sudo update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 1
echo 'export PATH=$PATH:/usr/local/bin' >> ~/.profile

# 環境変数を反映
source ~/.profile

exit
