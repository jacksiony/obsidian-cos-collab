# AI 操作规则（OpenClaw 必读）

> 本文档定义了 OpenClaw 在与 Obsidian 知识库协作时必须遵守的规则。

## 核心原则

- **只读 mirror**：不要修改、删除 `~/openclaw-system/mirror/` 中的任何文件。这是只读快照。
- **只写 proposals**：所有新内容、修改建议都必须写入 `~/openclaw-system/proposals/`。
- **人工 gate**：只有经过用户审核并手动执行 `publish.sh` 的内容才会进入正式知识库。
- **自动刷新**：publish 成功后 mirror 会自动刷新，无需手动干预。

## 输入：如何读知识

✅ **正确做法**：
```markdown
用户：帮我总结一下关于 XXX 的内容
OpenClaw：读取 ~/openclaw-system/mirror/06AI_workspace/01AI_Drafts/XXX.md
（分析并总结）
```

❌ **错误做法**：
- 直接打开 Vault 原始目录（如 `~/obsidian/`）读取
- 尝试修改 `mirror/` 中的文件
- 扫描整个 Vault（只读 AI 工作区相关目录）

## 输出：如何写草稿

所有输出必须保存为 Markdown 文件到 `~/openclaw-system/proposals/`，并且必须包含 frontmatter 元数据。

### 文件命名

使用时间戳前缀，避免冲突：
- 新内容：`%(Y%m%d-%H%M%S)-标题.md`
- 修改建议：在原文件名前加 `rev-` 和时间戳

示例：
```
20260407-2230-会议总结.md
rev-20260407-2230-项目计划.md
```

### Frontmatter 格式

必须至少包含以下字段：

```yaml
---
target: AI Inbox      # 或 AI Drafts
title: 笔记标题
created: 2026-04-07T22:30:00+08:00
---
```

**target 含义**：
- `AI Inbox`：全新生成的内容，放入 `00AI_Inbox/`
- `AI Drafts`：对已有内容的修改建议，放入 `01AI_Drafts/`

### 内容格式

- 使用 Markdown 标准语法
- 不要包含 HTML 或其他格式
- 图片附件需另传（暂不支持自动上传）
- 代码块用 triple backticks

示例完整文件：

```markdown
---
target: AI Inbox
title: 如何用 AI 辅助阅读论文
created: 2026-04-07T22:35:00+08:00
---

# 如何用 AI 辅助阅读论文

这篇笔记总结了使用 AI 快速提取论文核心内容的三种方法：

1. **摘要提取**：让 AI 读 PDF → 给出 200 字摘要
2. **关键概念**：提取论文中的术语解释
3. **相关论文**：根据摘要搜索类似研究

## 推荐工具

- Claude 3.5 Sonnet（长上下文）
- Perplexity（实时搜索）
- Zotero + GPT
```

## 禁止行为

❌ 以下行为会破坏系统安全：

- `rm`、`mv`、`cp` 操作 `mirror/` 中的任何文件
- 直接写入 `~/obsidian/` 或 COS 路径
- 跳过 proposals 直接发布
- 修改其他用户的文件（多用户场景）
- 尝试批量发布未经审核的内容
- 修改 `publish.sh` 逻辑绕过 target 检查

## 工作流示例

**场景**：用户要求写一篇新笔记《AI 学习路径》

1. OpenClaw 从 `mirror/` 读取相关参考内容（如《机器学习入门》）
2. 生成新内容，保存为 `~/openclaw-system/proposals/20260407-2235-AI学习路径.md`
3. frontmatter 中 `target: AI Inbox`
4. 通知用户审查
5. 用户执行：`bash ~/openclaw-system/scripts/publish.sh 20260407-2235-AI学习路径.md`
6. publish.sh 上传到 COS → 触发 sync.sh → mirror 刷新 → 本地 Obsidian 同步更新

## 审计与日志

- 所有 `publish.sh` 操作记录在 `~/openclaw-system/logs/publish.log`
- 所有 `sync.sh` 操作记录在 `~/openclaw-system/logs/sync.log`
- 已发布文件归档在 `~/openclaw-system/published/`
- 删除的文件（手动 reject）应移动到 `~/openclaw-system/rejected/`

## 故障应对

| 症状 | 应采取的 AI 行为 |
|------|------------------|
| `mirror/` 不存在 | 提示用户运行 `setup.sh` 或 `sync.sh` |
| proposals 目录不可写 | 检查权限：`chmod u+w ~/openclaw-system/proposals` |
| 用户要求直接修改文件 | 拒绝并解释安全原则，建议走 proposals → publish 流程 |
| COS 同步延迟 | 告知用户镜像刷新可能延迟，建议 5 分钟后查看 |
| 版本控制未开启 | 提醒用户在 COS 控制台开启版本管理 |

## 升级与自定义

此规则文件可随版本迭代。升级时：
1. 备份现有 `AI_RULES.md`
2. 替换为新版本
3. 通知用户查阅变更

自定义扩展：
- 添加白名单路径：`ALLOWED_READ_PATHS=mirror/06AI_workspace`
- 限制输出格式：`REQUIRE_FRONTMATTER=true`
- 添加水印：`ADD_WATERMARK=true`

---

**记住**：你是辅助者，不是管理员。保持边界，让人类掌控最终决策。
