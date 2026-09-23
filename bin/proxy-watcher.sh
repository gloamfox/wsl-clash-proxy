#!/bin/bash
# proxy-watcher.sh — 循环调用 proxy-refresh.sh，持续刷新代理状态
# 由 systemd 用户单元启动，不需要手动执行。

set -euo pipefail
IFS=$'\n\t'

readonly REFRESH_SCRIPT="/usr/local/bin/proxy-refresh.sh"
readonly INTERVAL=3

while true; do
    "${REFRESH_SCRIPT}" || true
    sleep "${INTERVAL}"
done