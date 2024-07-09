#!/bin/bash

# 必要なパッケージのインストール
sudo apt install -y software-properties-common
echo "" | sudo add-apt-repository ppa:deadsnakes/ppa
sudo apt update
sudo apt install -y python3.12 python3.12-dev

# 必要な開発ツールのインストール
sudo apt-get install -y libreadline-dev zlib1g-dev libncursesw5-dev libssl-dev libsqlite3-dev libgdbm-dev libc6-dev libbz2-dev
sudo apt-get install -y build-essential libffi-dev libexpat1-dev liblzma-dev python3-testresources

# システムパッケージ制限を無視してpipをインストール
curl -sS https://bootstrap.pypa.io/get-pip.py | sudo python3.12 --break-system-packages
sudo python3.12 -m pip install --upgrade pip --break-system-packages

# 必要に応じてpipコマンドを移動
sudo mv /usr/local/bin/pip /usr/local/bin/pip_ && sudo mv /usr/local/bin/pip3.12 /usr/local/bin/pip
echo 'export PATH=$PATH:/usr/local/bin' >> ~/.profile && source ~/.profile

exit
