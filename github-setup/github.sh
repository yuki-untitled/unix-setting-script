#!/bin/sh

# 1回だけ実行すればいいので、その場でユーザーに入力させる（ファイルにトークンを残さない）
echo "[GitHub設定スクリプト]"
read -p "GitHubユーザー名を入力: " GIT_USER
read -p "GitHubメールアドレスを入力: " GIT_MAIL

# 1. Gitの基本設定を直接実行 (シェル設定ファイルには書き込まない)
git config --global user.name "$GIT_USER"
git config --global user.email "$GIT_MAIL"
echo "Gitの基本情報をシステムに登録しました。"

# 2. SSHキーの生成（パスワードレス認証の準備）
if [ ! -f ~/.ssh/id_ed25519 ]; then
    echo "安全な通信のためのSSHキーを生成します（すべてEnterを押してください）..."
    ssh-keygen -t ed25519 -C "$GIT_MAIL" -N "" -f ~/.ssh/id_ed25519
fi

echo "--------------------------------------------------------"
echo "【重要】以下の文字列（公開鍵）をすべてコピーし、"
echo "GitHubの設定（ https://github.com/settings/keys ）に登録してください。"
echo "--------------------------------------------------------"
cat ~/.ssh/id_ed25519.pub
echo "--------------------------------------------------------"