# Hermes Agent - fnOS Official Package

官方维护的 Hermes Agent fnOS fpk 包，支持内嵌自更新。

## 功能特性

- **内嵌自更新**：自动检查 Hermes 上游最新版本，发现更新时提示用户
- **全中文控制面板**：端口 9119，开箱即用
- **多平台消息网关**：支持微信、飞书、Telegram、Discord 等
- **技能系统**：支持 MCP 扩展与持久记忆
- **独立数据目录**：与应用隔离，不会干扰其他 Hermes 实例

## 架构设计

```
┌─────────────────────────────────────────────────────────────┐
│                        fnOS 应用中心                         │
│                    (安装/管理入口)                           │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                     Hermes Agent (fpk)                       │
│  ┌─────────────┐  ┌──────────────┐  ┌───────────────────┐  │
│  │  cmd/main   │  │cmd/self-     │  │  cmd/install_     │  │
│  │             │  │update        │  │  callback         │  │
│  └──────┬──────┘  └──────┬───────┘  └────────┬──────────┘  │
│         │                │                    │             │
│         ▼                ▼                    ▼             │
│  ┌─────────────┐  ┌──────────────┐  ┌───────────────────┐  │
│  │  Monitor    │  │  检查上游    │  │  初始化数据目录   │  │
│  │  (Python)   │  │  GitHub API  │  │  安装 hermes-src  │  │
│  └──────┬──────┘  └──────┬───────┘  └────────┬──────────┘  │
│         │                │                    │             │
│         ▼                ▼                    ▼             │
│  ┌─────────────────────────────────────────────────────────┐│
│  │              Hermes Gateway + Dashboard                  ││
│  │                   (端口 8642 + 9119)                     ││
│  └─────────────────────────────────────────────────────────┘│
│                              │                               │
│                              ▼                               │
│  ┌─────────────────────────────────────────────────────────┐│
│  │           用户数据目录 (@apphome/hermes-agent/data)      ││
│  │  config.yaml, .env, sessions/, skills/, memories/       ││
│  └─────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│              NousResearch/hermes-agent (上游)                │
│         (GitHub Releases + PyPI)                            │
└─────────────────────────────────────────────────────────────┘
```

## 目录结构

```
fnos-hermes-official/
├── .github/workflows/
│   ├── build.yml          # CI 构建流水线
│   └── auto-update.yml    # 自动检测上游版本
├── app/
│   └── ui/
│       └── config         # 桌面入口配置（必需）
├── cmd/
│   ├── main               # 生命周期管理（start/stop/status/update）
│   ├── self-update        # 自更新脚本（核心创新）
│   ├── install_callback   # 安装后回调
│   ├── upgrade_callback   # 升级后回调
│   ├── uninstall_callback # 卸载后回调
│   └── *_init             # 前置清理脚本
├── config/
│   ├── bootstrap/
│   │   └── hermes-version.env  # 版本配置
│   ├── privilege          # 运行权限
│   └── resource           # 端口配置
├── wizard/
│   ├── install            # 安装向导
│   └── uninstall          # 卸载向导
├── scripts/
│   └── build-fpk.sh       # 本地构建脚本
├── manifest               # 应用清单（含 update_url）
├── ICON.PNG               # 应用图标
├── LICENSE
└── README.md
```

## 自更新机制详解

### 工作流程

1. **启动时检查**：`cmd/main` 在启动时调用 `self-update check`
2. **定时检查**：可通过 cron 任务定期执行
3. **手动触发**：用户可通过控制面板或 CLI 手动检查
4. **版本比较**：调用 GitHub API 获取最新版本，与本地版本比较
5. **提示升级**：发现新版本后，通过控制面板 UI 提示用户

### 状态文件

```json
// /vol1/@appdata/hermes-agent/self-update-state.json
{
    "last_check": "2026-09-04T10:00:00+08:00",
    "latest_version": "v0.22.0",
    "local_version": "0.21.0",
    "has_update": true,
    "enabled": true,
    "created_at": "2026-09-04T09:00:00+08:00"
}
```

### 使用方式

```bash
# 检查是否有新版本
/hermes-agent/cmd/self-update check

# 执行更新（会调用 fnOS 升级回调）
/hermes-agent/cmd/self-update update

# 查看当前状态
/hermes-agent/cmd/self-update status
```

## 快速开始

### 本地构建

```bash
# 安装依赖（如需）
chmod +x scripts/build-fpk.sh

# 构建（自动递增版本）
./scripts/build-fpk.sh

# 或指定版本
./scripts/build-fpk.sh 0.22.0

# 或保持当前版本
./scripts/build-fpk.sh --noinc
```

### 安装到飞牛 NAS

1. 下载生成的 `.fpk` 文件
2. 飞牛桌面 → 应用中心 → 手动安装
3. 上传 `.fpk`，完成安装向导
4. 桌面出现 Hermes Agent 图标，点击打开控制面板
5. 在「模型」页配置 API Key
6. 点击「启动」即可使用

### GitHub Actions

仓库配置了 CI/CD：

- **每次 push 到 main**：自动构建 fpk 并发布到 GitHub Releases
- **定时任务**：每天自动检查 Hermes 上游新版本，如有更新则创建 PR
- **手动触发**：可通过 GitHub Actions 页面手动运行工作流

## 与上游的关系

| 组件 | 来源 | 更新方式 |
|------|------|----------|
| Hermes Agent 核心 | NousResearch/hermes-agent | fpk 内嵌源码 + 自更新脚本 |
| fpk 打包层 | 本仓库 | GitHub Releases |
| fnOS 适配 | 本仓库 | 随 fpk 一起更新 |

## 许可证

- fpk 打包层：MIT License
- Hermes Agent 核心：MIT License (Nous Research)

## 相关链接

- [NousResearch/hermes-agent](https://github.com/NousResearch/hermes-agent) - 上游项目
- [Hermes Agent 文档](https://hermes-agent.nousresearch.com)
- [飞牛 fnOS 开发者文档](https://developer.fnnas.com)
