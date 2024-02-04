#!/bin/bash

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

# Install rcon_cli in /usr/games/rcon
curl -LO https://github.com/gorcon/rcon-cli/releases/download/v0.10.3/rcon-0.10.3-amd64_linux.tar.gz
tar -xvzf rcon-0.10.3-amd64_linux.tar.gz
mv rcon-0.10.3-amd64_linux/rcon /usr/games/
rm -rf rcon-0.10.3-amd64_linux rcon-0.10.3-amd64_linux.tar.gz

# palworld-server.service のインストール完了まで待機
count=0
max_count=360  # 30分まで
while ! systemctl status palworld-server.service | grep -q "active (running)"; do
    if [ $count -ge $max_count ]; then
        echo "palworld-server.service did not become active within the expected time."
        exit 1
    fi
    sleep 5
    ((count++))
done

# サーバー停止
sleep 10; systemctl stop palworld-server.service

# サーバプロセス起動サービス palworld-server.service ファイルに -useperfthreads -NoAsyncLoadingThread -UseMultithreadForDS を付与
sed -i '/^ExecStart=\/opt\/palworld\/PalServer\.sh port=8211$/c\ExecStart=/opt/palworld/PalServer.sh port=8211 -useperfthreads -NoAsyncLoadingThread -UseMultithreadForDS' /etc/systemd/system/palworld-server.service

# Initial Palworld AdminPassword 反映
cp -f /opt/palworld/DefaultPalWorldSettings.ini /opt/palworld/Pal/Saved/Config/LinuxServer/PalWorldSettings.ini
sed -i 's/AdminPassword="[^"]*"/AdminPassword="'$ADMIN_PASSWORD'"/' /opt/palworld/Pal/Saved/Config/LinuxServer/PalWorldSettings.ini
# RCONEnabled
sed -i 's/RCONEnabled=False/RCONEnabled=True/' /opt/palworld/Pal/Saved/Config/LinuxServer/PalWorldSettings.ini

# 自動アップデートスクリプト update-palworld.sh 作成
apt install -y jq

cat <<EOF | sudo tee /opt/palworld/update-palworld.sh > /dev/null
#!/bin/bash

# Paths
Steamcmd="/usr/games/steamcmd"
rcon_cli="/usr/games/rcon"
install_dir="/opt/palworld/"
service_name="palworld-server.service"

echo "# Environment Check"
date

# Retrieve the current Build ID
OLD_Build=\`\$Steamcmd +force_install_dir \$install_dir +login anonymous +app_status 2394010 +quit | grep -e "BuildID" | awk '{print \$8}'\`
echo "Current BuildID: \$OLD_Build"

# Attempt to fetch the New Build ID using curl
NEW_Build=\$(curl -s https://api.steamcmd.net/v1/info/2394010 | jq -r '.data["2394010"].depots.branches.public.buildid')

# Fallback to SteamCMD method if curl fails to retrieve data
if [ -z "\$NEW_Build" ] || [ "\$NEW_Build" = "null" ]; then
    echo "Failed to fetch New BuildID with curl. Resorting to SteamCMD."
    \$Steamcmd +force_install_dir \$install_dir +login anonymous +app_update 2394010 validate +quit > /dev/null
    NEW_Build=\`\$Steamcmd +force_install_dir \$install_dir +login anonymous +app_status 2394010 +quit | grep -e "BuildID" | awk '{print \$8}'\`
fi

echo "Fetched New BuildID: \$NEW_Build"

# Update the server if the Build IDs do not match
if [ "\$OLD_Build" = "\$NEW_Build" ]; then
    echo "No update required. Build numbers are identical."
else
    echo "# Updating the game server..."
    \$Steamcmd +force_install_dir \$install_dir +login anonymous +app_update 2394010 validate +quit > /dev/null
    echo "Game server updated successfully to BuildID: \$NEW_Build"

    echo "Initiating \${service_name} restart due to an update."
    \${rcon_cli} -a "127.0.0.1:25575" -p $ADMIN_PASSWORD "Broadcast The-server-will-restart-in-60-seconds.Please-prepare-to-exit-the-game."
    sleep 30
    \${rcon_cli} -a "127.0.0.1:25575" -p $ADMIN_PASSWORD "Broadcast The-server-will-restart-in-30-seconds.Please-prepare-to-exit-the-game."
    sleep 20
    \${rcon_cli} -a "127.0.0.1:25575" -p $ADMIN_PASSWORD "Broadcast The-server-will-restart-in-10-seconds.Please-prepare-to-exit-the-game."
    sleep 10
    sudo systemctl stop \$service_name
    sudo systemctl start \$service_name
    systemctl status \$service_name
fi
EOF

# update-palworld.sh の自動実行登録
chmod +x /opt/palworld/update-palworld.sh
chown palworld:palworld /opt/palworld/update-palworld.sh
echo "*/30 * * * * /opt/palworld/update-palworld.sh" | crontab -u palworld -

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
