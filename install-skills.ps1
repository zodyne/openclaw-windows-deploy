# install-skills.ps1 — 可选技能装配脚本（自动安装依赖）
# 用法:
#   .\install-skills.ps1 -List                              # 列出可选技能
#   .\install-skills.ps1 -Install read-image,latex-tikz-figures  # 按需装配
#   .\install-skills.ps1 -All                               # 全部装配
#   .\install-skills.ps1 -Install read-image -SkipDeps      # 跳过依赖安装
param(
    [string[]]$Install,
    [switch]$List,
    [switch]$All,
    [switch]$Force,
    [switch]$SkipDeps    # 跳过依赖自动安装
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$SkillsSrc = "$ScriptDir\skills"
$Workspace = "$env:USERPROFILE\.openclaw\workspace"

function Write-Step { Write-Host "`n▶ $args" -ForegroundColor Cyan }
function Write-OK   { Write-Host "  ✓ $args" -ForegroundColor Green }
function Write-Warn { Write-Host "  ⚠ $args" -ForegroundColor Yellow }
function Write-Err  { Write-Host "  ✗ $args" -ForegroundColor Red }
function Write-Info { Write-Host "  ℹ $args" -ForegroundColor Gray }

# 加载 manifest
$manifestPath = "$SkillsSrc\manifest.json"
if (-not (Test-Path $manifestPath)) {
    Write-Err "技能清单文件缺失: $manifestPath"
    exit 1
}
$manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json

function Get-SkillList {
    $manifest.skills.PSObject.Properties | ForEach-Object {
        [PSCustomObject]@{
            Name = $_.Name
            DisplayName = $_.Value.name
            Category = $_.Value.category
            Description = $_.Value.description
            Requirements = $_.Value.requirements
        }
    }
}

# ─── 依赖检测工具 ───
function Test-Command {
    param([string]$cmd)
    $null = Get-Command $cmd -ErrorAction SilentlyContinue
    return $?
}

function Install-WithWinget {
    param([string]$PackageId)
    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if ($winget) {
        Write-Info "  winget install $PackageId"
        winget install $PackageId --silent --accept-package-agreements 2>&1 | ForEach-Object { Write-Info "    $_" }
        return $?
    }
    return $false
}

function Install-PipPackage {
    param([string[]]$packages)
    try {
        $v = python --version 2>&1
        if ($v -notmatch "Python 3") {
            Write-Warn "  Python 3 不可用，跳过 pip 依赖: $($packages -join ', ')"
            Write-Info "  请先安装 Python 3: https://www.python.org/downloads/"
            return $false
        }
    } catch {
        Write-Warn "  Python 不可用，跳过 pip 依赖"
        return $false
    }
    foreach ($pkg in $packages) {
        Write-Info "  pip install $pkg"
        pip install $pkg --quiet 2>&1 | ForEach-Object { Write-Info "    $_" }
    }
    Write-OK "pip 依赖已安装: $($packages -join ', ')"
    return $true
}

# ─── 每个技能的依赖安装器 ───
function Install-SkillDeps {
    param([string]$SkillName)
    
    if ($SkipDeps) {
        Write-Info "  跳过依赖安装（-SkipDeps）"
        return
    }

    switch ($SkillName) {
        "read-image" {
            # 需要 Python 3 + rapidocr-onnxruntime
            Install-PipPackage @("rapidocr-onnxruntime")
        }
        
        "latex-tikz-figures" {
            # 需要 xelatex (TeX Live / MiKTeX) + poppler (pdftoppm)
            Write-Info "  检测 LaTeX 和 poppler..."
            
            if (-not (Test-Command "xelatex")) {
                Write-Info "  xelatex 未安装，尝试安装 MiKTeX..."
                $ok = Install-WithWinget "MiKTeX.MiKTeX"
                if (-not $ok) {
                    Write-Warn "  无法自动安装 LaTeX，请手动安装:"
                    Write-Info "    winget install MiKTeX.MiKTeX"
                    Write-Info "    或访问 https://miktex.org/download"
                }
            } else {
                Write-OK "  xelatex 已安装"
            }
            
            if (-not (Test-Command "pdftoppm")) {
                Write-Info "  pdftoppm 未安装，尝试安装 poppler..."
                $ok = Install-WithWinget "OSSP.poppler"
                if (-not $ok) {
                    # Fallback: 通过 conda 或手动
                    Write-Warn "  无法通过 winget 安装 poppler"
                    Write-Info "    方式1: winget install OSSP.poppler"
                    Write-Info "    方式2: conda install -c conda-forge poppler"
                    Write-Info "    方式3: https://github.com/oschwartz10612/poppler-windows/releases"
                }
            } else {
                Write-OK "  pdftoppm 已安装"
            }
        }
        
        "evidence-ledger" {
            # 需要 Python 3 + PyYAML
            Install-PipPackage @("pyyaml")
        }
        
        "anti-drift-governance" {
            # 需要 Python 3 + PyYAML
            Install-PipPackage @("pyyaml")
        }
        
        "gbrain-knowledge-workflow" {
            # 需要 GBrain MCP 服务（无法自动安装，仅提示）
            Write-Info "  此技能需要 GBrain MCP 服务已部署"
            Write-Info "  参考: docs/design/gbrain/ 目录下的架构文档"
            Write-Info "  如果尚未部署 GBrain，此技能仅作参考文档用途"
        }
        
        default {
            Write-Info "  无已知依赖"
        }
    }
}

# ─── 安装技能本体 ───
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
    
    if ((Test-Path $dstPath) -and -not $Force) {
        Write-Warn "$SkillName 已存在，跳过（使用 -Force 覆盖）"
        return $false
    }
    
    # 复制文件
    $null = New-Item -ItemType Directory -Force -Path $dstPath
    Copy-Item -Path "$srcPath\*" -Destination $dstPath -Recurse -Force
    Write-OK "$SkillName → $dstPath"
    
    # 安装依赖
    Write-Info "安装依赖..."
    Install-SkillDeps -SkillName $SkillName
    
    return $true
}

# ══════════════════════════════════════════════
# 主流程
# ══════════════════════════════════════════════

Write-Host @"

╔══════════════════════════════════════════════╗
║     OpenClaw Skills 装配工具（自动装依赖）   ║
╚══════════════════════════════════════════════╝

"@ -ForegroundColor Cyan

# 确认 workspace 存在
if (-not (Test-Path "$Workspace\skills")) {
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
    Write-Host "  .\install-skills.ps1 -Install evidence-ledger -SkipDeps  # 仅复制文件"
    exit 0
}

# 全部安装
if ($All) {
    Write-Step "安装全部技能（含依赖）"
    $count = 0
    foreach ($skill in (Get-SkillList).Name) {
        Write-Step "[$skill]"
        if (Install-Skill -SkillName $skill) { $count++ }
    }
    Write-Host ""
    Write-OK "完成: $count 个技能已安装到 $Workspace\skills\"
    exit 0
}

# 指定安装
if ($Install) {
    $count = 0
    foreach ($skill in $Install) {
        $skill = $skill.Trim()
        Write-Step "[$skill]"
        if (Install-Skill -SkillName $skill) { $count++ }
    }
    Write-Host ""
    Write-OK "完成: $count 个技能已安装到 $Workspace\skills\"
    Write-Info "技能安装后，OpenClaw Agent 会在匹配触发词时自动使用。"
    exit 0
}
