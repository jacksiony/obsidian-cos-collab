# OpenClaw Workspace 与 Memory 配置指南

> OpenClaw 的工作空间是 AI 的「短期记忆」层，用于存放规则、偏好、任务状态。

## workspace 目录结构

```
~/openclaw-system/workspace/
├── AI_RULES.md        # 从技能复制过来，告诉 AI 如何协作
├── current-task.md    # 当前任务进度（可选）
├── preferences.md     # 个人偏好（如中文输出、Markdown 格式）
├── projects/          # 按项目组织的临时笔记
│   ├── project-a/
│   └── project-b/
└── scratch/           # 草稿本（不进入正式 proposals）
```

## 配置内容

### AI_RULES.md

直接复制 `skills/obsidian-cos-collab/config/rules/AI_RULES.md` 到 `workspace/AI_RULES.md`。

这文件会被 OpenClaw 自动加载（如果放在主 workspace 中），或者需要在 system prompt 中显式引用。

### preferences.md

```markdown
# OpenClaw 偏好设置

- 输出语言：中文（简体）
- 默认格式：Markdown
- 笔记时间戳格式：%Y%m%d-%H%M%S
- 引用来源：使用记忆库内容时标注来源
```

## workspace vs mirror vs proposals

| 目录 | 用途 | 谁可写 | 谁可读 |
|------|------|--------|--------|
| `workspace/` | OpenClaw 的短期上下文 | OpenClaw | OpenClaw |
| `mirror/` | COS 内容的只读快照 | 无（只读） | OpenClaw |
| `proposals/` | AI 产出草稿区 | OpenClaw | 用户（人工审核） |

**关键区别**：
- `workspace` 是 OpenClaw 自己的「大脑」，存储任务状态、对话历史、临时思考
- `mirror` 是「外部知识」的只读副本，相当于数据库只读副本
- `proposals` 是「待发布」的输出缓冲区

## 配置 OpenClaw 加载规则

如果你的 OpenClaw 主目录是 `~/.openclaw/workspace/`（常见），可以直接：

```bash
# 复制规则文件
cp ~/.openclaw/workspace/skills/obsidian-cos-collab/config/rules/AI_RULES.md ~/.openclaw/workspace/AI_RULES.md
```

OpenClaw 启动时会自动读取主目录下的规则文件。

如果使用自定义工作区，在启动参数中指定：

```bash
openclaw --workspace ~/my-workspace
```

并在 `~/my-workspace/AI_RULES.md` 中写入协作规则。

## 与 memory/ 的关系

- `memory/`（每日笔记）是**长期记忆**，记录事件、对话、决策
- `workspace/` 是**短期上下文**，每次会话重置
- `mirror/` 是**外部快照**，定期刷新

OpenClaw 在处理任务时：
1. 从 `workspace/` 加载当前会话上下文
2. 从 `mirror/` 读取相关外部知识
3. 思考后输出到 `proposals/`（人工发布）或直接回复用户

## 高级：工作区脚本

可以在 `workspace/scripts/` 放自定义脚本，例如：

```bash
#!/bin/bash
# workspace/scripts/watch-mirror.sh
# 监控 mirror 目录变化，通知 OpenClaw 刷新上下文

inotifywait -m -e modify,create,delete ~/openclaw-system/mirror |
while read path action file; do
    echo "[INFO] Mirror changed: $path $file" >> ~/openclaw-system/logs/watch.log
    # 触发 OpenClaw 重新加载（需实现 hook）
done
```

---

参考：原始文章中关于 OpenClaw 工作区的讨论
