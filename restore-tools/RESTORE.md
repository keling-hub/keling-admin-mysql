# 数据恢复详细说明

## 恢复流程

### 1. 准备工作

- 确保MySQL服务正在运行
- 确认备份文件存在且完整
- 准备足够的磁盘空间

### 2. 选择恢复方式

#### 方式一：使用恢复脚本（推荐）

```bash
# Linux/macOS
./restore-tools/restore.sh

# Windows
restore-tools\restore.bat

# PowerShell
.\restore-tools\restore.ps1
```

#### 方式二：手动恢复

```bash
# 解压备份文件
gunzip backup_file.sql.gz

# 恢复数据库
mysql -u keling -p keling_admin < backup_file.sql
```

### 3. 恢复步骤

1. **停止应用服务**
   ```bash
   # 停止后端服务
   docker-compose -f ../keling-admin-back/docker-compose.yml down
   ```

2. **备份当前数据**（可选但推荐）
   ```bash
   # 创建当前数据备份
   mysqldump -u keling -p keling_admin > current_backup.sql
   ```

3. **执行恢复操作**
   ```bash
   # 使用恢复脚本
   ./restore-tools/restore.sh
   ```

4. **验证恢复结果**
   ```bash
   # 连接数据库检查
   mysql -u keling -p keling_admin -e "SHOW TABLES;"
   ```

5. **重启应用服务**
   ```bash
   # 启动后端服务
   docker-compose -f ../keling-admin-back/docker-compose.yml up -d
   ```

## 恢复选项

### 完整恢复

恢复整个数据库，包括所有表和数据：

```bash
./restore-tools/restore.sh
```

### 部分恢复

只恢复特定的表：

```bash
# 解压备份文件
gunzip backup_file.sql.gz

# 提取特定表的SQL
grep -A 1000 "CREATE TABLE.*table_name" backup_file.sql > table_backup.sql

# 恢复特定表
mysql -u keling -p keling_admin < table_backup.sql
```

### 增量恢复

如果有增量备份文件：

```bash
# 先恢复基础备份
./restore-tools/restore.sh -f base_backup.sql.gz

# 再应用增量备份
mysql -u keling -p keling_admin < incremental_backup.sql
```

## 故障排除

### 恢复失败

1. **检查备份文件**
   ```bash
   # 验证备份文件完整性
   file backup_file.sql.gz
   gunzip -t backup_file.sql.gz
   ```

2. **检查数据库连接**
   ```bash
   # 测试连接
   mysql -u keling -p -e "SELECT 1;"
   ```

3. **检查磁盘空间**
   ```bash
   # 查看可用空间
   df -h
   ```

### 数据不一致

1. **检查表结构**
   ```bash
   mysql -u keling -p keling_admin -e "DESCRIBE table_name;"
   ```

2. **验证数据完整性**
   ```bash
   mysql -u keling -p keling_admin -e "CHECK TABLE table_name;"
   ```

3. **重新恢复**
   ```bash
   # 删除有问题的表
   mysql -u keling -p keling_admin -e "DROP TABLE table_name;"
   
   # 重新恢复
   ./restore-tools/restore.sh
   ```

## 最佳实践

1. **定期测试恢复**
   - 每月测试一次恢复流程
   - 在测试环境中验证备份

2. **文档记录**
   - 记录恢复操作日志
   - 保存恢复配置文件

3. **监控告警**
   - 设置恢复操作监控
   - 配置异常告警机制

4. **安全措施**
   - 限制恢复脚本访问权限
   - 使用加密传输备份文件
   - 定期轮换备份密钥
