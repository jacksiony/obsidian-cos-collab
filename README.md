# Obsidian + COS + OpenClaw 协作系统

> 让 AI 安全参与你的知识管理——受控的工作流，清晰的边界，可靠的版本控制。

这是一套用 OpenClaw + Obsidian + COS 搭一个「可控 AI 知识系统」》的完整技能包。它解决了 AI 直接操作 Obsidian 带来的风险：乱改文件、无版本控制、多端同步冲突。

## 核心设计

```
本地 Obsidian（电脑/手机）
        ↑（COS 同步链路）
        ↓
  腾讯云 COS 存储桶（版本控制开启）
        ↑           ↓
   sync.sh      publish.sh
        ↑           ↓
   mirror/     proposals/
        ↑
  OpenClaw（读 mirror，写 proposals）
```

**三个关键原则**：

1. **读隔离**：OpenClaw 只读 `mirror/`（COS 的只读快照），不直接碰正式知识库
2. **写隔离**：OpenClaw 只写 `proposals/`（草稿待确认区），不能直接入库
3. **人 gate**：必须手动执行 `publish.sh` 才把草稿发布到 COS，再同步回 Obsidian

## 目录结构

```
~/.openclaw/workspace/skills/obsidian-cos-collab/
├── SKILL.md              # 技能定义文件（OpenClaw 自动识别）
├── README.md             # 本文件
├── scripts/              # 核心脚本
│   ├── sync.sh          # 从 COS 同步到 mirror（只读）
│   ├── publish.sh       # 从 proposals 发布到 COS
│   ├── setup.sh         # 首次环境初始化
│   └── utils.sh         # 共享函数库
├── config/
│   ├── .env.example     # 环境变量模板
│   └── rules/
│       ├── AI_RULES.md  # OpenClaw 操作规则（需复制到 workspace）
│       └── TEMPLATE.md  # 新笔记模板
├── references/           # 参考文档
│   ├── cos-versioning.md
│   ├── obsidian-sync.md
│   └── openclaw-workspace.md
├── docs/
│   ├── usage-guide.md
│   └── troubleshooting.md
└── assets/               # 图片、图表等
```

## 快速开始

###  prerequisites

- [腾讯云 COS](https://cloud.tencent.com/product/cos) 存储桶（已开启版本控制）
- [Obsidian](https://obsidian.md) Vault 已配置 COS 多端同步
- Ubuntu/Debian 服务器（运行 OpenClaw）
- Python3 + pip（用于安装 coscmd）

### 安装

1. **克隆或复制此技能到 OpenClaw 的 skills 目录**

```bash
# 如果 skill 已在，跳过
cd ~/.openclaw/workspace/skills/
# 确保 obsidian-cos-collab 目录存在
```

2. **执行初始化**

```bash
cd ~/.openclaw/workspace/skills/obsidian-cos-collab
bash scripts/setup.sh
```

setup.sh 会：
- 创建 `~/openclaw-system/` 目录结构
- 创建 Python 虚拟环境并安装 coscmd
- 生成配置文件 `.env`
- 询问 COS 参数并配置 `sync.sh` 和 `publish.sh`

3. **配置 Obsidian 工作区**

在你的 Obsidian Vault 根目录创建：

```
06AI_workspace/
├── 00AI_Inbox/          # AI 新内容入口
├── 01AI_Drafts/         # AI 修改建议
└── 02System/
    ├── AI_RULES.md      # AI 操作规则（从 config/rules/ 复制）
    └── TEMPLATE.md      # 新笔记模板
```

4. **配置 OpenClaw**

在你的 OpenClaw 主目录（或 memory）中添加规则：

```markdown
# 知识库协作规则（必读）
- 读：只读 ~/openclaw-system/mirror/ 目录，不做任何修改
- 写：所有输出保存为 Markdown 到 ~/openclaw-system/proposals/，文件名带时间戳
- frontmatter 必须包含 `target: AI Inbox` 或 `target: AI Drafts`
- 不要尝试直接修改或删除 mirror/ 中的文件
```

### 验证安装

```bash
# 1. 手动同步一次 mirror
bash ~/openclaw-system/scripts/sync.sh

# 检查 mirror 是否包含你的笔记
ls ~/openclaw-system/mirror/06AI_workspace/

# 2. 测试 proposals 写入
echo "# 测试" > ~/openclaw-system/proposals/20260407-test.md

# 3. 检查日志
tail -f ~/openclaw-system/logs/sync.log
```

## 使用方式

### OpenClaw 读知识

OpenClaw 分析问题时，从 `~/openclaw-system/mirror/` 读取相关笔记。这是只读快照，AI 可以自由查阅但不能修改。

示例：

```
用户：帮我总结一下上周的会议记录
OpenClaw：读取 ~/openclaw-system/mirror/06AI_workspace/01AI_Drafts/20260405-会议记录.md
```

### OpenClaw 写草稿

所有 AI 产出的内容都以 Markdown 文件形式保存到 `proposals/`，格式：

```markdown
---
target: AI Inbox  # 或 AI Drafts
title: 笔记标题
created: 2026-04-07T22:30:00+08:00
---

# 标题

正文内容...
```

**不要直接发布**——先让人工审核。

### 人工发布

审核通过后，执行：

```bash
# 发布单个
bash ~/openclaw-system/scripts/publish.sh 20260407-会议总结.md

# 批量发布（确认所有文件都审核过）
bash ~/openclaw-system/scripts/publish.sh *.md
```

发布流程：
1. 根据 `target:` 决定上传到 COS 的哪个目录
2. 调用 `coscmd upload` 上传
3. 移动文件到 `published/`
4. 自动调用 `sync.sh` 刷新 mirror
5. 写入操作日志

### 自动定时同步（可选）

添加 crontab 兜底：

```bash
crontab -e
# 每小时同步一次 mirror（防止手动 sync 遗漏）
0 * * * * /bin/bash /root/openclaw-system/scripts/sync.sh > /dev/null 2>&1
```

## 安全与回滚

### COS 版本控制

必须在 COS 控制台开启：
- 路径：存储桶 → 基础配置 → 容错容灾管理 → 开启版本控制

回滚方法：
1. 进入 COS 控制台，找到文件的历史版本
2. 选择要回滚的版本，点击「恢复到当前版本」

### 本地归档

- `published/`：已发布成功的草稿（可 git 追踪）
- `rejected/`：拒绝的草稿（保留记录）
- `logs/`：所有 sync/publish 操作的完整日志

### 目录权限

```bash
# mirror 只读（防止 AI 意外写入）
chmod -R 555 ~/openclaw-system/mirror

# proposals 可写
chmod -R u+rwx ~/openclaw-system/proposals
```

## 故障排查

| 症状 | 检查点 | 命令 |
|------|--------|------|
| sync.sh 失败 | COS 配置、网络 | tail -n 50 ~/openclaw-system/logs/sync.log |
| coscmd command not found | 虚拟环境路径 | ls ~/venvs/coscmd/bin/coscmd |
| mirror 不是只读 | 权限设置 | ls -ld ~/openclaw-system/mirror |
| 发布后 Obsidian 未更新 | COS 同步客户端 | 检查手机/电脑 Obsidian 同步状态 |
| proposals 无法创建 | 目录所有权 | df -h ~/openclaw-system/proposals |

详细 troubleshooting 见 `docs/troubleshooting.md`。

## 原理与哲学

### 为什么不用直接读写？

直接让 AI 操作 Obsidian 仓库的风险：
- **多端冲突**：AI 在云端写，手机本地也写，COS 同步容易冲突
- **无版本控制**：写坏了无法回滚
- **权限过大**：AI 可能误删、误改重要文件
- **边界模糊**：AI 应该辅助思考，而不是替你管理知识

### 为什么需要 mirror？

mirror 是 COS 内容的 **只读快照**，它的作用是：
- 给 AI 提供上下文（足够相关，不必全量仓库）
- 明确隔离：AI 读这里，不读其他地方
- 性能优化：本地文件读取比跨网络访问 COS 快

### 为什么 proposals 不能直接入库？

这是整个系统的 **安全阀**。所有 AI 产出必须经过人工审核才能发布。虽然多了一步，但避免了：
- AI 生成错误内容污染知识库
- 重复、无意义的内容堆积
- 版权或隐私问题

### 与 Git 对比

| 方案 | 优点 | 缺点 |
|------|------|------|
| 本系统（COS + 隔离） | 多端同步现成、版本控制、云原生 | 需腾讯云、稍复杂 |
| Git + 远程仓库 | 开源免费、diff 审查 | Obsidian 同步需额外配置 |
| 直接 SSH 读写 | 简单直接 | 高风险、无隔离 |

## 扩展方向

- [ ] 将 proposals/ 加入 git，实现 diff 可视化审查
- [ ] webhook 通知：发布成功发送到 Feishu/Telegram
- [ ] OpenClaw 内置命令：`/publish 文件名` 一键发布
- [ ] 自动文件名：`%(Y%m%d-%H%M%S)-title.md` 格式
- [ ] mirror 智能增量同步（根据修改时间）
- [ ] 多 Vault 支持（每个 Vault 独立 proposals/ 目录）

## FAQ

**Q: 能否让 AI 自动发布？**
A: 不建议。人工 gate 是安全底线。如果非要，可以把 `publish.sh` 做成定时任务扫描 proposals/，但风险自担。

**Q: 可以用其他云存储吗？**
A: 可以。只需替换 `coscmd` 为对应 CLI 工具（如 aws s3、rclone 等），修改脚本即可。

**Q: mirror 和 proposals 可以放不同磁盘吗？**
A: 可以。修改 `sync.sh` 和 `publish.sh` 中的路径变量即可。

**Q: 手机端的 Obsidian 能看到 AI 写的内容吗？**
A: 能。publish.sh 上传到 COS 后，手机/电脑的 Obsidian 会自动同步下来（前提是同步路径正确）。

**Q: 我可以修改 script 吗？**
A: 当然。这是你的系统。但建议改前备份，并保持核心隔离原则不变。

## 致谢

本文基于 [参数之缘]的经验：

感谢分享开放式架构思路。

---

**状态**：v1.0.0 · 兼容 OpenClaw ≥ 2026.04 · 测试环境 Ubuntu 22.04 + Tencent Cloud COS
