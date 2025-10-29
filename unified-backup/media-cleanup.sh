#!/usr/bin/env sh
set -eu
log(){ printf '[%s] %s\n' "$(date '+%F %T')" "$*"; }

log "开始执行自定义媒体备份清理策略..."

SNAPSHOTS=$(restic -r "$RESTIC_REPOSITORY" snapshots --json | jq -r '.[] | "\(.time) \(.id)"' | sort)

CURRENT_DATE=$(date +%Y-%m-%d)
FOURTEEN_DAYS_AGO=$(date -d "14 days ago" +%Y-%m-%d 2>/dev/null || date -v-14d +%Y-%m-%d 2>/dev/null || date -j -v-14d +%Y-%m-%d 2>/dev/null || date -d@$(($(date +%s) - 14*24*60*60)) +%Y-%m-%d 2>/dev/null)

log "当前日期: $CURRENT_DATE"
log "14天前日期: $FOURTEEN_DAYS_AGO"

echo "$SNAPSHOTS" | while IFS=' ' read -r snapshot_time snapshot_id; do
  snapshot_date=$(echo "$snapshot_time" | cut -d'T' -f1)
  snapshot_day=$(echo "$snapshot_date" | cut -d'-' -f3)

  keep=false
  if [ "$snapshot_date" \> "$FOURTEEN_DAYS_AGO" ] || [ "$snapshot_date" = "$FOURTEEN_DAYS_AGO" ]; then
    keep=true; log "保留最近14天内备份: $snapshot_date ($snapshot_id)"
  fi
  if [ "$snapshot_day" = "01" ]; then
    keep=true; log "保留月初备份: $snapshot_date ($snapshot_id)"
  fi
  if [ "$keep" = false ]; then
    log "删除过期备份: $snapshot_date ($snapshot_id)"; restic -r "$RESTIC_REPOSITORY" forget "$snapshot_id" --prune || true
  fi
done

log "媒体备份清理策略执行完成"
log "开始清理未引用的数据..."
restic -r "$RESTIC_REPOSITORY" prune || true
log "数据清理完成"

# 清理完成后同步到E盘
log "开始同步到E盘..."
if [ -f "/app/sync-to-e-drive.sh" ]; then
    /app/sync-to-e-drive.sh >> /var/log/media-backup.log 2>&1
    log "E盘同步完成"
else
    log "E盘同步脚本不存在，跳过同步"
fi


