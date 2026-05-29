#!/bin/bash
#
# mysql_backup.sh - 全量备份 MySQL 数据库 nanmeihao
#
# 用法: ./mysql_backup.sh
# 定时任务示例 (每天凌晨 3:00 执行):
#   0 3 * * * /root/mysqlAutoBackup/mysql_backup.sh >> /root/mysqlAutoBackup/backup.log 2>&1
#

set -euo pipefail

# ========== 配置 ==========
BACKUP_DIR="/root/mysqlAutoBackup/backups"
DB_NAME="nanmeihao"
LOG_FILE="/root/mysqlAutoBackup/backup.log"
MYSQL_HOST="localhost"
MYSQL_USER="root"
MYSQL_PASSWORD="hh20061202"

# 保留天数 (超过此天数的备份会被清理)
RETENTION_DAYS=7

# ========== 日志函数 ==========
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

# ========== 主流程 ==========
log "========== 开始备份数据库: ${DB_NAME} =========="

# 检查备份目录
if [[ ! -d "${BACKUP_DIR}" ]]; then
    log "创建备份目录: ${BACKUP_DIR}"
    mkdir -p "${BACKUP_DIR}"
fi

# 生成备份文件名: nanmeihao_20260529_030000.sql.gz
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
BACKUP_FILE="${BACKUP_DIR}/${DB_NAME}_${TIMESTAMP}.sql.gz"

# 执行备份
log "正在导出数据库到: ${BACKUP_FILE}"
mysqldump -h"${MYSQL_HOST}" -u"${MYSQL_USER}" -p"${MYSQL_PASSWORD}" \
    "${DB_NAME}" \
    | gzip -9 \
    > "${BACKUP_FILE}"

# 验证备份文件
if [[ -s "${BACKUP_FILE}" ]]; then
    SIZE=$(du -h "${BACKUP_FILE}" | cut -f1)
    log "备份成功: ${BACKUP_FILE} (${SIZE})"
else
    log "错误: 备份文件为空，备份可能失败"
    exit 1
fi

# 清理过期备份
log "清理超过 ${RETENTION_DAYS} 天的旧备份..."
DELETED_COUNT=0
while IFS= read -r old_backup; do
    rm -f "${old_backup}"
    log "已删除旧备份: ${old_backup}"
    ((DELETED_COUNT++)) || true
done < <(find "${BACKUP_DIR}" -maxdepth 1 -name "${DB_NAME}_*.sql.gz" -type f -mtime +"${RETENTION_DAYS}")

if [[ "${DELETED_COUNT}" -eq 0 ]]; then
    log "无需清理旧备份"
else
    log "共清理 ${DELETED_COUNT} 个旧备份"
fi

log "========== 备份完成 =========="
