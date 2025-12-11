# Keling Admin MySQL 数据恢复工具

> **注意**：Docker 服务（MySQL、Redis、统一备份等）已由 `keling-admin-back` 统一管理，请查看后端的 `docker-compose.yml` 进行服务管理。

## 📁 目录说明

本目录包含数据库配置文件和数据恢复工具：

```
keling-admin-mysql/
├── unified-backup/              # 统一备份服务（由后端 docker-compose.yml 管理）
│   ├── Dockerfile               # 备份容器构建文件
│   ├── entrypoint.sh            # 主入口脚本
│   ├── mysql-backup.sh          # MySQL备份脚本
│   ├── media-cleanup.sh         # 媒体清理脚本
│   ├── export_browse.py         # 可浏览副本导出
│   └── sync-to-e-drive.sh       # E盘同步脚本
├── restore-tools/                # 数据恢复工具
│   ├── restore.sh               # Linux/macOS 恢复脚本
│   ├── restore.bat              # Windows 批处理恢复脚本
│   ├── restore.ps1              # PowerShell 恢复脚本
│   ├── restore-docker.ps1       # Docker 环境恢复脚本（推荐）
│   └── README.md                # 恢复工具说明
├── my.cnf                       # MySQL 配置文件
└── skip-name-resolve.cnf        # MySQL DNS 解析配置
```

## 🚀 服务管理

### 启动/停止服务

所有 Docker 服务由后端统一管理：

```bash
# 进入后端目录
cd ../keling-admin-back

# 启动所有服务（包括 MySQL、Redis、统一备份等）
docker-compose up -d

# 停止所有服务
docker-compose down

# 查看服务状态
docker-compose ps

# 查看日志
docker-compose logs unified-backup
```

### 手动执行备份

```bash
# 进入后端目录
cd ../keling-admin-back

# MySQL备份
docker-compose exec unified-backup /app/mysql/backup.sh

# 媒体备份
docker-compose exec unified-backup /app/media/cleanup.sh

# E盘同步
docker-compose exec unified-backup /app/sync-to-e-drive.sh
```

## 📊 备份系统功能

- **自动备份**：每天00:00和12:00执行MySQL和媒体文件备份
- **E盘同步**：备份完成后自动同步到E盘
- **智能保留**：
  - 删除12:00备份（只保留00:00备份）
  - 最近一个月：保留所有备份
  - 超过一个月：只保留每月1号备份
- **容量优化**：Docker卷只保存1天，E盘长期存储

## 🔧 数据恢复

### 使用恢复工具

详细说明请查看 [`restore-tools/README.md`](./restore-tools/README.md)

#### Windows (PowerShell - 推荐)

```powershell
cd restore-tools
.\restore-docker.ps1
```

#### Linux/macOS

```bash
cd restore-tools
chmod +x restore.sh
./restore.sh
```

#### Windows (批处理)

```cmd
cd restore-tools
restore.bat
```

### 查看备份文件

#### 📁 MySQL 数据库备份文件

**Docker卷（临时存储，只保留当天数据）:**
```bash
# 容器内路径
docker exec keling-unified-backup ls -la /data/mysql/

# 文件格式: YYYY-MM-DD_HHMM.sql
# 示例: 2025-11-08_0000.sql, 2025-11-08_1200.sql
```

**E盘（长期存储，自动同步）:**
```bash
# Windows 路径
dir E:\keling-backup\mysql\

# 容器内路径
docker exec keling-unified-backup ls -la /mnt/e-drive/keling-backup/mysql/
```

**保留策略:**
- 删除12:00备份（只保留00:00备份）
- 最近一个月：保留所有00:00备份
- 超过一个月：只保留每月1号00:00备份

#### 📁 媒体文件备份

**Docker卷（临时存储）:**
```bash
docker exec keling-unified-backup ls -la /data/
```

**E盘（长期存储）:**
```bash
# Windows 路径
dir E:\keling-backup\media\

# 容器内路径
docker exec keling-unified-backup ls -la /mnt/e-drive/keling-backup/media/
```

## ⚙️ 配置说明

### 备份配置

备份服务配置在后端的 `docker-compose.yml` 和 `.env.docker` 文件中：

```bash
# 后端目录
cd ../keling-admin-back

# 查看配置
cat docker-compose.yml | grep -A 30 unified-backup
cat .env.docker
```

### MySQL 配置

- `my.cnf` - MySQL 主配置文件
- `skip-name-resolve.cnf` - 跳过 DNS 解析配置

这些配置文件由后端的 `docker-compose.yml` 挂载到 MySQL 容器中。

## 📈 数据流向

```
数据库 → Docker卷（临时存储） → E盘（长期存储）
```

### 📂 备份文件保存位置

#### MySQL 数据库备份

1. **Docker卷（临时存储）**
   - 容器内路径: `/data/mysql`
   - 文件格式: `YYYY-MM-DD_HHMM.sql`
   - 保留策略: 只保留当天数据，自动清理历史数据

2. **E盘（长期存储）**
   - Windows路径: `E:\keling-backup\mysql\`
   - 容器内路径: `/mnt/e-drive/keling-backup/mysql`
   - 保留策略:
     - 删除12:00备份（只保留00:00备份）
     - 最近一个月：保留所有00:00备份
     - 超过一个月：只保留每月1号00:00备份

#### 媒体文件备份

1. **Docker卷（临时存储）**
   - 容器内路径: `/data/`

2. **E盘（长期存储）**
   - Windows路径: `E:\keling-backup\media\`
   - 容器内路径: `/mnt/e-drive/keling-backup/media`

## 🛠️ 故障排除

### 查看备份日志

```bash
# 进入后端目录
cd ../keling-admin-back

# 查看统一备份日志
docker-compose logs unified-backup

# 查看MySQL备份日志
docker-compose exec unified-backup cat /var/log/mysql-backup.log

# 查看媒体备份日志
docker-compose exec unified-backup cat /var/log/media-backup.log
```

### 检查备份文件

```bash
# 检查E盘挂载
docker exec keling-unified-backup ls -la /mnt/e-drive/keling-backup/mysql/

# 检查容器内备份
docker exec keling-unified-backup ls -la /data/mysql/
```

### 备份失败排查

```bash
# 检查数据库连接
docker exec keling-unified-backup mysql -h keling-mysql -u root -p131415 -e "SELECT 1"

# 查看详细错误
cd ../keling-admin-back
docker-compose logs unified-backup
```

## 📝 注意事项

1. **Docker 服务管理**：所有服务由 `keling-admin-back/docker-compose.yml` 统一管理
2. **配置文件**：备份相关配置在后端的 `.env.docker` 文件中
3. **恢复操作**：恢复操作会覆盖现有数据，请谨慎操作
4. **备份位置**：备份文件存储在 E盘 `E:\keling-backup\mysql\`

## 🔗 相关文档

- [恢复工具说明](./restore-tools/README.md)
- [恢复详细文档](./restore-tools/RESTORE.md)
- [备份修复总结](./BACKUP_FIX_SUMMARY.md)
- [后端 Docker 部署说明](../keling-admin-back/Docker部署说明.md)
