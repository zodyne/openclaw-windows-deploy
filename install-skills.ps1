# install-skills.ps1 — 可选技能装配脚本
# 将预打包的 Skills 和 SOP 安装到 OpenClaw workspace
param(
    [string[]]$Install,     # 指定安装的技能名（空则列出可选项）
    [switch]$List,          # 列出所有可用技能
    [switch]$All,           # 安装全部
    [switch]$Force          # 覆盖已存在的文件
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$SkillsSrc = "$ScriptDir\skills"
$Workspace = "$env:USERPROFILE\.openclaw\workspace"

function Write-Step { Write-Host "`n▶ $args" -ForegroundColor Cyan }
function Write-OK   { Write-Host "  ✓ $args" -ForegroundColor Green }
function Write-Warn { Write-Host "  ⚠ $args" -ForegroundColor Yellow }
function Write-Info { Write-Host "  ℹ $args" -ForegroundColor Gray }
function Write-Err  { Write-Host "  ✗ $args" -ForegroundColor Red }

# 加载 manifest
$manifestPath = "$SkillsSrc\manifest.json"
if (-not (Test-Path $manifestPath)) {
    Write-Err "技能清单文件缺失: $manifestPath"
    exit 1
}
$manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json

function Get-SkillList {
    $manifest.skills.PSObject.Properties | ForEach-Object {
        $name = $_.Name
        $info = $_.Value
        [PSCustomObject]@{
            Name = $name
            DisplayName = $info.name
            Category = $info.category
            Description = $info.description
            Requirements = $info.requirements
        }
    }
}

function Install-Skill {
    param([string]$SkillName)
    
    $skillDef = $manifest.skills.$SkillName
    if (-not $skillDef) {
        Write-Err "未知技能: $SkillName"
        return $false
    }
    
    $srcPath = "$SkillsSrc\$SkillName"
    $dstPath = "$Workspace\skills\$SkillName"
    
    if (-not (Test-Path $srcPath)) {
        Write-Err "技能源文件缺失: $srcPath"
        return $false
    }
    
    # 检查是否已存在
    if ((Test-Path $dstPath) -and -not $Force) {
        Write-Warn "$SkillName 已存在，跳过（使用 -Force 覆盖）"
        return $false
    }
    
    # 创建目标目录并复制
    $null = New-Item -ItemType Directory -Force -Path $dstPath
    Copy-Item -Path "$srcPath\*" -Destination $dstPath -Recurse -Force
    
    # 执行权限标记（shell 脚本）
    Get-ChildItem $dstPath -Recurse -Filter "*.sh" | ForEach-Object {
        Write-Info "  标记可执行: $($_.Name)"
    }
    
    Write-OK "$SkillName → $dstPath"
    
    # 显示依赖提示
    if ($skillDef.requirements -and $skillDef.requirements -ne "无") {
        Write-Info "  依赖: $($skillDef.requirements)"
    }
    
    # 特殊安装后提示
    switch ($SkillName) {
        "read-image" {
            Write-Info "  安装 Python 依赖: pip install rapidocr-onnxruntime"
        }
        "evidence-ledger" {
            Write-Info "  安装 Python 依赖: pip install pyyaml"
            Write-Info "  使用方式: 在目标项目运行 SKILL.md 中的 init 工作流"
        }
        "anti-drift-governance" {
            Write-Info "  安装 Python 依赖: pip install pyyaml"
        }
        "latex-tikz-figures" {
            Write-Info "  需安装: xelatex (TeX Live 或 MiKTeX) + poppler (pdftoppm)"
        }
        "gbrain-knowledge-workflow" {
            Write-Info "  需要: GBrain MCP 服务已部署"
            Write-Info "  参考: docs/CONFIGURATION.md → MCP Servers 章节"
        }
    }
    
    return $true
}

# ══════════════════════════════════════════════
# 主流程
# ══════════════════════════════════════════════

Write-Host @"

╔══════════════════════════════════════════════╗
║     OpenClaw Skills 装配工具                 ║
╚══════════════════════════════════════════════╝

"@ -ForegroundColor Cyan

# 确认 workspace 存在
if (-not (Test-Path "$Workspace\skills")) {
    Write-Info "创建 workspace skills 目录: $Workspace\skills"
    $null = New-Item -ItemType Directory -Force -Path "$Workspace\skills"
}

# 列出模式
if ($List -or (-not $Install -and -not $All)) {
    Write-Step "可用技能包"
    
    $skills = Get-SkillList
    $skills | Format-Table -AutoSize -Property Name, Category, DisplayName
    
    Write-Host ""
    $skills | ForEach-Object {
        Write-Host "  $($_.Name)" -ForegroundColor Cyan
        Write-Host "    $($_.Description)" -ForegroundColor Gray
        Write-Host "    依赖: $($_.Requirements)" -ForegroundColor DarkGray
        Write-Host ""
    }
    
    Write-Host "用法:" -ForegroundColor Cyan
    Write-Host "  .\install-skills.ps1 -Install read-image,latex-tikz-figures"
    Write-Host "  .\install-skills.ps1 -All"
    Write-Host "  .\install-skills.ps1 -Install evidence-ledger -Force"
    exit 0
}

# 全部安装
if ($All) {
    Write-Step "安装全部技能"
    $count = 0
    foreach ($skill in (Get-SkillList).Name) {
        if (Install-Skill -SkillName $skill) { $count++ }
    }
    Write-Host ""
    Write-OK "完成: $count 个技能已安装到 $Workspace\skills\"
    exit 0
}

# 指定安装
if ($Install) {
    Write-Step "安装指定技能"
    $count = 0
    foreach ($skill in $Install) {
        $skill = $skill.Trim()
        if (Install-Skill -SkillName $skill) { $count++ }
    }
    Write-Host ""
    Write-OK "完成: $count 个技能已安装到 $Workspace\skills\"
    
    Write-Host ""
    Write-Info "技能安装后，OpenClaw Agent 会在匹配触发词时自动使用。"
    Write-Info "可在 openclaw.json 的 skills.entries 中手动启用/禁用。"
    exit 0
}
