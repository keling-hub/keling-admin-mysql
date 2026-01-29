# 快速恢复脚本 - 自动查找并使用最新的备份文件恢复数据库

param(
    [string]$BackupFile = "",
    [string]$ContainerName = "keling-mysql",
    [string]$DbName = "kbk",
    [string]$DbUser = "keling",
    [string]$DbPass = "131415"
)

Write-Host "========================================" -ForegroundColor Green
Write-Host "  MySQL 数据库快速恢复" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

# 如果没有指定备份文件，自动查找最新的
if (-not $BackupFile) {
    Write-Host "查找最新的备份文件..." -ForegroundColor Yellow
    
    # 检查E盘备份目录
    $eDriveBackup = "E:\keling-backup\mysql"
    $backupFiles = @()
    
    if (Test-Path $eDriveBackup) {
        $backupFiles = Get-ChildItem -Path $eDriveBackup -Filter "*.sql" -ErrorAction SilentlyContinue | 
            Where-Object { $_.Length -gt 0 } | 
            Sort-Object LastWriteTime -Descending
    }
    
    if ($backupFiles.Count -eq 0) {
        Write-Host "错误: 在 E:\keling-backup\mysql 目录下未找到备份文件" -ForegroundColor Red
        Write-Host "请使用 -BackupFile 参数指定备份文件路径" -ForegroundColor Yellow
        exit 1
    }
    
    $BackupFile = $backupFiles[0].FullName
    Write-Host "找到最新备份文件: $BackupFile" -ForegroundColor Cyan
    Write-Host "文件日期: $($backupFiles[0].LastWriteTime)" -ForegroundColor Cyan
    Write-Host ""
}

# 检查备份文件
Write-Host "检查备份文件..." -ForegroundColor Yellow
if (-not (Test-Path $BackupFile)) {
    Write-Host "错误: 备份文件不存在: $BackupFile" -ForegroundColor Red
    exit 1
}

$fileInfo = Get-Item $BackupFile
$fileSizeMB = [math]::Round($fileInfo.Length / 1MB, 2)
Write-Host "备份文件: $BackupFile" -ForegroundColor Cyan
Write-Host "文件大小: $fileSizeMB MB" -ForegroundColor Cyan
Write-Host "文件日期: $($fileInfo.LastWriteTime)" -ForegroundColor Cyan
Write-Host ""

# 检查容器
Write-Host "检查 MySQL 容器..." -ForegroundColor Yellow
$containerStatus = docker ps --filter "name=$ContainerName" --format "{{.Status}}" 2>&1
if (-not $containerStatus -or $containerStatus -match "Error") {
    Write-Host "错误: MySQL 容器不存在或未运行" -ForegroundColor Red
    Write-Host "请先启动服务: docker-compose up -d" -ForegroundColor Yellow
    exit 1
}
Write-Host "容器状态: $containerStatus" -ForegroundColor Cyan
Write-Host ""

# 确认操作
Write-Host "警告: 此操作将覆盖现有数据库 '$DbName' 的所有数据！" -ForegroundColor Red
$confirm = Read-Host "确认要继续吗？(y/N)"
if ($confirm -ne "y" -and $confirm -ne "Y") {
    Write-Host "操作已取消" -ForegroundColor Yellow
    exit 0
}

Write-Host ""
Write-Host "开始恢复数据库..." -ForegroundColor Yellow
Write-Host "这可能需要几分钟，请耐心等待..." -ForegroundColor Cyan

try {
    # 创建临时文件
    $tempFile = "temp_restore_$(Get-Date -Format 'yyyyMMddHHmmss').sql"
    Write-Host "复制备份文件到临时位置..." -ForegroundColor Cyan
    Copy-Item $BackupFile $tempFile
    
    # 复制到容器
    Write-Host "复制文件到容器..." -ForegroundColor Cyan
    $containerTempFile = "/tmp/restore_$(Get-Date -Format 'yyyyMMddHHmmss').sql"
    docker cp $tempFile "${ContainerName}:${containerTempFile}"
    
    if ($LASTEXITCODE -ne 0) {
        throw "复制文件到容器失败"
    }
    
    # 执行恢复
    Write-Host "执行数据库恢复..." -ForegroundColor Cyan
    Write-Host "这可能需要几分钟，请耐心等待..." -ForegroundColor Gray
    $restoreOutput = docker exec $ContainerName sh -c "mysql -u$DbUser -p$DbPass $DbName < $containerTempFile" 2>&1
    
    # 检查恢复结果（MySQL 可能返回警告但不一定是错误）
    if ($restoreOutput -match "ERROR|error|Error" -and $LASTEXITCODE -ne 0) {
        Write-Host "恢复输出: $restoreOutput" -ForegroundColor Yellow
        throw "数据库恢复失败"
    }
    
    # 清理容器内临时文件
    Write-Host "清理临时文件..." -ForegroundColor Cyan
    docker exec $ContainerName sh -c "rm -f $containerTempFile" 2>&1 | Out-Null
    
    # 清理本地临时文件
    Remove-Item $tempFile -ErrorAction SilentlyContinue
    
    Write-Host ""
    Write-Host "数据库恢复完成！" -ForegroundColor Green
    
    # 验证恢复结果
    Write-Host ""
    Write-Host "验证恢复结果..." -ForegroundColor Yellow
    $tableOutput = docker exec $ContainerName mysql -u$DbUser -p$DbPass $DbName -e "SHOW TABLES;" 2>&1
    $tableCount = ($tableOutput | Select-String -Pattern "^\w" | Measure-Object).Count
    Write-Host "恢复的表数量: $tableCount" -ForegroundColor Cyan
    
    if ($tableCount -gt 0) {
        Write-Host ""
        Write-Host "恢复成功！" -ForegroundColor Green
    } else {
        Write-Host ""
        Write-Host "警告: 未检测到表，请手动检查数据库" -ForegroundColor Yellow
    }
    
} catch {
    Write-Host ""
    Write-Host "错误: $($_.Exception.Message)" -ForegroundColor Red
    if (Test-Path $tempFile) {
        Remove-Item $tempFile -ErrorAction SilentlyContinue
    }
    exit 1
}

Write-Host ""
Write-Host "完成！" -ForegroundColor Green

