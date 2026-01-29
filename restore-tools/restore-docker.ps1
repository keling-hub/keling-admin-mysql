# MySQL数据恢复脚本 (Docker版本 - PowerShell)

param(
    [string]$BackupFile,
    [string]$ContainerName = "keling-mysql",
    [string]$BackupContainer = "keling-unified-backup",
    [string]$DbName = "kbk",
    [string]$DbUser = "keling",
    [string]$DbPass = "131415",
    [string]$BackupDir = "",
    [switch]$ListBackups
)

Write-Host "========================================" -ForegroundColor Green
Write-Host "  MySQL数据恢复工具 (Docker版本)" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

# 检查容器是否存在
Write-Host "检查Docker容器..." -ForegroundColor Yellow
$mysqlContainer = docker ps -a --filter "name=$ContainerName" --format "{{.Names}}"
if (-not $mysqlContainer) {
    Write-Host "错误: MySQL容器 '$ContainerName' 不存在或未运行" -ForegroundColor Red
    Write-Host "请先启动服务: docker-compose up -d" -ForegroundColor Yellow
    exit 1
}

$backupContainerExists = docker ps -a --filter "name=$BackupContainer" --format "{{.Names}}"
if (-not $backupContainerExists) {
    Write-Host "警告: 备份容器 '$BackupContainer' 不存在，将尝试从本地文件恢复" -ForegroundColor Yellow
}

# 查找备份文件
Write-Host "`n查找备份文件..." -ForegroundColor Yellow
$backupFiles = @()

# 1. 检查容器内的备份目录
if ($backupContainerExists) {
    Write-Host "  检查容器内备份目录..." -ForegroundColor Cyan
    $containerBackups = docker exec $BackupContainer sh -c "find /data/mysql /mnt/e-drive/mysql -name '*.sql.gz' -o -name '*.sql' 2>/dev/null | head -20" 2>&1
    if ($containerBackups -and $containerBackups -notmatch "Error|No such file") {
        $containerBackups -split "`n" | Where-Object { $_ -and $_ -notmatch "Error|No such file" } | ForEach-Object {
            $backupFiles += @{
                Path = $_
                Source = "容器"
                Type = if ($_ -match "\.gz$") { "gz" } else { "sql" }
            }
        }
    }
}

# 2. 检查本地E盘备份
Write-Host "  检查E盘备份目录..." -ForegroundColor Cyan
$eDriveBackup = "E:\keling-backup\mysql"
if (Test-Path $eDriveBackup) {
    $localBackups = Get-ChildItem -Path $eDriveBackup -Recurse -Filter "*.sql*" -ErrorAction SilentlyContinue
    foreach ($file in $localBackups) {
        $backupFiles += @{
            Path = $file.FullName
            Source = "本地E盘"
            Type = if ($file.Extension -eq ".gz") { "gz" } else { "sql" }
            Size = $file.Length
            Date = $file.LastWriteTime
        }
    }
}

# 3. 检查本地其他备份目录
if ($BackupDir) {
    Write-Host "  检查指定备份目录: $BackupDir" -ForegroundColor Cyan
    if (Test-Path $BackupDir) {
        $localBackups = Get-ChildItem -Path $BackupDir -Recurse -Filter "*.sql*" -ErrorAction SilentlyContinue
        foreach ($file in $localBackups) {
            $backupFiles += @{
                Path = $file.FullName
                Source = "本地指定目录"
                Type = if ($file.Extension -eq ".gz") { "gz" } else { "sql" }
                Size = $file.Length
                Date = $file.LastWriteTime
            }
        }
    }
}

# 列出所有备份文件
if ($ListBackups -or (-not $BackupFile)) {
    Write-Host "`n找到的备份文件:" -ForegroundColor Green
    if ($backupFiles.Count -eq 0) {
        Write-Host "  没有找到备份文件！" -ForegroundColor Red
        Write-Host "`n请检查以下位置:" -ForegroundColor Yellow
        Write-Host "  1. 容器内: /data/mysql 或 /mnt/e-drive/mysql" -ForegroundColor Cyan
        Write-Host "  2. 本地E盘: E:\keling-backup\mysql" -ForegroundColor Cyan
        Write-Host "  3. 或者使用 -BackupFile 参数指定备份文件路径" -ForegroundColor Cyan
        exit 1
    }
    
    $index = 1
    foreach ($backup in $backupFiles) {
        $sizeMB = if ($backup.Size) { [math]::Round($backup.Size / 1MB, 2) } else { 0 }
        $sizeInfo = if ($sizeMB -gt 0) { " ($sizeMB MB)" } else { "" }
        $dateInfo = if ($backup.Date) { " - $($backup.Date.ToString('yyyy-MM-dd HH:mm'))" } else { "" }
        Write-Host "  [$index] $($backup.Path)$sizeInfo$dateInfo [$($backup.Source)]" -ForegroundColor Cyan
        $index++
    }
    
    if (-not $BackupFile) {
        Write-Host ""
        $selected = Read-Host "请选择要恢复的备份文件编号 (1-$($backupFiles.Count))"
        try {
            $selectedIndex = [int]$selected - 1
            if ($selectedIndex -ge 0 -and $selectedIndex -lt $backupFiles.Count) {
                $BackupFile = $backupFiles[$selectedIndex].Path
            } else {
                Write-Host "无效的选择" -ForegroundColor Red
                exit 1
            }
        } catch {
            Write-Host "无效的输入" -ForegroundColor Red
            exit 1
        }
    }
}

# 检查备份文件
if (-not $BackupFile) {
    Write-Host "错误: 未指定备份文件" -ForegroundColor Red
    exit 1
}

$isContainerPath = $BackupFile -match "^/"
$isLocalPath = Test-Path $BackupFile

if (-not $isContainerPath -and -not $isLocalPath) {
    Write-Host "错误: 备份文件不存在: $BackupFile" -ForegroundColor Red
    exit 1
}

Write-Host "`n准备恢复数据库:" -ForegroundColor Yellow
Write-Host "  数据库: $DbName" -ForegroundColor Cyan
Write-Host "  备份文件: $BackupFile" -ForegroundColor Cyan
Write-Host "  容器: $ContainerName" -ForegroundColor Cyan

# 确认操作
Write-Host ""
$confirm = Read-Host "确认要恢复数据库吗？这将覆盖现有数据！(y/N)"
if ($confirm -ne "y" -and $confirm -ne "Y") {
    Write-Host "操作已取消" -ForegroundColor Yellow
    exit 0
}

try {
    # 创建临时文件
    $tempFile = "temp_restore_$(Get-Date -Format 'yyyyMMddHHmmss').sql"
    
    # 处理备份文件
    if ($isContainerPath) {
        # 从容器复制文件
        Write-Host "`n从容器复制备份文件..." -ForegroundColor Yellow
        $containerFile = $BackupFile
        
        # 如果是压缩文件，先复制到临时位置
        if ($BackupFile -match "\.gz$") {
            Write-Host "  解压容器内的备份文件..." -ForegroundColor Cyan
            docker exec $BackupContainer sh -c "gzip -dc $containerFile" > $tempFile
        } else {
            Write-Host "  复制容器内的备份文件..." -ForegroundColor Cyan
            docker exec $BackupContainer cat $containerFile > $tempFile
        }
    } else {
        # 本地文件
        Write-Host "`n处理本地备份文件..." -ForegroundColor Yellow
        
        if ($BackupFile -match "\.gz$") {
            Write-Host "  解压备份文件..." -ForegroundColor Cyan
            # 尝试使用7zip或gzip
            if (Get-Command "7z" -ErrorAction SilentlyContinue) {
                & 7z x $BackupFile -so > $tempFile
            } elseif (Get-Command "gzip" -ErrorAction SilentlyContinue) {
                & gzip -dc $BackupFile > $tempFile
            } else {
                # 使用容器解压
                Write-Host "  使用Docker容器解压..." -ForegroundColor Cyan
                $tempGz = "temp_backup.gz"
                Copy-Item $BackupFile $tempGz
                docker run --rm -v "${PWD}:/data" alpine sh -c "cd /data && gzip -dc $tempGz > $tempFile"
                Remove-Item $tempGz -ErrorAction SilentlyContinue
            }
        } else {
            Copy-Item $BackupFile $tempFile
        }
    }
    
    if (-not (Test-Path $tempFile)) {
        throw "无法创建临时SQL文件"
    }
    
    # 恢复数据库
    Write-Host "`n恢复数据库..." -ForegroundColor Yellow
    Write-Host "  这可能需要几分钟，请耐心等待..." -ForegroundColor Cyan
    
    # 将SQL文件复制到容器并执行
    $tempFileInContainer = "/tmp/restore_$(Get-Date -Format 'yyyyMMddHHmmss').sql"
    
    # 复制文件到容器
    docker cp $tempFile "${ContainerName}:${tempFileInContainer}"
    
    # 执行恢复
    $restoreResult = docker exec $ContainerName sh -c "mysql -u$DbUser -p$DbPass $DbName < $tempFileInContainer 2>&1"
    
    # 清理容器内临时文件
    docker exec $ContainerName sh -c "rm -f $tempFileInContainer" 2>&1 | Out-Null
    
    # 清理本地临时文件
    Remove-Item $tempFile -ErrorAction SilentlyContinue
    
    # 检查恢复是否成功（MySQL 恢复命令的退出码可能不准确，需要检查输出）
    $restoreSuccess = $true
    if ($restoreResult -match "ERROR|error|Error") {
        $restoreSuccess = $false
    }
    
    if ($restoreSuccess -and $LASTEXITCODE -eq 0) {
        Write-Host "`n数据库恢复完成！" -ForegroundColor Green
        
        # 验证恢复结果
        Write-Host "`n验证恢复结果..." -ForegroundColor Yellow
        $tableOutput = docker exec $ContainerName mysql -u$DbUser -p$DbPass $DbName -e "SHOW TABLES;" 2>&1
        $tableCount = ($tableOutput | Select-String -Pattern "^\w" | Measure-Object).Count
        Write-Host "  恢复的表数量: $tableCount" -ForegroundColor Cyan
        
        if ($tableCount -gt 0) {
            Write-Host "`n恢复成功！" -ForegroundColor Green
        } else {
            Write-Host "`n警告: 未检测到表，请手动检查数据库" -ForegroundColor Yellow
        }
    } else {
        Write-Host "`n恢复过程中出现错误:" -ForegroundColor Red
        Write-Host $restoreResult -ForegroundColor Yellow
        throw "恢复失败"
    }
    
} catch {
    Write-Host "`n错误: $($_.Exception.Message)" -ForegroundColor Red
    if (Test-Path $tempFile) {
        Remove-Item $tempFile -ErrorAction SilentlyContinue
    }
    exit 1
}

Write-Host "`n完成！" -ForegroundColor Green

