# Palworld-ConoHaVPS
ConoHa VPS で Palworld を起動までセットアップするスタートアップスクリプトです。

スタートアップスクリプト欄に以下の URL を指定すると、自動的に palworld ユーザのホームディレクトリに steamcmd と palworld detecated server がインストールされ、立ち上がります。
```
https://raw.githubusercontent.com/palsoku/Palworld-ConoHaVPS/main/startup-palworld.sh
```

ConoHa VPS のスタートアップスクリプトは一定時間以内に正常終了しないとエラーを吐いて VPS が作成されないので、  
startup-palworld.sh ではセットアップを行う [setup-palworld_remove-valheim.sh](./setup-palworld_remove-valheim.sh) をダウンロードしてバックグランド実行し、早急に正常終了を返す役割を担っています。

利用方法はこちらの記事をご確認ください。
* [【親切自動設定付き】パルワールドサーバーの建て方【ConoHa for GAME】](https://palsoku.jp/tips/palworld-server-conoha/)


下にいくほどアップデートされています

| スタートアップスクリプト | セットアップを行うシェルスクリプト | 用途 |
|---|---|---|
| startup.sh | setup-palworld.sh | AlmaLinux で Palworld をインストールする |
| startup-palworld.sh | setup-palworld_remove-valheim.sh | Valheim のゲームイメージを削除し Palworld をインストールする |
| startup-palworld-template.sh | setup-palworld-template.sh | Palworld テンプレートを元にパフォーマンスを改善する |
