# Palworld-ConoHaVPS
ConoHa VPS で Palworld を起動までセットアップするスタートアップスクリプトです。

スタートアップスクリプト欄に以下の URL を指定すると、自動的に palworld ユーザのホームディレクトリに steamcmd と palworld detecated server がインストールされ、立ち上がります。
```
https://raw.githubusercontent.com/palsoku/Palworld-ConoHaVPS/main/startup-palworld.sh
```

ConoHa VPS のスタートアップスクリプトは一定時間以内に正常終了しないとエラーを吐いて VPS が作成されないので、  
startup-palworld.sh ではセットアップを行う [setup-palworld_remove-valheim.sh](./setup-palworld_remove-valheim.sh) をダウンロードしてバックグランド実行し、早急に正常終了を返す役割を担っています。