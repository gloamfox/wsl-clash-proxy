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

log_info()  { echo -e "${COLOR_GREEN}[INFO]${NC} $*"; }
log_warn()  { echo -e "${COLOR_YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${COLOR_RED}[ERROR]${NC} $*" >&2; }

# 检查命令是否存在
has_command() {
    command -v "$1" &>/dev/null
}

# 解析 systemd 用户实例所需的运行时目录
# 兼容 sudo 丢失环境变量或通过非交互式 shell 调用的情况
resolve_runtime_dir() {
    if [[ -z "${XDG_RUNTIME_DIR:-}" ]]; then
        export XDG_RUNTIME_DIR="/run/user/$(id -u)"
    fi
    if [[ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]] && [[ -S "${XDG_RUNTIME_DIR}/bus" ]]; then
        export DBUS_SESSION_BUS_ADDRESS="unix:path=${XDG_RUNTIME_DIR}/bus"
    fi
}