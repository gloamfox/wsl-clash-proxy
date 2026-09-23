#!/bin/bash
# common.sh — 公共函数库（被 source，不直接执行）

# 防止重复 source
[[ -n "${_WSL_CLASH_PROXY_COMMON_LOADED:-}" ]] && return 0
_WSL_CLASH_PROXY_COMMON_LOADED=1

# 颜色定义
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[1;33m'
readonly COLOR_RED='\033[0;31m'
readonly COLOR_NC='\033[0m'

log_info()  { echo -e "${COLOR_GREEN}[INFO]${COLOR_NC} $*"; }
log_warn()  { echo -e "${COLOR_YELLOW}[WARN]${COLOR_NC} $*"; }
log_error() { echo -e "${COLOR_RED}[ERROR]${COLOR_NC} $*" >&2; }

# 检查命令是否存在
has_command() {
    command -v "$1" &>/dev/null
}

# 解析 systemd 用户实例所需的运行时目录
# 兼容 sudo 丢失环境变量或通过非交互式 shell 调用的情况
resolve_runtime_dir() {
    if [[ -z "${XDG_RUNTIME_DIR:-}" ]]; then
        XDG_RUNTIME_DIR="/run/user/$(id -u)"
        export XDG_RUNTIME_DIR
    fi
    if [[ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]] && [[ -S "${XDG_RUNTIME_DIR}/bus" ]]; then
        DBUS_SESSION_BUS_ADDRESS="unix:path=${XDG_RUNTIME_DIR}/bus"
        export DBUS_SESSION_BUS_ADDRESS
    fi
}

# 解析代理端口：环境变量 PROXY_PORT > 配置文件 > 默认端口
#
# 参数（均可选，用于测试注入）：
#   $1  环境变量端口覆盖值（默认取 ${PROXY_PORT}）
#   $2  配置文件路径（默认 ${HOME}/.config/wsl-clash-proxy/proxy.conf）
#   $3  兜底默认端口（默认 7897）
resolve_proxy_port() {
    local env_port="${1:-${PROXY_PORT:-}}"
    local conf_file="${2:-${HOME}/.config/wsl-clash-proxy/proxy.conf}"
    local default_port="${3:-7897}"

    if [[ -n "${env_port}" ]]; then
        echo "${env_port}"
        return 0
    fi

    if [[ -f "${conf_file}" ]]; then
        local port
        port="$(grep -E '^[[:space:]]*PROXY_PORT=[0-9]+' "${conf_file}" | tail -1 | cut -d= -f2-)"
        if [[ -n "${port}" ]]; then
            echo "${port}"
            return 0
        fi
    fi

    echo "${default_port}"
}