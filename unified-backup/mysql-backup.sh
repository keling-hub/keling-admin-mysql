#!/usr/bin/env sh
set -euo pipefail

log(){ printf '[%s] %s\n' "$(date '+%F %T')" "$*"; }

DB_HOST=${MYSQL_HOST:-keling-mysql}
DB_PORT=${MYSQL_PORT:-3306}
DB_NAME=${MYSQL_DATABASE:-kbk}
DB_USER=${MYSQL_USER:-root}
DB_PASS=${MYSQL_PASSWORD:-131415}
RETENTION_DAYS=${MAX_BACKUPS:-30}

# 输出目录（避免与只读 /backup 冲突）
MYSQL_BACKUP_DIR=${MYSQL_BACKUP_DIR:-/data/mysql}

# 确保目录存在并具有正确权限
if [ ! -d "$MYSQL_BACKUP_DIR" ]; then
    log "创建备份目录: $MYSQL_BACKUP_DIR"
    mkdir -p "$MYSQL_BACKUP_DIR" || {
        log "无法创建备份目录: $MYSQL_BACKUP_DIR"
        exit 1
    }
fi

# 检查目录权限
if [ ! -w "$MYSQL_BACKUP_DIR" ]; then
    log "备份目录不可写: $MYSQL_BACKUP_DIR"
    exit 1
fi

# 清理历史残留的临时文件（> 1 小时）
find "$MYSQL_BACKUP_DIR" -name "*.sql.tmp" -type f -mmin +60 -delete 2>/dev/null || true

DATE=$(date +"%Y-%m-%d")
HM=$(date +"%H%M")
FILE="${MYSQL_BACKUP_DIR}/${DATE}_${HM}.sql"
TMP_FILE="${FILE}.tmp"
# 无论成功或失败，退出时清理临时文件（避免残留 0KB）
cleanup_tmp() { [ -f "$TMP_FILE" ] && rm -f "$TMP_FILE" || true; }
trap cleanup_tmp EXIT

log "开始备份数据库: $DB_NAME -> $FILE"
if mysqldump -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASS" \
  --protocol=tcp \
  --single-transaction --routines --triggers --events --hex-blob \
  --default-character-set=utf8mb4 "$DB_NAME" > "$TMP_FILE" 2>>/var/log/mysql-backup.log; then
  mv -f "$TMP_FILE" "$FILE"
  log "数据库备份完成: $FILE (size: $(stat -c%s "$FILE" 2>/dev/null || wc -c < "$FILE"))"
else
  rm -f "$TMP_FILE" || true
  log "数据库备份失败，请检查连接配置与权限"
  exit 1
fi

# Docker卷清理策略：只保留当天的数据
log "开始清理Docker卷中的历史数据..."

# 清理所有非当天的备份文件
TODAY=$(date +"%Y-%m-%d")
for file in "$MYSQL_BACKUP_DIR"/*.sql; do
  if [ -f "$file" ]; then
    filename=$(basename "$file")
    # 提取文件名中的日期部分
    file_date=$(echo "$filename" | cut -d'_' -f1)
    if [ "$file_date" != "$TODAY" ]; then
      log "删除非当天备份: $filename"
      rm -f "$file" || true
    else
      log "保留当天备份: $filename"
    fi
  fi
done

# 备份完成后同步到E盘
log "开始同步到E盘..."
if [ -f "/app/sync-to-e-drive.sh" ]; then
    /app/sync-to-e-drive.sh >> /var/log/mysql-backup.log 2>&1
    log "E盘同步完成"
else
    log "E盘同步脚本不存在，跳过同步"
fi

# 00:00 时清理前一日 12:00 的备份（如果还在当天）
if [ "$HM" = "0000" ]; then
  YDAY=$(date -d yesterday +%Y-%m-%d 2>/dev/null || date -v-1d +%Y-%m-%d 2>/dev/null || echo "")
  if [ -n "$YDAY" ]; then
    NOON="${MYSQL_BACKUP_DIR}/${YDAY}_1200.sql"
    if [ -f "$NOON" ]; then
      log "清理昨日12:00备份: $NOON"; rm -f "$NOON" || true
    fi
  fi
fi

log "Docker卷清理完成，只保留当天数据"


