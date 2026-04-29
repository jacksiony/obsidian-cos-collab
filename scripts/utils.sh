#!/bin/bash
# 共享函数库

# 日志级别
LOG_LEVEL=${LOG_LEVEL:-INFO}  # DEBUG, INFO, WARN, ERR

# 颜色（可选）
COLOR_RED='\033[0;31m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[1;33m'
COLOR_RESET='\033[0m'

# 日志函数
log() {
    local level=$1
    shift
    local msg="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    case "$level" in
        DEBUG) [[ "$LOG_LEVEL" == "DEBUG" ]] && echo "[$timestamp] [$level] $msg" ;;
        INFO)  echo "[$timestamp] [$level] $msg" ;;
        WARN)  echo -e "${COLOR_YELLOW}[$timestamp] [$level] $msg${COLOR_RESET}" >&2 ;;
        ERR)   echo -e "${COLOR_RED}[$timestamp] [$level] $msg${COLOR_RESET}" >&2 ;;
    esac
}

# 检查命令是否存在
require_cmd() {
    if ! command -v "$1" &> /dev/null; then
        log ERR "命令未找到: $1"
        return 1
    fi
    return 0
}

# 加载 .env 配置（如果存在）
load_env() {
    local env_file="${1:-$(dirname "$(readlink -f "$0")")/../config/.env}"
    if [ -f "$env_file" ]; then
        log DEBUG "加载配置: $env_file"
        set -a
        source "$env_file"
        set +a
    fi
}

# 安全检查：防止在 mirror 目录写入
assert_not_mirror() {
    local path="$1"
    local mirror_dir="${MIRROR_DIR:-$HOME/openclaw-system/mirror}"
    if [[ "$path" == "$mirror_dir"* ]]; then
        log ERR "安全拦截：禁止在 mirror 目录写入"
        return 1
    fi
    return 0
}

# 文件锁（防止并发）
lock_file() {
    local lockfile="$1"
    local timeout=${2:-30}
    local start=$(date +%s)
    while ! mkdir "$lockfile" 2>/dev/null; do
        sleep 1
        if (( $(date +%s) - start > timeout )); then
            log ERR "锁定超时: $lockfile"
            return 1
        fi
    done
    echo $$ > "$lockfile/pid"
}

# 释放锁
unlock_file() {
    local lockfile="$1"
    rm -rf "$lockfile"
}

# 打印分隔线
print_separator() {
    echo "=========================================="
}

# 导出函数
export -f log require_cmd load_env assert_not_mirror lock_file unlock_file print_separator
