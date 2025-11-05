# 快速开始指南

> **注意**：Docker 服务已由 `keling-admin-back` 统一管理，本目录主要提供数据恢复工具。

## 1. 环境准备

确保已安装以下工具：
- Docker 和 Docker Compose
- MySQL客户端工具（可选，用于数据恢复）

## 2. 启动服务

所有服务由后端统一管理：

```bash
# 进入后端目录
cd ../../keling-admin-back

# 启动所有服务（包括 MySQL、Redis、统一备份等）
docker-compose up -d

# 查看服务状态
docker-compose ps
```

## 3. 验证服务

```bash
# 进入后端目录
cd ../../keling-admin-back

# 检查服务状态
docker-compose ps

# 查看 MySQL 日志
docker-compose logs mysql

# 连接数据库
docker-compose exec mysql mysql -u keling -p kbk
```

## 4. 数据备份

备份服务由后端的统一备份服务自动执行：

```bash
# 进入后端目录
cd ../../keling-admin-back

# 查看备份服务状态
docker-compose ps unified-backup

# 查看备份日志
docker-compose logs unified-backup

# 手动执行 MySQL 备份
docker-compose exec unified-backup /app/mysql/backup.sh

# 查看备份文件（E盘）
# Windows: dir E:\keling-backup\mysql\
# 容器内: docker exec keling-unified-backup ls -la /data/mysql/
```

## 5. 数据恢复

使用恢复工具恢复数据：

### Windows (PowerShell - 推荐)

```powershell
# 进入恢复工具目录
cd restore-tools

# 运行恢复脚本（会自动查找备份文件）
.\restore-docker.ps1
```

### Linux/macOS

```bash
# 进入恢复工具目录
cd restore-tools

# 给脚本执行权限
chmod +x restore.sh

# 运行恢复脚本
./restore.sh
```

### Windows (批处理)

```cmd
cd restore-tools
restore.bat
```

详细说明请查看 [README.md](./README.md)

## 6. 停止服务

```bash
# 进入后端目录
cd ../../keling-admin-back

# 停止所有服务
docker-compose down

# 停止并删除数据卷（谨慎操作，会删除数据）
docker-compose down -v
```

## 常用命令

### 服务管理

```bash
# 进入后端目录
cd ../../keling-admin-back

# 重启服务
docker-compose restart

# 查看所有服务日志
docker-compose logs -f

# 查看特定服务日志
docker-compose logs -f mysql
docker-compose logs -f unified-backup
```

### 数据库操作

```bash
# 进入 MySQL 容器
docker exec -it keling-mysql bash

# 连接数据库
docker exec -it keling-mysql mysql -u keling -p kbk

# 执行 SQL
docker exec keling-mysql mysql -ukeling -p131415 kbk -e "SHOW TABLES;"
```

### 备份管理

```bash
# 查看备份文件（E盘）
# Windows PowerShell
Get-ChildItem E:\keling-backup\mysql\ -Filter "*.sql*" | Sort-Object LastWriteTime -Descending

# 查看容器内备份
docker exec keling-unified-backup ls -la /data/mysql/

# 手动执行备份
docker exec keling-unified-backup /app/mysql/backup.sh
```

### 清理

```bash
# 清理未使用的镜像
docker system prune

# 清理未使用的卷
docker volume prune
```

## 相关文档

- [恢复工具说明](./README.md)
- [恢复详细文档](./RESTORE.md)
- [主目录 README](../README.md)
