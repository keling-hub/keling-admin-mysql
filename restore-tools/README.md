# MySQL 数据库恢复工具

本目录包含用于恢复 MySQL 数据库的 Docker 版本恢复工具。

## 文件说明

- `restore-docker.ps1` - 完整功能恢复脚本（支持列出备份、交互式选择等）
- `quick-restore.ps1` - 快速恢复脚本（自动查找最新备份，推荐日常使用）
- `README.md` - 本说明文件

## 快速开始

### 方法1：快速恢复（推荐）

使用 `quick-restore.ps1` 脚本，自动查找最新的备份文件并恢复：

```powershell
# 进入恢复工具目录
cd keling-admin-mysql\restore-tools

# 自动查找最新备份并恢复（推荐）
.\quick-restore.ps1

# 或者指定备份文件
.\quick-restore.ps1 -BackupFile "E:\keling-backup\mysql\2025-12-29_1608.sql"

# 自定义数据库参数
.\quick-restore.ps1 -DbName "kbk" -DbUser "keling" -DbPass "131415"
```

### 方法2：完整功能恢复

使用 `restore-docker.ps1` 脚本，功能更完整：

```powershell
# 列出所有可用备份文件
.\restore-docker.ps1 -ListBackups

# 交互式恢复（会列出所有备份供选择）
.\restore-docker.ps1

# 直接指定备份文件恢复
.\restore-docker.ps1 -BackupFile "E:\keling-backup\mysql\2025-12-29_1608.sql"

# 使用容器内的备份文件
.\restore-docker.ps1 -BackupFile "/mnt/e-drive/mysql/2025-12-29_1608.sql"

# 自定义所有参数
.\restore-docker.ps1 `
    -BackupFile "E:\keling-backup\mysql\2025-12-29_1608.sql" `
    -ContainerName "keling-mysql" `
    -DbName "kbk" `
    -DbUser "keling" `
    -DbPass "131415"
```

## 参数说明

### quick-restore.ps1 参数

- `BackupFile` - 备份文件路径（可选，不指定时自动查找最新的）
- `ContainerName` - MySQL容器名称（默认：keling-mysql）
- `DbName` - 数据库名称（默认：kbk）
- `DbUser` - 数据库用户名（默认：keling）
- `DbPass` - 数据库密码（默认：131415）

### restore-docker.ps1 参数

- `BackupFile` - 备份文件路径（可选，不指定时会列出可用文件供选择）
- `ContainerName` - MySQL容器名称（默认：keling-mysql）
- `BackupContainer` - 备份容器名称（默认：keling-unified-backup）
- `DbName` - 数据库名称（默认：kbk）
- `DbUser` - 数据库用户名（默认：keling）
- `DbPass` - 数据库密码（默认：131415）
- `BackupDir` - 自定义备份文件目录（可选）
- `ListBackups` - 仅列出备份文件，不执行恢复

## 备份文件位置

脚本会自动在以下位置查找备份文件：

1. **E盘备份目录**（主要位置）
   - `E:\keling-backup\mysql\*.sql`

2. **容器内备份目录**（如果备份容器存在）
   - `/data/mysql/*.sql` - Docker卷中的临时备份
   - `/mnt/e-drive/mysql/*.sql` - E盘挂载的长期备份

3. **用户指定目录**（通过 `-BackupDir` 参数）

## 使用示例

### 示例1：快速恢复（最简单）

```powershell
cd keling-admin-mysql\restore-tools
.\quick-restore.ps1
```

脚本会自动：
1. 查找 E 盘最新的备份文件
2. 显示备份文件信息
3. 询问确认
4. 执行恢复
5. 验证恢复结果

### 示例2：恢复指定文件

```powershell
.\quick-restore.ps1 -BackupFile "E:\keling-backup\mysql\2025-12-29_1608.sql"
```

### 示例3：查看所有可用备份

```powershell
.\restore-docker.ps1 -ListBackups
```

### 示例4：交互式选择备份

```powershell
.\restore-docker.ps1
```

脚本会列出所有找到的备份文件，您可以选择要恢复的编号。

## 恢复流程

### 1. 准备工作

- 确保 Docker 服务正在运行
- 确保 MySQL 容器（keling-mysql）正在运行
- 确认备份文件存在且完整
- 准备足够的磁盘空间

### 2. 执行恢复

```powershell
# 快速恢复（推荐）
.\quick-restore.ps1

# 或完整功能恢复
.\restore-docker.ps1
```

### 3. 验证恢复结果

恢复完成后，脚本会自动验证表数量。您也可以手动验证：

```powershell
# 手动验证表数量
docker exec keling-mysql mysql -ukeling -p131415 kbk -e "SHOW TABLES;"

# 检查数据库大小
docker exec keling-mysql mysql -ukeling -p131415 kbk -e "SELECT table_schema as 'Database', ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS 'Size (MB)' FROM information_schema.tables WHERE table_schema='kbk';"
```

## 故障排除

### 问题1：找不到备份文件

**错误信息**：
```
错误: 在 E:\keling-backup\mysql 目录下未找到备份文件
```

**解决方法**：
- 检查 E 盘备份目录是否存在
- 使用 `-BackupFile` 参数指定备份文件路径
- 检查备份文件是否被删除或移动

### 问题2：容器不存在

**错误信息**：
```
错误: MySQL 容器不存在或未运行
```

**解决方法**：
```powershell
# 进入后端目录
cd ..\..\keling-admin-back

# 启动服务
docker-compose up -d
```

### 问题3：恢复失败

**错误信息**：
```
数据库恢复失败
```

**解决方法**：
1. 检查数据库连接参数是否正确
2. 验证备份文件是否完整
3. 查看 MySQL 容器日志：
   ```powershell
   docker logs keling-mysql
   ```
4. 检查容器内临时文件：
   ```powershell
   docker exec keling-mysql ls -la /tmp/restore_*.sql
   ```

### 问题4：权限错误

**错误信息**：
```
复制文件到容器失败
```

**解决方法**：
- 确保 Docker 有权限访问备份文件
- 检查 Docker Desktop 的 Shared Drives 设置
- 尝试以管理员身份运行 PowerShell

### 问题5：编码问题

如果 PowerShell 脚本出现编码相关的错误，可以：

1. **直接使用 Docker 命令恢复**（备选方案）
   ```powershell
   # 复制备份文件到容器
   docker cp "E:\keling-backup\mysql\2025-12-29_1608.sql" keling-mysql:/tmp/restore.sql
   
   # 执行恢复
   docker exec keling-mysql sh -c "mysql -ukeling -p131415 kbk < /tmp/restore.sql"
   
   # 清理临时文件
   docker exec keling-mysql sh -c "rm -f /tmp/restore.sql"
   ```

2. **重新保存文件为 UTF-8 BOM 编码**
   ```powershell
   $content = Get-Content .\quick-restore.ps1 -Raw -Encoding UTF8
   [System.IO.File]::WriteAllText("$PWD\quick-restore.ps1", $content, [System.Text.UTF8Encoding]::new($true))
   ```

## 注意事项

1. **数据覆盖警告**：恢复操作会覆盖现有数据库的所有数据，请谨慎操作
2. **容器状态**：确保 MySQL 容器正在运行
3. **备份文件**：确保备份文件完整且可读
4. **磁盘空间**：确保有足够的磁盘空间用于恢复
5. **恢复时间**：大型数据库恢复可能需要几分钟到几十分钟

## 最佳实践

1. **定期测试恢复流程**
   - 每月在测试环境测试一次恢复流程
   - 验证备份文件完整性
   - 记录恢复时间，评估 RTO（恢复时间目标）

2. **恢复前备份**
   - 恢复前先备份当前数据（可选但推荐）
   ```powershell
   docker-compose exec unified-backup /app/mysql/backup.sh
   ```

3. **验证恢复结果**
   - 恢复后检查表数量和数据完整性
   - 验证关键业务数据是否正确

4. **文档记录**
   - 记录所有恢复操作日志
   - 保存恢复配置文件
   - 记录恢复过程中的问题和解决方案

## Linux/macOS 使用

如果需要在 Linux/macOS 上使用，需要安装 PowerShell Core：

```bash
# macOS
brew install powershell

# Linux (Ubuntu/Debian)
# 参考: https://docs.microsoft.com/powershell/scripting/install/installing-powershell-core-on-linux

# 使用 PowerShell Core 运行脚本
cd restore-tools
pwsh restore-docker.ps1
pwsh quick-restore.ps1
```

## 相关文档

- [主目录 README](../README.md) - MySQL 配置和备份系统说明
