# OpenClaw 部署后健康检查
param(
    [string]$GatewayUrl = "http://127.0.0.1:18789",
    [string]$GatewayToken = "",
    [switch]$Json
)

$results = @{
    timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    gateway = @{}
    config = @{}
    node = @{}
    npm = @{}
    model = @{}
    status = ""
    checks = @()
}

function Add-Check($name, $pass, $detail) {
    $results.checks += @{ name = $name; pass = $pass; detail = $detail }
    if (-not $pass) {
        $results.status = "DEGRADED"
    }
}

# 1. Gateway 健康
try {
    $headers = @{}
    if ($GatewayToken) { $headers["Authorization"] = "Bearer $GatewayToken" }
    $resp = Invoke-RestMethod -Uri "$GatewayUrl/healthz" -TimeoutSec 5 -Headers $headers
    $results.gateway = $resp
    Add-Check "Gateway 健康检查" $true "$($resp.status)"
} catch {
    $results.gateway = @{ error = $_.Exception.Message }
    Add-Check "Gateway 健康检查" $false "无法连接: $($_.Exception.Message)"
}

# 2. 配置验证
try {
    $configCheck = openclaw config validate 2>&1
    $results.config.valid = ($LASTEXITCODE -eq 0)
    $results.config.output = $configCheck
    Add-Check "配置验证" ($LASTEXITCODE -eq 0) $configCheck
} catch {
    Add-Check "配置验证" $false "命令执行失败"
}

# 3. Gateway 状态
try {
    $statusJson = openclaw gateway status --json 2>&1 | ConvertFrom-Json
    $results.node.gatewayStatus = $statusJson
    Add-Check "Gateway 运行状态" ($statusJson.runtime -eq "running") "$($statusJson.runtime)"
} catch {
    Add-Check "Gateway 运行状态" $false "无法获取状态"
}

# 4. OpenClaw 版本
try {
    $ver = openclaw --version 2>&1
    $results.node.cliVersion = $ver
    Add-Check "CLI 版本" $true $ver
} catch {
    Add-Check "CLI 版本" $false "openclaw 命令不可用"
}

# 5. npm 全局包
try {
    $npmList = npm list -g openclaw --depth=0 2>&1
    $results.npm.output = $npmList
    Add-Check "npm 包" ($LASTEXITCODE -eq 0) "openclaw 已安装"
} catch {
    Add-Check "npm 包" $false "openclaw 未通过 npm 安装"
}

# 综合状态
if ($results.status -ne "DEGRADED") { $results.status = "HEALTHY" }
if ($results.checks.Where({ -not $_.pass }).Count -eq $results.checks.Count) { $results.status = "UNHEALTHY" }

if ($Json) {
    $results | ConvertTo-Json -Depth 5
} else {
    Write-Host ""
    Write-Host "╔══════════════════════════════════════╗"
    Write-Host "║   OpenClaw 健康检查报告              ║"
    Write-Host "╚══════════════════════════════════════╝"
    Write-Host "时间: $($results.timestamp)"
    Write-Host ""
    
    $results.checks | ForEach-Object {
        $icon = if ($_.pass) { "✓" } else { "✗" }
        $color = if ($_.pass) { "Green" } else { "Red" }
        Write-Host "$icon $($_.name): $($_.detail)" -ForegroundColor $color
    }
    
    Write-Host ""
    $color = switch ($results.status) {
        "HEALTHY"   { "Green" }
        "DEGRADED"  { "Yellow" }
        "UNHEALTHY" { "Red" }
    }
    Write-Host "综合状态: $($results.status)" -ForegroundColor $color
}
