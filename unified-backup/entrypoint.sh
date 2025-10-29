#!/usr/bin/env sh
set -eu

log(){ printf '[%s] %s\n' "$(date '+%F %T')" "$*"; }

# 时区
TZ="${TZ:-Asia/Shanghai}"
if [ -f "/usr/share/zoneinfo/$TZ" ]; then
  cp "/usr/share/zoneinfo/$TZ" /etc/localtime || true
  echo "$TZ" > /etc/timezone || true
fi
log "时区: $TZ"

# MySQL 环境
MYSQL_HOST=${MYSQL_HOST:-keling-mysql}
MYSQL_PORT=${MYSQL_PORT:-3306}
MYSQL_DATABASE=${MYSQL_DATABASE:-kbk}
MYSQL_USER=${MYSQL_USER:-root}
MYSQL_PASSWORD=${MYSQL_PASSWORD:-131415}
MAX_BACKUPS=${MAX_BACKUPS:-14}

# 媒体备份环境（restic）
RESTIC_REPOSITORY=${RESTIC_REPOSITORY:-/data/repo}
RESTIC_PASSWORD=${RESTIC_PASSWORD:-change-me}
RESTIC_BACKUP_ARGS=${RESTIC_BACKUP_ARGS:---verbose}
BROWSE_SOURCE_ROOT=${BROWSE_SOURCE_ROOT:-/backup}
BROWSE_OUTPUT_ROOT=${BROWSE_OUTPUT_ROOT:-/data/browse}

# 定时：MySQL 00:00/12:00；媒体 00:30/12:30（允许外部传入，可能带引号与CR）
MYSQL_CRON=${MYSQL_CRON:-"0 0 * * *\n0 12 * * *"}
MEDIA_CRON=${MEDIA_CRON:-"30 0 * * *\n30 12 * * *"}

mkdir -p /var/log /etc/crontabs /var/spool/cron/crontabs /app/mysql /app/media /data/mysql

# 写入环境给脚本使用
export MYSQL_HOST MYSQL_PORT MYSQL_DATABASE MYSQL_USER MYSQL_PASSWORD MAX_BACKUPS
export RESTIC_REPOSITORY RESTIC_PASSWORD RESTIC_BACKUP_ARGS BROWSE_SOURCE_ROOT BROWSE_OUTPUT_ROOT

log "初始化 restic 仓库: $RESTIC_REPOSITORY"
if ! restic -r "$RESTIC_REPOSITORY" snapshots >/dev/null 2>&1; then
  restic -r "$RESTIC_REPOSITORY" init || true
fi

log "设置定时任务..."
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

log "crontab 内容如下:"; sed -n '1,200p' /tmp/cronfile || true
if ! crontab /tmp/cronfile; then
  log "crontab 写入失败，检查 CRON 表达式内容"
fi
rm -f /tmp/cronfile

# 首次各执行一次（防重复）
if [ ! -f /var/run/unified-backup.initial.done ]; then
  log "执行首次 MySQL 备份..."; /bin/sh -lc "MYSQL_BACKUP_DIR=/data/mysql /app/mysql/backup.sh >> /var/log/mysql-backup.log 2>&1" || true
  log "执行首次媒体备份..."; /bin/sh -lc "echo '[\$(date +%F\ %T)] 开始媒体文件备份...' && restic -r \"$RESTIC_REPOSITORY\" backup \"$BROWSE_SOURCE_ROOT\" $RESTIC_BACKUP_ARGS >> /var/log/media-backup.log 2>&1 && echo '[\$(date +%F\ %T)] 媒体文件备份完成' >> /var/log/media-backup.log" || true
  log "执行首次媒体清理与导出..."; /bin/sh -lc "/app/media/cleanup.sh >> /var/log/media-backup.log 2>&1 && python3 /app/media/export_browse.py >> /var/log/media-backup.log 2>&1" || true
  touch /var/run/unified-backup.initial.done || true
fi

log "启动定时任务守护进程..."
# 确保日志文件存在，并将日志实时输出到 Docker 日志
touch /var/log/mysql-backup.log /var/log/media-backup.log || true
tail -n 0 -F /var/log/mysql-backup.log /var/log/media-backup.log &
exec crond -n


