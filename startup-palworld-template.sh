#!/bin/bash

# setup-palworld_remove-valheim.sh をダウンロード
curl -LO https://raw.githubusercontent.com/palsoku/Palworld-ConoHaVPS/main/setup-palworld.sh

# ダウンロードしたスクリプトに実行権限を付与
chmod +x setup-palworld.sh

# スクリプトをバックグラウンドで実行
./setup-palworld.sh &
