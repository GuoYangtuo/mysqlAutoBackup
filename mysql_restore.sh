#!/bin/bash
#
# mysql_restore.sh - 从阿里云 OSS 恢复 MySQL 数据库 nanmeihao
#
# 用法:
#   ./mysql_restore.sh                      # 恢复到最后一次备份
#   ./mysql_restore.sh <备份文件名>          # 恢复指定备份（如 nanmeihao_20260529_030000.sql.gz）
#   ./mysql_restore.sh --list               # 列出 OSS 上所有可用备份
#   ./mysql_restore.sh --help               # 显示帮助
#
# 注意: 恢复操作会覆盖当前数据库，请谨慎操作
#

set -euo pipefail

# ========== 配置 ==========
TEMP_DIR="/root/mysqlAutoBackup/backups"
OSS_BUCKET="oss://nannianghaowu-mysql-backup"
DB_NAME="potato_timer"
MYSQL_HOST="localhost"
MYSQL_USER="root"
MYSQL_PASSWORD="hh20061202"

# ========== 日志函数 ==========
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

# ========== 列出 OSS 上的备份 ==========
list_backups() {
    log "OSS 备份列表 (${OSS_BUCKET}):"
    local count=1
    while IFS= read -r obj; do
        local filename
        filename=$(basename "${obj}")
        local size
        size=$(echo "${obj}" | awk '{print $5}')
        local mtime
        mtime=$(echo "${obj}" | awk '{print $1, $2}')
        printf "  [%d] %s  %s  %s\n" "${count}" "${filename}" "${size:-?}" "${mtime:-?}"
        ((count++)) || true
    done < <(ossutil ls "${OSS_BUCKET}/" 2>/dev/null | awk '/\.sql\.gz/ {print $0}')
}

# ========== 获取 OSS 上最新的备份文件名 ==========
latest_backup_name() {
    ossutil ls "${OSS_BUCKET}/" 2>/dev/null \
        | awk '/\.sql\.gz/ {print $NF}' \
        | xargs -I{} basename {} \
        | sort -r \
        | head -1
}

# ========== 主流程 ==========

if [[ $# -eq 0 ]]; then
    log "未指定备份文件，将恢复到 OSS 上最后一个备份"
    BACKUP_NAME=$(latest_backup_name)
    if [[ -z "${BACKUP_NAME}" ]]; then
        log "错误: OSS 上未找到任何备份文件"
        exit 1
    fi
    log "选择备份: ${BACKUP_NAME}"
elif [[ "$1" == "--list" ]]; then
    list_backups
    exit 0
elif [[ "$1" == "--help" ]]; then
    echo "用法:"
    echo "  $0                      恢复到最后一次备份（从 OSS）"
    echo "  $0 <备份文件名>          恢复指定备份（从 OSS）"
    echo "  $0 --list               列出 OSS 上所有可用备份"
    echo "  $0 --help               显示帮助"
    exit 0
else
    BACKUP_NAME="$1"
fi

mkdir -p "${TEMP_DIR}"

# 下载备份
OSS_PATH="${OSS_BUCKET}/${BACKUP_NAME}"
LOCAL_FILE="${TEMP_DIR}/${BACKUP_NAME}"

log "正在从 OSS 下载: ${OSS_PATH}"
if ! ossutil cp "${OSS_PATH}" "${LOCAL_FILE}" --force 2>&1; then
    log "错误: 下载失败，备份文件可能不存在: ${OSS_PATH}"
    exit 1
fi

# 确认操作
if [[ -t 0 ]]; then
    echo ""
    echo "WARNING: 此操作将用以下备份覆盖数据库 '${DB_NAME}':"
    echo "  OSS:  ${OSS_PATH}"
    echo "  大小: $(du -h "${LOCAL_FILE}" | cut -f1)"
    echo ""
    read -rp "确认恢复? 输入 'yes' 继续: " confirm
    if [[ "${confirm}" != "yes" ]]; then
        log "已取消恢复操作"
        rm -f "${LOCAL_FILE}"
        exit 0
    fi
fi

log "========== 开始恢复数据库: ${DB_NAME} =========="
log "备份文件: ${LOCAL_FILE}"

# 执行恢复
log "正在恢复数据库，请稍候..."
zcat "${LOCAL_FILE}" \
    | mysql -h"${MYSQL_HOST}" -u"${MYSQL_USER}" -p"${MYSQL_PASSWORD}" "${DB_NAME}"

# 清理临时文件
rm -f "${LOCAL_FILE}"

log "========== 恢复完成 =========="
log "数据库 '${DB_NAME}' 已成功恢复到备份: ${BACKUP_NAME}"
