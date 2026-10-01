#!/bin/bash
set -eu

KEY_FILE="$HOME/.ssh/id_ed25519"

# 空欄のまま進まないよう、入力されるまで聞き直す
prompt() {
    local message="$1" answer=""
    while [ -z "$answer" ]; do
        read -rp "$message" answer
    done
    printf '%s' "$answer"
}

# 1回だけ実行すればいいので、その場でユーザーに入力させる（ファイルにトークンを残さない）
echo "[GitHub設定スクリプト]"
GIT_USER=$(prompt "GitHubユーザー名を入力: ")
GIT_MAIL=$(prompt "GitHubメールアドレスを入力: ")

# 1. Gitの基本設定を直接実行 (シェル設定ファイルには書き込まない)
git config --global user.name "$GIT_USER"
git config --global user.email "$GIT_MAIL"
echo "Gitの基本情報をシステムに登録しました。"

# 2. SSHキーの生成（パスワードレス認証の準備）
if [ -f "$KEY_FILE" ]; then
    echo "既存のSSHキー ($KEY_FILE) を使用します。"
else
    echo "安全な通信のためのSSHキーを生成します..."
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    ssh-keygen -t ed25519 -C "$GIT_MAIL" -N "" -f "$KEY_FILE"
fi

echo "--------------------------------------------------------"
echo "【重要】以下の文字列（公開鍵）をすべてコピーし、"
echo "GitHubの設定（ https://github.com/settings/keys ）に登録してください。"
echo "--------------------------------------------------------"
cat "$KEY_FILE.pub"
echo "--------------------------------------------------------"
