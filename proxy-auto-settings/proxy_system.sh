#!/bin/bash
# sudo（root 権限）で実行するスクリプト。
# proxy.env はユーザーが自由に書き換えられるファイルなので、
# root として source（実行）せず、値だけを読み取って厳密に検証する。

if [ "$(id -u)" -ne 0 ]; then
    echo "[System] Error: run this script with sudo." 1>&2
    exit 1
fi

# sudo実行時でも元のユーザーのホームにある設定ファイルを参照
TARGET_USER="${SUDO_USER:-$USER}"
USER_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
ENV_FILE="$USER_HOME/proxy.env"

# proxy.env を「KEY=VALUE」形式として読み込む（シェルスクリプトとしては実行しない）
load_env() {
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
urlencode() {
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
in_proxy_network() {
    awk -v dns="$PROXY_DNS" '$1 == "search" && index($0, dns) { found = 1 } END { exit !found }' /etc/resolv.conf
}

# 以前に書き込んだプロキシ設定を削除する
remove_system_proxy() {
    sed -i -E '/^(https?|ftp)_proxy=/Id' /etc/environment
    rm -f /etc/apt/apt.conf.d/99proxy
    [ -f /etc/wgetrc ] && sed -i -E '/^(https?|ftp)_proxy/d' /etc/wgetrc
}

set_system_proxy() {
    echo -e "\e[31m[System] Set system proxy settings\e[m" 1>&2
    remove_system_proxy

    # /etc/environment
    local name
    for name in http_proxy https_proxy ftp_proxy HTTP_PROXY HTTPS_PROXY FTP_PROXY; do
        echo "${name}=\"${PROXY_URL}\"" >> /etc/environment
    done

    # apt設定 (独立ファイルで管理)
    printf 'Acquire::http::proxy "%s";\nAcquire::https::proxy "%s";\n' "$PROXY_URL" "$PROXY_URL" \
        > /etc/apt/apt.conf.d/99proxy

    # wget設定
    if [ -f /etc/wgetrc ]; then
        printf 'http_proxy = %s\nhttps_proxy = %s\nftp_proxy = %s\n' "$PROXY_URL" "$PROXY_URL" "$PROXY_URL" \
            >> /etc/wgetrc
    fi
}

unset_system_proxy() {
    echo -e "\e[36m[System] Unset system proxy settings\e[m" 1>&2
    remove_system_proxy
}

if [ ! -f "$ENV_FILE" ]; then
    echo "[System] Error: $ENV_FILE not found." 1>&2
    exit 1
fi

PROXY_USER="" PROXY_PASS="" PROXY_HOST="" PROXY_PORT="" PROXY_DNS=""
load_env "$ENV_FILE"

# root で書き込む値なので、想定外の文字が入っていたら何もせず終了する
if ! [[ "$PROXY_HOST" =~ ^[A-Za-z0-9.-]+$ && "$PROXY_PORT" =~ ^[0-9]+$ && "$PROXY_DNS" =~ ^[A-Za-z0-9.-]+$ ]]; then
    echo "[System] Error: invalid PROXY_HOST / PROXY_PORT / PROXY_DNS in $ENV_FILE." 1>&2
    exit 1
fi

CREDENTIALS=""
if [ -n "$PROXY_USER" ]; then
    CREDENTIALS="$(urlencode "$PROXY_USER"):$(urlencode "$PROXY_PASS")@"
fi
PROXY_URL="http://${CREDENTIALS}${PROXY_HOST}:${PROXY_PORT}/"

if in_proxy_network; then
    set_system_proxy
else
    unset_system_proxy
fi
