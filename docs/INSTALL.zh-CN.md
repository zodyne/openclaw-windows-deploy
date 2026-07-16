# OpenClaw Windows 安装说明（中文）

## 目录

1. [系统要求](#系统要求)
2. [快速安装](#快速安装)
3. [装配技能包](#装配技能包)
4. [配置说明](#配置说明)
5. [启动与验证](#启动与验证)
6. [卸载](#卸载)

---

## 系统要求

| 项目 | 最低 | 推荐 |
|------|------|------|
| 操作系统 | Windows 10 20H2 | Windows 11 |
| 架构 | x64 / ARM64 | x64 |
| 内存 | 8 GB | 16 GB+ |
| 磁盘 | 5 GB | 10 GB+ |
| 网络 | 稳定互联网 | — |

**注册 API 账号（必需）：**
- **智谱 AI**：https://open.bigmodel.cn/ → 获取 API Key
- **DeepSeek**：https://platform.deepseek.com/ → 获取 API Key

---

## 快速安装

### 第一步：下载

```powershell
git clone https://github.com/YOUR_ORG/openclaw-windows-deploy.git
cd openclaw-windows-deploy
```

### 第二步：配置 API Key

```powershell
copy config\env.example.ps1 config\env.ps1
notepad config\env.ps1
```

修改为真实的 API Key：

```powershell
$env:ZHIPU_API_KEY = "sk-xxx…xxxx"
$env:DEEPSEEK_API_KEY = "sk-xxx…xxxx"
```

### 第三步：环境检测（可选）

```powershell
.\scripts\check-env.ps1
```

### 第四步：一键部署

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
.\deploy.ps1
```

**自动完成：**
1. 检测/安装 Node.js
2. npm 全局安装 OpenClaw
3. 生成 `openclaw.json` 配置
4. 创建工作区骨架（空 AGENTS.md / SOUL.md / USER.md，用户自行填写）
5. 注册 Gateway 为 Windows 后台服务
6. 健康检查

### 第五步：访问控制面板

打开 **http://127.0.0.1:18789/**

---

## 装配技能包

部署完成后，工作区是空白的。本仓库内置 5 个预打包技能包，可一键装配：

### 查看可用技能

```powershell
.\install-skills.ps1 -List
```

输出示例：
```
Name                     Category    DisplayName
----                     --------    -----------
read-image               utility     Read Image (RapidOCR)
latex-tikz-figures       utility     LaTeX/TikZ Figure Checker
evidence-ledger          governance  Evidence Ledger (项目防漂移治理)
anti-drift-governance    governance  Anti-Drift Governance (多角色审查环)
gbrain-knowledge-workflow knowledge   GBrain Knowledge Workflow
```

### 安装指定技能

```powershell
# 安装单个
.\install-skills.ps1 -Install read-image

# 安装多个
.\install-skills.ps1 -Install read-image,latex-tikz-figures,evidence-ledger

# 安装全部
.\install-skills.ps1 -All

# 覆盖已存在的技能
.\install-skills.ps1 -Install evidence-ledger -Force
```

### 技能详解

#### read-image — 离线 OCR

纯文本模型（GLM-5.2 / DeepSeek）无法直接读图。此技能通过 RapidOCR（ONNX Runtime）将图片转为文字，离线运行，支持中英文。

**安装依赖：**
```powershell
pip install rapidocr-onnxruntime
```

**触发词：** 读图、OCR、识别图片文字、extract text from image

#### latex-tikz-figures — LaTeX 编译检查

将 LaTeX 图表的视觉缺陷（箭头交叉、标签溢出、字体缺失）转化为可 grep 的编译日志信号。包含 `--render` 模式可将 PDF 页面转为 PNG 交由视觉模型做最终检查。

**安装依赖：**
```powershell
# 安装 TeX 发行版（二选一）
winget install TeXLive.TeXLive    # 或 MiKTeX.MiKTeX
winget install OSSP.poppler       # pdftoppm
```

#### evidence-ledger — 项目防漂移治理

为长期工程项目建立证据驱动的状态追踪系统：
- 哈希锁定的项目宪章（目标不可被 agent 偷改）
- 证据分档账本（not_started → compiled_only → verified_*）
- 声明-证据绑定校验器（脚本自动验证一切"完成"声明）
- 换脑审计机制（全新会话独立审计）

**适用场景：** 多会话工程项目、移植/迁移项目、需要可审计进度追踪的场景。

**安装依赖：**
```powershell
pip install pyyaml
```

#### anti-drift-governance — 多角色审查环

五角色证据驱动治理系统：部署者 → 调查者 → 复核者 → 审计者 → 汇报者。每个角色独立视角、独立判据、交叉验证。内置 R1-R8 不可协商规则。

与 evidence-ledger 互补：evidence-ledger 是通用框架，anti-drift-governance 增加了多角色审查环机制。

#### gbrain-knowledge-workflow — 知识图谱工作流

通过 GBrain MCP 服务维护和查询本地知识库的标准操作流程。包含写入纪律、provenance 标记规则、CLI 禁令等实战约定。

**前提：** 需要部署 GBrain MCP 服务。

---

## 配置说明

### 模型架构

```
用户请求 → Gateway (127.0.0.1:18789)
              │
              ├── 主模型: GLM-5.2 (智谱 AI)
              │   └── API: https://open.bigmodel.cn/api/anthropic
              │
              └── 回退: DeepSeek V4
                  └── API: https://api.deepseek.com/v1
```

### 配置文件位置

| 文件 | 路径 |
|------|------|
| 主配置 | `%USERPROFILE%\.openclaw\openclaw.json` |
| 工作区 | `%USERPROFILE%\.openclaw\workspace\` |
| 技能 | `%USERPROFILE%\.openclaw\workspace\skills\` |
| 日志 | `%TEMP%\openclaw\` |

### 可选：启用 Ollama 记忆搜索

```powershell
# 编辑 env.ps1
notepad config\env.ps1
# 设 OLLAMA_ENABLED = "1"

# 重新部署
.\deploy.ps1
```

---

## 启动与验证

### Gateway 管理命令

```powershell
openclaw gateway status       # 状态
openclaw gateway restart      # 重启
openclaw config validate      # 配置验证
openclaw doctor               # 诊断
.\scripts\healthcheck.ps1     # 健康检查
```

---

## 卸载

```powershell
openclaw gateway uninstall
npm uninstall -g openclaw
Remove-Item -Recurse $env:USERPROFILE\.openclaw  # 可选：删除数据
```

详见 [FAQ.md](./FAQ.md)。
