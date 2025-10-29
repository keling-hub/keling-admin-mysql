# 数据恢复工具

本目录包含用于恢复MySQL数据库和媒体文件的工具脚本。

## 文件说明

- `restore.sh` - Linux/macOS恢复脚本
- `restore.bat` - Windows批处理恢复脚本  
- `restore.ps1` - PowerShell恢复脚本
- `README.md` - 本说明文件

## 使用方法

### Linux/macOS

```bash
# 给脚本执行权限
chmod +x restore.sh

# 运行恢复脚本
./restore.sh
```

### Windows (批处理)

```cmd
# 直接运行
restore.bat
```

### Windows (PowerShell)

```powershell
# 运行PowerShell脚本
.\restore.ps1

# 或者指定参数
.\restore.ps1 -BackupFile "backup_20240101_120000.sql.gz" -DbHost "localhost"
```

## 参数说明

- `BackupFile` - 备份文件名（可选，不指定时会列出可用文件）
- `DbHost` - 数据库主机地址（默认：localhost）
- `DbPort` - 数据库端口（默认：3306）
- `DbName` - 数据库名称（默认：keling_admin）
- `DbUser` - 数据库用户名（默认：keling）
- `DbPass` - 数据库密码（默认：keling123456）
- `BackupDir` - 备份文件目录（默认：./output/mysql）

## 注意事项

1. 恢复操作会覆盖现有数据，请谨慎操作
2. 确保数据库服务正在运行
3. 确保有足够的磁盘空间
4. 建议在恢复前先备份当前数据

## 故障排除

### 常见错误

1. **连接失败**
   - 检查数据库服务是否启动
   - 验证连接参数是否正确
   - 确认网络连接正常

2. **权限错误**
   - 确保数据库用户有足够权限
   - 检查文件系统权限

3. **备份文件损坏**
   - 验证备份文件完整性
   - 尝试重新生成备份

## 安全建议

1. 定期测试恢复流程
2. 在非生产环境验证备份
3. 使用强密码保护数据库
4. 限制恢复脚本的访问权限
