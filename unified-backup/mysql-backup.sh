#!/usr/bin/env sh
set -euo pipefail

log(){ printf '[%s] %s\n' "$(date '+%F %T')" "$*"; }

log "=========================================="
log "MySQL 数据库备份任务开始"
log "=========================================="

DB_HOST=${MYSQL_HOST:-keling-mysql}
DB_PORT=${MYSQL_PORT:-3306}
DB_NAME=${MYSQL_DATABASE:-kbk}
DB_USER=${MYSQL_USER:-root}
DB_PASS=${MYSQL_PASSWORD:-131415}
RETENTION_DAYS=${MAX_BACKUPS:-30}

log "备份配置信息:"
log "  数据库主机: $DB_HOST"
log "  数据库端口: $DB_PORT"
log "  数据库名称: $DB_NAME"
log "  数据库用户: $DB_USER"
log "  保留天数: $RETENTION_DAYS"

# 输出目录（避免与只读 /backup 冲突）
MYSQL_BACKUP_DIR=${MYSQL_BACKUP_DIR:-/data/mysql}

log "检查备份目录: $MYSQL_BACKUP_DIR"

# 确保目录存在并具有正确权限
if [ ! -d "$MYSQL_BACKUP_DIR" ]; then
    log "备份目录不存在，正在创建..."
    mkdir -p "$MYSQL_BACKUP_DIR" || {
        log "❌ 错误: 无法创建备份目录: $MYSQL_BACKUP_DIR"
        exit 1
    }
    log "✅ 备份目录创建成功"
else
    log "✅ 备份目录已存在"
fi

# 检查目录权限
if [ ! -w "$MYSQL_BACKUP_DIR" ]; then
    log "❌ 错误: 备份目录不可写: $MYSQL_BACKUP_DIR"
    log "请检查目录权限"
    exit 1
fi
log "✅ 备份目录权限检查通过"

# 清理历史残留的临时文件（> 1 小时）
log "清理历史残留的临时文件..."
temp_count=$(find "$MYSQL_BACKUP_DIR" -name "*.sql.tmp" -type f -mmin +60 2>/dev/null | wc -l || echo "0")
if [ "$temp_count" -gt 0 ]; then
    log "发现 $temp_count 个超过1小时的临时文件，正在清理..."
find "$MYSQL_BACKUP_DIR" -name "*.sql.tmp" -type f -mmin +60 -delete 2>/dev/null || true
    log "✅ 临时文件清理完成"
else
    log "✅ 没有需要清理的临时文件"
fi

DATE=$(date +"%Y-%m-%d")
HM=$(date +"%H%M")
FILE="${MYSQL_BACKUP_DIR}/${DATE}_${HM}.sql"
TMP_FILE="${FILE}.tmp"

log "备份文件信息:"
log "  备份日期: $DATE"
log "  备份时间: $HM"
log "  备份文件: $FILE"
log "  临时文件: $TMP_FILE"

# 无论成功或失败，退出时清理临时文件（避免残留 0KB）
cleanup_tmp() { 
    if [ -f "$TMP_FILE" ]; then
        log "清理临时文件: $TMP_FILE"
        rm -f "$TMP_FILE" || true
    fi
}
trap cleanup_tmp EXIT

# 测试数据库连接
log "测试数据库连接..."
if mysql -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASS" -e "SELECT 1" >/dev/null 2>&1; then
    log "✅ 数据库连接测试成功"
else
    log "❌ 错误: 数据库连接测试失败"
    log "请检查:"
    log "  1. 数据库服务是否运行"
    log "  2. 连接参数是否正确"
    log "  3. 用户权限是否足够"
    exit 1
fi

# 获取数据库信息
log "获取数据库信息..."
DB_SIZE=$(mysql -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASS" -e "SELECT ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS 'DB Size in MB' FROM information_schema.tables WHERE table_schema='$DB_NAME';" -s -N 2>/dev/null || echo "未知")
TABLE_COUNT=$(mysql -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASS" -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='$DB_NAME';" -s -N 2>/dev/null || echo "未知")

log "数据库统计信息:"
log "  数据库大小: ${DB_SIZE} MB"
log "  数据表数量: $TABLE_COUNT"

# 开始备份
log "=========================================="
log "开始执行数据库备份..."
log "=========================================="
log "执行 mysqldump 命令..."
log "  包含: 事务、存储过程、触发器、事件、二进制数据"

BACKUP_START_TIME=$(date +%s)
if mysqldump -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASS" \
  --protocol=tcp \
  --single-transaction --routines --triggers --events --hex-blob \
  --default-character-set=utf8mb4 "$DB_NAME" > "$TMP_FILE" 2>>/var/log/mysql-backup.log; then
  BACKUP_END_TIME=$(date +%s)
  BACKUP_DURATION=$((BACKUP_END_TIME - BACKUP_START_TIME))
  
  # 检查临时文件大小
  if [ -f "$TMP_FILE" ] && [ -s "$TMP_FILE" ]; then
    TMP_SIZE=$(stat -c%s "$TMP_FILE" 2>/dev/null || wc -c < "$TMP_FILE")
    log "✅ 数据库备份转储完成"
    log "  临时文件大小: $TMP_SIZE 字节 ($(numfmt --to=iec-i --suffix=B $TMP_SIZE 2>/dev/null || echo "未知"))"
    log "  备份耗时: ${BACKUP_DURATION} 秒"
    
    # 移动临时文件到正式文件
    log "将临时文件移动到正式备份文件..."
    if mv -f "$TMP_FILE" "$FILE"; then
        FILE_SIZE=$(stat -c%s "$FILE" 2>/dev/null || wc -c < "$FILE")
        log "✅ 数据库备份完成"
        log "  备份文件: $FILE"
        log "  文件大小: $FILE_SIZE 字节 ($(numfmt --to=iec-i --suffix=B $FILE_SIZE 2>/dev/null || echo "未知"))"
        log "  备份耗时: ${BACKUP_DURATION} 秒"
else
        log "❌ 错误: 移动临时文件失败"
        exit 1
    fi
  else
    log "❌ 错误: 备份文件为空或不存在"
    rm -f "$TMP_FILE" || true
    exit 1
  fi
else
  log "❌ 错误: 数据库备份失败"
  log "请检查:"
  log "  1. 数据库连接是否正常"
  log "  2. 用户权限是否足够执行 mysqldump"
  log "  3. 查看详细错误日志: /var/log/mysql-backup.log"
  rm -f "$TMP_FILE" || true
  exit 1
fi

# Docker卷清理策略：只保留当天的数据
log "=========================================="
log "开始清理Docker卷中的历史数据..."
log "=========================================="
log "清理策略: 只保留当天的备份文件"

# 统计当前备份文件
TODAY=$(date +"%Y-%m-%d")
TOTAL_FILES=0
KEPT_FILES=0
DELETED_FILES=0

log "当前日期: $TODAY"
log "扫描备份目录: $MYSQL_BACKUP_DIR"

# 清理所有非当天的备份文件
for file in "$MYSQL_BACKUP_DIR"/*.sql; do
  if [ -f "$file" ]; then
    TOTAL_FILES=$((TOTAL_FILES + 1))
    filename=$(basename "$file")
    # 提取文件名中的日期部分
    file_date=$(echo "$filename" | cut -d'_' -f1)
    file_size=$(stat -c%s "$file" 2>/dev/null || wc -c < "$file")
    
    if [ "$file_date" != "$TODAY" ]; then
      log "  🗑️  删除非当天备份: $filename (大小: $file_size 字节)"
      rm -f "$file" || true
      DELETED_FILES=$((DELETED_FILES + 1))
    else
      log "  ✅ 保留当天备份: $filename (大小: $file_size 字节)"
      KEPT_FILES=$((KEPT_FILES + 1))
    fi
  fi
done

log "Docker卷清理统计:"
log "  总文件数: $TOTAL_FILES"
log "  保留文件: $KEPT_FILES"
log "  删除文件: $DELETED_FILES"

# 00:00 时清理前一日 12:00 的备份（如果还在当天）
if [ "$HM" = "0000" ]; then
  log "检测到00:00备份时间，清理前一日12:00备份..."
  YDAY=$(date -d yesterday +%Y-%m-%d 2>/dev/null || date -v-1d +%Y-%m-%d 2>/dev/null || echo "")
  if [ -n "$YDAY" ]; then
    NOON="${MYSQL_BACKUP_DIR}/${YDAY}_1200.sql"
    if [ -f "$NOON" ]; then
      NOON_SIZE=$(stat -c%s "$NOON" 2>/dev/null || wc -c < "$NOON")
      log "  🗑️  清理昨日12:00备份: $(basename "$NOON") (大小: $NOON_SIZE 字节)"
      rm -f "$NOON" || true
    else
      log "  ✅ 昨日12:00备份不存在，无需清理"
    fi
  fi
fi

log "✅ Docker卷清理完成，只保留当天数据"

# 备份完成后同步到E盘
log "=========================================="
log "开始同步到E盘..."
log "=========================================="
if [ -f "/app/sync-to-e-drive.sh" ]; then
    log "执行E盘同步脚本..."
    /app/sync-to-e-drive.sh >> /var/log/mysql-backup.log 2>&1
    if [ $? -eq 0 ]; then
        log "✅ E盘同步完成"
    else
        log "⚠️  警告: E盘同步可能存在问题，请检查日志"
    fi
else
    log "⚠️  警告: E盘同步脚本不存在，跳过同步"
    log "脚本路径: /app/sync-to-e-drive.sh"
fi

log "=========================================="
log "MySQL 数据库备份任务完成"
log "=========================================="


