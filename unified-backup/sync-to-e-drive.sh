#!/usr/bin/env sh
set -eu

log(){ printf '[%s] %s\n' "$(date '+%F %T')" "$*"; }

# E盘同步脚本 - 将Docker卷中的备份文件同步到E盘
# E盘作为主要长期存储，Docker卷只保存当天数据
# 保留策略：
# 1. 删除12:00备份（只保留00:00备份）
# 2. 最近一个月：保留所有备份
# 3. 超过一个月：只保留每月1号备份

# 检查E盘是否可用（通过挂载点检查）
E_DRIVE_MOUNT="/mnt/e-drive"
E_DRIVE_BACKUP_DIR="$E_DRIVE_MOUNT/keling-backup"
E_DRIVE_MYSQL_DIR="$E_DRIVE_BACKUP_DIR/mysql"
E_DRIVE_MEDIA_DIR="$E_DRIVE_BACKUP_DIR/media"

# 本地备份目录
LOCAL_MYSQL_DIR="/data/mysql"
LOCAL_MEDIA_DIR="/data"

log "=========================================="
log "E盘同步任务开始"
log "=========================================="
log "同步策略: Docker卷只保存当天数据，E盘作为主要长期存储"

log "路径配置:"
log "  E盘挂载点: $E_DRIVE_MOUNT"
log "  E盘MySQL目录: $E_DRIVE_MYSQL_DIR"
log "  E盘媒体目录: $E_DRIVE_MEDIA_DIR"
log "  本地MySQL目录: $LOCAL_MYSQL_DIR"
log "  本地媒体目录: $LOCAL_MEDIA_DIR"

log "=========================================="
log "检查E盘挂载状态"
log "=========================================="

# 检查E盘挂载点是否存在
if [ ! -d "$E_DRIVE_MOUNT" ]; then
    log "❌ 错误: E盘挂载点不存在: $E_DRIVE_MOUNT"
    log "可能原因:"
    log "  1. Docker卷未正确挂载"
    log "  2. Windows上未配置Shared Drives"
    log "  3. 命名卷配置错误"
    log "跳过E盘同步"
    exit 0
fi
log "✅ E盘挂载点存在"

# 检查E盘是否可写
if [ ! -w "$E_DRIVE_MOUNT" ]; then
    log "❌ 错误: E盘挂载点不可写: $E_DRIVE_MOUNT"
    log "请检查挂载权限"
    log "跳过E盘同步"
    exit 0
fi
log "✅ E盘挂载点可写"

# 检查E盘可用空间
if command -v df >/dev/null 2>&1; then
    E_DRIVE_SPACE=$(df -h "$E_DRIVE_MOUNT" 2>/dev/null | tail -1 | awk '{print $4}' || echo "未知")
    log "E盘可用空间: $E_DRIVE_SPACE"
fi

log "=========================================="
log "创建E盘备份目录"
log "=========================================="
log "正在创建目录: $E_DRIVE_MYSQL_DIR, $E_DRIVE_MEDIA_DIR"
mkdir -p "$E_DRIVE_MYSQL_DIR" "$E_DRIVE_MEDIA_DIR" || {
    log "❌ 错误: 无法创建E盘备份目录"
    log "请检查E盘权限和空间"
    exit 0
}

# 验证目录创建成功
if [ ! -d "$E_DRIVE_MYSQL_DIR" ] || [ ! -d "$E_DRIVE_MEDIA_DIR" ]; then
    log "❌ 错误: E盘备份目录创建失败"
    log "MySQL目录存在: $([ -d "$E_DRIVE_MYSQL_DIR" ] && echo "是" || echo "否")"
    log "媒体目录存在: $([ -d "$E_DRIVE_MEDIA_DIR" ] && echo "是" || echo "否")"
    exit 0
fi
log "✅ E盘备份目录创建成功"

log "=========================================="
log "检查本地备份目录"
log "=========================================="

# 检查本地MySQL备份目录
if [ ! -d "$LOCAL_MYSQL_DIR" ]; then
    log "⚠️  警告: 本地MySQL备份目录不存在: $LOCAL_MYSQL_DIR"
else
    log "✅ 本地MySQL备份目录存在: $LOCAL_MYSQL_DIR"
    MYSQL_FILE_COUNT=$(ls -1 "$LOCAL_MYSQL_DIR"/*.sql 2>/dev/null | wc -l || echo "0")
    MYSQL_TOTAL_SIZE=0
    if [ "$MYSQL_FILE_COUNT" -gt 0 ]; then
        log "  发现 $MYSQL_FILE_COUNT 个MySQL备份文件:"
        for file in "$LOCAL_MYSQL_DIR"/*.sql; do
            if [ -f "$file" ]; then
                file_size=$(stat -c%s "$file" 2>/dev/null || wc -c < "$file")
                MYSQL_TOTAL_SIZE=$((MYSQL_TOTAL_SIZE + file_size))
                log "    - $(basename "$file") ($(numfmt --to=iec-i --suffix=B $file_size 2>/dev/null || echo "${file_size} 字节"))"
            fi
        done
        log "  总大小: $(numfmt --to=iec-i --suffix=B $MYSQL_TOTAL_SIZE 2>/dev/null || echo "${MYSQL_TOTAL_SIZE} 字节")"
    else
        log "  ℹ️  无.sql文件需要同步"
fi
fi

# 检查本地媒体备份目录
if [ ! -d "$LOCAL_MEDIA_DIR" ]; then
    log "⚠️  警告: 本地媒体备份目录不存在: $LOCAL_MEDIA_DIR"
else
    log "✅ 本地媒体备份目录存在: $LOCAL_MEDIA_DIR"
    MEDIA_FILE_COUNT=$(ls -1 "$LOCAL_MEDIA_DIR"/*.tar.gz "$LOCAL_MEDIA_DIR"/*.sql 2>/dev/null | wc -l || echo "0")
    MEDIA_TOTAL_SIZE=0
    if [ "$MEDIA_FILE_COUNT" -gt 0 ]; then
        log "  发现 $MEDIA_FILE_COUNT 个媒体备份文件:"
        for file in "$LOCAL_MEDIA_DIR"/*.tar.gz "$LOCAL_MEDIA_DIR"/*.sql; do
            if [ -f "$file" ]; then
                file_size=$(stat -c%s "$file" 2>/dev/null || wc -c < "$file")
                MEDIA_TOTAL_SIZE=$((MEDIA_TOTAL_SIZE + file_size))
                log "    - $(basename "$file") ($(numfmt --to=iec-i --suffix=B $file_size 2>/dev/null || echo "${file_size} 字节"))"
fi
        done
        log "  总大小: $(numfmt --to=iec-i --suffix=B $MEDIA_TOTAL_SIZE 2>/dev/null || echo "${MEDIA_TOTAL_SIZE} 字节")"
    else
        log "  ℹ️  无备份文件需要同步"
    fi
fi

log "=========================================="
log "同步MySQL备份文件到E盘"
log "=========================================="

mysql_synced=0
mysql_skipped=0
mysql_failed=0

if [ -d "$LOCAL_MYSQL_DIR" ]; then
    mysql_file_list=$(ls -1 "$LOCAL_MYSQL_DIR"/*.sql 2>/dev/null || echo "")
    if [ -z "$mysql_file_list" ]; then
        log "ℹ️  本地MySQL目录中没有备份文件需要同步"
    else
    for file in "$LOCAL_MYSQL_DIR"/*.sql; do
        if [ -f "$file" ]; then
            filename=$(basename "$file")
            e_drive_file="$E_DRIVE_MYSQL_DIR/$filename"
                local_size=$(stat -c%s "$file" 2>/dev/null || wc -c < "$file")
            
            # 如果E盘文件不存在或本地文件更新，则复制
            if [ ! -f "$e_drive_file" ] || [ "$file" -nt "$e_drive_file" ]; then
                log "开始复制MySQL备份: $filename"
                    log "  源文件: $file"
                    log "  源文件大小: $(numfmt --to=iec-i --suffix=B $local_size 2>/dev/null || echo "${local_size} 字节")"
                    log "  目标文件: $e_drive_file"
                
                # 检查源文件是否存在且可读
                if [ ! -r "$file" ]; then
                        log "  ❌ 错误: 源文件不可读: $file"
                        mysql_failed=$((mysql_failed + 1))
                    continue
                fi
                
                # 执行复制操作
                    COPY_START=$(date +%s)
                if cp "$file" "$e_drive_file"; then
                        COPY_END=$(date +%s)
                        COPY_DURATION=$((COPY_END - COPY_START))
                        
                    # 验证复制是否成功
                    if [ -f "$e_drive_file" ] && [ -s "$e_drive_file" ]; then
                        remote_size=$(stat -c%s "$e_drive_file" 2>/dev/null || wc -c < "$e_drive_file")
                        if [ "$local_size" = "$remote_size" ]; then
                                log "  ✅ 复制成功"
                                log "    目标文件大小: $(numfmt --to=iec-i --suffix=B $remote_size 2>/dev/null || echo "${remote_size} 字节")"
                                log "    复制耗时: ${COPY_DURATION} 秒"
                            mysql_synced=$((mysql_synced + 1))
                        else
                                log "  ❌ 错误: 文件大小不匹配"
                                log "    本地大小: $local_size 字节"
                                log "    远程大小: $remote_size 字节"
                                log "    差异: $((local_size - remote_size)) 字节"
                            rm -f "$e_drive_file" || true
                                mysql_failed=$((mysql_failed + 1))
                            fi
                        else
                            log "  ❌ 错误: 复制后目标文件不存在或为空"
                            mysql_failed=$((mysql_failed + 1))
                        fi
                    else
                        log "  ❌ 错误: 复制操作失败"
                        log "    可能原因: E盘空间不足或权限不足"
                        mysql_failed=$((mysql_failed + 1))
                    fi
                else
                    log "  ⏭️  跳过: $filename (E盘已存在且为最新版本)"
                    mysql_skipped=$((mysql_skipped + 1))
            fi
        fi
    done
fi
else
    log "⚠️  警告: 本地MySQL备份目录不存在，跳过MySQL同步"
fi

log "MySQL同步统计:"
log "  成功同步: $mysql_synced 个文件"
log "  跳过: $mysql_skipped 个文件"
log "  失败: $mysql_failed 个文件"

log "=========================================="
log "同步媒体备份文件到E盘"
log "=========================================="

media_synced=0
media_skipped=0
media_failed=0

if [ -d "$LOCAL_MEDIA_DIR" ]; then
    media_file_list=$(ls -1 "$LOCAL_MEDIA_DIR"/*.tar.gz "$LOCAL_MEDIA_DIR"/*.sql 2>/dev/null || echo "")
    if [ -z "$media_file_list" ]; then
        log "ℹ️  本地媒体目录中没有备份文件需要同步"
    else
    for file in "$LOCAL_MEDIA_DIR"/*.tar.gz "$LOCAL_MEDIA_DIR"/*.sql; do
        if [ -f "$file" ]; then
            filename=$(basename "$file")
            e_drive_file="$E_DRIVE_MEDIA_DIR/$filename"
                local_size=$(stat -c%s "$file" 2>/dev/null || wc -c < "$file")
            
            # 如果E盘文件不存在或本地文件更新，则复制
            if [ ! -f "$e_drive_file" ] || [ "$file" -nt "$e_drive_file" ]; then
                log "开始复制媒体备份: $filename"
                    log "  源文件大小: $(numfmt --to=iec-i --suffix=B $local_size 2>/dev/null || echo "${local_size} 字节")"
                
                # 检查源文件是否存在且可读
                if [ ! -r "$file" ]; then
                        log "  ❌ 错误: 源文件不可读: $file"
                        media_failed=$((media_failed + 1))
                    continue
                fi
                
                # 执行复制操作
                    COPY_START=$(date +%s)
                if cp "$file" "$e_drive_file"; then
                        COPY_END=$(date +%s)
                        COPY_DURATION=$((COPY_END - COPY_START))
                        
                    # 验证复制是否成功
                    if [ -f "$e_drive_file" ] && [ -s "$e_drive_file" ]; then
                        remote_size=$(stat -c%s "$e_drive_file" 2>/dev/null || wc -c < "$e_drive_file")
                        if [ "$local_size" = "$remote_size" ]; then
                                log "  ✅ 复制成功"
                                log "    目标文件大小: $(numfmt --to=iec-i --suffix=B $remote_size 2>/dev/null || echo "${remote_size} 字节")"
                                log "    复制耗时: ${COPY_DURATION} 秒"
                            media_synced=$((media_synced + 1))
                        else
                                log "  ❌ 错误: 文件大小不匹配"
                                log "    本地大小: $local_size 字节"
                                log "    远程大小: $remote_size 字节"
                                log "    差异: $((local_size - remote_size)) 字节"
                            rm -f "$e_drive_file" || true
                                media_failed=$((media_failed + 1))
                            fi
                        else
                            log "  ❌ 错误: 复制后目标文件不存在或为空"
                            media_failed=$((media_failed + 1))
                        fi
                    else
                        log "  ❌ 错误: 复制操作失败"
                        log "    可能原因: E盘空间不足或权限不足"
                        media_failed=$((media_failed + 1))
                    fi
                else
                    log "  ⏭️  跳过: $filename (E盘已存在且为最新版本)"
                    media_skipped=$((media_skipped + 1))
                fi
            fi
        done
                fi
            else
    log "⚠️  警告: 本地媒体备份目录不存在，跳过媒体同步"
fi

log "媒体同步统计:"
log "  成功同步: $media_synced 个文件"
log "  跳过: $media_skipped 个文件"
log "  失败: $media_failed 个文件"

log "=========================================="
log "同步任务汇总"
log "=========================================="
log "MySQL备份: 成功 $mysql_synced, 跳过 $mysql_skipped, 失败 $mysql_failed"
log "媒体备份: 成功 $media_synced, 跳过 $media_skipped, 失败 $media_failed"
TOTAL_SUCCESS=$((mysql_synced + media_synced))
TOTAL_FAILED=$((mysql_failed + media_failed))
if [ "$TOTAL_FAILED" -eq 0 ]; then
    log "✅ 所有文件同步成功"
else
    log "⚠️  警告: 有 $TOTAL_FAILED 个文件同步失败"
fi

log "=========================================="
log "执行E盘清理策略"
log "=========================================="

current_hour=$(date +%H)
current_date=$(date +%Y-%m-%d)

log "当前时间: $(date '+%Y-%m-%d %H:%M:%S')"
log "当前小时: $current_hour"

if [ "$current_hour" = "00" ]; then
    log "检测到00:00时，执行E盘清理策略..."
    log "清理策略:"
    log "  1. 删除前一天的12:00备份（只保留00:00备份）"
    log "  2. 最近一个月：保留所有00:00备份"
    log "  3. 超过一个月：只保留每月1号00:00备份"
    
    one_month_ago=$(date -d "1 month ago" +%Y-%m-%d 2>/dev/null || date -v-1m +%Y-%m-%d 2>/dev/null || date -j -v-1m +%Y-%m-%d 2>/dev/null || date -d@$(($(date +%s) - 30*24*60*60)) +%Y-%m-%d 2>/dev/null)
    
    log "日期范围:"
    log "  当前日期: $current_date"
    log "  一个月前: $one_month_ago"
    
    mysql_cleaned=0
    mysql_kept=0
    media_cleaned=0
    media_kept=0
    
    # 清理MySQL备份
    log "开始清理MySQL备份..."
    if [ -d "$E_DRIVE_MYSQL_DIR" ]; then
        E_DRIVE_MYSQL_COUNT=$(ls -1 "$E_DRIVE_MYSQL_DIR"/*.sql 2>/dev/null | wc -l || echo "0")
        log "E盘MySQL目录共有 $E_DRIVE_MYSQL_COUNT 个备份文件"
        
        for file in "$E_DRIVE_MYSQL_DIR"/*.sql; do
            if [ -f "$file" ]; then
                filename=$(basename "$file")
                file_date=$(date -r "$file" +%Y-%m-%d 2>/dev/null || date -r "$file" +%Y-%m-%d 2>/dev/null || echo "")
                file_size=$(stat -c%s "$file" 2>/dev/null || wc -c < "$file")
                should_delete=false
                reason=""
                
                # 规则1: 删除前一天的12:00备份（只保留00:00备份）
                if echo "$filename" | grep -q "_1200\.sql$"; then
                    # 检查是否是前一天的12:00备份
                    yesterday=$(date -d yesterday +%Y-%m-%d 2>/dev/null || date -v-1d +%Y-%m-%d 2>/dev/null || echo "")
                    if [ -n "$yesterday" ] && echo "$filename" | grep -q "^${yesterday}_1200\.sql$"; then
                        should_delete=true
                        reason="前一天12:00备份"
                    else
                        should_delete=false
                        reason="当天12:00备份，保留"
                    fi
                # 规则2: 最近一个月保留所有00:00备份
                elif [ "$file_date" \> "$one_month_ago" ] || [ "$file_date" = "$one_month_ago" ]; then
                    should_delete=false
                    reason="最近一个月内"
                # 规则3: 超过一个月只保留1号00:00备份
                else
                    day_of_month=$(date -r "$file" +%d 2>/dev/null || date -r "$file" +%d 2>/dev/null || echo "")
                    if [ "$day_of_month" = "01" ]; then
                        should_delete=false
                        reason="月初1号"
                    else
                        should_delete=true
                        reason="超过一个月且非1号"
                    fi
                fi
                
                if [ "$should_delete" = true ]; then
                    if rm -f "$file"; then
                        log "  🗑️  删除: $filename ($reason) (大小: $(numfmt --to=iec-i --suffix=B $file_size 2>/dev/null || echo "${file_size} 字节"))"
                    mysql_cleaned=$((mysql_cleaned + 1))
                    else
                        log "  ⚠️  警告: 删除失败: $filename"
                    fi
                else
                    log "  ✅ 保留: $filename ($reason) (大小: $(numfmt --to=iec-i --suffix=B $file_size 2>/dev/null || echo "${file_size} 字节"))"
                    mysql_kept=$((mysql_kept + 1))
                fi
            fi
        done
        
        log "MySQL清理统计:"
        log "  保留文件: $mysql_kept"
        log "  删除文件: $mysql_cleaned"
    else
        log "⚠️  警告: E盘MySQL目录不存在，跳过清理"
    fi
else
    log "当前时间非00:00，跳过E盘清理策略"
    log "原因: 保留当天12:00备份，避免误删"
    mysql_cleaned=0
    mysql_kept=0
    media_cleaned=0
    media_kept=0
fi

log "=========================================="
log "E盘同步任务完成"
log "=========================================="
log "同步结果:"
log "  MySQL: 同步 $mysql_synced, 跳过 $mysql_skipped, 失败 $mysql_failed"
log "  媒体: 同步 $media_synced, 跳过 $media_skipped, 失败 $media_failed"
if [ "$current_hour" = "00" ]; then
    log "清理结果:"
    log "  MySQL: 保留 $mysql_kept, 删除 $mysql_cleaned"
fi
