#!/bin/bash

# Valheimサーバーの停止
systemctl stop valheim_server

# Valheimの関連ファイルを削除
rm -rf /etc/systemd/system/valheim_server.service /opt/valheim_server/ /home/valheim /etc/motd

# Valheimユーザを削除
userdel valheim

# palworld ユーザーを作成
useradd -m palworld

# Root ユーザのパスワードログインを禁止し SSH は公開鍵認証に
sed -i '/^PermitRootLogin/s/.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
systemctl restart sshd

# palworld ユーザーにsudo NOPASSWD:ALL 権限を付与
echo "palworld ALL=(ALL) NOPASSWD:ALL" | tee /etc/sudoers.d/palworld

# ufw を無効化
systemctl stop ufw.service
systemctl disable ufw.service

# /opt/palworld/ 作成
mkdir -p /opt/palworld/
chown -R palworld:palworld /opt/palworld/

# palworld ユーザーになって detecated server ファイルをダウンロード
sudo -i -u palworld bash << 'EOF'

# ゲームファイルダウンロード
/usr/games/steamcmd +force_install_dir /opt/palworld/ +login anonymous +app_update 2394010 validate +quit

# steamclient.so: cannot open shared object file: No such file or directory 対策
mkdir -p /home/palworld/.steam/sdk64/
ln -s /home/palworld/.steam/steamcmd/linux64/steamclient.so /home/palworld/.steam/sdk64/steamclient.so

EOF

# サーバプロセス起動サービス /etc/systemd/system/palworld-dedicated.service ファイルを作成
cat <<EOF > /etc/systemd/system/palworld-dedicated.service
[Unit]
Description=Palworld Dedicated Server
Wants=network-online.target
After=syslog.target network.target nss-lookup.target network-online.target

[Service]
ExecStartPre=/usr/games/steamcmd +force_install_dir /opt/palworld/ +login anonymous +app_update 2394010 +quit
ExecStart=/opt/palworld/PalServer.sh port=8211 players=32 -useperfthreads -NoAsyncLoadingThread -UseMultithreadForDS
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

# systemd のデーモンを再読み込み
systemctl daemon-reload

# palworld-dedicated.service を有効化
systemctl enable palworld-dedicated.service

# 自動アップデートスクリプト update-palworld.sh 作成
cat <<EOF > /opt/palworld/update-palworld.sh
#!/bin/sh

# Steam CMD path
Steamcmd="/usr/games/steamcmd"
install_dir="/opt/palworld/"

echo "# Check the environment."
date
OLD_Build=\`\$Steamcmd +force_install_dir \$install_dir +login anonymous +app_status 2394010 +quit | grep -e "BuildID" | awk '{print \$8}'\`
echo "Old BuildID: \$OLD_Build"

echo "# Start updating the game server..."
\$Steamcmd +force_install_dir \$install_dir +login anonymous +app_update 2394010 validate +quit > /dev/null

echo "# Check the environment after the update."
NEW_Build=\`\$Steamcmd +force_install_dir \$install_dir +login anonymous +app_status 2394010 +quit | grep -e "BuildID" | awk '{print \$8}'\`
echo "New BuildID: \$NEW_Build"

# Check if updated.
if [ \$OLD_Build = \$NEW_Build ]; then
    echo "Build number matches."
else
    echo "Restart palworld-dedicated.service because an game update exists."
    sudo systemctl stop palworld-dedicated.service
    sudo systemctl start palworld-dedicated.service
    systemctl status palworld-dedicated.service
fi
EOF

# update-palworld.sh の自動実行登録
chmod +x /opt/palworld/update-palworld.sh
chown palworld:palworld /opt/palworld/update-palworld.sh
echo "0 */3 * * * /opt/palworld/update-palworld.sh" | crontab -u palworld -

# /swapfile の作成
fallocate -l 16G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon -p 10 /swapfile
echo '/swapfile none swap sw,pri=10 0 0' | tee -a /etc/fstab

# palworld-dedicated.service サーバプロセスを起動
sudo systemctl start palworld-dedicated.service

# 起動後に DefaultPalWorldSettings.ini が作成されるのを待ってコピー
sleep 120
cp /opt/palworld/DefaultPalWorldSettings.ini /opt/palworld/Pal/Saved/Config/LinuxServer/PalWorldSettings.ini
