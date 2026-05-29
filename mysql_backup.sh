#!/bin/bash
#
# mysql_backup.sh - 全量备份 MySQL 数据库 nanmeihao 并上传至阿里云 OSS
#
# 用法: ./mysql_backup.sh
# 定时任务示例 (每天凌晨 3:00 执行):
#   0 3 * * * /root/mysqlAutoBackup/mysql_backup.sh >> /root/mysqlAutoBackup/backup.log 2>&1
#

set -euo pipefail

# ========== 配置 ==========
# 临时本地目录（备份生成后即上传至 OSS，本地文件会立即清理）
TEMP_DIR="/root/mysqlAutoBackup/backups"
OSS_BUCKET="oss://nannianghaowu-mysql-backup"
DB_NAME="potato_timer"
LOG_FILE="/root/mysqlAutoBackup/backup.log"
MYSQL_HOST="localhost"
MYSQL_USER="root"
MYSQL_PASSWORD="hh20061202"

# ========== 日志函数 ==========
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "${LOG_FILE}"
}

# ========== 主流程 ==========
log "========== 开始备份数据库: ${DB_NAME} =========="

mkdir -p "${TEMP_DIR}"

# 生成备份文件名
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
LOCAL_BACKUP="${TEMP_DIR}/${DB_NAME}_${TIMESTAMP}.sql.gz"

# 导出数据库
log "正在导出数据库到临时文件..."
mysqldump -h"${MYSQL_HOST}" -u"${MYSQL_USER}" -p"${MYSQL_PASSWORD}" \
    "${DB_NAME}" \
    | gzip -9 \
    > "${LOCAL_BACKUP}"

# 验证本地文件
if [[ ! -s "${LOCAL_BACKUP}" ]]; then
    log "错误: 备份文件为空，备份失败"
    exit 1
fi

SIZE=$(du -h "${LOCAL_BACKUP}" | cut -f1)
log "本地备份生成成功: ${LOCAL_BACKUP} (${SIZE})"

# 上传至 OSS
log "正在上传至 OSS: ${OSS_BUCKET}/"
if ossutil cp "${LOCAL_BACKUP}" "${OSS_BUCKET}/" --force; then
    log "OSS 上传成功: ${OSS_BUCKET}/${DB_NAME}_${TIMESTAMP}.sql.gz"
else
    log "错误: OSS 上传失败，请检查 ossutil 配置和网络连接"
    exit 1
fi

# 上传成功后立即删除本地临时文件
rm -f "${LOCAL_BACKUP}"
log "本地临时文件已清理"

log "========== 备份完成 =========="
