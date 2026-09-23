#!/bin/bash
# proxy-check.sh — 查看当前 WSL 代理状态

set -euo pipefail
IFS=$'\n\t'

readonly ENV_FILE="${HOME}/.config/wsl-proxy.env"
readonly SERVICE_NAME="proxy-watcher.service"
readonly TEST_URL="http://www.gstatic.com/generate_204"

echo "========================================"
echo " WSL Clash Proxy 状态检查"
echo "========================================"
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
PORT="${http_proxy##*:}"
PORT="${PORT%%/*}"
PORT="${PORT:-7890}"
HTTP_CODE="$(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 3 \
    -x "http://127.0.0.1:${PORT}" \
    "${TEST_URL}" 2>/dev/null || echo "000")"
if [[ "${HTTP_CODE}" == "204" || "${HTTP_CODE}" == "200" ]]; then
    echo "  ✓ 代理可用 (HTTP ${HTTP_CODE})"
else
    echo "  ✗ 代理不可用 (HTTP ${HTTP_CODE})"
fi