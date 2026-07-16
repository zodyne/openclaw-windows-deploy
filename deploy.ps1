# OpenClaw Windows 一键部署脚本
# 用法: .\deploy.ps1 [-SkipOllama] [-SkipGatewayService] [-DryRun] [-ConfigOnly]
param(
    [switch]$SkipOllama,
    [switch]$SkipGatewayService,
    [switch]$DryRun,
    [switch]$ConfigOnly
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$OpenClawHome = "$env:USERPROFILE\.openclaw"
$OpenClawConfig = "$OpenClawHome\openclaw.json"
$WorkspaceDir = "$OpenClawHome\workspace"

function Write-Step { Write-Host "`n▶ $args" -ForegroundColor Cyan }
function Write-OK   { Write-Host "  ✓ $args" -ForegroundColor Green }
function Write-Warn { Write-Host "  ⚠ $args" -ForegroundColor Yellow }
function Write-Err  { Write-Host "  ✗ $args" -ForegroundColor Red }
function Write-Info { Write-Host "  ℹ $args" -ForegroundColor Gray }

# ─── 加载环境变量 ───
function Load-EnvConfig {
    $envFile = "$ScriptDir\config\env.ps1"
    if (Test-Path $envFile) {
        Write-Info "加载环境变量: $envFile"
        . $envFile
    } else {
        $exampleFile = "$ScriptDir\config\env.example.ps1"
        if (Test-Path $exampleFile) {
            Copy-Item $exampleFile $envFile -Force
        }
        Write-Err "请编辑 config\env.ps1 填入 API Key 后重新运行"
        exit 1
    }
}

# ─── 环境检测 ───
function Test-Prerequisites {
    Write-Step "环境检测"
    $os = Get-CimInstance Win32_OperatingSystem
    Write-Info "操作系统: $($os.Caption) ($($os.OSArchitecture))"
    Write-Info "PowerShell: $($PSVersionTable.PSVersion)"
    
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
    if ($isAdmin) { Write-OK "管理员权限" }
    else { Write-Warn "非管理员权限，Gateway 将使用用户级 Scheduled Task" }
    
    try {
        $null = Invoke-WebRequest -Uri "https://open.bigmodel.cn" -TimeoutSec 5 -UseBasicParsing
        Write-OK "网络: api.open.bigmodel.cn 可达"
    } catch {
        Write-Warn "无法访问 open.bigmodel.cn，请检查网络"
    }
}

# ─── 安装 Node.js ───
function Install-NodeJS {
    Write-Step "检测 Node.js"
    try {
        $v = node --version 2>$null
        Write-OK "Node.js 已安装: $v"
        return
    } catch {}
    
    Write-Info "Node.js 未安装，尝试自动安装..."
    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if ($winget) {
        winget install OpenJS.NodeJS.LTS --silent --accept-package-agreements
    } else {
        $nodeUrl = "https://nodejs.org/dist/v24.11.0/node-v24.11.0-win-x64.zip"
        $nodeZip = "$env:TEMP\nodejs.zip"
        $nodeDir = "$env:LOCALAPPDATA\OpenClaw\deps\portable-node"
        Invoke-WebRequest -Uri $nodeUrl -OutFile $nodeZip
        Expand-Archive $nodeZip -DestinationPath $nodeDir -Force
        Remove-Item $nodeZip
        $binDir = (Get-ChildItem $nodeDir -Directory | Select-Object -First 1).FullName
        [Environment]::SetEnvironmentVariable("PATH", "$binDir;$env:PATH", "User")
        $env:PATH = "$binDir;$env:PATH"
    }
    try {
        Write-OK "Node.js 安装成功: $(node --version)"
    } catch {
        Write-Err "Node.js 安装失败，请手动安装: https://nodejs.org/"
        exit 1
    }
}

# ─── 安装 OpenClaw ───
function Install-OpenClaw {
    Write-Step "安装 OpenClaw"
    try {
        $v = openclaw --version 2>$null
        Write-OK "OpenClaw 已安装: $v"
        return
    } catch {}
    
    Write-Info "通过 npm 安装 OpenClaw..."
    npm install -g openclaw@latest
    try {
        Write-OK "OpenClaw 安装成功: $(openclaw --version)"
    } catch {
        Write-Err "OpenClaw 安装失败"
        exit 1
    }
}

# ─── 生成配置文件 ───
function New-OpenClawConfig {
    Write-Step "生成配置文件"
    
    $null = New-Item -ItemType Directory -Force -Path $OpenClawHome
    $null = New-Item -ItemType Directory -Force -Path $WorkspaceDir
    
    # 生成 Gateway Token
    $bytes = New-Object byte[] 32
    [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    $gatewayToken = -join ($bytes | ForEach-Object { $_.ToString("x2") })
    
    $baseConfigPath = "$ScriptDir\config\openclaw.base.json"
    if (-not (Test-Path $baseConfigPath)) {
        Write-Err "配置模板缺失: $baseConfigPath"
        exit 1
    }
    
    $config = Get-Content $baseConfigPath -Raw | ConvertFrom-Json
    $config.models.providers.zai.apiKey = $env:ZHIPU_API_KEY
    $config.models.providers.novasky.apiKey = $env:DEEPSEEK_API_KEY
    $config.gateway.auth.token = $gatewayToken
    
    # workspace 路径适配 Windows JSON 格式
    $wsPath = $WorkspaceDir.Replace('\', '/')
    $config.agents.defaults.workspace = $wsPath
    foreach ($agent in $config.agents.list) {
        if ($agent.workspace) { $agent.workspace = $wsPath }
    }
    
    # Ollama 记忆搜索
    if ($env:OLLAMA_ENABLED -eq "1") {
        $config.agents.defaults.memorySearch.enabled = $true
    } else {
        $config.agents.defaults.memorySearch.enabled = $false
    }
    
    $config | ConvertTo-Json -Depth 20 | Set-Content $OpenClawConfig -Encoding UTF8
    Write-OK "配置已生成: $OpenClawConfig"
    Write-Info "Gateway Token: $gatewayToken"
}

# ─── 安装 Ollama（可选）───
function Install-Ollama {
    if ($SkipOllama -or $env:OLLAMA_ENABLED -ne "1") {
        Write-Info "跳过 Ollama（OLLAMA_ENABLED != 1）"
        return
    }
    
    Write-Step "安装 Ollama"
    try {
        ollama --version 2>$null | Out-Null
        Write-OK "Ollama 已安装"
    } catch {
        $installer = "$env:TEMP\OllamaSetup.exe"
        Invoke-WebRequest -Uri "https://ollama.com/download/OllamaSetup.exe" -OutFile $installer
        Start-Process $installer -ArgumentList "/S" -Wait
        Remove-Item $installer
    }
    Write-Info "拉取 bge-m3 模型 (约 1.2GB)..."
    ollama pull bge-m3
    Write-OK "Ollama + bge-m3 就绪"
}

# ─── 初始化工作区（最小骨架，不含个人内容）───
function Initialize-Workspace {
    Write-Step "初始化工作区骨架"
    
    $null = New-Item -ItemType Directory -Force -Path "$WorkspaceDir\memory"
    $null = New-Item -ItemType Directory -Force -Path "$WorkspaceDir\skills"
    
    # AGENTS.md — 最小骨架，用户自行填写
    @"
# AGENTS.md — 全局操作规则

<!-- 此文件为部署生成的最小骨架，请根据实际需要补充规则。 -->

## 操作纪律
- 每次改代码后必须实际运行验证，附命令+输出作为证据
- 对不确定的事实标注不确定性，不编造

## 审批规则
<!-- 定义哪些动作需要人工审批（如对外发送、删除文件、git push 等）-->
"@ | Set-Content "$WorkspaceDir\AGENTS.md" -Encoding UTF8
    
    # SOUL.md — 人设骨架
    @"
# SOUL.md — 助手人设

<!-- 定义助手的人设、回复风格、行为边界。 -->

## 回复风格
- 简洁直接，结论先行

## 行为边界
- 对外发送消息/邮件/删除文件等敏感操作需用户确认
"@ | Set-Content "$WorkspaceDir\SOUL.md" -Encoding UTF8
    
    # USER.md — 用户信息骨架
    @"
# USER.md — 用户信息

- **Name:** （请填写）
- **Timezone:** Asia/Shanghai
- **Notes:** （请填写用户背景和工作偏好）
"@ | Set-Content "$WorkspaceDir\USER.md" -Encoding UTF8
    
    # HEARTBEAT.md — 心跳任务骨架
    @"
# HEARTBEAT.md — 心跳任务

<!-- 定义定时心跳任务的内容。OpenClaw 会在 cron 心跳时读取此文件。 -->

## 每日晨报（可选）
- 读取 memory/ 下的项目状态和偏好
- 列出今日建议优先处理的事项
"@ | Set-Content "$WorkspaceDir\HEARTBEAT.md" -Encoding UTF8
    
    # TOOLS.md — 工具清单骨架
    @"
# TOOLS.md — 工具清单

<!-- 登记已启用的工具、技能和 MCP 服务器。 -->

## 已启用
- memorySearch（如 Ollama 已启用）
- web_fetch（内置）
"@ | Set-Content "$WorkspaceDir\TOOLS.md" -Encoding UTF8
    
    Write-OK "工作区骨架已创建"
    Write-Info "路径: $WorkspaceDir"
    Write-Info "提示: 运行 .\install-skills.ps1 装配可选技能包"
}

# ─── 安装 Gateway 服务 ───
function Install-GatewayService {
    if ($SkipGatewayService) {
        Write-Info "跳过 Gateway 服务注册"
        return
    }
    
    Write-Step "注册 Gateway 服务"
    
    $validate = openclaw config validate 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Err "配置验证失败: $validate"
        exit 1
    }
    Write-OK "配置验证通过"
    
    openclaw gateway install
    Start-Sleep -Seconds 2
    Write-OK "Gateway 服务已注册"
}

# ─── 健康检查 ───
function Invoke-HealthCheck {
    Write-Step "部署后健康检查"
    
    try {
        $health = Invoke-RestMethod -Uri "http://127.0.0.1:18789/healthz" -TimeoutSec 5
        Write-OK "Gateway 健康: $($health.status)"
    } catch {
        Write-Warn "Gateway 未响应，可能在启动中（等待几秒后重试）"
        Start-Sleep -Seconds 3
        try {
            $health = Invoke-RestMethod -Uri "http://127.0.0.1:18789/healthz" -TimeoutSec 5
            Write-OK "Gateway 健康: $($health.status)"
        } catch {
            Write-Warn "Gateway 仍未就绪，请手动检查: openclaw gateway status"
        }
    }
    
    openclaw config validate 2>&1 | ForEach-Object { Write-Info $_ }
}

# ══════════════════════════════════════════════
# 主流程
# ══════════════════════════════════════════════

Write-Host @"

╔══════════════════════════════════════════════╗
║     OpenClaw Windows 一键部署工具             ║
║     v2.0 | 基于 OpenClaw 2026.6.11           ║
╚══════════════════════════════════════════════╝

"@ -ForegroundColor Cyan

Load-EnvConfig

if ($DryRun) {
    Write-Step "DRY RUN — 仅预览"
    Test-Prerequisites
    Write-Info "将安装: Node.js → OpenClaw → Ollama($($env:OLLAMA_ENABLED -eq '1'))"
    Write-Info "将写入: $OpenClawConfig"
    Write-Info "将注册: Gateway 服务"
    Write-Info "可选后续: .\install-skills.ps1 -All"
    exit 0
}

if ($ConfigOnly) {
    New-OpenClawConfig
    Initialize-Workspace
    Write-OK "配置完成。手动启动: openclaw gateway run"
    exit 0
}

Test-Prerequisites
Install-NodeJS
Install-OpenClaw
Install-Ollama
Initialize-Workspace
New-OpenClawConfig
Install-GatewayService
Invoke-HealthCheck

Write-Host @"

╔══════════════════════════════════════════════╗
║  ✓ 部署完成！                                ║
║                                              ║
║  控制面板: http://127.0.0.1:18789/           ║
║  工作区:   $WorkspaceDir
║                                              ║
║  下一步:                                     ║
║  1. 打开浏览器访问控制面板                      ║
║  2. 装配技能包: .\install-skills.ps1 -List    ║
║  3. 编辑工作区文件 (AGENTS/SOUL/USER.md)      ║
╚══════════════════════════════════════════════╝

"@ -ForegroundColor Green
