# Xray

基于当前菜单式 `xray.sh` 演进的轻量化 Xray 管理脚本仓库。

> 当前阶段：仓库骨架已建立，仍以现有单核心脚本为主，后续逐步模块化拆分。

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
   ├─ init.sh
   └─ core.sh
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
- 将仓库文件安装到目标目录
- 建立 `/usr/local/bin/xray` 快捷入口

### `src/init.sh`
初始化入口。

当前职责：
- 载入 `src/core.sh`
- 保证仓库版入口能运行现有核心脚本

### `src/core.sh`
当前核心主脚本。

当前版本直接承载现有菜单式逻辑，后续再逐步拆分为：
- `config.sh`
- `service.sh`
- `protocol.sh`
- `share.sh`
- `menu.sh`
- `help.sh`
- `download.sh`

## 安装方式（当前骨架版）

### 本地安装
在仓库目录执行：

```bash
bash install.sh
```

默认安装到：

- `/usr/local/etc/xray/sh/`
- `/usr/local/bin/xray`

### 运行
安装完成后：

```bash
xray
```

## 当前状态说明

当前仓库已经：
- 建立 GitHub 仓库结构
- 完成首次推送
- 接入基础 Release Workflow
- 将现有脚本纳入仓库管理

但目前仍属于：

> **仓库化第一阶段**

也就是：
- 先保证仓库有清晰结构
- 再逐步做真正模块化拆分
- 尽量避免一次性大改造成不稳定

## 后续计划

建议按以下顺序推进：

1. 完善仓库骨架
2. 强化安装脚本
3. 拆分 `src/core.sh`
4. 完善帮助文档
5. 优化 GitHub Release 发布流程

## 许可说明

当前仓库仍处于整理与重构阶段，请根据最终发布需求确认许可证文本。
