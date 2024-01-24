#!/bin/bash

/usr/bin/date

# Initial Palworld AdminPassword 作成
ADMIN_PASSWORD=$(< /dev/urandom tr -dc A-Za-z0-9 | head -c8)

# /etc/motd 7行目に AdminPassword 追加
sed -i '7a\
Initial Palworld AdminPassword : '"$ADMIN_PASSWORD" /etc/motd
sed -i '8a\
' /etc/motd

# palworld user のシェルを bash に
chsh -s /bin/bash palworld

# Root ユーザのパスワードログインを禁止し SSH は公開鍵認証に
sed -i '/^PermitRootLogin/s/.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
systemctl restart sshd

# palworld ユーザーにsudo NOPASSWD:ALL 権限を付与
echo "palworld ALL=(ALL) NOPASSWD:ALL" | tee /etc/sudoers.d/palworld

# サーバー停止
sysyemctl stop palworld-server.service

# サーバプロセス起動サービス palworld-server.service ファイルに -useperfthreads -NoAsyncLoadingThread -UseMultithreadForDS を付与
sed -i '/^ExecStart=\/opt\/palworld\/PalServer\.sh port=8211$/c\ExecStart=/opt/palworld/PalServer.sh port=8211 -useperfthreads -NoAsyncLoadingThread -UseMultithreadForDS' /etc/systemd/system/palworld-server.service

# Initial Palworld AdminPassword 反映
cp -f /opt/palworld/DefaultPalWorldSettings.ini /opt/palworld/Pal/Saved/Config/LinuxServer/PalWorldSettings.ini
sed -i 's/AdminPassword="[^"]*"/AdminPassword="'$ADMIN_PASSWORD'"/' /opt/palworld/Pal/Saved/Config/LinuxServer/PalWorldSettings.ini

# RCONEnabled
sed -i 's/RCONEnabled=False/RCONEnabled=True/' /opt/palworld/Pal/Saved/Config/LinuxServer/PalWorldSettings.ini

# Install rcon_cli in /usr/games/rcon
curl -LO https://github.com/gorcon/rcon-cli/releases/download/v0.10.3/rcon-0.10.3-amd64_linux.tar.gz
tar -xvzf rcon-0.10.3-amd64_linux.tar.gz
mv rcon-0.10.3-amd64_linux/rcon /usr/games/
rm -rf rcon-0.10.3-amd64_linux rcon-0.10.3-amd64_linux.tar.gz

# 自動アップデートスクリプト update-palworld.sh 作成
cat <<EOF > /opt/palworld/update-palworld.sh
#!/bin/sh

# Steam CMD path
Steamcmd="/usr/games/steamcmd"
Rconcmd="/usr/games/rcon"
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
    echo "Restart palworld-server.service because an game update exists."
    \$Rconcmd -a "127.0.0.1:25575" -p \$ADMIN_PASSWORD "Broadcast The-server-will-restart-in-60-seconds.Please-prepare-to-exit-the-game."
    sleep 60; sudo systemctl stop palworld-server.service
    sudo systemctl start palworld-server.service
    systemctl status palworld-server.service
fi
EOF

# update-palworld.sh の自動実行登録
chmod +x /opt/palworld/update-palworld.sh
chown palworld:palworld /opt/palworld/update-palworld.sh
echo "0 */3 * * * /opt/palworld/update-palworld.sh" | crontab -u palworld -

# swapfile を16GBで割り当て直し
swapoff /swap.img
rm -f /swap.img
sed -i '/\/swap\.img/d' /etc/fstab

fallocate -l 16G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon -p 10 /swapfile
echo '/swapfile none swap sw,pri=10 0 0' | tee -a /etc/fstab

# palworld-server.service サーバプロセスを起動
systemctl daemon-reload
systemctl start palworld-server.service

/usr/bin/date
