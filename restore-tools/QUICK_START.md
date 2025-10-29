# 快速开始指南

## 1. 环境准备

确保已安装以下工具：
- Docker 和 Docker Compose
- MySQL客户端工具（可选）

## 2. 启动服务

```bash
# 复制环境配置文件
cp env.example .env

# 编辑配置文件（可选）
nano .env

# 启动MySQL服务
docker-compose up -d mysql
```

## 3. 验证服务

```bash
# 检查服务状态
docker-compose ps

# 查看日志
docker-compose logs mysql

# 连接数据库
docker-compose exec mysql mysql -u keling -p keling_admin
```

## 4. 数据备份

```bash
# 手动备份
docker-compose run --rm mysql-backup

# 查看备份文件
ls output/mysql/
```

## 5. 数据恢复

```bash
# 使用恢复工具
./restore-tools/restore.sh
```

## 6. 停止服务

```bash
# 停止所有服务
docker-compose down

# 停止并删除数据卷（谨慎操作）
docker-compose down -v
```

## 常用命令

```bash
# 重启服务
docker-compose restart mysql

# 进入容器
docker-compose exec mysql bash

# 查看容器日志
docker-compose logs -f mysql

# 清理未使用的镜像
docker system prune
```
