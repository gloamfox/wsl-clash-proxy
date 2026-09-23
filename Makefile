# Makefile — 统一项目入口
#
# 用法：
#   make install   安装到系统（sudo）
#   make uninstall 卸载
#   make test      运行 bats 单元测试
#   make lint      静态检查（shellcheck）

SHELL := /bin/bash

REPO        := gloamfox/wsl-clash-proxy
PROXY_PORT  ?= 7897

# 检查命令是否可用
have := $(shell command -v $(1) 2>/dev/null)

.PHONY: all install uninstall test lint

all: lint test

## 安装：一键部署脚本、systemd 单元与 shell 配置
install:
	@PROXY_PORT=$(PROXY_PORT) bash install.sh

## 卸载：清理脚本、单元文件与 shell 配置
uninstall:
	@bash uninstall.sh

## 测试：运行 bats 单元测试
test:
	@if [ -z "$(call have,bats)" ]; then \
	    echo "[ERROR] 需要 bats-core：apt-get install bats 或见 https://github.com/bats-core/bats-core"; \
	    exit 1; \
	fi
	@bats tests/

## 静态检查：shellcheck 全量扫描
lint:
	@if [ -z "$(call have,shellcheck)" ]; then \
	    echo "[ERROR] 需要 shellcheck：apt-get install shellcheck 或见 https://github.com/koalaman/shellcheck"; \
	    exit 1; \
	fi
	@shellcheck install.sh uninstall.sh lib/*.sh bin/* shell/*.sh