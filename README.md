# Keling Admin MySQL 备份系统

## 🎯 功能特性

- **自动备份**：每天00:00和12:00执行MySQL和媒体文件备份
- **E盘同步**：备份完成后自动同步到E盘
- **智能保留**：
  - 删除12:00备份（只保留00:00备份）
  - 最近一个月：保留所有备份
  - 超过一个月：只保留每月1号备份
- **容量优化**：Docker卷只保存1天，E盘长期存储

## 🚀 快速开始

### 1. 启动备份服务
```bash
docker-compose up -d
```

### 2. 查看服务状态
```bash
docker-compose ps
docker-compose logs unified-backup
```

### 3. 手动执行备份
```bash
# MySQL备份
docker-compose exec unified-backup /app/mysql/backup.sh

# 媒体备份
docker-compose exec unified-backup /app/media/cleanup.sh
```

## 📁 文件结构

```
keling-admin-mysql/
├── docker-compose.yml              # Docker配置
├── unified-backup/                 # 备份服务
│   ├── Dockerfile                  # 容器构建文件
│   ├── entrypoint.sh              # 主入口脚本
│   ├── mysql-backup.sh            # MySQL备份脚本
│   ├── media-cleanup.sh           # 媒体清理脚本
│   ├── export_browse.py           # 可浏览副本导出
│   └── sync-to-e-drive.sh         # E盘同步脚本
└── restore-tools/                  # 恢复工具
```

## ⚙️ 配置说明

### 备份时间
- **MySQL备份**：每天00:00和12:00
- **媒体备份**：每天00:30和12:30
- **E盘同步**：备份完成后自动执行

### 存储策略
- **Docker卷**：只保存当天数据（中转存储）
- **E盘**：主要长期存储，按策略保留历史数据

### 环境变量
```bash
# 数据库配置
DB_HOST=keling-mysql
DB_PORT=3306
DB_USER=root
DB_PASSWORD=131415
DB_NAME=kbk

# 备份配置
MAX_BACKUPS=1  # Docker卷保留天数
```

## 📊 数据流向

```
数据库 → Docker卷（当天数据） → E盘（长期存储）
```

## 🔧 管理命令

### 查看备份文件
```bash
# 查看E盘备份
ls -la E:\keling-backup\mysql\

# 查看容器内备份
docker-compose exec unified-backup ls -la /data/mysql/
```

### 查看日志
```bash
# 查看备份日志
docker-compose logs unified-backup

# 查看MySQL备份日志
docker-compose exec unified-backup cat /var/log/mysql-backup.log

# 查看媒体备份日志
docker-compose exec unified-backup cat /var/log/media-backup.log
```

### 手动同步到E盘
```bash
# 手动执行E盘同步
docker-compose exec unified-backup /app/sync-to-e-drive.sh
```

## 🛠️ 故障排除

### 容器无法启动
```bash
# 检查网络
docker network ls | grep keling-net

# 创建网络
docker network create keling-net
```

### E盘同步失败
```bash
# 检查E盘挂载
docker-compose exec unified-backup ls -la /mnt/e-drive/

# 检查权限
docker-compose exec unified-backup ls -la /mnt/e-drive/keling-backup/
```

### 备份失败
```bash
# 检查数据库连接
docker-compose exec unified-backup mysql -h keling-mysql -u root -p131415 -e "SELECT 1"

# 查看详细错误
docker-compose logs unified-backup
```

## 📈 存储优化

| 位置 | 保留策略 | 用途 |
|------|----------|------|
| Docker卷 | 当天数据 | 临时中转 |
| E盘 | 智能保留 | 主要长期存储 |

## ✅ 优势

1. **自动化**：无需手动干预，定时执行
2. **智能保留**：自动清理过期备份，节省空间
3. **容量优化**：Docker卷只保存当天数据，避免容量不足
4. **数据安全**：E盘长期存储，完整备份历史
5. **集成化**：所有功能集成在容器内部，无需外部脚本

## 🎉 总结

现在备份系统完全集成在Docker容器内部：
- ✅ 自动备份和同步
- ✅ 智能保留策略
- ✅ 容量优化
- ✅ 无需外部脚本