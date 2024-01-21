#!/bin/bash

# setup-palworld_remove-valheim.sh をダウンロード
curl -o 2.sh https://raw.githubusercontent.com/palsoku/Palworld-ConoHaVPS/main/2.sh

# ダウンロードしたスクリプトに実行権限を付与
chmod +x 2.sh

# スクリプトをバックグラウンドで実行
./2.sh &
