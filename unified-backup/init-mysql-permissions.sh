#!/usr/bin/env sh
# MySQL 权限初始化脚本
# 此脚本用于授予备份用户从备份容器连接的权限

set -euo pipefail

log(){ printf '[%s] %s\n' "$(date '+%F %T')" "$*"; }

DB_HOST=${MYSQL_HOST:-mysql}
DB_PORT=${MYSQL_PORT:-3306}
BACKUP_USER=${MYSQL_USER:-keling}
BACKUP_PASS=${MYSQL_PASSWORD:-${DB_PASSWORD:-131415}}
BACKUP_DB=${MYSQL_DATABASE:-kbk}
# 使用 root 用户来授予权限
ROOT_USER=${MYSQL_ROOT_USER:-root}
ROOT_PASS=${MYSQL_ROOT_PASSWORD:-root123456}
MAX_RETRIES=30
RETRY_INTERVAL=2

log "=========================================="
log "初始化 MySQL 备份用户权限"
log "=========================================="
log "等待 MySQL 服务就绪..."

# 等待 MySQL 服务可用（使用 root 用户测试）
for i in $(seq 1 $MAX_RETRIES); do
    if mysql -h"$DB_HOST" -P"$DB_PORT" -u"$ROOT_USER" -p"$ROOT_PASS" -e "SELECT 1" >/dev/null 2>&1; then
        log "✅ MySQL 服务已就绪"
        break
    fi
    if [ $i -eq $MAX_RETRIES ]; then
        log "❌ 错误: MySQL 服务在 ${MAX_RETRIES} 次重试后仍不可用"
        log "请检查 MySQL 服务是否正常运行"
        exit 1
    fi
    log "等待 MySQL 服务... ($i/$MAX_RETRIES)"
    sleep $RETRY_INTERVAL
done

log "检查备份用户权限..."
log "  备份用户: $BACKUP_USER"
log "  备份数据库: $BACKUP_DB"

# 检查备份用户是否可以从 '%' 连接
CAN_CONNECT=$(mysql -h"$DB_HOST" -P"$DB_PORT" -u"$ROOT_USER" -p"$ROOT_PASS" -s -N -e "SELECT COUNT(*) FROM mysql.user WHERE User='$BACKUP_USER' AND Host='%';" 2>/dev/null || echo "0")

if [ "$CAN_CONNECT" = "0" ]; then
    log "备份用户无法从远程连接，正在授予权限..."
    
    # 使用 root 用户授予备份用户权限
    mysql -h"$DB_HOST" -P"$DB_PORT" -u"$ROOT_USER" -p"$ROOT_PASS" <<EOF 2>/dev/null || true
-- 创建备份用户（如果不存在）
CREATE USER IF NOT EXISTS '$BACKUP_USER'@'%' IDENTIFIED BY '$BACKUP_PASS';
-- 授予备份数据库的 SELECT, LOCK TABLES, SHOW VIEW, EVENT, TRIGGER 权限（备份所需的最小权限）
GRANT SELECT, LOCK TABLES, SHOW VIEW, EVENT, TRIGGER ON \`$BACKUP_DB\`.* TO '$BACKUP_USER'@'%';
-- 刷新权限
FLUSH PRIVILEGES;
EOF
    
    # 验证权限是否设置成功
    VERIFY=$(mysql -h"$DB_HOST" -P"$DB_PORT" -u"$ROOT_USER" -p"$ROOT_PASS" -s -N -e "SELECT COUNT(*) FROM mysql.user WHERE User='$BACKUP_USER' AND Host='%';" 2>/dev/null || echo "0")
    
    if [ "$VERIFY" != "0" ]; then
        log "✅ 备份用户权限已授予"
        log "  用户: $BACKUP_USER@'%'"
        log "  数据库: $BACKUP_DB"
        log "  权限: SELECT, LOCK TABLES, SHOW VIEW, EVENT, TRIGGER"
    else
        log "⚠️  警告: 授予权限可能失败，但将继续尝试备份"
        log "如果备份仍然失败，请手动在 MySQL 中执行以下 SQL:"
        log "  CREATE USER IF NOT EXISTS '$BACKUP_USER'@'%' IDENTIFIED BY '$BACKUP_PASS';"
        log "  GRANT SELECT, LOCK TABLES, SHOW VIEW, EVENT, TRIGGER ON \`$BACKUP_DB\`.* TO '$BACKUP_USER'@'%';"
        log "  FLUSH PRIVILEGES;"
    fi
else
    log "✅ 备份用户已具有远程连接权限"
fi

# 测试备份用户连接
log "测试备份用户连接..."
if mysql -h"$DB_HOST" -P"$DB_PORT" -u"$BACKUP_USER" -p"$BACKUP_PASS" -e "SELECT 1" >/dev/null 2>&1; then
    log "✅ 备份用户连接测试成功"
else
    log "⚠️  警告: 备份用户连接测试失败，但将继续尝试备份"
fi

log "=========================================="
log "MySQL 权限初始化完成"
log "=========================================="

