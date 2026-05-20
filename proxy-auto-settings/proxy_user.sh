#!/bin/bash

# 設定ファイルの読み込み
ENV_FILE="$HOME/proxy.env"
if [ ! -f "$ENV_FILE" ]; then
    echo -e "\e[33m[User] Warning: $ENV_FILE not found. Skipping proxy settings.\e[m"
    return 0 2>/dev/null || exit 0
fi
source "$ENV_FILE"

# プロキシURLの組み立て
PROXY_URL="http://${PROXY_USER}:${PROXY_PASS}@${PROXY_HOST}:${PROXY_PORT}/"

# 環境検知
check_proxy_environment() {
    local current_dns=$(grep "search" /etc/resolv.conf)
    [[ "$current_dns" == *"$PROXY_DNS"* ]]
}

# 設定適用
set_user_proxy() {
    echo -e "\e[31m[ User ] Set  user  proxy settings\e[m" 1>&2

    # 環境変数
    export http_proxy="${PROXY_URL}"
    export https_proxy="${PROXY_URL}"
    export ftp_proxy="${PROXY_URL}"
    export HTTP_PROXY="${PROXY_URL}"
    export HTTPS_PROXY="${PROXY_URL}"
    export FTP_PROXY="${PROXY_URL}"

    # Git
    git config --global http.proxy "${PROXY_URL}"
    git config --global https.proxy "${PROXY_URL}"

    # curl
    [ -f "$HOME/.curlrc" ] && sed -i '/^proxy/d' "$HOME/.curlrc"
    echo "proxy = \"http://${PROXY_HOST}:${PROXY_PORT}\"" >> "$HOME/.curlrc"
    echo "proxy-user = \"${PROXY_USER}:${PROXY_PASS}\"" >> "$HOME/.curlrc"
}

# 設定解除
unset_user_proxy() {
    echo -e "\e[36m[ User ] Unset  user  proxy settings\e[m" 1>&2
    unset http_proxy https_proxy ftp_proxy HTTP_PROXY HTTPS_PROXY FTP_PROXY
    git config --global --unset http.proxy
    git config --global --unset https.proxy
    [ -f "$HOME/.curlrc" ] && sed -i '/^proxy/d' "$HOME/.curlrc"
}

# メイン処理
if check_proxy_environment; then
    set_user_proxy
else
    unset_user_proxy
fi