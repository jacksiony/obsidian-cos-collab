# 故障排查

## 问题 1: coscmd 报错 "externally-managed-environment"

**症状**：
```
error: externally-managed-environment
```

**原因**：系统 Python 开启了 PEP 668 保护，禁止全局 pip 安装。

**解决**：使用虚拟环境（setup.sh 已自动配置）。

```bash
# 正确调用方式（使用虚拟环境中的 coscmd）
~/venvs/coscmd/bin/coscmd --help

# 如果脚本中路径不对，修改为：
COSCMD="$HOME/venvs/coscmd/bin/coscmd"
```

## 问题 2: sync.sh 同步失败，日志显示权限错误

**症状**：
```
[WARN] 同步失败: Permission denied
```

**原因**：镜像目录权限不足或不可写。

**解决**：
```bash
# 检查 mirror 权限
ls -ld ~/openclaw-system/mirror

# 应为 drwxrwxr-x（用户可写），如果不是：
chmod u+rwx ~/openclaw-system/mirror
```

如果文件系统只读（如挂载问题），检查磁盘空间：
```bash
df -h ~/openclaw-system
```

## 问题 3: COS 上传后 Obsidian 未更新

**症状**：
publish.sh 显示发布成功，但手机/电脑没看到新文件。

**原因**：
- Obsidian 同步客户端未运行
- 同步路径配置错误
- COS 存储桶地域与客户端不匹配

**排查步骤**：
1. 登录 COS 控制台，确认文件已上传到正确路径
2. 检查电脑端同步工具的日志
3. 在手机端手动触发同步（下拉刷新）
4. 确认所有端使用相同的 COS 路径

## 问题 4: 发布时 "target 字段缺失"

**症状**：
```
[WARN] 文件 xxx.md 缺少有效的 target 字段，跳过
```

**原因**：proposals 文件的 frontmatter 中缺少 `target: AI Inbox` 或 `target: AI Drafts`。

**解决**：手动编辑文件，添加 frontmatter：

```yaml
---
target: AI Inbox
title: 我的笔记
created: 2026-04-07
---
```

## 问题 5: 虚拟环境创建失败（python3-venv 未安装）

**症状**：
```
python3: command not found
或
venv 模块不存在
```

**解决**：
```bash
apt update
apt install -y python3 python3-venv python3-pip
```

## 问题 6: COS 上传超时

**症状**：
```
[ERR] 上传失败: timeout
```

**解决**：
- 检查网络连接
- 大文件分片上传（coscmd 自动处理，但可调整 `--part-size`）
- 使用腾讯云内网地址（如果 OpenClaw 也在腾讯云）

```bash
# 测试网络
ping cos.ap-guangzhou.myqcloud.com

# 测试上传（小文件）
echo "test" > /tmp/test.txt
coscmd upload /tmp/test.txt /test-upload.txt
```

## 问题 7: 权限混淆——AI 试图修改 mirror

**症状**：OpenClaw 在 `mirror/` 中创建/删除文件。

**解决**：
1. 强化规则：在 AI_RULES.md 中加粗警告
2. 设置文件系统权限：
   ```bash
   chmod -R 555 ~/openclaw-system/mirror   # 只读
   ```
3. 如果 AI 仍尝试修改，需检查其 prompt 或上下文是否包含错误指令

## 问题 8: proposals 目录写满

**症状**：
```
No space left on device
```

**解决**：
- 清理已发布的 proposals：`published/` 可归档到压缩包
- 定期清理 `rejected/`
- 扩充磁盘空间
- 考虑将 proposals 移到更大磁盘并符号链接：
  ```bash
  mv ~/openclaw-system/proposals /data/proposals
  ln -s /data/proposals ~/openclaw-system/proposals
  ```

## 问题 9: 版本控制未开启导致无法回滚

**症状**：
文件误删后，COS 控制台看不到历史版本。

**解决**：
1. 在 COS 控制台开启版本控制（容错容灾管理）
2. 对于已删除的文件，在控制台「回收站」中查找
3. 未来无法回滚未开启版本控制的文件（只能从本地备份恢复）

## 问题 10: 时区不一致

**症状**：文件时间戳与实际时间差 8 小时。

**原因**：服务器时区不是 Asia/Shanghai。

**解决**：
```bash
# 检查时区
timedatectl

# 设置时区
timedatectl set-timezone Asia/Shanghai
```

脚本中的时间格式已使用 `date '+%F %T'`，依赖系统时区。

## 收集日志

如果问题无法解决，收集日志并寻求帮助：

```bash
# 打包日志
tar -czf ~/openclaw-system-logs.tar.gz \
  ~/openclaw-system/logs/ \
  ~/openclaw-system/scripts/*.sh

# 查看最新日志
tail -n 100 ~/openclaw-system/logs/sync.log
tail -n 100 ~/openclaw-system/logs/publish.log
```

## 需要更多帮助？

- 原始文章：https://mp.weixin.qq.com/s/Rs_ioKdbTbZcFuATM9Mmtw
- 腾讯云 COS 文档：https://cloud.tencent.com/document/product/436
- OpenClaw 社区：Discord #support
