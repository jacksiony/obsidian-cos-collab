# 使用指南

## 目标读者

- 已经在使用 Obsidian 管理知识
- 使用腾讯云 COS 做多端同步
- 希望在 Obsidian 中集成 OpenClaw AI 辅助
- 重视数据安全和可控性

## 快速路径

1. **环境准备**：确保 COS 存储桶、Obsidian Vault、服务器就绪
2. **运行 setup.sh**：自动创建目录、安装依赖、配置 COS
3. **配置 OpenClaw**：复制 AI_RULES.md，约定工作流
4. **测试同步**：`sync.sh` 能否正常拉取文件
5. **测试发布**：手动创建 proposals 文件，执行 `publish.sh`
6. **日常使用**：AI 读 mirror，写 proposals；人工确认后发布

## 详细步骤

### 第 1 步：前置检查

- [ ] 腾讯云账号，已创建 COS 存储桶
- [ ] 存储桶已开启版本控制
- [ ] Obsidian Vault 路径已知（如 `~/obsidian/`）
- [ ] Vault 中已创建 `06AI_workspace/` 三级目录（Inbox/Drafts/System）
- [ ] 服务器已安装 OpenClaw
- [ ] 服务器有 Python3 和 apt 权限

### 第 2 步：运行初始化脚本

```bash
cd ~/.openclaw/workspace/skills/obsidian-cos-collab
bash scripts/setup.sh
```

按照提示输入 COS SecretId、SecretKey、Bucket、Region。

脚本会：
- 创建 `~/openclaw-system/` 及其子目录
- 创建 Python 虚拟环境并安装 coscmd
- 配置 `~/.coscmd/config`
- 生成 `sync.sh` 和 `publish.sh`（已内嵌默认路径）
- 复制 AI_RULES.md 到 workspace（如果存在）

### 第 3 步：调整路径（如需）

默认 COS 路径为 `/obsidian_vault/06AI_workspace/...`，如果你的 Vault 实际路径不同，需要修改：

- `scripts/sync.sh` 中的 `COS_VAULT_PATH`
- `scripts/publish.sh` 中的 `COS_INBOX_PATH` 和 `COS_DRAFTS_PATH`
- 或者设置环境变量覆盖默认值

建议：修改脚本中的变量，而非复制整个脚本。

### 第 4 步：配置 OpenClaw AI 规则

将 `config/rules/AI_RULES.md` 内容放入 OpenClaw 的 workspace：

```bash
# 如果你使用默认 workspace
cp config/rules/AI_RULES.md ~/.openclaw/workspace/AI_RULES.md
```

或者在每次对话开始时，手动告诉 OpenClaw 规则（不推荐）。

### 第 5 步：首次同步

```bash
# 测试 mirror 同步
bash ~/openclaw-system/scripts/sync.sh

# 检查是否拉下文件
ls ~/openclaw-system/mirror/06AI_workspace/
```

如果为空，可能 COS 路径配置错误或该目录下确实无文件（正常）。

### 第 6 步：测试发布流程

1. **创建一个草稿**：
   ```bash
   cat > ~/openclaw-system/proposals/test-发布流程.md << 'EOF'
   ---
   target: AI Inbox
   title: 测试发布流程
   created: 2026-04-07T22:30:00+08:00
   ---

   # 测试发布流程

   这是一条测试消息，用于验证整个发布链路是否正常。
   EOF
   ```

2. **执行发布**：
   ```bash
   bash ~/openclaw-system/scripts/publish.sh test-发布流程.md
   ```

3. **验证**：
   - COS 控制台应看到新文件出现在 `06AI_workspace/00AI_Inbox/`
   - 手机/电脑 Obsidian 同步后应能看到该文件
   - `~/openclaw-system/published/` 应包含该文件
   - `~/openclaw-system/logs/publish.log` 应有记录

### 第 7 步：日常使用

#### AI 读知识

当用户提问涉及已有笔记时，OpenClaw 自动从 `mirror/` 读取：

```
用户：我之前写过一篇关于神经网络优化的笔记，帮我总结一下
OpenClaw：→ 读取 ~/openclaw-system/mirror/06AI_workspace/01AI_Drafts/20260401-神经网络优化.md
        → 生成摘要，直接回复
```

#### AI 写草稿

当用户要求生成新内容时：

```
用户：帮我写一篇《Obsidian 插件开发入门》
OpenClaw：→ 生成 markdown 内容，带 frontmatter
        → 保存为 ~/openclaw-system/proposals/20260407-2235-Obsidian插件开发入门.md
        → 告知用户已生成草稿，待审核发布
```

#### 人工审核发布

```bash
# 查看待发布文件
ls ~/openclaw-system/proposals/

# 审查内容（可选）
cat ~/openclaw-system/proposals/20260407-2235-Obsidian插件开发入门.md

# 确认无误后发布
bash ~/openclaw-system/scripts/publish.sh 20260407-2235-Obsidian插件开发入门.md

# 批量发布
bash ~/openclaw-system/scripts/publish.sh *.md
```

## 最佳实践

1. **文件名带时间戳**：避免冲突，便于排序
2. **target 准确填写**：Inbox 还是 Drafts 决定上传路径
3. **勤 sync**：发布后 mirror 自动刷新，但平时也可手动 `sync.sh` 获取最新内容
4. **用 logs 审计**：`logs/` 目录保留所有操作记录
5. ** proposals 不清理**：published/ 和 rejected/ 用于归档，不要删除
6. **COCS 版本控制必开**：最后一道防线

## 进阶用法

### 让 OpenClaw 自动识别 proposals

在 AI_RULES.md 中添加：

> 当用户说「发布」「确认入库」「ok 发布」时，自动执行 `publish.sh` 带上刚才生成的文件名。

（需 OpenClaw 支持命令执行权限）

### 添加 Feishu 通知

在 `publish.sh` 末尾添加：

```bash
curl -X POST "$FEISHU_WEBHOOK" \
  -H "Content-Type: application/json" \
  -d "{\"msg_type\":\"text\",\"content\":{\"text\":\"已发布: $name\"}}"
```

### proposals 加入 git

```bash
cd ~/openclaw-system
git init
git add proposals/
# 每次发布前自动 commit，记录修改历史
```

---

更多详情见 `docs/troubleshooting.md`。
