#!/bin/bash
set -e

echo "======================================"
echo " Obsidian + COS + OpenClaw 初始化向导"
echo "======================================"
echo ""

# 1. 创建基础目录结构
BASE="${OPENCLAW_SYSTEM_BASE:-$HOME/openclaw-system}"
echo "[1] 创建目录结构: $BASE"
mkdir -p "$BASE"/{workspace,mirror,proposals,published,rejected,logs,scripts}
echo "    ✓ 目录创建完成"
echo ""

# 2. 安装 Python 虚拟环境
echo "[2] 检查并创建虚拟环境"
if [ ! -d "$HOME/venvs/coscmd" ]; then
    echo "    - 安装 python3-venv..."
    apt update && apt install -y python3-venv > /dev/null 2>&1 || true
    echo "    - 创建虚拟环境..."
    python3 -m venv "$HOME/venvs/coscmd"
    source "$HOME/venvs/coscmd/bin/activate"
    pip install -U pip > /dev/null 2>&1
    pip install coscmd > /dev/null 2>&1
    echo "    ✓ coscmd 已安装到虚拟环境"
else
    echo "    ✓ 虚拟环境已存在: $HOME/venvs/coscmd"
fi
echo ""

# 3. 询问 COS 配置
echo "[3] 配置腾讯云 COS 参数"
echo "    请到腾讯云控制台获取这些信息："
echo "    - SecretId (AKID...)"
echo "    - SecretKey"
echo "    - 存储桶名称 (bucket-1250000000)"
echo "    - 地域 (ap-guangzhou, ap-beijing等)"
echo ""

read -p "SecretId: " COS_SECRET_ID
read -p "SecretKey: " COS_SECRET_KEY
read -p "Bucket (bucket-1250000000): " COS_BUCKET
read -p "Region (ap-guangzhou): " COS_REGION
echo ""

# 4. 生成脚本配置
echo "[4] 写入脚本配置文件"
cat > "$BASE/scripts/sync.sh" << 'SYNC_EOF'
#!/bin/bash
set -e

BASE="$HOME/openclaw-system"
MIRROR="$BASE/mirror"
LOG="$BASE/logs/sync.log"
COSCMD="$HOME/venvs/coscmd/bin/coscmd"
COS_VAULT_PATH="/obsidian/"
SYNC_PATHS="06AI_workspace/00AI_Inbox 06AI_workspace/01AI_Drafts 06AI_workspace/02System"

mkdir -p "$MIRROR" "$(dirname "$LOG")"
echo "==== $(date '+%F %T') 开始同步 ====" >> "$LOG"
chmod -R u+w "$MIRROR" 2>/dev/null || true

for path in $SYNC_PATHS; do
    echo "[INFO] 同步: $path" >> "$LOG"
    "$COSCMD" download -r "$COS_VAULT_PATH$path" "$MIRROR/$path" >> "$LOG" 2>&1 || {
        echo "[WARN] $path 同步失败（可能目录不存在）" >> "$LOG"
    }
done

chmod -R 555 "$MIRROR" 2>/dev/null || true
echo "[OK] 同步完成" >> "$LOG"
SYNC_EOF

cat > "$BASE/scripts/publish.sh" << 'PUBLISH_EOF'
#!/bin/bash
set -e

BASE="$HOME/openclaw-system"
PROPOSALS="$BASE/proposals"
PUBLISHED="$BASE/published"
REJECTED="$BASE/rejected"
LOG="$BASE/logs/publish.log"
SYNC="$BASE/scripts/sync.sh"
COSCMD="$HOME/venvs/coscmd/bin/coscmd"

COS_INBOX_PATH="/obsidian_vault/06AI_workspace/00AI_Inbox/"
COS_DRAFTS_PATH="/obsidian_vault/06AI_workspace/01AI_Drafts/"

mkdir -p "$PUBLISHED" "$REJECTED" "$(dirname "$LOG")"
echo "==== $(date '+%F %T') 开始发布 ====" >> "$LOG"

if [ $# -eq 0 ]; then
    echo "[ERR] 未指定文件名" | tee -a "$LOG"
    exit 1
fi

for name in "$@"; do
    SRC="$PROPOSALS/$name"
    [ -f "$SRC" ] || { echo "[WARN] 不存在: $name" >> "$LOG"; continue; }

    if grep -q "target: AI Inbox" "$SRC"; then
        DST="$COS_INBOX_PATH$name"
    elif grep -q "target: AI Drafts" "$SRC"; then
        DST="$COS_DRAFTS_PATH$name"
    else
        echo "[WARN] 缺少 target 字段: $name" >> "$LOG"
        continue
    fi

    "$COSCMD" upload "$SRC" "$DST" >> "$LOG" 2>&1 && {
        mv "$SRC" "$PUBLISHED/"
        echo "[OK] 发布: $name" >> "$LOG"
    } || {
        echo "[ERR] 上传失败: $name" >> "$LOG"
    }
done

bash "$SYNC" >> "$LOG" 2>&1 || echo "[WARN] 镜像刷新失败" >> "$LOG"
echo "[OK] 完成" >> "$LOG"
PUBLISH_EOF
chmod +x "$BASE/scripts/sync.sh" "$BASE/scripts/publish.sh"

echo "    ✓ 脚本已生成"
echo ""

# 5. 配置 coscmd
echo "[5] 配置 coscmd"
mkdir -p "$HOME/.coscmd"
cat > "$HOME/.coscmd/config" << CONFIG_EOF
[cos]
secret_id = $COS_SECRET_ID
secret_key = $COS_SECRET_KEY
bucket = $COS_BUCKET
region = $COS_REGION
CONFIG_EOF
echo "    ✓ coscmd 配置写入 $HOME/.coscmd/config"
echo ""

# 6. 验证配置
echo "[6] 验证配置"
if "$HOME/venvs/coscmd/bin/coscmd" list > /dev/null 2>&1; then
    echo "    ✓ coscmd 可以连接 COS"
else
    echo "    ⚠ coscmd 连接测试失败，请手动检查 SecretId/SecretKey"
fi
echo ""

# 7. 复制规则文件
echo "[7] 复制规则模板"
cp -f "$(dirname "$0")/config/rules/AI_RULES.md" "$BASE/workspace/AI_RULES.md" 2>/dev/null || true
echo "    ✓ AI_RULES.md 已复制（如有）"
echo ""

# 8. 完成
echo "======================================"
echo " 初始化完成！"
echo "======================================"
echo ""
echo "下一步："
echo "1. 确保 COS 存储桶已开启版本控制"
echo "2. 在 Obsidian Vault 创建 06AI_workspace/ 目录结构"
echo "3. 复制 AI_RULES.md 到你的 Vault/02System/"
echo "4. 测试同步：bash $BASE/scripts/sync.sh"
echo "5. 在 OpenClaw 中配置规则（读 mirror/，写 proposals/）"
echo ""
echo "祝搭建顺利！有任何问题查看 docs/troubleshooting.md"
echo ""
