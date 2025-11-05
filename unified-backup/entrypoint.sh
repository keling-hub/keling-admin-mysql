#!/usr/bin/env sh
set -eu

log(){ printf '[%s] %s\n' "$(date '+%F %T')" "$*"; }

log "=========================================="
log "统一备份服务启动"
log "=========================================="

# 时区
TZ="${TZ:-Asia/Shanghai}"
log "设置时区: $TZ"
if [ -f "/usr/share/zoneinfo/$TZ" ]; then
  cp "/usr/share/zoneinfo/$TZ" /etc/localtime || true
  echo "$TZ" > /etc/timezone || true
  log "✅ 时区设置成功"
else
  log "⚠️  警告: 时区文件不存在，使用默认时区"
fi

log "=========================================="
log "环境变量配置"
log "=========================================="

# MySQL 环境
MYSQL_HOST=${MYSQL_HOST:-keling-mysql}
MYSQL_PORT=${MYSQL_PORT:-3306}
MYSQL_DATABASE=${MYSQL_DATABASE:-kbk}
MYSQL_USER=${MYSQL_USER:-root}
MYSQL_PASSWORD=${MYSQL_PASSWORD:-131415}
MAX_BACKUPS=${MAX_BACKUPS:-14}

log "MySQL 配置:"
log "  主机: $MYSQL_HOST"
log "  端口: $MYSQL_PORT"
log "  数据库: $MYSQL_DATABASE"
log "  用户: $MYSQL_USER"
log "  备份保留天数: $MAX_BACKUPS"

# 媒体备份环境（restic）
RESTIC_REPOSITORY=${RESTIC_REPOSITORY:-/data/repo}
RESTIC_PASSWORD=${RESTIC_PASSWORD:-change-me}
RESTIC_BACKUP_ARGS=${RESTIC_BACKUP_ARGS:---verbose}
BROWSE_SOURCE_ROOT=${BROWSE_SOURCE_ROOT:-/backup}
BROWSE_OUTPUT_ROOT=${BROWSE_OUTPUT_ROOT:-/data/browse}

log "Restic 配置:"
log "  仓库路径: $RESTIC_REPOSITORY"
log "  源目录: $BROWSE_SOURCE_ROOT"
log "  输出目录: $BROWSE_OUTPUT_ROOT"
log "  备份参数: $RESTIC_BACKUP_ARGS"

# 定时：MySQL 00:00/12:00；媒体 00:30/12:30（允许外部传入，可能带引号与CR）
MYSQL_CRON=${MYSQL_CRON:-"0 0 * * *\n0 12 * * *"}
MEDIA_CRON=${MEDIA_CRON:-"30 0 * * *\n30 12 * * *"}

log "=========================================="
log "创建必要的目录"
log "=========================================="
log "创建日志和脚本目录..."
mkdir -p /var/log /etc/crontabs /var/spool/cron/crontabs /app/mysql /app/media /data/mysql || {
    log "❌ 错误: 无法创建必要目录"
    exit 1
}
log "✅ 目录创建成功"

# 写入环境给脚本使用
export MYSQL_HOST MYSQL_PORT MYSQL_DATABASE MYSQL_USER MYSQL_PASSWORD MAX_BACKUPS
export RESTIC_REPOSITORY RESTIC_PASSWORD RESTIC_BACKUP_ARGS BROWSE_SOURCE_ROOT BROWSE_OUTPUT_ROOT

log "=========================================="
log "初始化 Restic 备份仓库"
log "=========================================="
log "仓库路径: $RESTIC_REPOSITORY"

if ! restic -r "$RESTIC_REPOSITORY" snapshots >/dev/null 2>&1; then
  log "Restic 仓库不存在，正在初始化..."
  if restic -r "$RESTIC_REPOSITORY" init >/dev/null 2>&1; then
    log "✅ Restic 仓库初始化成功"
  else
    log "⚠️  警告: Restic 仓库初始化失败，将稍后重试"
  fi
else
  log "✅ Restic 仓库已存在且可用"
  SNAPSHOT_COUNT=$(restic -r "$RESTIC_REPOSITORY" snapshots --json 2>/dev/null | jq 'length' || echo "0")
  log "当前快照数量: $SNAPSHOT_COUNT"
fi

log "=========================================="
log "设置定时任务"
log "=========================================="
log "MySQL 备份计划:"
printf "%s\n" "$MYSQL_CRON" | tr -d '\r' | sed 's/^"//;s/"$//' | while IFS= read -r line; do
  [ -z "$line" ] && continue
  case "$line" in \#*) continue;; esac
  log "  - $line"
done

log "媒体备份计划:"
printf "%s\n" "$MEDIA_CRON" | tr -d '\r' | sed 's/^"//;s/"$//' | while IFS= read -r line; do
  [ -z "$line" ] && continue
  case "$line" in \#*) continue;; esac
  log "  - $line"
done
rm -f /tmp/cronfile
# MySQL 两次（去除 CR 与包裹引号，过滤空行与注释）
printf "%s\n" "$MYSQL_CRON" | tr -d '\r' | sed 's/^"//;s/"$//' | while IFS= read -r line; do
  [ -z "$line" ] && continue
  case "$line" in \#*) continue;; esac
  echo "$line /bin/sh -lc 'MYSQL_BACKUP_DIR=/data/mysql /app/mysql/backup.sh >> /var/log/mysql-backup.log 2>&1'" >> /tmp/cronfile
done
# 媒体两次（去除 CR 与包裹引号，过滤空行与注释）
printf "%s\n" "$MEDIA_CRON" | tr -d '\r' | sed 's/^"//;s/"$//' | while IFS= read -r line; do
  [ -z "$line" ] && continue
  case "$line" in \#*) continue;; esac
  echo "$line /bin/sh -lc 'echo \"[\$(date +%F\ %T)] 开始媒体文件备份...\" && restic -r \"$RESTIC_REPOSITORY\" backup \"$BROWSE_SOURCE_ROOT\" $RESTIC_BACKUP_ARGS && echo \"[\$(date +%F\ %T)] 媒体文件备份完成\" && /app/media/cleanup.sh && echo \"[\$(date +%F\ %T)] 清理完成\" && python3 /app/media/export_browse.py && echo \"[\$(date +%F\ %T)] 可浏览副本导出完成\"' >> /var/log/media-backup.log 2>&1" >> /tmp/cronfile
done

log "验证 crontab 配置..."
CRON_LINE_COUNT=$(wc -l < /tmp/cronfile 2>/dev/null || echo "0")
log "定时任务数量: $CRON_LINE_COUNT"
log "crontab 内容:"
sed -n '1,200p' /tmp/cronfile | while IFS= read -r line; do
    log "  $line"
done || true

if crontab /tmp/cronfile; then
    log "✅ crontab 配置写入成功"
else
    log "❌ 错误: crontab 写入失败"
    log "请检查 CRON 表达式内容"
    exit 1
fi
rm -f /tmp/cronfile

# 首次各执行一次（防重复）
if [ ! -f /var/run/unified-backup.initial.done ]; then
  log "=========================================="
  log "执行首次备份任务（仅首次启动时执行）"
  log "=========================================="
  
  log "执行首次 MySQL 备份..."
  if /bin/sh -lc "MYSQL_BACKUP_DIR=/data/mysql /app/mysql/backup.sh >> /var/log/mysql-backup.log 2>&1"; then
    log "✅ 首次 MySQL 备份完成"
  else
    log "⚠️  警告: 首次 MySQL 备份失败，请检查日志"
  fi
  
  log "执行首次媒体文件备份..."
  if /bin/sh -lc "echo '[\$(date +%F\ %T)] 开始媒体文件备份...' && restic -r \"$RESTIC_REPOSITORY\" backup \"$BROWSE_SOURCE_ROOT\" $RESTIC_BACKUP_ARGS >> /var/log/media-backup.log 2>&1 && echo '[\$(date +%F\ %T)] 媒体文件备份完成' >> /var/log/media-backup.log"; then
    log "✅ 首次媒体文件备份完成"
  else
    log "⚠️  警告: 首次媒体文件备份失败，请检查日志"
  fi
  
  log "执行首次媒体清理与导出..."
  if /bin/sh -lc "/app/media/cleanup.sh >> /var/log/media-backup.log 2>&1 && python3 /app/media/export_browse.py >> /var/log/media-backup.log 2>&1"; then
    log "✅ 首次媒体清理与导出完成"
  else
    log "⚠️  警告: 首次媒体清理与导出失败，请检查日志"
  fi
  
  touch /var/run/unified-backup.initial.done || true
  log "✅ 首次备份任务标记已创建"
else
  log "ℹ️  首次备份已完成，跳过首次备份任务"
fi

log "=========================================="
log "启动定时任务守护进程"
log "=========================================="
log "日志文件:"
log "  MySQL备份日志: /var/log/mysql-backup.log"
log "  媒体备份日志: /var/log/media-backup.log"
log "开始实时监控日志输出..."
# 确保日志文件存在，并将日志实时输出到 Docker 日志
touch /var/log/mysql-backup.log /var/log/media-backup.log || true
tail -n 0 -F /var/log/mysql-backup.log /var/log/media-backup.log &
exec crond -n


