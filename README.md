# 备份（每天凌晨 3:00 自动执行，已配置好）
./mysql_backup.sh
# 恢复到最后一次备份
./mysql_restore.sh
# 恢复指定备份
./mysql_restore.sh nanmeihao_20260529_184257.sql.gz
# 列出 OSS 上所有备份
./mysql_restore.sh --list
# 帮助
./mysql_restore.sh --help
# OSSUtil工具位置
/usr/local/bin