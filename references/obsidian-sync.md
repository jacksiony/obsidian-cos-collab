# Obsidian + COS 多端同步配置

> 让你的 Obsidian Vault 在电脑、手机、云端之间自动同步。

## 推荐方案：官方移动端 + COS 同步工具

### 电脑端（macOS / Windows / Linux）

1. 安装 [官方 Obsidian](https://obsidian.md)
2. 创建或打开你的 Vault
3. 设置 → 第三方同步 → 选择**自定义同步服务**
4. 配置：
   - 同步目标：本地文件夹（如 `~/obsidian/`）
   - 此文件夹由 COS 同步工具管理

5. 安装 COS 同步工具：
   - **推荐**：腾讯云 [COSCLI](https://github.com/tencentyun/coscli)（两字节版，可视化）
   - **或**：coscmd（命令行）
   - **或**：rclone 配置 COS 远程

6. 将 COS 同步目录设置为 `~/obsidian/`（与 Obsidian  vault 路径一致）
7. 启动双向同步

### 手机端（iOS / Android）

1. 安装 [Obsidian 官方 App](https://obsidian.md/mobile)
2. 选择 **从文件夹打开** → 找到手机上的同步文件夹（如 `Documents/obsidian/`）
3. 或者使用 **iCloud / Dropbox** 同步，然后在手机端访问

**简化方案**（推荐）：
- 在电脑端使用 COS 同步
- 手机端使用 Obsidian **付费同步服务**（官方云）
- 中间通过 COS 作为单一数据源（电脑端同步工具将 Vault 上传到 COS，手机端通过 Obsidian 同步服务拉取 COS 中的文件）

> 注意：手机端无法直接安装 coscmd，需依赖 obsidian 官方同步或第三方云盘。

### 目录结构（最终）

```
电脑：
~/obsidian/                     # COS 本地挂载点（同步中）
├── 00_Inbox/
├── 01_Projects/
├── 02Resources/
├── 06AI_workspace/            # AI 工作区
│   ├── 00AI_Inbox/
│   ├── 01AI_Drafts/
│   └── 02System/
└── .obsidian/

手机：
/Documents/obsidian/            # 与电脑相同结构
```

## 关键配置：忽略文件

在 Obsidian 设置中，添加忽略规则，避免同步临时文件：

```
.git/
.DS_Store
Thumbs.db
*.tmp
*.log
obsidian.json  # 不同设备配置不同，建议单独管理
```

## 同步冲突处理

如果出现冲突文件（如 `filename (conflict copy).md`）：

1. **不要慌张**：COS 版本控制已开启，原文件可回滚
2. 手动合并两个版本
3. 删除冲突副本

预防措施：
- 避免同时编辑同一文件（电脑+手机）
- AI 发布前确保本地无未提交的修改
- 使用 `mirror/` 读、`proposals/` 写，避免冲突源头

## 验证同步

```bash
# 电脑端上传测试
echo "test" > ~/obsidian/06AI_workspace/00AI_Inbox/test-sync.md

# 等待 30 秒（COS 同步延迟）
# 手机端应能看到该文件

# 手机端编辑并保存
# 电脑端应自动同步更新
```

## FAQ

**Q: 可以用 iCloud 代替 COS 吗？**
A: 可以，但需要调整 publish.sh 中的 COS 上传命令。核心思想是：云存储作为单一数据源，所有端通过它同步。

**Q: 同步速度慢怎么办？**
A: 检查网络，或开启 COS 传输加速。也可以只同步 `06AI_workspace/` 子目录（已在 sync.sh 中实现）。

**Q: 手机端能看到 AI 发布的内容吗？**
A: 能。publish.sh 上传到 COS 后，所有端的同步工具会自动拉取。

**Q: 如何备份整个 Vault？**
A: COS 本身就是备份。开启版本控制后，所有历史都可追溯。

---

参考：原始文章《OpenClaw 在腾讯云，我的 Obsidian 在本地：我是怎么让它们安全协作的》
