#!/usr/bin/env sh
# E盘挂载检查脚本
# 用于诊断 E 盘挂载问题

set -euo pipefail

log(){ printf '[%s] %s\n' "$(date '+%F %T')" "$*"; }

E_DRIVE_MOUNT="/mnt/e-drive"
E_DRIVE_BACKUP_DIR="$E_DRIVE_MOUNT"
E_DRIVE_MYSQL_DIR="$E_DRIVE_BACKUP_DIR/mysql"

log "=========================================="
log "E盘挂载诊断工具"
log "=========================================="

log "检查挂载点: $E_DRIVE_MOUNT"

# 检查挂载点是否存在
if [ ! -d "$E_DRIVE_MOUNT" ]; then
    log "❌ 错误: 挂载点不存在: $E_DRIVE_MOUNT"
    log ""
    log "解决方案:"
    log "  1. 检查 docker-compose.yml 中的 E 盘挂载配置"
    log "  2. 确保 E:\\keling-backup 目录在 Windows 上存在"
    log "  3. 重启 Docker 容器: docker-compose restart unified-backup"
    exit 1
fi
log "✅ 挂载点存在"

# 检查挂载点是否可写
if [ ! -w "$E_DRIVE_MOUNT" ]; then
    log "❌ 错误: 挂载点不可写: $E_DRIVE_MOUNT"
    log "请检查挂载权限"
    exit 1
fi
log "✅ 挂载点可写"

# 检查挂载类型
log ""
log "检查挂载信息:"
if command -v mount >/dev/null 2>&1; then
    mount | grep "$E_DRIVE_MOUNT" || log "  ⚠️  无法获取挂载信息"
fi

# 检查磁盘空间
log ""
log "检查磁盘空间:"
if command -v df >/dev/null 2>&1; then
    df -h "$E_DRIVE_MOUNT" 2>/dev/null || log "  ⚠️  无法获取磁盘空间信息"
fi

# 检查备份目录
log ""
log "检查备份目录:"
if [ ! -d "$E_DRIVE_BACKUP_DIR" ]; then
    log "  ⚠️  备份目录不存在: $E_DRIVE_BACKUP_DIR"
    log "  正在创建..."
    mkdir -p "$E_DRIVE_BACKUP_DIR" "$E_DRIVE_MYSQL_DIR" || {
        log "  ❌ 无法创建备份目录"
        exit 1
    }
    log "  ✅ 备份目录创建成功"
else
    log "  ✅ 备份目录存在: $E_DRIVE_BACKUP_DIR"
fi

# 检查 MySQL 备份目录
log ""
log "检查 MySQL 备份目录:"
if [ ! -d "$E_DRIVE_MYSQL_DIR" ]; then
    log "  ⚠️  MySQL 备份目录不存在: $E_DRIVE_MYSQL_DIR"
    log "  正在创建..."
    mkdir -p "$E_DRIVE_MYSQL_DIR" || {
        log "  ❌ 无法创建 MySQL 备份目录"
        exit 1
    }
    log "  ✅ MySQL 备份目录创建成功"
else
    log "  ✅ MySQL 备份目录存在: $E_DRIVE_MYSQL_DIR"
fi

# 列出备份文件
log ""
log "检查备份文件:"
if [ -d "$E_DRIVE_MYSQL_DIR" ]; then
    FILE_COUNT=$(ls -1 "$E_DRIVE_MYSQL_DIR"/*.sql 2>/dev/null | wc -l || echo "0")
    if [ "$FILE_COUNT" -gt 0 ]; then
        log "  ✅ 发现 $FILE_COUNT 个备份文件:"
        ls -lh "$E_DRIVE_MYSQL_DIR"/*.sql 2>/dev/null | head -10 | while IFS= read -r line; do
            log "    $line"
        done
        if [ "$FILE_COUNT" -gt 10 ]; then
            log "    ... 还有 $((FILE_COUNT - 10)) 个文件"
        fi
    else
        log "  ⚠️  没有找到备份文件"
        log "  可能原因:"
        log "    1. 备份尚未执行"
        log "    2. 同步脚本执行失败"
        log "    3. 文件被清理策略删除"
    fi
fi

# 测试写入
log ""
log "测试写入权限:"
TEST_FILE="$E_DRIVE_MYSQL_DIR/.write-test-$(date +%s)"
if echo "test" > "$TEST_FILE" 2>/dev/null; then
    rm -f "$TEST_FILE" 2>/dev/null || true
    log "  ✅ 写入测试成功"
else
    log "  ❌ 写入测试失败"
    log "  请检查 E 盘权限和空间"
fi

log ""
log "=========================================="
log "诊断完成"
log "=========================================="
log ""
log "如果文件仍然不在 E 盘，请检查:"
log "  1. docker-compose.yml 中的 E 盘挂载配置是否正确"
log "  2. Windows 上 E:\\keling-backup 目录是否存在"
log "  3. Docker Desktop 是否启用了 E 盘的 Shared Drives"
log "  4. 重启容器: docker-compose restart unified-backup"

