# MySQL数据恢复脚本 (PowerShell版本)

param(
    [string]$BackupFile,
    [string]$DbHost = "localhost",
    [int]$DbPort = 3306,
    [string]$DbName = "keling_admin",
    [string]$DbUser = "keling",
    [string]$DbPass = "keling123456",
    [string]$BackupDir = ".\output\mysql"
)

Write-Host "MySQL数据恢复工具" -ForegroundColor Green
Write-Host "==================" -ForegroundColor Green

# 检查备份目录
if (-not (Test-Path $BackupDir)) {
    Write-Host "错误: 备份目录不存在: $BackupDir" -ForegroundColor Red
    exit 1
}

# 如果没有指定备份文件，列出可用的备份文件
if (-not $BackupFile) {
    Write-Host "可用的备份文件:" -ForegroundColor Yellow
    $backupFiles = Get-ChildItem -Path $BackupDir -Filter "*.sql.gz" -ErrorAction SilentlyContinue
    if ($backupFiles) {
        $backupFiles | ForEach-Object { Write-Host "  $($_.Name)" }
    } else {
        Write-Host "  没有找到备份文件" -ForegroundColor Red
        exit 1
    }
    
    $BackupFile = Read-Host "请输入要恢复的备份文件名 (包含.sql.gz)"
}

# 检查备份文件是否存在
$backupPath = Join-Path $BackupDir $BackupFile
if (-not (Test-Path $backupPath)) {
    Write-Host "错误: 备份文件不存在: $backupPath" -ForegroundColor Red
    exit 1
}

Write-Host "准备恢复数据库: $DbName" -ForegroundColor Yellow
Write-Host "备份文件: $backupPath" -ForegroundColor Yellow

# 确认操作
$confirm = Read-Host "确认要恢复数据库吗？这将覆盖现有数据！(y/N)"
if ($confirm -ne "y" -and $confirm -ne "Y") {
    Write-Host "操作已取消" -ForegroundColor Yellow
    exit 0
}

try {
    # 解压备份文件
    Write-Host "解压备份文件..." -ForegroundColor Yellow
    $tempFile = "temp_restore.sql"
    
    # 使用7zip或gzip解压
    if (Get-Command "7z" -ErrorAction SilentlyContinue) {
        & 7z x $backupPath -so > $tempFile
    } elseif (Get-Command "gzip" -ErrorAction SilentlyContinue) {
        & gzip -dc $backupPath > $tempFile
    } else {
        Write-Host "错误: 需要安装7zip或gzip来解压备份文件" -ForegroundColor Red
        exit 1
    }
    
    # 恢复数据库
    Write-Host "恢复数据库..." -ForegroundColor Yellow
    $mysqlCmd = "mysql -h$DbHost -P$DbPort -u$DbUser -p$DbPass $DbName"
    Get-Content $tempFile | & $mysqlCmd
    
    # 清理临时文件
    Remove-Item $tempFile -ErrorAction SilentlyContinue
    
    Write-Host "数据库恢复完成！" -ForegroundColor Green
} catch {
    Write-Host "恢复过程中发生错误: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
