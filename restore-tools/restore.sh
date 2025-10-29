#!/bin/bash

# MySQL数据恢复脚本

set -e

# 配置变量
DB_HOST=${DB_HOST:-localhost}
DB_PORT=${DB_PORT:-3306}
DB_NAME=${MYSQL_DATABASE:-keling_admin}
DB_USER=${MYSQL_USER:-keling}
DB_PASS=${MYSQL_PASSWORD:-keling123456}
BACKUP_DIR=${BACKUP_DIR:-./output/mysql}

echo "MySQL数据恢复工具"
echo "=================="

# 检查备份目录
if [ ! -d "$BACKUP_DIR" ]; then
    echo "错误: 备份目录不存在: $BACKUP_DIR"
    exit 1
fi

# 列出可用的备份文件
echo "可用的备份文件:"
ls -la $BACKUP_DIR/*.sql.gz 2>/dev/null || echo "没有找到备份文件"

# 提示用户选择备份文件
echo ""
read -p "请输入要恢复的备份文件名 (包含.sql.gz): " BACKUP_FILE

if [ ! -f "$BACKUP_DIR/$BACKUP_FILE" ]; then
    echo "错误: 备份文件不存在: $BACKUP_DIR/$BACKUP_FILE"
    exit 1
fi

echo "准备恢复数据库: $DB_NAME"
echo "备份文件: $BACKUP_DIR/$BACKUP_FILE"

# 确认操作
read -p "确认要恢复数据库吗？这将覆盖现有数据！(y/N): " CONFIRM
if [[ ! $CONFIRM =~ ^[Yy]$ ]]; then
    echo "操作已取消"
    exit 0
fi

# 解压备份文件
echo "解压备份文件..."
gunzip -c "$BACKUP_DIR/$BACKUP_FILE" > /tmp/restore.sql

# 恢复数据库
echo "恢复数据库..."
mysql -h$DB_HOST -P$DB_PORT -u$DB_USER -p$DB_PASS $DB_NAME < /tmp/restore.sql

# 清理临时文件
rm -f /tmp/restore.sql

echo "数据库恢复完成！"
