#!/bin/bash
# uninstall.sh — 卸载 WSL Clash Proxy
#
# 该脚本可独立运行（bash <(curl ...)），所有卸载逻辑内联，
# 不依赖仓库文件即可清理系统脚本、systemd 单元与 shell 配置。

set -euo pipefail
IFS=$'\n\t'

readonly SERVICE_NAME="proxy-watcher.service"
readonly INSTALL_DIR="/usr/local/bin"
readonly LIB_DIR="/usr/local/lib/wsl-clash-proxy"
readonly CONFIG_DIR="${HOME}/.config/wsl-clash-proxy"
readonly ENV_FILE="${CONFIG_DIR}/wsl-proxy.env"
readonly CONF_FILE="${CONFIG_DIR}/proxy.conf"

_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || echo "")"

# 优先复用公共函数库；独立运行时提供内联兜底
if [[ -f "${_script_dir}/lib/common.sh" ]]; then
    source "${_script_dir}/lib/common.sh"
else
    log_info()  { echo -e "\033[0;32m[INFO]\033[0m $*"; }
    log_warn()  { echo -e "\033[1;33m[WARN]\033[0m $*"; }
    log_error() { echo -e "\033[0;31m[ERROR]\033[0m $*" >&2; }
fi

echo ""
echo "=========================================="
echo "  WSL Clash Proxy 卸载"
echo "=========================================="
echo ""

log_info "停止并禁用服务..."
sudo systemctl --global disable "${SERVICE_NAME}" 2>/dev/null || true
systemctl --user stop "${SERVICE_NAME}" 2>/dev/null || true
systemctl --user disable "${SERVICE_NAME}" 2>/dev/null || true
log_info "  服务已停止"

log_info "删除单元文件..."
sudo rm -f "/etc/systemd/user/${SERVICE_NAME}"
sudo rm -f "/etc/systemd/user/default.target.wants/${SERVICE_NAME}"
log_info "  单元已删除"

log_info "删除脚本..."
sudo rm -f "${INSTALL_DIR}/proxy-refresh" \
            "${INSTALL_DIR}/proxy-watcher" \
            "${INSTALL_DIR}/proxy-check"
sudo rm -rf "${LIB_DIR}"
log_info "  脚本已删除"

log_info "删除配置文件..."
rm -f "${ENV_FILE}" "${CONF_FILE}"
rmdir "${CONFIG_DIR}" 2>/dev/null || true
log_info "  配置文件已删除"

log_info "清理 shell 配置..."
for rc in "${HOME}/.bashrc" "${HOME}/.zshrc"; do
    if [[ -f "${rc}" ]] && grep -q "WSL Clash Proxy Auto-Load" "${rc}" 2>/dev/null; then
        sed -i '/# ===== WSL Clash Proxy Auto-Load/,/# ===== End WSL Clash Proxy =====/d' "${rc}"
        log_info "  已清理 ${rc}"
    fi
done

echo ""
log_info "卸载完成。"
echo ""
echo "  提示：当前终端可能残留代理环境变量，请执行："
echo "    unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY all_proxy ALL_PROXY"
echo "  或直接关闭终端重新打开。"
echo ""