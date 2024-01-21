#!/bin/bash

# setup-palworld_remove-valheim.sh をダウンロード
curl -o setup-palworld_remove-valheim.sh https://raw.githubusercontent.com/naoya-in/Palworld-ConoHaVPS/main/setup-palworld_remove-valheim.sh

# ダウンロードしたスクリプトに実行権限を付与
chmod +x setup-palworld_remove-valheim.sh

# スクリプトをバックグラウンドで実行
./setup-palworld_remove-valheim.sh &
