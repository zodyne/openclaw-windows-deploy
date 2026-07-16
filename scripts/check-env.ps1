# 环境检测脚本
# 在部署前运行，检查系统是否满足要求
param(
    [switch]$Json  # 以 JSON 格式输出结果
)

$results = @{
    os = ""
    osArch = ""
    psVersion = ""
    isAdmin = $false
    nodeInstalled = $false
    nodeVersion = ""
    npmInstalled = $false
    npmVersion = ""
    gitInstalled = $false
    ollamaInstalled = $false
    networkOk = $false
    diskFreeGB = 0
    memoryGB = 0
    issues = @()
    recommendations = @()
}

# OS
$os = Get-CimInstance Win32_OperatingSystem
$results.os = "$($os.Caption)"
$results.osArch = $os.OSArchitecture

# PS Version
$results.psVersion = $PSVersionTable.PSVersion.ToString()

# Admin
$results.isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if (-not $results.isAdmin) {
    $results.recommendations += "建议以管理员身份运行以获得最佳体验"
}

# Node.js
try {
    $v = node --version 2>$null
    $results.nodeInstalled = $true
    $results.nodeVersion = $v
    $major = [int]($v -replace 'v','' -split '\.')[0]
    if ($major -lt 22) {
        $results.issues += "Node.js 版本过低 ($v)，需要 ≥ 22.19"
    }
} catch {
    $results.issues += "Node.js 未安装"
}

# npm
try {
    $v = npm --version 2>$null
    $results.npmInstalled = $true
    $results.npmVersion = $v
} catch {
    $results.issues += "npm 不可用"
}

# Git
try {
    git --version 2>$null | Out-Null
    $results.gitInstalled = $true
} catch {
    $results.recommendations += "Git 未安装（非必需但推荐）"
}

# Ollama
try {
    ollama --version 2>$null | Out-Null
    $results.ollamaInstalled = $true
} catch {}

# Network
try {
    $null = Invoke-WebRequest -Uri "https://open.bigmodel.cn" -TimeoutSec 5 -UseBasicParsing
    $results.networkOk = $true
} catch {
    $results.issues += "无法访问 open.bigmodel.cn"
}

# Disk
$disk = Get-PSDrive C -ErrorAction SilentlyContinue
if ($disk) {
    $results.diskFreeGB = [math]::Round($disk.Free / 1GB, 1)
    if ($results.diskFreeGB -lt 5) {
        $results.issues += "C 盘剩余空间不足 5GB"
    }
}

# Memory
$results.memoryGB = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 1)

if ($Json) {
    $results | ConvertTo-Json -Depth 3
} else {
    Write-Host "╔══════════════════════════════════════╗"
    Write-Host "║   OpenClaw 环境检测报告              ║"
    Write-Host "╚══════════════════════════════════════╝"
    Write-Host ""
    Write-Host "系统: $($results.os) ($($results.osArch))"
    Write-Host "PowerShell: $($results.psVersion)"
    Write-Host "管理员: $($results.isAdmin)"
    Write-Host "内存: $($results.memoryGB) GB"
    Write-Host "磁盘: $($results.diskFreeGB) GB 可用"
    Write-Host ""
    Write-Host "--- 组件 ---"
    Write-Host "Node.js: $(if ($results.nodeInstalled) { "✓ $($results.nodeVersion)" } else { "✗ 未安装" })"
    Write-Host "npm:     $(if ($results.npmInstalled) { "✓ $($results.npmVersion)" } else { "✗ 不可用" })"
    Write-Host "Git:     $(if ($results.gitInstalled) { "✓" } else { "✗ 未安装（可选）" })"
    Write-Host "Ollama:  $(if ($results.ollamaInstalled) { "✓" } else { "✗ 未安装（可选）" })"
    Write-Host "网络:    $(if ($results.networkOk) { "✓" } else { "✗" })"
    Write-Host ""
    
    if ($results.issues.Count -gt 0) {
        Write-Host "--- 问题 ---" -ForegroundColor Red
        $results.issues | ForEach-Object { Write-Host "✗ $_" -ForegroundColor Red }
        Write-Host ""
    }
    
    if ($results.recommendations.Count -gt 0) {
        Write-Host "--- 建议 ---" -ForegroundColor Yellow
        $results.recommendations | ForEach-Object { Write-Host "⚠ $_" -ForegroundColor Yellow }
        Write-Host ""
    }
    
    if ($results.issues.Count -eq 0) {
        Write-Host "✓ 环境检测通过，可以开始部署" -ForegroundColor Green
    }
}
