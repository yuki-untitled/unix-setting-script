#!/bin/bash

# sudo実行時でも元のユーザーのホームにある設定ファイルを参照
TARGET_USER="${SUDO_USER:-$USER}"
USER_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
ENV_FILE="$USER_HOME/proxy.env"

if [ ! -f "$ENV_FILE" ]; then
    echo "[System] Error: $ENV_FILE not found."
    exit 1
fi
source "$ENV_FILE"

PROXY_URL="http://${PROXY_USER}:${PROXY_PASS}@${PROXY_HOST}:${PROXY_PORT}/"

check_proxy_environment() {
    local current_dns=$(grep "search" /etc/resolv.conf)
    [[ "$current_dns" == *"$PROXY_DNS"* ]]
}

set_system_proxy() {
    echo -e "\e[31m[System] Set system proxy settings\e[m" 1>&2

    # /etc/environment の更新 (重複削除後に追記)
    # 互換性のため大文字小文字を個別に削除
    sudo sed -i '/[hH][tT][tT][pP]_[pP][rR][oO][xX][yY]/d' /etc/environment
    sudo sed -i '/[fF][tT][pP]_[pP][rR][oO][xX][yY]/d' /etc/environment

    sudo bash -c "cat << EOF >> /etc/environment
http_proxy=\"${PROXY_URL}\"
https_proxy=\"${PROXY_URL}\"
ftp_proxy=\"${PROXY_URL}\"
HTTP_PROXY=\"${PROXY_URL}\"
HTTPS_PROXY=\"${PROXY_URL}\"
FTP_PROXY=\"${PROXY_URL}\"
EOF"

    # apt設定 (独立ファイルで管理)
    echo "Acquire::http::proxy \"${PROXY_URL}\";" | sudo tee /etc/apt/apt.conf.d/99proxy > /dev/null
    echo "Acquire::https::proxy \"${PROXY_URL}\";" | sudo tee -a /etc/apt/apt.conf.d/99proxy > /dev/null

    # wget設定
    if [ -f /etc/wgetrc ]; then
        sudo sed -i '/^http_proxy/d' /etc/wgetrc
        sudo sed -i '/^https_proxy/d' /etc/wgetrc
        sudo sed -i '/^ftp_proxy/d' /etc/wgetrc
        sudo bash -c "cat << EOF >> /etc/wgetrc
http_proxy = ${PROXY_URL}
https_proxy = ${PROXY_URL}
ftp_proxy = ${PROXY_URL}
EOF"
    fi
}

unset_system_proxy() {
    echo -e "\e[36m[System] Unset system proxy settings\e[m" 1>&2
    sudo sed -i '/[hH][tT][tT][pP]_[pP][rR][oO][xX][yY]/d' /etc/environment
    sudo sed -i '/[fF][tT][pP]_[pP][rR][oO][xX][yY]/d' /etc/environment
    [ -f "/etc/apt/apt.conf.d/99proxy" ] && sudo rm -f "/etc/apt/apt.conf.d/99proxy"
    
    if [ -f /etc/wgetrc ]; then
        sudo sed -i '/^http_proxy/d' /etc/wgetrc
        sudo sed -i '/^https_proxy/d' /etc/wgetrc
        sudo sed -i '/^ftp_proxy/d' /etc/wgetrc
    fi
}

if check_proxy_environment; then
    set_system_proxy
else
    unset_system_proxy
fi