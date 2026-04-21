# Xray SingBox + Reality 一键管理脚本

<div align="center">

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Linux-blue.svg)]()
[![Protocol](https://img.shields.io/badge/protocol-SS%2BReaLity-orange.svg)]()
[![Init](https://img.shields.io/badge/init-systemd%20%7C%20openrc-purple.svg)]()


</div>

> 当前发布版本：`v1.0`

## ✨ 功能特性

- 🔐 **支持 VLESS + Reality / SS + ReaLity / Trojan + Reality / VMess + Reality / AnyTLS + Reality 协议**
- 🐧 **多发行版支持** - 支持 Alpine (OpenRC)、Debian/Ubuntu (systemd)、CentOS/Rocky/Fedora (systemd)
- 🌐 **双栈 IP 支持** - 支持 IPv4/IPv6 优先级设置，自动检测公网 IP
- 🛠️ **完整节点管理** - 添加、删除、修改端口、查看节点信息
- 📱 **Quantumult X 配置** - 自动生成 Quantumult X 兼容配置格式
- 🔄 **脚本自更新** - 一键更新脚本到最新版本
- 🧩 **双内核支持** - 同时支持 Xray 与 Sing-box 内核管理
- 🧹 **完整卸载** - 支持卸载 Xray / Sing-box 内核，及卸载脚本

## 📋 系统要求

| 项目 | 要求 |
|------|------|
| **操作系统** | Alpine / Debian / Ubuntu / CentOS / Rocky / Fedora 等 Linux 发行版 |
| **包管理器** | `apk` / `apt-get` / `yum` / `dnf` 任一即可 |
| **初始化系统** | systemd 或 OpenRC |
| **架构** | x86_64 / AMD64 / ARM64 / ARMv7 |
| **权限** | Root 用户权限 |
| **网络** | 可访问 GitHub 以下载 Xray / Sing-box 核心 |

## 🚀 快速开始

### 一键安装脚本

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Ezrea7/ReaLity/main/install.sh)
```



## 快捷指令

### 安装完成后，使用以下命令进入管理菜单：

```bash
xtls
```

### 安装完成后的快速检查

如需确认脚本是否安装到正确位置，可手动执行：

```bash
readlink -f /usr/local/bin/xtls
head -n 4 /usr/local/etc/xray/sh/xray.sh
```

正常情况下，快捷命令应指向：

```text
/usr/local/etc/xray/sh/xray.sh
```

### 端口说明

当前脚本仅校验端口格式（1-65535），不再额外拦截“端口已被占用”或“系统进程占用”场景。
如端口确实冲突，由实际服务启动结果决定。

## Quantumult X 配置示例

### SS + ReaLity

```text
shadowsocks=服务器IP:端口, method=2022-blake3-aes-128-gcm 或 aes-128-gcm, password=密码, obfs=over-tls, obfs-host=伪装域名, tls-verification=false, reality-base64-pubkey=公钥, reality-hex-shortid=短ID, udp-relay=true, tag=节点名称
```

### AnyTLS + Reality

```text
anytls=example.com:443, password=pwd, over-tls=true, tls-host=apple.com, reality-base64-pubkey=k4Uxez0sjl8bKaZH2Vgi8-WDFshML51QkxKFLWFIONk, reality-hex-shortid=0123456789abcdef, udp-relay=true, tag=anytls-reality-tls-01
```

### 推荐客户端：Quantumult X

如需配置其他客户端，请查看脚本内生成的 JSON 配置内容。

## 配置文件

### Xray 核心配置文件

```text
/usr/local/etc/xray/config.json
```

### Sing-box 核心配置文件

```text
/usr/local/etc/sing-box/config.json
```

### 节点源数据

```text
/usr/local/etc/xtls/metadata.json
```

### IP 优先级配置

```text
/usr/local/etc/xray/ip_preference.conf
```

## 当前仓库结构

```text
Xray/
├─ README.md
├─ LICENSE
├─ VERSION
├─ install.sh
├─ xray.sh
├─ .github/
│  └─ workflows/
│     └─ release.yml
└─ src/
   ├─ base.sh
   ├─ init.sh
   ├─ core.sh
   ├─ download.sh
   ├─ service.sh
   ├─ singbox.sh
   ├─ help.sh
   ├─ config.sh
   ├─ protocol.sh
   ├─ share.sh
   └─ menu.sh
```

### 模块职责说明

- `src/service.sh`：统一负责 Xray / Sing-box 的服务、状态、卸载、运行摘要
- `src/singbox.sh`：Sing-box 轻占位模块，作为后续扩展保留位，避免与 `src/service.sh` 重复维护服务逻辑

## 发布方式

- push 到 `main` 默认发行
- 自动读取 `VERSION`
- 自动打包为 `code.zip`
- 自动按版本号创建 / 更新 Release

## 更新日志

- `v1.0`：版本体系切换到 1.x 主版本线；当前仓库为双内核脚本，支持 Xray / Sing-box、AnyTLS + Reality、Quantumult X 输出、Release 安装与更新。
- `v0.3.40`：修复 SS + ReaLity 加密方式选择提示未完整显示的问题。
- `v0.3.39`：补充 SS + ReaLity 加密方式选择提示文案。
- `v0.3.38`：SS2022 + Reality 改为 SS + ReaLity，并支持 `2022-blake3-aes-128-gcm` / `aes-128-gcm` 两种可选 method。
- `v0.3.37`：移除监听端口可用性校验，端口输入仅保留格式检查。
- `v0.3.36`：安装器输出简化，移除终端自检展示，自检方式改写入 README。
- `v0.3.35`：统一由 `service.sh` 负责双内核服务逻辑，`singbox.sh` 收缩为轻占位模块。
- `v0.3.34`：清理版本硬编码回退值，升级双内核关键函数完整性保护，并为安装器增加安装后快速检查思路。
- `v0.3.33`：修复 13 号菜单“设置网络优先级”函数缺失导致闪退问题。
- `v0.3.31`：主菜单标题改为 `Xray Sing-box / Reality 协议管理脚本`。
- `v0.3.30`：README 顶部标题改为 `Xray SingBox + Reality 一键管理脚本`。
- `v0.3.29`：仓库更名为 `ReaLity`，并同步修正内部更新地址与安装地址。
- `v0.3.28`：所有 Quantumult X 输出统一加入 `tls-verification=false`。
- `v0.3.27`：Sing-box 安装/更新后自动启动或重启，行为与 Xray 保持一致。
- `v0.3.26`：按当前仓库实际功能重写 README，修正安装指令、路径、协议说明与发行说明。
- `v0.3.25`：统一 Xray / Sing-box 状态显示为 未安装 / 已停止 / 运行中。
- `v0.3.24`：修复 `xtls` 快捷命令自指向问题。
- `v0.3.23`：发行流程改为 main 默认发行，并增强 Release 资产覆盖。
- `v0.3.22`：加入 Sing-box 内核支持与 AnyTLS + Reality 协议支持。

## 版本规则

- 当前开始使用 `1.x` 版本体系。
- 后续默认按小版本递增，例如：`1.1`、`1.2`、`1.3` ...
- 每累计 10 次版本修改后，再提升一次根版本号，例如：`1.9` → `2.0`

## License

MIT License
