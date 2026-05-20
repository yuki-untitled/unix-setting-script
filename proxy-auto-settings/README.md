# プロキシ自動判定・適用スクリプト

このフォルダには、WSL2（Ubuntuなど）環境において、接続しているネットワーク環境（社内・学内LANか自宅かなど）を自動で判別し、プロキシ設定を自動的に適用・解除するためのスクリプト群が格納されています。

ターミナル起動時にバックグラウンドで環境を検知し、適切な状態へと自動で切り替えます。

## 📂 構成ファイルと役割

プロキシ切り替えは、以下の3つのファイルが連携して動作します。

* **`proxy.env`** : プロキシの接続情報（認証情報やホスト等）を定義する設定ファイル。
* **`proxy_user.sh`** : ログインしているユーザー個人の環境（環境変数、`.curlrc`、Git設定）を制御するスクリプト。
* **`proxy_system.sh`** : OS全体のパッケージ管理や共通ツール（`/etc/environment`、`apt`、`wget`）を制御するスクリプト。

## 🛠 自動判別の仕組み

スクリプトは、WSL2が生成するDNS設定ファイル（`/etc/resolv.conf`）内の `search` 行を読み取ります。
そこに `proxy.env` で指定した特定のドメイン（`PROXY_DNS`）が含まれている場合は**プロキシを適用（Set）**し、含まれていない場合は自動的に**プロキシを解除（Unset）**します。

## 🚀 設定手順

### 0. 3つのファイルをダウンロード
まずは、`proxy.env`、`proxy_user.sh`、`proxy_system.sh`をダウンロードし、ホームディレクトリ `~` に配置します。


### 1. プロキシ情報の編集
設定ファイル `proxy.env` を、中身を環境に合わせて編集します。

```bash
vim ~/proxy.env
```

編集方法のヒント： `i` キーを押してインサート（編集）モードに入り、書き換えたら `Esc` を押して `:wq` で保存して終了します。

### 2. スクリプトの配置と実行権限の付与
スクリプトを共有ディレクトリ（`/usr/local/bin/`）に移動し、名前をシンプルに整理して、実行権限を与えます。

```bash
sudo mkdir -p /usr/local/bin/proxy
sudo cp ~/proxy_user.sh /usr/local/bin/proxy/user
sudo cp ~/proxy_system.sh /usr/local/bin/proxy/system

sudo chmod +x /usr/local/bin/proxy/user
sudo chmod +x /usr/local/bin/proxy/system
```

### 3. sudo 権限の設定（パスワードレス化）
ターミナル起動時にパスワード入力を求められないよう、`visudo` を使って権限を設定します。

```bash
sudo visudo
```

ファイルの末尾に、以下の内容を追記して保存します。

```text
# Proxy Auto Settings
user ALL=(ALL) NOPASSWD: /usr/local/bin/proxy/*
```

### 4. ターミナル起動時の自動実行設定
最後に、ターミナルが立ち上がった瞬間に自動で判別が走るよう、`.bashrc` の末尾に設定を追加します。

```bash
vim ~/.bashrc
```

ファイルの最下行に、以下の記述を追記してください。

```text
# Proxy Auto Settings
if [ -f /usr/local/bin/proxy/user ]; then
    source /usr/local/bin/proxy/user
fi
if [ -f /usr/local/bin/proxy/system ]; then
    sudo /usr/local/bin/proxy/system
fi
```

(または、以下のシンプルな1行ずつの記述方法でも同様に動作します)

```text
# Proxy Auto Settings
[ -f /usr/local/bin/proxy/user ] && source /usr/local/bin/proxy/user
[ -f /usr/local/bin/proxy/system ] && sudo /usr/local/bin/proxy/system
```

## 🎉 完了

これで設定はすべて完了です！
次回以降、WSL2のターミナルを起動（または`source ~/.bashrc`を実行）した際に、自動的に学内・社内のLAN環境か、あるいは自宅等の自前Wi-FiかをDNSから瞬時に判定し、プロキシの適用・解除を行ってくれるようになります。
