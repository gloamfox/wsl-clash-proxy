#!/usr/bin/env bats
# 测试公共库 common.sh 的端口解析逻辑

setup() {
    # 隔离测试环境，避免污染真实 HOME
    TEST_TMP="$(mktemp -d)"
    export TEST_TMP
    load_env() {
        # shellcheck disable=SC1090
        source "${BATS_TEST_DIRNAME}/../lib/common.sh"
    }
    load_env
}

teardown() {
    rm -rf "${TEST_TMP}"
}

@test "无环境变量且无配置文件时使用默认端口 7897" {
    run resolve_proxy_port "" "${TEST_TMP}/nonexistent.conf" "7897"
    [ "$status" -eq 0 ]
    [ "$output" = "7897" ]
}

@test "环境变量 PROXY_PORT 优先" {
    run resolve_proxy_port "7899" "${TEST_TMP}/nonexistent.conf" "7897"
    [ "$status" -eq 0 ]
    [ "$output" = "7899" ]
}

@test "配置文件优先级低于环境变量" {
    printf 'PROXY_PORT=7777\n' > "${TEST_TMP}/proxy.conf"
    run resolve_proxy_port "7899" "${TEST_TMP}/proxy.conf" "7897"
    [ "$status" -eq 0 ]
    [ "$output" = "7899" ]
}

@test "配置文件生效于默认端口" {
    printf 'PROXY_PORT=7777\n' > "${TEST_TMP}/proxy.conf"
    run resolve_proxy_port "" "${TEST_TMP}/proxy.conf" "7897"
    [ "$status" -eq 0 ]
    [ "$output" = "7777" ]
}

@test "配置文件为空时回退默认端口" {
    printf '' > "${TEST_TMP}/proxy.conf"
    run resolve_proxy_port "" "${TEST_TMP}/proxy.conf" "7897"
    [ "$status" -eq 0 ]
    [ "$output" = "7897" ]
}

@test "配置文件有多行时取最后一行" {
    printf 'PROXY_PORT=1111\n# 注释\nPROXY_PORT=2222\n' > "${TEST_TMP}/proxy.conf"
    run resolve_proxy_port "" "${TEST_TMP}/proxy.conf" "7897"
    [ "$status" -eq 0 ]
    [ "$output" = "2222" ]
}