#!/bin/bash
set -e

# 加载共享库
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

# 加载配置
BASE="${OPENCLAW_SYSTEM_BASE:-$HOME/openclaw-system}"
PROPOSALS="${PROPOSALS_DIR:-$BASE/proposals}"
PUBLISHED="${PUBLISHED_DIR:-$BASE/published}"
REJECTED="${REJECTED_DIR:-$BASE/rejected}"
LOG="${PUBLISH_LOG:-$BASE/logs/publish.log}"
SYNC_SCRIPT="${SYNC_SCRIPT:-$BASE/scripts/sync.sh}"
COSCMD="${COSCMD:-$HOME/venvs/coscmd/bin/coscmd}"

# COS 路径
COS_INBOX_PATH="${COS_INBOX_PATH:-/obsidian_vault/06AI_workspace/00AI_Inbox/}"
COS_DRAFTS_PATH="${COS_DRAFTS_PATH:-/obsidian_vault/06AI_workspace/01AI_Drafts/}"

mkdir -p "$PUBLISHED" "$REJECTED" "$(dirname "$LOG")"

print_separator >> "$LOG"
log INFO "开始发布" >> "$LOG"

# 检查参数
if [ $# -eq 0 ]; then
    log ERR "未指定 proposal 文件名" >> "$LOG"
    echo "用法: $0 <file1.md> [file2.md ...]" >&2
    exit 1
fi

# 检查 coscmd
if [ ! -x "$COSCMD" ]; then
    log ERR "coscmd 不存在: $COSCMD" >> "$LOG"
    exit 1
fi

# 获取文件锁（防止并发发布）
LOCK_DIR="/tmp/obsidian-publish.lock"
lock_file "$LOCK_DIR" 30 || exit 1

# 处理每个文件
for name in "$@"; do
    SRC="$PROPOSALS/$name"

    if [ ! -f "$SRC" ]; then
        log WARN "文件不存在: $name" >> "$LOG"
        continue
    fi

    # 安全检查：确保不是 mirror 里的文件
    if ! assert_not_mirror "$SRC"; then
        log ERR "尝试从 mirror 发布（禁止操作）: $name" >> "$LOG"
        continue
    fi

    # 解析 target（支持 YAML frontmatter）
    if grep -q "target:[[:space:]]*AI Inbox" "$SRC"; then
        COS_DST="$COS_INBOX_PATH$name"
        TARGET_DIR="inbox"
    elif grep -q "target:[[:space:]]*AI Drafts" "$SRC"; then
        COS_DST="$COS_DRAFTS_PATH$name"
        TARGET_DIR="drafts"
    else
        log WARN "文件 $name 缺少有效的 target 字段，跳过" >> "$LOG"
        continue
    fi

    log INFO "发布 $name -> $COS_DST" >> "$LOG"

    # 上传到 COS
    if "$COSCMD" upload "$SRC" "$COS_DST" >> "$LOG" 2>&1; then
        # 成功后移动到 published
        mv "$SRC" "$PUBLISHED/$name"
        log INFO "发布成功: $name ($TARGET_DIR)" >> "$LOG"
    else
        # 失败保留原文件，并记录
        log ERR "上传失败: $name" >> "$LOG"
        continue
    fi
done

# 释放锁
unlock_file "$LOCK_DIR"

# 刷新 mirror（异步执行，不阻塞）
log INFO "触发 mirror 刷新..." >> "$LOG"
if [ -x "$SYNC_SCRIPT" ]; then
    bash "$SYNC_SCRIPT" >> "$LOG" 2>&1 || log WARN "mirror 刷新失败，请手动检查" >> "$LOG"
else
    log WARN "sync.sh 不存在，跳过刷新" >> "$LOG"
fi

log INFO "发布流程完成" >> "$LOG"
print_separator >> "$LOG"
