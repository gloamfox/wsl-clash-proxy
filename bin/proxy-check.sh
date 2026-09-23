#!/bin/bash
# proxy-check.sh — 查看当前 WSL 代理状态

set -euo pipefail
IFS=$'\n\t'

readonly CONFIG_DIR="${HOME}/.config/wsl-clash-proxy"
readonly CONF_FILE="${CONFIG_DIR}/proxy.conf"
readonly ENV_FILE="${CONFIG_DIR}/wsl-proxy.env"
readonly SERVICE_NAME="proxy-watcher.service"
readonly TEST_URL="http://www.gstatic.com/generate_204"
readonly DEFAULT_PORT="7897"

# 解析代理端口：优先取当前 shell 环境变量，其次配置文件，最后默认值
resolve_port() {
    if [[ -n "${http_proxy:-}" ]]; then
        local port="${http_proxy##*:}"
        port="${port%%/*}"
        if [[ -n "${port}" ]]; then
            echo "${port}"
            return 0
        fi
    fi
    if [[ -f "${CONF_FILE}" ]]; then
        local conf_port
        conf_port="$(grep -E '^[[:space:]]*PROXY_PORT=[0-9]+' "${CONF_FILE}" | tail -1 | cut -d= -f2-)"
        if [[ -n "${conf_port}" ]]; then
            echo "${conf_port}"
            return 0
        fi
    fi
    echo "${DEFAULT_PORT}"
}

PORT="$(resolve_port)"

echo "========================================"
echo " WSL Clash Proxy 状态检查"
echo "========================================"
echo ""
echo "  当前探测端口: ${PORT}"
echo ""

echo "[1] 环境变量："
echo "  http_proxy  = ${http_proxy:-(未设置)}"
echo "  https_proxy = ${https_proxy:-(未设置)}"
echo "  all_proxy   = ${all_proxy:-(未设置)}"
echo ""

echo "[2] 配置文件 (${ENV_FILE})："
if [[ -f "${ENV_FILE}" ]]; then
    if [[ -s "${ENV_FILE}" ]]; then
        sed 's/^/  /' "${ENV_FILE}"
    else
        echo "  (文件为空)"
    fi
else
    echo "  (文件不存在)"
fi
echo ""

echo "[3] systemd 服务状态："
systemctl --user status "${SERVICE_NAME}" --no-pager 2>/dev/null | head -5 | sed 's/^/  /' || echo "  (无法获取)"
echo ""

echo "[4] 代理连通性测试："
HTTP_CODE="$(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 3 \
    -x "http://127.0.0.1:${PORT}" \
    "${TEST_URL}" 2>/dev/null || echo "000")"
if [[ "${HTTP_CODE}" == "204" || "${HTTP_CODE}" == "200" ]]; then
    echo "  ✓ 代理可用 (HTTP ${HTTP_CODE})"
else
    echo "  ✗ 代理不可用 (HTTP ${HTTP_CODE})"
fi