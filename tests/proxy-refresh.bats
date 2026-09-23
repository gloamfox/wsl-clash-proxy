#!/usr/bin/env bats
# 测试 proxy-refresh 的写文件逻辑（不依赖真实网络）

setup() {
    TEST_TMP="$(mktemp -d)"
    export TEST_TMP
    # 注入测试用的 HOME，避免污染真实环境
    export HOME="${TEST_TMP}"
    # shellcheck disable=SC1090
    source "${BATS_TEST_DIRNAME}/../bin/proxy-refresh"
}

teardown() {
    rm -rf "${TEST_TMP}"
}

@test "write_proxy 写入指定的端口" {
    write_proxy "7899"
    grep -q 'export http_proxy="http://127.0.0.1:7899"' "${ENV_FILE}"
    grep -q 'export https_proxy="http://127.0.0.1:7899"' "${ENV_FILE}"
    grep -q 'export all_proxy="socks5://127.0.0.1:7899"' "${ENV_FILE}"
}

@test "write_cleanup 清空而非清空文件为空" {
    # 先写代理变量，再清理，验证写的是 unset 语句
    write_proxy "7899"
    write_cleanup
    grep -q 'unset http_proxy' "${ENV_FILE}"
    grep -q 'unset https_proxy' "${ENV_FILE}"
    # 清理后不应再含 export 代理语句
    ! grep -q 'export http_proxy' "${ENV_FILE}"
}