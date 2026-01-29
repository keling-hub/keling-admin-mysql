#!/usr/bin/env sh
set -eu
log(){ printf '[%s] %s\n' "$(date '+%F %T')" "$*"; }

log "=========================================="
log "媒体文件备份清理任务开始"
log "=========================================="

log "Restic 配置信息:"
log "  仓库路径: ${RESTIC_REPOSITORY:-/data/repo}"
log "  源目录: ${BROWSE_SOURCE_ROOT:-/backup}"
log "  输出目录: ${BROWSE_OUTPUT_ROOT:-/data/browse}"

log "开始执行自定义媒体备份清理策略..."

# 检查 restic 仓库是否可用
log "检查 Restic 仓库..."
if ! restic -r "$RESTIC_REPOSITORY" snapshots >/dev/null 2>&1; then
    log "⚠️  警告: Restic 仓库不存在或不可访问: $RESTIC_REPOSITORY"
    log "尝试初始化仓库..."
    if restic -r "$RESTIC_REPOSITORY" init >/dev/null 2>&1; then
        log "✅ Restic 仓库初始化成功"
    else
        log "❌ 错误: Restic 仓库初始化失败"
        exit 1
    fi
else
    log "✅ Restic 仓库可用"
fi

log "获取所有备份快照..."
SNAPSHOTS=$(restic -r "$RESTIC_REPOSITORY" snapshots --json 2>/dev/null | jq -r '.[] | "\(.time) \(.id)"' | sort || echo "")

if [ -z "$SNAPSHOTS" ]; then
    log "⚠️  警告: 没有找到任何备份快照"
    log "可能这是首次备份或仓库为空"
else
    SNAPSHOT_COUNT=$(echo "$SNAPSHOTS" | wc -l)
    log "✅ 找到 $SNAPSHOT_COUNT 个备份快照"
fi

CURRENT_DATE=$(date +%Y-%m-%d)
# 使用时间戳计算，兼容性更好（14天前）
FOURTEEN_DAYS_AGO=$(date -d@$(($(date +%s) - 14*24*60*60)) +%Y-%m-%d 2>/dev/null || date -d "14 days ago" +%Y-%m-%d 2>/dev/null || date -v-14d +%Y-%m-%d 2>/dev/null || echo "")

log "日期信息:"
log "  当前日期: $CURRENT_DATE"
log "  14天前日期: $FOURTEEN_DAYS_AGO"

log "=========================================="
log "开始分析备份快照..."
log "=========================================="

KEPT_COUNT=0
DELETED_COUNT=0

if [ -n "$SNAPSHOTS" ]; then
    # 使用临时文件避免子shell问题，确保变量能正确累加
    TMP_SNAPSHOTS=$(mktemp /tmp/snapshots.XXXXXX 2>/dev/null || echo "/tmp/snapshots.$$")
    echo "$SNAPSHOTS" > "$TMP_SNAPSHOTS"
    
    while IFS=' ' read -r snapshot_time snapshot_id; do
        if [ -z "$snapshot_time" ] || [ -z "$snapshot_id" ]; then
            continue
        fi
        
        snapshot_date=$(echo "$snapshot_time" | cut -d'T' -f1)
        snapshot_day=$(echo "$snapshot_date" | cut -d'-' -f3)

        keep=false
        reason=""
        
        # 使用时间戳比较日期（更可靠）
        snapshot_timestamp=$(date -d "$snapshot_date" +%s 2>/dev/null || echo "0")
        fourteen_days_ago_timestamp=$(date -d "$FOURTEEN_DAYS_AGO" +%s 2>/dev/null || echo "0")
        
        if [ "$snapshot_timestamp" -ge "$fourteen_days_ago_timestamp" ] && [ "$snapshot_timestamp" -gt 0 ] && [ "$fourteen_days_ago_timestamp" -gt 0 ]; then
            keep=true
            reason="最近14天内"
            log "  ✅ 保留备份: $snapshot_date (ID: ${snapshot_id:0:8}...) - $reason"
            KEPT_COUNT=$((KEPT_COUNT + 1))
        fi
        if [ "$snapshot_day" = "01" ]; then
            keep=true
            reason="月初1号备份"
            log "  ✅ 保留备份: $snapshot_date (ID: ${snapshot_id:0:8}...) - $reason"
            KEPT_COUNT=$((KEPT_COUNT + 1))
        fi
        if [ "$keep" = false ]; then
            log "  🗑️  删除过期备份: $snapshot_date (ID: ${snapshot_id:0:8}...) - 超过14天且非月初"
            if restic -r "$RESTIC_REPOSITORY" forget "$snapshot_id" --prune >/dev/null 2>&1; then
                log "    ✅ 删除成功"
                DELETED_COUNT=$((DELETED_COUNT + 1))
            else
                log "    ⚠️  删除失败，继续处理下一个"
            fi
        fi
    done < "$TMP_SNAPSHOTS"
    
    # 清理临时文件
    rm -f "$TMP_SNAPSHOTS" 2>/dev/null || true
else
    log "  ℹ️  没有备份快照需要处理"
fi

log "=========================================="
log "备份快照清理统计:"
log "  保留快照: $KEPT_COUNT"
log "  删除快照: $DELETED_COUNT"
log "=========================================="

log "开始清理未引用的数据..."
log "执行 restic prune 命令..."
if restic -r "$RESTIC_REPOSITORY" prune >/dev/null 2>&1; then
    log "✅ 未引用数据清理完成"
else
    log "⚠️  警告: 数据清理过程中可能存在问题"
fi

log "=========================================="
log "媒体备份清理策略执行完成"
log "=========================================="

# 清理完成后同步到E盘
log "=========================================="
log "开始同步到E盘..."
log "=========================================="
if [ -f "/app/sync-to-e-drive.sh" ]; then
    log "执行E盘同步脚本..."
    /app/sync-to-e-drive.sh >> /var/log/media-backup.log 2>&1
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
log "媒体文件备份清理任务完成"
log "=========================================="


