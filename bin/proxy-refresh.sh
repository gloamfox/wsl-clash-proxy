#!/bin/bash
# proxy-refresh.sh — 探测 Clash 代理可用性，刷新当前用户的代理环境变量文件
#
# Usage: proxy-refresh.sh
# Env:   PROXY_PORT   Clash 混合端口（默认 7890）
# Exit:  0  始终成功（用于 systemd 循环调用）
#
# 代理可用时写入 export 语句；不可用时写入 unset 语句，
# 确保已打开的 shell 加载该文件后能正确清空旧代理变量。

set -euo pipefail
IFS=$'\n\t'

readonly PROXY_PORT="${PROXY_PORT:-7890}"
readonly ENV_FILE="${HOME}/.config/wsl-proxy.env"
readonly TEST_URL="http://www.gstatic.com/generate_204"
readonly CONNECT_TIMEOUT=2

# 确保父目录存在
mkdir -p "$(dirname "${ENV_FILE}")"

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

# 通过代理端口实际请求测试 URL，验证代理是否真正可用
is_proxy_alive() {
    local http_code
    http_code="$(curl -s -o /dev/null -w '%{http_code}' \
        --connect-timeout "${CONNECT_TIMEOUT}" \
        -x "http://127.0.0.1:${PROXY_PORT}" \
        "${TEST_URL}" 2>/dev/null || echo "000")"
    [[ "${http_code}" == "204" || "${http_code}" == "200" ]]
}

write_proxy() {
    cat > "${ENV_FILE}" <<EOF
export http_proxy="http://127.0.0.1:${PROXY_PORT}"
export https_proxy="http://127.0.0.1:${PROXY_PORT}"
export HTTP_PROXY="http://127.0.0.1:${PROXY_PORT}"
export HTTPS_PROXY="http://127.0.0.1:${PROXY_PORT}"
export all_proxy="socks5://127.0.0.1:${PROXY_PORT}"
export ALL_PROXY="socks5://127.0.0.1:${PROXY_PORT}"
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