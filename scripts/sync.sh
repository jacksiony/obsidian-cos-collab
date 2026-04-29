#!/bin/bash
set -e

# 加载共享库
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

# 加载配置（如有 .env）
load_env

# 配置默认值
BASE="${OPENCLAW_SYSTEM_BASE:-$HOME/openclaw-system}"
MIRROR="${MIRROR_DIR:-$BASE/mirror}"
LOG="${SYNC_LOG:-$BASE/logs/sync.log}"
COS_VAULT_PATH="${COS_VAULT_PATH:-/obsidian/}"
SYNC_PATHS="${SYNC_PATHS:-06AI_workspace/00AI_Inbox 06AI_workspace/01AI_Drafts 06AI_workspace/02System}"
COSCMD="${COSCMD:-$HOME/venvs/coscmd/bin/coscmd}"

mkdir -p "$MIRROR" "$(dirname "$LOG")"

print_separator >> "$LOG"
log INFO "开始同步" >> "$LOG"

# 检查 coscmd 是否存在
if [ ! -x "$COSCMD" ]; then
    log ERR "coscmd 不存在: $COSCMD" >> "$LOG"
    exit 1
fi

# 确保 mirror 可写（同步前临时开放权限）
chmod -R u+w "$MIRROR" 2>/dev/null || true

# 同步每个路径
for path in $SYNC_PATHS; do
    log INFO "同步路径: $path" >> "$LOG"
    "$COSCMD" download -r "$COS_VAULT_PATH$path" "$MIRROR/$path" >> "$LOG" 2>&1 || {
        log WARN "路径 $path 同步失败（可能不存在）" >> "$LOG"
    }
done

# 恢复只读权限
chmod -R 555 "$MIRROR" 2>/dev/null || true

log INFO "mirror 同步完成" >> "$LOG"
print_separator >> "$LOG"
