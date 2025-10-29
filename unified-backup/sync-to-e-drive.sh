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

log "开始E盘同步..."
log "Docker卷只保存当天数据，E盘作为主要长期存储"

# 调试信息
log "调试信息:"
log "  E盘挂载点: $E_DRIVE_MOUNT"
log "  E盘MySQL目录: $E_DRIVE_MYSQL_DIR"
log "  E盘媒体目录: $E_DRIVE_MEDIA_DIR"
log "  本地MySQL目录: $LOCAL_MYSQL_DIR"
log "  本地媒体目录: $LOCAL_MEDIA_DIR"

# 检查E盘挂载点是否存在
if [ ! -d "$E_DRIVE_MOUNT" ]; then
    log "E盘挂载点不存在: $E_DRIVE_MOUNT"
    log "跳过E盘同步"
    exit 0
fi

# 检查E盘是否可写
if [ ! -w "$E_DRIVE_MOUNT" ]; then
    log "E盘挂载点不可写: $E_DRIVE_MOUNT"
    log "跳过E盘同步"
    exit 0
fi

# 创建E盘备份目录
log "创建E盘备份目录: $E_DRIVE_MYSQL_DIR, $E_DRIVE_MEDIA_DIR"
mkdir -p "$E_DRIVE_MYSQL_DIR" "$E_DRIVE_MEDIA_DIR" || {
    log "无法创建E盘备份目录，跳过同步"
    exit 0
}

# 验证目录创建成功
if [ ! -d "$E_DRIVE_MYSQL_DIR" ] || [ ! -d "$E_DRIVE_MEDIA_DIR" ]; then
    log "E盘备份目录创建失败"
    exit 0
fi

log "E盘备份目录验证成功"

# 检查本地备份目录
log "检查本地备份目录..."
if [ ! -d "$LOCAL_MYSQL_DIR" ]; then
    log "本地MySQL备份目录不存在: $LOCAL_MYSQL_DIR"
else
    log "本地MySQL备份目录存在: $LOCAL_MYSQL_DIR"
    # 列出本地MySQL目录中的文件
    log "本地MySQL目录中的文件:"
    ls -la "$LOCAL_MYSQL_DIR"/*.sql 2>/dev/null || log "  无.sql文件"
fi

if [ ! -d "$LOCAL_MEDIA_DIR" ]; then
    log "本地媒体备份目录不存在: $LOCAL_MEDIA_DIR"
else
    log "本地媒体备份目录存在: $LOCAL_MEDIA_DIR"
    # 列出本地媒体目录中的文件
    log "本地媒体目录中的文件:"
    ls -la "$LOCAL_MEDIA_DIR"/*.tar.gz "$LOCAL_MEDIA_DIR"/*.sql 2>/dev/null || log "  无备份文件"
fi

# 同步MySQL备份文件
log "同步MySQL备份文件到E盘..."
mysql_synced=0
if [ -d "$LOCAL_MYSQL_DIR" ]; then
    for file in "$LOCAL_MYSQL_DIR"/*.sql; do
        if [ -f "$file" ]; then
            filename=$(basename "$file")
            e_drive_file="$E_DRIVE_MYSQL_DIR/$filename"
            
            # 如果E盘文件不存在或本地文件更新，则复制
            if [ ! -f "$e_drive_file" ] || [ "$file" -nt "$e_drive_file" ]; then
                log "开始复制MySQL备份: $filename"
                log "源文件: $file"
                log "目标文件: $e_drive_file"
                
                # 检查源文件是否存在且可读
                if [ ! -r "$file" ]; then
                    log "错误: 源文件不可读: $file"
                    continue
                fi
                
                # 执行复制操作
                if cp "$file" "$e_drive_file"; then
                    # 验证复制是否成功
                    if [ -f "$e_drive_file" ] && [ -s "$e_drive_file" ]; then
                        local_size=$(stat -c%s "$file" 2>/dev/null || wc -c < "$file")
                        remote_size=$(stat -c%s "$e_drive_file" 2>/dev/null || wc -c < "$e_drive_file")
                        if [ "$local_size" = "$remote_size" ]; then
                            log "复制MySQL备份成功: $filename (size: $local_size)"
                            mysql_synced=$((mysql_synced + 1))
                        else
                            log "错误: 文件大小不匹配 - 本地: $local_size, 远程: $remote_size"
                            rm -f "$e_drive_file" || true
                        fi
                    else
                        log "错误: 复制后目标文件不存在或为空"
                    fi
                else
                    log "错误: 复制MySQL备份失败: $filename"
                fi
            else
                log "跳过MySQL备份: $filename (已存在且最新)"
            fi
        fi
    done
fi

# 同步媒体备份文件
log "同步媒体备份文件到E盘..."
media_synced=0
if [ -d "$LOCAL_MEDIA_DIR" ]; then
    for file in "$LOCAL_MEDIA_DIR"/*.tar.gz "$LOCAL_MEDIA_DIR"/*.sql; do
        if [ -f "$file" ]; then
            filename=$(basename "$file")
            e_drive_file="$E_DRIVE_MEDIA_DIR/$filename"
            
            # 如果E盘文件不存在或本地文件更新，则复制
            if [ ! -f "$e_drive_file" ] || [ "$file" -nt "$e_drive_file" ]; then
                log "开始复制媒体备份: $filename"
                
                # 检查源文件是否存在且可读
                if [ ! -r "$file" ]; then
                    log "错误: 源文件不可读: $file"
                    continue
                fi
                
                # 执行复制操作
                if cp "$file" "$e_drive_file"; then
                    # 验证复制是否成功
                    if [ -f "$e_drive_file" ] && [ -s "$e_drive_file" ]; then
                        local_size=$(stat -c%s "$file" 2>/dev/null || wc -c < "$file")
                        remote_size=$(stat -c%s "$e_drive_file" 2>/dev/null || wc -c < "$e_drive_file")
                        if [ "$local_size" = "$remote_size" ]; then
                            log "复制媒体备份成功: $filename (size: $local_size)"
                            media_synced=$((media_synced + 1))
                        else
                            log "错误: 文件大小不匹配 - 本地: $local_size, 远程: $remote_size"
                            rm -f "$e_drive_file" || true
                        fi
                    else
                        log "错误: 复制后目标文件不存在或为空"
                    fi
                else
                    log "错误: 复制媒体备份失败: $filename"
                fi
            else
                log "跳过媒体备份: $filename (已存在且最新)"
            fi
        fi
    done
fi

log "同步完成: $mysql_synced MySQL文件, $media_synced 媒体文件"

# 执行E盘清理策略（只在00:00时执行，避免删除当天的12:00备份）
current_hour=$(date +%H)
if [ "$current_hour" = "00" ]; then
    log "执行E盘清理策略（00:00时清理前一天的12:00备份）..."
    
    current_date=$(date +%Y-%m-%d)
    one_month_ago=$(date -d "1 month ago" +%Y-%m-%d 2>/dev/null || date -v-1m +%Y-%m-%d 2>/dev/null || date -j -v-1m +%Y-%m-%d 2>/dev/null || date -d@$(($(date +%s) - 30*24*60*60)) +%Y-%m-%d 2>/dev/null)
    
    mysql_cleaned=0
    media_cleaned=0
    
    # 清理MySQL备份
    if [ -d "$E_DRIVE_MYSQL_DIR" ]; then
        for file in "$E_DRIVE_MYSQL_DIR"/*.sql; do
            if [ -f "$file" ]; then
                filename=$(basename "$file")
                file_date=$(date -r "$file" +%Y-%m-%d 2>/dev/null || date -r "$file" +%Y-%m-%d 2>/dev/null || echo "")
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
                    rm -f "$file"
                    log "删除MySQL备份: $filename ($reason)"
                    mysql_cleaned=$((mysql_cleaned + 1))
                else
                    log "保留MySQL备份: $filename ($reason)"
                fi
            fi
        done
    fi
else
    log "跳过E盘清理策略（非00:00时，保留当天12:00备份）"
    mysql_cleaned=0
    media_cleaned=0
fi

log "E盘同步完成"
