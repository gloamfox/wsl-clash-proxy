# wsl-clash-proxy

在 WSL2 镜像模式下，让 WSL 终端自动跟随 Windows 宿主机的 Clash 代理，无需重启 WSL。

## 解决什么问题

WSL2 的 `autoProxy` 只在发行版启动时读取一次 Windows 代理设置，是个启动快照。
Clash 后启动时，WSL 内不会自动更新代理，必须 `wsl --shutdown` 重启才能生效。

本项目通过一个后台 systemd 用户服务，每 3 秒检测一次 Clash 代理端口，
把最新的代理环境变量写入 `~/.config/wsl-clash-proxy/wsl-proxy.env`，shell 在每次提示符前自动加载。
Clash 开启或关闭后，WSL 终端最多 3 秒内跟上。

## 前置条件

1. WSL2 已启用 systemd（`/etc/wsl.conf` 中 `[boot] systemd=true`）
2. `.wslconfig` 中配置了 `networkingMode=mirrored`
3. Clash Verge 已开启 **Allow LAN**（允许局域网连接）
4. Windows 防火墙已放行 Clash 混合端口

## 一键安装

```bash
bash <(curl -sL https://raw.githubusercontent.com/gloamfox/wsl-clash-proxy/main/install.sh)
```

自定义端口（安装时指定，写入 `~/.config/wsl-clash-proxy/proxy.conf`）：

```bash
PROXY_PORT=7897 bash <(curl -sL https://raw.githubusercontent.com/gloamfox/wsl-clash-proxy/main/install.sh)
```

端口优先级：环境变量 `PROXY_PORT` > 配置文件 `proxy.conf` > 默认 `7897`。

固定版本：

```bash
REF=v1.0.0 bash <(curl -sL https://raw.githubusercontent.com/gloamfox/wsl-clash-proxy/main/install.sh)
```

## 手动安装（或开发）

```bash
git clone https://github.com/gloamfox/wsl-clash-proxy.git
cd wsl-clash-proxy
make install          # 或 bash install.sh
```

## 验证

```bash
proxy-check
```

或：

```bash
echo $http_proxy
curl -s -o /dev/null -w '%{http_code}' https://www.google.com
```

## 卸载

```bash
bash <(curl -sL https://raw.githubusercontent.com/gloamfox/wsl-clash-proxy/main/uninstall.sh)
```

本地卸载：`make uninstall`

## 开发

```bash
make test      # 运行 bats 单元测试
make lint      # shellcheck 静态检查
```

## 工作原理

```
┌─────────────────────────┐    每 3 秒探测    ┌───────────────────────┐
│ proxy-watcher.service   │ ───────────────▶ │ 127.0.0.1:<混合端口>  │
│ (systemd user unit)     │                  │ (Windows 宿主机 Clash)│
└───────────┬─────────────┘                  └───────────────────────┘
            │ 写入
            ▼
┌────────────────────────────────┐ source ┌───────────────────────┐
│ ~/.config/wsl-clash-proxy/     │ ─────▶ │ 交互式 Shell (bash/zsh)│
│   wsl-proxy.env                │        └───────────────────────┘
└────────────────────────────────┘
```

## 目录说明
```txt
wsl-clash-proxy/
├── README.md
├── LICENSE
├── Makefile                      # 统一入口（install/uninstall/test/lint）
├── install.sh                    # 入口脚本，带自举逻辑
├── uninstall.sh                  # 卸载脚本
├── lib/
│   └── common.sh                 # 公共函数（日志、颜色、端口解析）
├── bin/
│   ├── proxy-refresh             # 核心：探测 + 写环境变量文件
│   ├── proxy-watcher             # 循环调度 proxy-refresh
│   └── proxy-check               # 状态检查工具
├── systemd/
│   └── proxy-watcher.service     # systemd 用户单元模板
├── shell/
│   ├── bash-snippet.sh           # bash 自动加载片段
│   └── zsh-snippet.sh            # zsh 自动加载片段
└── tests/
    ├── common.bats               # 端口解析单元测试
    └── proxy-refresh.bats        # 环境变量文件写入测试
```

安装后运行时产生的文件（位于用户主目录，非仓库）：

```txt
~/.config/wsl-clash-proxy/
├── proxy.conf        # 代理端口配置（由 install.sh 生成）
└── wsl-proxy.env     # 代理环境变量（由 proxy-refresh 周期刷新）
```


## License

MIT