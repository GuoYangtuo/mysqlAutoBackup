#!/bin/bash
#
# mysql_restore.sh - 恢复 MySQL 数据库 nanmeihao
#
# 用法:
#   ./mysql_restore.sh                      # 恢复到最后一次备份
#   ./mysql_restore.sh <备份文件路径>        # 恢复指定备份
#
# 注意: 恢复操作会覆盖当前数据库，请谨慎操作
#

set -euo pipefail

# ========== 配置 ==========
BACKUP_DIR="/root/mysqlAutoBackup/backups"
DB_NAME="nanmeihao"
MYSQL_HOST="localhost"
MYSQL_USER="root"
MYSQL_PASSWORD="hh20061202"

# ========== 日志函数 ==========
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

# ========== 列出所有备份 ==========
list_backups() {
    log "可用备份列表:"
    local count=1
    while IFS= read -r f; do
        local size
        size=$(du -h "${f}" | cut -f1)
        local mtime
        mtime=$(stat -c '%y' "${f}" | cut -d'.' -f1)
        echo "  [$count] $(basename "${f}")  ${size}  ${mtime}"
        ((count++)) || true
    done < <(find "${BACKUP_DIR}" -maxdepth 1 -name "${DB_NAME}_*.sql.gz" -type f | sort -r)
}

# ========== 获取最后一个备份 ==========
latest_backup() {
    find "${BACKUP_DIR}" -maxdepth 1 -name "${DB_NAME}_*.sql.gz" -type f -print0 \
        | xargs -0 ls -t 2>/dev/null \
        | head -1
}

# ========== 主流程 ==========

# 检查参数
if [[ $# -eq 0 ]]; then
    # 不指定备份文件，默认使用最后一个
    log "未指定备份文件，将恢复到最后一个备份"
    BACKUP_FILE=$(latest_backup)
    if [[ -z "${BACKUP_FILE}" ]]; then
        log "错误: 未找到任何备份文件，请先执行 mysql_backup.sh 进行备份"
        exit 1
    fi
    log "选择备份文件: $(basename "${BACKUP_FILE}")"
elif [[ $# -eq 1 && "$1" == "--list" ]]; then
    # 仅列出备份
    list_backups
    exit 0
elif [[ $# -eq 1 && "$1" == "--help" ]]; then
    echo "用法:"
    echo "  $0                      恢复到最后一次备份"
    echo "  $0 <备份文件路径>        恢复指定备份"
    echo "  $0 --list               列出所有可用备份"
    echo "  $0 --help               显示帮助信息"
    exit 0
else
    # 指定了备份文件
    BACKUP_FILE="$1"
    if [[ ! -f "${BACKUP_FILE}" ]]; then
        log "错误: 备份文件不存在: ${BACKUP_FILE}"
        exit 1
    fi
fi

# 确认操作 (非交互式环境下跳过)
if [[ -t 0 ]]; then
    echo ""
    echo "WARNING: 此操作将用以下备份覆盖数据库 '${DB_NAME}':"
    echo "  文件: $(basename "${BACKUP_FILE}")"
    echo "  大小: $(du -h "${BACKUP_FILE}" | cut -f1)"
    echo ""
    read -rp "确认恢复? 输入 'yes' 继续: " confirm
    if [[ "${confirm}" != "yes" ]]; then
        log "已取消恢复操作"
        exit 0
    fi
fi

log "========== 开始恢复数据库: ${DB_NAME} =========="
log "备份文件: ${BACKUP_FILE}"

# 执行恢复
log "正在恢复数据库，请稍候..."
zcat "${BACKUP_FILE}" \
    | mysql -h"${MYSQL_HOST}" -u"${MYSQL_USER}" -p"${MYSQL_PASSWORD}" "${DB_NAME}"

log "========== 恢复完成 =========="
log "数据库 '${DB_NAME}' 已成功恢复到备份: $(basename "${BACKUP_FILE}")"
