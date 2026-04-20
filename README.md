# Xray

基于当前菜单式 `xray.sh` 演进的轻量化 Xray 管理脚本仓库。

> 当前阶段：仓库骨架已建立，并已完成第三阶段关键收尾项。

> 当前发布版本：`v0.3.21`

## 设计目标

- **基于现有脚本继续演进**，不照抄大型命令体系
- 保持 **稳定、轻量、高效**
- 默认以 **交互菜单** 为主
- 面向 **Reality / Xray 常用场景**
- 支持 GitHub Release 分发与后续持续更新

## 当前仓库结构

```text
Xray/
├─ README.md
├─ LICENSE
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
   ├─ help.sh
   ├─ config.sh
   ├─ protocol.sh
   ├─ share.sh
   └─ menu.sh
```

## 文件说明

### `xray.sh`
仓库入口脚本。

当前职责：
- 提供版本号
- 将参数传递给 `src/init.sh`

### `install.sh`
轻量安装脚本。

当前职责：
- 从 GitHub Release 拉取最新 `code.zip`
- 将仓库文件安装到目标目录
- 建立 `/usr/local/bin/xtls` 与 `/usr/local/bin/XTLS` 快捷入口
- 输出当前安装版本

### `src/base.sh`
第三阶段新增的基础模块。

包含：
- 全局变量
- 颜色与输出函数
- root 检查
- init system 检测
- 脚本快捷方式安装
- IP 优先级与系统信息公共逻辑

### `src/init.sh`
初始化入口。

当前职责：
- 初始化全局变量
- 载入已拆分模块
- 最后载入当前单体核心 `src/core.sh`

### `src/core.sh`
当前核心主脚本。

当前仍承载大部分菜单与协议逻辑，后续继续拆分。

### `src/download.sh`
已拆出的下载与更新模块。

包含：
- 依赖安装
- 下载封装
- Xray 安装/更新
- 脚本自更新

### `src/service.sh`
已拆出的服务与卸载模块。

包含：
- Xray systemd / openrc service 生成
- Sing-box systemd / openrc service 生成
- Xray / Sing-box 服务启动/停止/重启/状态
- Xray / Sing-box 卸载
- 脚本卸载

### `src/help.sh`
当前帮助占位模块。

本仓库默认以菜单使用为主，不扩展复杂命令帮助体系。

### `src/config.sh`
已拆出的配置与元数据操作模块。

包含：
- JSON 修改
- 端口冲突检查
- 配置初始化
- 元数据读写
- 节点索引与查询

### `src/protocol.sh`
已拆出的协议实现模块。

包含：
- Reality 密钥生成
- Sing-box AnyTLS + Reality 密钥生成
- SS2022 / Trojan / VMess / VLESS / AnyTLS 的入站构建
- 协议添加逻辑

### `src/share.sh`
已拆出的分享链接模块。

包含：
- Quantumult X 链接生成
- VLESS 标准分享链接生成
- AnyTLS + Reality Quantumult X 链接生成
- 分享链接展示

### `src/menu.sh`
已拆出的交互菜单模块。

包含：
- 输入交互
- 节点查看/删除/改端口
- 添加协议菜单
- 主菜单入口

## 安装方式（当前骨架版）

### 一键安装

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Ezrea7/Xray/main/install.sh)
```

### 本地安装
在仓库目录执行：

```bash
bash install.sh
```

默认安装到：

- `/usr/local/etc/xray/sh/`
- `/usr/local/bin/xtls`
- `/usr/local/bin/XTLS`

### 运行
安装完成后：

```bash
xtls
```

## 发布方式

当前仓库已接入 GitHub Actions：

- 仅在推送 `v*` 标签时发布
- 自动打包为 `code.zip`
- 自动以标签名创建 Release

### 发布示例

```bash
git tag v0.3.21
git push origin v0.3.21
```

## 当前状态说明

当前仓库已经：
- 建立 GitHub 仓库结构
- 完成基础安装器与入口脚本
- 接入按标签发布的 Release Workflow
- 完成模块化拆分（download / service / help / config / protocol / share / menu）
- 引入 `base.sh`
- 将 `core.sh` 收缩为最小壳层，实际逻辑由模块承载
- 安装器改为从 GitHub Release 获取最新 `code.zip`
- 更新逻辑改为按仓库 Release 更新
- 已加入 Sing-box 内核安装 / 服务 / 卸载能力
- 已加入 AnyTLS + Reality 协议支持（基于 Sing-box）
- 保持现有菜单逻辑继续可运行

## 后续计划

建议按以下顺序推进：

1. 视需要补充 VERSION 读取容错
2. 做一次正式 tag 发布测试
3. 继续优化 README 与发布说明

## 许可说明

当前仓库仍处于整理与重构阶段，请根据最终发布需求确认许可证文本。
