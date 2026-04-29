---
name: obsidian-cos-collab
description: 通过腾讯云 COS 实现 OpenClaw 与本地 Obsidian 的安全协作系统。AI 只读 mirror（快照）、只写 proposals（草稿），人工确认后才发布到 COS 并同步回 Obsidian。解决 AI 乱改知识库、多端同步冲突、版本控制问题。
tags:
  - obsidian
  - cos
  - knowledge-management
  - ai-collaboration
  - tencent-cloud
version: 1.0.0
author: 安生（基于参数之缘文章）
---

# Obsidian + COS + OpenClaw 协作技能

一套让 OpenClaw 安全参与 Obsidian 知识管理的完整系统。AI 永远不直接触碰正式知识库，而是通过 mirror/proposals 隔离层进行可控协作。

## 核心原则

- **读隔离**：OpenClaw 只读取 `mirror/` 目录（COS 的只读快照）
- **写隔离**：OpenClaw 只写入 `proposals/` 目录（待确认草稿）
- **人工确认**：必须人工审核后执行 `publish.sh` 才真正入库
- **自动同步**：发布后自动触发 `sync.sh` 刷新 mirror
- **版本保险**：COS 开启版本控制，支持回滚

## 目录结构

```
~/openclaw-system/
├── workspace/      # OpenClaw 工作上下文
├── mirror/         # COS 只读快照（AI 只读这里）
├── proposals/      # AI 草稿输出区（只写这里）
├── published/      # 已发布草稿（自动归档）
├── rejected/       # 拒绝的草稿（自动归档）
├── logs/           # 操作日志
└── scripts/        # 核心脚本
    ├── sync.sh     # 从 COS 同步到 mirror
    ├── publish.sh  # 发布 proposals 到 COS
    ├── setup.sh    # 环境初始化
    └── utils.sh    # 共享函数
```

## 快速开始

### 1. 前置条件

- 腾讯云账号 + COS 存储桶（已开启版本控制）
- Obsidian Vault 已通过 COS 同步（电脑/手机互通）
- 服务器（OpenClaw 运行环境）
- Python3 + venv（用于 coscmd）

### 2. 一键初始化

```bash
# 进入 skill 目录
cd ~/.openclaw/workspace/skills/obsidian-cos-collab

# 运行初始化脚本（会问 COS 配置信息）
bash scripts/setup.sh
```

### 3. 配置 OpenClaw

在 OpenClaw 的 SKILL.md 或 memory 中定义：

```markdown
## 知识库协作规则
- 读知识：查看 ~/openclaw-system/mirror/ 下的文件
- 写知识：输出到 ~/openclaw-system/proposals/ 文件名.md
- 不要修改、删除 mirror/ 中的任何文件
- 新内容放 00AI_Inbox/，修改建议放 01AI_Drafts/
```

### 4. 验证系统

```bash
# 手动同步一次 mirror
bash ~/openclaw-system/scripts/sync.sh

# 测试 proposals 目录权限
touch ~/openclaw-system/proposals/test.md
```

## 工作流

### AI 读知识

OpenClaw 在 workspace 中分析问题时，从 `~/openclaw-system/mirror/` 读取参考内容。这是 COS 的本地只读副本。

### AI 写草稿

所有输出统一格式：

```markdown
---
target: AI Inbox  # 或 AI Drafts
title: 笔记标题
created: 2026-04-07
---

# 标题

正文内容...
```

保存到 `~/openclaw-system/proposals/`。

### 人工发布

审核 proposals/ 中的草稿后：

```bash
# 发布单个文件
bash ~/openclaw-system/scripts/publish.sh 笔记标题.md

# 发布多个文件
bash ~/openclaw-system/scripts/publish.sh 笔记1.md 笔记2.md
```

发布后：
- 文件上传到 COS 对应路径
- 移动到 published/
- 自动触发 sync.sh 刷新 mirror

## 脚本说明

### sync.sh

从 COS 同步 Obsidian Vault 的指定目录到本地 mirror。

- 仅同步 AI 工作区（最小必要输入）
- 设置 mirror 为只读（chmod 555）
- 记录日志到 `~/openclaw-system/logs/sync.log`
- 支持定时 cron 兜底

### publish.sh

将人工确认的 proposals 上传到 COS。

- 根据 frontmatter 的 `target:` 决定上传路径：
  - `AI Inbox` → `/obsidian_vault/06AI_workspace/00AI_Inbox/`
  - `AI Drafts` → `/obsidian_vault/06AI_workspace/01AI_Drafts/`
- 上传成功后移动到 published/ 或 rejected/
- 自动调用 sync.sh 刷新 mirror

### setup.sh

首次环境初始化。

- 创建目录结构
- 配置虚拟环境和 coscmd
- 生成配置文件 `.env`
- 询问 COS 参数并生成脚本

## 安全机制

1. **文件系统权限**：mirror/ 设置为 555（只读），防止 AI 意外修改
2. **目录隔离**：AI 永远接触不到正式知识目录（通过 COS 路由）
3. **版本控制**：COS 开启版本管理，任何操作都可回滚
4. **人工 gate**：publish.sh 必须手动执行，AI 无法自动入库
5. **日志审计**：所有同步、发布操作记录到 logs/

## 故障处理

| 问题 | 解决方案 |
|------|----------|
| coscmd 报错 externally-managed-environment | 使用虚拟环境 `~/venvs/coscmd/bin/coscmd` |
| mirror 内容为空 | 检查 COS 配置，执行 `sync.sh` 并查看日志 |
| 无法创建 proposals 文件 | 检查目录权限 `chmod u+w ~/openclaw-system/proposals` |
| 发布后本地未更新 | 检查 COS 同步链路，确认手机/电脑客户端在线 |
| 版本控制未开启 | 在 COS 控制台：存储桶 → 基础配置 → 容错容灾管理 |

## 参考资料

- [COS 版本控制官方文档](references/cos-versioning.md)
- [Obsidian 同步最佳实践](references/obsidian-sync.md)
- [OpenClaw workspace 配置](references/openclaw-workspace.md)

## 扩展建议

- 为 proposals 添加 git 追踪，实现本地 diff 审查
- 用 Feishu webhook 通知发布事件
- 在 OpenClaw 中封装 `skill-obsidian-publish` 命令，一键发布
-  proposals/ 文件名加入时间戳：`%Y%m%d-%H%M%S-title.md`

---

**核心思想**：AI 是建议者，人是发布者，COS 是保险丝。
