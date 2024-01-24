#!/bin/bash

# setup-palworld_remove-valheim.sh をダウンロード
curl -LO https://raw.githubusercontent.com/palsoku/Palworld-ConoHaVPS/main/setup-palworld-template.sh

# ダウンロードしたスクリプトに実行権限を付与
chmod +x setup-palworld-template.sh

# スクリプトをバックグラウンドで実行
/usr/bin/date >> /setup.log
./setup-palworld-template.sh >> /setup.log 2>&1
