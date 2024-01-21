#!/bin/bash

# palworld ユーザーを作成
useradd -m palworld

# palworld ユーザーに sudo 権限を付与
echo 'palworld ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# セキュリティグループで制限するので firewalld を無効化 
systemctl stop firewalld
systemctl disable firewalld

# palworld ユーザーに切り替え
sudo -i -u palworld bash << 'EOF'

# palworld ユーザーのホームディレクトリに移動
cd ~

# glibc.i686 libstdc++.i686 tar をインストール
sudo dnf install -y glibc.i686 libstdc++.i686 tar

# palworld ユーザーのホームディレクトリで steamcmd_linux.tar.gz をダウンロード
curl -o steamcmd_linux.tar.gz https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz

# tar ファイルを解凍
tar xf steamcmd_linux.tar.gz

# SteamCMD を使ってゲームをインストールし、更新
./steamcmd.sh +force_install_dir ~/Steam/palworld/ +login anonymous +app_update 2394010 validate +quit

EOF

# palworld-dedicated.service ファイルを作成
cat << EOF > /etc/systemd/system/palworld-dedicated.service
[Unit]
Description=Palworld Dedicated Server
Wants=network-online.target
After=syslog.target network.target nss-lookup.target network-online.target

[Service]
ExecStart=/home/palworld/Steam/palworld/PalServer.sh port=8211 players=32 -useperfthreads -NoAsyncLoadingThread -UseMultithreadForDS
LimitNOFILE=100000
ExecReload=/bin/kill -s HUP \$MAINPID
ExecStop=/bin/kill -s INT \$MAINPID
Restart=always
User=palworld
Group=palworld
TimeoutStartSec=300

[Install]
WantedBy=multi-user.target
EOF

sudo -i -u palworld bash << 'EOF'

# steamclient.so: cannot open shared object file: No such file or directory 対策
mkdir -p /home/palworld/.steam/sdk64/
ln -s /home/palworld/linux64/steamclient.so /home/palworld/.steam/sdk64/steamclient.so

# systemd デーモンをリロード
sudo systemctl daemon-reload

# palworld-dedicated.service を有効化
sudo systemctl enable palworld-dedicated.service

# palworld-dedicated.service を起動
sudo systemctl start palworld-dedicated.service

# update-palworld.sh を作成
cat << 'EOT' > /home/palworld/update-palworld.sh
#!/bin/sh

# Steam CMD path
Steamcmd="/home/palworld/steamcmd.sh"
install_dir="/home/palworld/Steam/palworld"

echo "# Check the environment."
date
OLD_Build=`$Steamcmd +force_install_dir $install_dir +login anonymous +app_status 2394010 +quit | grep -e "BuildID" | awk '{print $8}'`
echo "Old BuildID: $OLD_Build"

echo "# Start updating the game server..."
$Steamcmd +force_install_dir $install_dir +login anonymous +app_update 2394010 validate +quit > /dev/null

echo "# Check the environment after the update."
NEW_Build=`$Steamcmd +force_install_dir $install_dir +login anonymous +app_status 2394010 +quit | grep -e "BuildID" | awk '{print $8}'`
echo "New BuildID: $NEW_Build"

# Check if updated.
if [ $OLD_Build = $NEW_Build ]; then
    echo "Build number matches."
else
    echo "Restart palworld-dedicated.service because an game update exists."
    sudo systemctl stop palworld-dedicated.service
    sudo systemctl start palworld-dedicated.service
    systemctl status palworld-dedicated.service
fi
EOT

# PalWorldSettings.ini 作成
cp /home/palworld/Steam/palworld/DefaultPalWorldSettings.ini /home/palworld/Steam/palworld/Pal/Saved/Config/LinuxServer/PalWorldSettings.ini

# 実行権限をつける
chmod +x /home/palworld/update-palworld.sh

# cron 登録
echo "0 */3 * * * /home/palworld/update-palworld.sh" | crontab -

EOF
