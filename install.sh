#!/bin/bash
# install.sh — WSL Clash Proxy 一键安装
#
# Usage: bash install.sh
# Env:   PROXY_PORT   Clash 混合端口（默认 7897）
#        REF          安装版本/分支（默认 main）
#
# 该脚本支持自举：既可以通过 git clone 后执行，也可以直接
#   bash <(curl -sL .../install.sh)
# 独立运行时，会自动下载完整仓库到临时目录后重新执行。

set -euo pipefail
IFS=$'\n\t'

# ============================================================
# 自举：检测是否处于完整仓库，否则下载仓库后重新执行
# ============================================================
readonly REPO="gloamfox/wsl-clash-proxy"
readonly REF="${REF:-main}"

_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || echo "")"

if [[ ! -d "${_script_dir}/lib" ]] || [[ ! -d "${_script_dir}/bin" ]]; then
    echo "[INFO] 检测到独立运行，正在下载完整仓库 (${REPO}@${REF})..."

    _tmpdir="$(mktemp -d)"
    trap 'rm -rf "${_tmpdir}"' EXIT

    _archive_url="https://github.com/${REPO}/archive/refs/heads/${REF}.tar.gz"

    if command -v curl &>/dev/null; then
        curl -fsSL "${_archive_url}" | tar -xz -C "${_tmpdir}" --strip-components=1
    elif command -v wget &>/dev/null; then
        wget -qO- "${_archive_url}" | tar -xz -C "${_tmpdir}" --strip-components=1
    else
        echo "[ERROR] 需要 curl 或 wget 来下载仓库。" >&2
        exit 1
    fi

    echo "[INFO] 仓库已下载，进入安装流程..."
    # 传入环境变量以保证子流程使用相同的端口/版本
    export REF
    export PROXY_PORT="${PROXY_PORT:-7897}"
    exec bash "${_tmpdir}/install.sh" "$@"
fi

# ============================================================
# 正常安装逻辑
# ============================================================
readonly SCRIPT_DIR="${_script_dir}"
readonly PROXY_PORT="${PROXY_PORT:-7897}"
readonly INSTALL_DIR="/usr/local/bin"
readonly SERVICE_NAME="proxy-watcher.service"
readonly CONFIG_DIR="${HOME}/.config/wsl-clash-proxy"
readonly CONF_FILE="${CONFIG_DIR}/proxy.conf"

source "${SCRIPT_DIR}/lib/common.sh"

# ------------------------------------------------------------
# 前置检查
# ------------------------------------------------------------
check_prerequisites() {
    log_info "检查前置条件..."

    # WSL2 环境校验
    if ! grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null; then
        log_warn "未检测到 WSL 环境，请确认是在 WSL2 内运行。"
    fi

    # sudo 可用性校验
    if ! has_command sudo; then
        log_warn "未检测到 sudo，安装/清理系统脚本需要 sudo 权限。"
        log_warn "建议先安装 sudo，或手动以 root 运行本脚本。"
    fi

    if ! ps -p 1 -o comm= | grep -q systemd; then
        log_error "WSL 未启用 systemd。"
        log_error "请在 /etc/wsl.conf 中添加以下内容后执行 wsl --shutdown 重启："
        log_error "  [boot]"
        log_error "  systemd=true"
        exit 1
    fi
    log_info "  systemd 已启用"

    if ! has_command nc; then
        log_warn "未检测到 nc，正在安装 netcat-openbsd..."
        sudo apt-get update -qq && sudo apt-get install -y -qq netcat-openbsd
    fi
    log_info "  nc 可用"

    if ! has_command curl; then
        log_warn "未检测到 curl，正在安装..."
        sudo apt-get update -qq && sudo apt-get install -y -qq curl
    fi
    log_info "  curl 可用"

    log_info "前置条件检查通过。"
}

# ------------------------------------------------------------
# 写入端口配置文件
# ------------------------------------------------------------
write_proxy_conf() {
    log_info "写入端口配置文件 ${CONF_FILE}..."
    mkdir -p "${CONFIG_DIR}"
    cat > "${CONF_FILE}" <<EOF
# WSL Clash Proxy 配置（由 install.sh 生成）
PROXY_PORT=${PROXY_PORT}
EOF
    log_info "  端口配置完成"
}

# ------------------------------------------------------------
# 部署脚本到 /usr/local/bin/
# ------------------------------------------------------------
deploy_binaries() {
    log_info "部署脚本到 ${INSTALL_DIR}/..."

    sudo install -m 755 "${SCRIPT_DIR}/bin/proxy-refresh.sh" "${INSTALL_DIR}/proxy-refresh.sh"
    sudo install -m 755 "${SCRIPT_DIR}/bin/proxy-watcher.sh" "${INSTALL_DIR}/proxy-watcher.sh"
    sudo install -m 755 "${SCRIPT_DIR}/bin/proxy-check.sh"   "${INSTALL_DIR}/proxy-check.sh"

    log_info "  脚本部署完成"
}

# ------------------------------------------------------------
# 部署 systemd 全局用户单元
# ------------------------------------------------------------
deploy_systemd_unit() {
    log_info "部署 systemd 用户单元到 /etc/systemd/user/..."

    sudo mkdir -p /etc/systemd/user
    sudo install -m 644 "${SCRIPT_DIR}/config/proxy-watcher.service" \
        "/etc/systemd/user/${SERVICE_NAME}"

    sudo systemctl --global enable "${SERVICE_NAME}" 2>/dev/null || true
    log_info "  单元已启用（全局）"
}

# ------------------------------------------------------------
# 注入 shell 自动加载配置
# ------------------------------------------------------------
inject_shell_config() {
    log_info "注入 shell 自动加载配置..."

    local injected=0
    local rc
    for rc in "${HOME}/.bashrc" "${HOME}/.zshrc"; do
        [[ ! -f "${rc}" ]] && continue

        if grep -q "WSL Clash Proxy Auto-Load" "${rc}" 2>/dev/null; then
            log_warn "  ${rc} 中已存在配置，跳过"
            continue
        fi

        if [[ "${rc}" == *"zsh"* ]]; then
            cat "${SCRIPT_DIR}/shell/zsh-snippet.sh" >> "${rc}"
        else
            cat "${SCRIPT_DIR}/shell/bash-snippet.sh" >> "${rc}"
        fi
        log_info "  已注入 ${rc}"
        injected=1
    done

    if [[ "${injected}" == "0" ]]; then
        log_warn "  未找到可注入的 shell 配置文件"
    fi
}

# ------------------------------------------------------------
# 立即启动服务（当前会话）
# ------------------------------------------------------------
start_service_now() {
    log_info "启动 systemd 用户服务..."

    resolve_runtime_dir

    systemctl --user daemon-reload 2>/dev/null || true
    systemctl --user start "${SERVICE_NAME}" 2>/dev/null || {
        log_warn "  服务启动失败，请重新登录后执行：systemctl --user start ${SERVICE_NAME}"
        return
    }
    log_info "  服务已启动"
}

# ------------------------------------------------------------
# 验证
# ------------------------------------------------------------
verify() {
    local env_file="${CONFIG_DIR}/wsl-proxy.env"
    echo ""
    log_info "========== 验证 =========="
    sleep 3

    if [[ -f "${env_file}" ]]; then
        echo "  代理配置文件内容："
        sed 's/^/    /' "${env_file}"
    else
        log_warn "  配置文件尚未生成（Clash 可能未运行）"
    fi

    echo ""
    echo "  systemd 服务状态："
    systemctl --user status "${SERVICE_NAME}" --no-pager 2>/dev/null | head -5 | sed 's/^/    /' || true

    echo ""
    log_info "安装完成！"
    echo ""
    echo "  下一步："
    echo "    1. 新开终端，或执行 source ~/.bashrc / source ~/.zshrc"
    echo "    2. 运行 proxy-check.sh 查看代理状态"
    echo "    3. 确保 Clash Verge 已开启 Allow LAN"
    echo ""
}

# ------------------------------------------------------------
# 主流程
# ------------------------------------------------------------
main() {
    echo ""
    echo "=========================================="
    echo "  WSL Clash Proxy 一键安装"
    echo "  代理端口: ${PROXY_PORT}"
    echo "=========================================="
    echo ""

    check_prerequisites
    write_proxy_conf
    deploy_binaries
    deploy_systemd_unit
    inject_shell_config
    start_service_now
    verify
}

main "$@"