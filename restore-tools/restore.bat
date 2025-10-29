@echo off
REM MySQL数据恢复脚本 (Windows版本)

setlocal enabledelayedexpansion

REM 配置变量
set DB_HOST=localhost
set DB_PORT=3306
set DB_NAME=keling_admin
set DB_USER=keling
set DB_PASS=keling123456
set BACKUP_DIR=.\output\mysql

echo MySQL数据恢复工具
echo ==================

REM 检查备份目录
if not exist "%BACKUP_DIR%" (
    echo 错误: 备份目录不存在: %BACKUP_DIR%
    pause
    exit /b 1
)

REM 列出可用的备份文件
echo 可用的备份文件:
dir /b "%BACKUP_DIR%\*.sql.gz" 2>nul || echo 没有找到备份文件

REM 提示用户选择备份文件
echo.
set /p BACKUP_FILE=请输入要恢复的备份文件名 (包含.sql.gz): 

if not exist "%BACKUP_DIR%\%BACKUP_FILE%" (
    echo 错误: 备份文件不存在: %BACKUP_DIR%\%BACKUP_FILE%
    pause
    exit /b 1
)

echo 准备恢复数据库: %DB_NAME%
echo 备份文件: %BACKUP_DIR%\%BACKUP_FILE%

REM 确认操作
set /p CONFIRM=确认要恢复数据库吗？这将覆盖现有数据！(y/N): 
if /i not "%CONFIRM%"=="y" (
    echo 操作已取消
    pause
    exit /b 0
)

REM 解压备份文件
echo 解压备份文件...
gzip -dc "%BACKUP_DIR%\%BACKUP_FILE%" > temp_restore.sql

REM 恢复数据库
echo 恢复数据库...
mysql -h%DB_HOST% -P%DB_PORT% -u%DB_USER% -p%DB_PASS% %DB_NAME% < temp_restore.sql

REM 清理临时文件
del temp_restore.sql

echo 数据库恢复完成！
pause
