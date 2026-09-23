#!/bin/bash
# proxy-refresh.sh — 探测 Clash 代理可用性，刷新当前用户的代理环境变量文件
#
# Usage: proxy-refresh.sh
# Env:   PROXY_PORT   Clash 混合端口（可选，覆盖配置文件）
# Exit:  0  始终成功（用于 systemd 循环调用）
#
# 代理可用时写入 export 语句；不可用时写入 unset 语句，
# 确保已打开的 shell 加载该文件后能正确清空旧代理变量。
# 端口优先级：环境变量 PROXY_PORT > 配置文件 > 默认 7897。

set -euo pipefail
IFS=$'\n\t'

readonly CONFIG_DIR="${HOME}/.config/wsl-clash-proxy"
readonly CONF_FILE="${CONFIG_DIR}/proxy.conf"
readonly ENV_FILE="${CONFIG_DIR}/wsl-proxy.env"
readonly DEFAULT_PORT="7897"
readonly TEST_URL="http://www.gstatic.com/generate_204"
readonly CONNECT_TIMEOUT=2

# 解析代理端口：环境变量覆盖 > 配置文件 > 默认值
resolve_port() {
    if [[ -n "${PROXY_PORT:-}" ]]; then
        echo "${PROXY_PORT}"
        return 0
    fi
    if [[ -f "${CONF_FILE}" ]]; then
        local port
        port="$(grep -E '^[[:space:]]*PROXY_PORT=[0-9]+' "${CONF_FILE}" | tail -1 | cut -d= -f2-)"
        if [[ -n "${port}" ]]; then
            echo "${port}"
            return 0
        fi
    fi
    echo "${DEFAULT_PORT}"
}

readonly PORT="$(resolve_port)"

# 确保父目录存在
mkdir -p "${CONFIG_DIR}"

# 写入 unset 语句（而非清空文件，因为 source 空文件不会清空已有变量）
write_cleanup() {
    cat > "${ENV_FILE}" <<'EOF'
unset http_proxy
unset https_proxy
unset HTTP_PROXY
unset HTTPS_PROXY
unset all_proxy
unset ALL_PROXY
EOF
}

# 探测代理端口是否可用
# 优先用 nc 做轻量 TCP 探测，避免 systemd 每 3 秒发起一次完整 HTTP 请求；
# 仅在缺少 nc 时才回退到 curl 实际请求验证。
is_proxy_alive() {
    if command -v nc &>/dev/null; then
        nc -z -w "${CONNECT_TIMEOUT}" 127.0.0.1 "${PORT}" 2>/dev/null
        return
    fi

    local http_code
    http_code="$(curl -s -o /dev/null -w '%{http_code}' \
        --connect-timeout "${CONNECT_TIMEOUT}" \
        -x "http://127.0.0.1:${PORT}" \
        "${TEST_URL}" 2>/dev/null || echo "000")"
    [[ "${http_code}" == "204" || "${http_code}" == "200" ]]
}

write_proxy() {
    cat > "${ENV_FILE}" <<EOF
export http_proxy="http://127.0.0.1:${PORT}"
export https_proxy="http://127.0.0.1:${PORT}"
export HTTP_PROXY="http://127.0.0.1:${PORT}"
export HTTPS_PROXY="http://127.0.0.1:${PORT}"
export all_proxy="socks5://127.0.0.1:${PORT}"
export ALL_PROXY="socks5://127.0.0.1:${PORT}"
export no_proxy="localhost,127.0.0.1,::1"
EOF
}

main() {
    if is_proxy_alive; then
        write_proxy
    else
        write_cleanup
    fi
}

main "$@"