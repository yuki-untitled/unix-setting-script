#!/bin/bash
# .bashrc から source して使うスクリプト。
# 呼び出し元のシェルに変数（特にパスワード）や関数を残さないよう、
# 処理はすべて関数内のローカル変数で行い、最後に関数自体も削除する。

# proxy.env を「KEY=VALUE」形式として読み込む（シェルスクリプトとしては実行しない）
__proxy_load_env() {
    local file="$1" key value
    while IFS='=' read -r key value || [ -n "$key" ]; do
        key="${key//[[:space:]]/}"
        case "$key" in
            PROXY_USER|PROXY_PASS|PROXY_HOST|PROXY_PORT|PROXY_DNS) ;;
            *) continue ;;
        esac
        value="${value%$'\r'}"
        if [[ "$value" == \"*\" || "$value" == \'*\' ]]; then
            value="${value:1:${#value}-2}"
        fi
        printf -v "$key" '%s' "$value"
    done < "$file"
}

# URL に含められない文字（@ : / など）をパーセントエンコードする
__proxy_urlencode() {
    local LC_ALL=C s="$1" out="" c i
    for ((i = 0; i < ${#s}; i++)); do
        c="${s:i:1}"
        case "$c" in
            [A-Za-z0-9._~-]) out+="$c" ;;
            *) printf -v c '%%%02X' "'$c"; out+="$c" ;;
        esac
    done
    printf '%s' "$out"
}

# resolv.conf の search 行に PROXY_DNS が含まれていればプロキシ環境と判定
__proxy_in_proxy_network() {
    awk -v dns="$1" '$1 == "search" && index($0, dns) { found = 1 } END { exit !found }' /etc/resolv.conf
}

__proxy_user_main() {
    local env_file="$HOME/proxy.env"
    local PROXY_USER="" PROXY_PASS="" PROXY_HOST="" PROXY_PORT="" PROXY_DNS=""
    local proxy_url credentials=""

    if [ ! -f "$env_file" ]; then
        echo -e "\e[33m[ User ] Warning: $env_file not found. Skipping proxy settings.\e[m" 1>&2
        return 0
    fi
    __proxy_load_env "$env_file"

    if [ -z "$PROXY_HOST" ] || [ -z "$PROXY_PORT" ] || [ -z "$PROXY_DNS" ]; then
        echo -e "\e[33m[ User ] Warning: PROXY_HOST / PROXY_PORT / PROXY_DNS must be set in $env_file.\e[m" 1>&2
        return 0
    fi

    if [ -n "$PROXY_USER" ]; then
        credentials="$(__proxy_urlencode "$PROXY_USER"):$(__proxy_urlencode "$PROXY_PASS")@"
    fi
    proxy_url="http://${credentials}${PROXY_HOST}:${PROXY_PORT}/"

    # .curlrc の既存プロキシ設定は、適用・解除どちらの場合も一旦削除する
    [ -f "$HOME/.curlrc" ] && sed -i '/^proxy/d' "$HOME/.curlrc"

    if __proxy_in_proxy_network "$PROXY_DNS"; then
        echo -e "\e[31m[ User ] Set  user  proxy settings\e[m" 1>&2

        # 環境変数
        export http_proxy="$proxy_url" https_proxy="$proxy_url" ftp_proxy="$proxy_url"
        export HTTP_PROXY="$proxy_url" HTTPS_PROXY="$proxy_url" FTP_PROXY="$proxy_url"

        # Git（https 通信にも http.proxy が使われる）
        git config --global http.proxy "$proxy_url"

        # curl（パスワードを含むので本人のみ読み書き可能にする）
        echo "proxy = \"$proxy_url\"" >> "$HOME/.curlrc"
        chmod 600 "$HOME/.curlrc"
    else
        echo -e "\e[36m[ User ] Unset  user  proxy settings\e[m" 1>&2
        unset http_proxy https_proxy ftp_proxy HTTP_PROXY HTTPS_PROXY FTP_PROXY
        git config --global --unset http.proxy
        # 旧バージョンが設定していた値も掃除する
        git config --global --unset https.proxy
    fi
}

__proxy_user_main
unset -f __proxy_load_env __proxy_urlencode __proxy_in_proxy_network __proxy_user_main
