# Xray xTLS + Reality 一键管理脚本

<div align="center">

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Linux-blue.svg)]()
[![Protocol](https://img.shields.io/badge/protocol-SS2022%2BReality-orange.svg)]()
[![Init](https://img.shields.io/badge/init-systemd%20%7C%20openrc-purple.svg)]()

**基于 [大表哥 singbox-lite](https://github.com/0xdabiaoge/singbox-lite) 脚本二次开发**

</div>

> 当前发布版本：`v0.3.26`

## ✨ 功能特性

- 🔐 **支持 VLESS + Reality / SS2022 + Reality / Trojan + Reality / VMess + Reality / AnyTLS + Reality 协议**
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
bash <(curl -fsSL https://raw.githubusercontent.com/Ezrea7/Xray/main/install.sh)
```

## 快捷指令

### 安装完成后，使用以下命令进入管理菜单：

```bash
xtls
```

## Quantumult X 配置示例

### SS2022 + Reality

```text
shadowsocks=服务器IP:端口, method=2022-blake3-aes-128-gcm, password=密码, obfs=over-tls, obfs-host=伪装域名, reality-base64-pubkey=公钥, reality-hex-shortid=短ID, udp-relay=true, tag=节点名称
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

## 发布方式

- push 到 `main` 默认发行
- 自动读取 `VERSION`
- 自动打包为 `code.zip`
- 自动按版本号创建 / 更新 Release

## 更新日志

- `0.3.26`：按当前仓库实际功能重写 README，修正安装指令、路径、协议说明与发行说明
- `0.3.25`：统一 Xray / Sing-box 状态显示为 未安装 / 已停止 / 运行中
- `0.3.24`：修复 `xtls` 快捷命令自指向问题
- `0.3.23`：发行流程改为 main 默认发行，并增强 Release 资产覆盖
- `0.3.22`：加入 Sing-box 内核支持与 AnyTLS + Reality 协议支持

## License

MIT License
