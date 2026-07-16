# OpenClaw Windows 一键部署工具包

[English](#english) | [中文](#中文)

---

## 中文

基于 OpenClaw v2026.6.11，为 Windows 10/11 用户提供开箱即用的一键部署方案。内置 5 个可选技能包，装配即用。

### 功能特性

- 🚀 **一键安装**：PowerShell 脚本自动完成 Node.js → OpenClaw → 模型配置 → Gateway 服务注册
- 🧠 **双模型引擎**：GLM-5.2（主）+ DeepSeek-V4（回退），自动故障切换
- 📦 **5 个可选技能包**：OCR 读图、LaTeX 检查、项目防漂移治理、知识图谱工作流（自动装依赖）
- 🛡️ **安全设计**：API Key 通过环境变量注入，配置文件不含密钥
- ✅ **部署后自动健康检查**
- 🔧 **全链路自动**：Node.js、Python 3、Ollama、pip 包、LaTeX 均自动检测安装

### 快速开始

```powershell
# 1. 克隆
git clone https://github.com/YOUR_ORG/openclaw-windows-deploy.git
cd openclaw-windows-deploy

# 2. 配置 API 密钥
copy config\env.example.ps1 config\env.ps1
notepad config\env.ps1   # 填入智谱 + DeepSeek 的 API Key

# 3. 一键部署
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
.\deploy.ps1

# 4. 装配技能包（可选）
.\install-skills.ps1 -List          # 查看可选技能
.\install-skills.ps1 -Install read-image,evidence-ledger  # 按需装配
.\install-skills.ps1 -All           # 全部装配
```

部署完成后访问 `http://127.0.0.1:18789/`。

### 内置技能包

| 技能 | 类别 | 功能 | 依赖 |
|------|------|------|------|
| **read-image** | 工具 | 离线 OCR 图片文字提取（中英文），纯文本模型读图替代方案 | Python + rapidocr-onnxruntime |
| **latex-tikz-figures** | 工具 | LaTeX/TikZ 编译检查器，将视觉缺陷转为可 grep 的日志信号 | xelatex + poppler |
| **evidence-ledger** | 治理 | 哈希锁定宪章 + 证据分档账本 + 声明-证据绑定校验器 + 换脑审计 | Python + PyYAML |
| **anti-drift-governance** | 治理 | 五角色证据驱动治理：部署→调查→复核→审计→汇报交叉验证环 | Python + PyYAML |
| **gbrain-knowledge-workflow** | 知识 | 通过 MCP 工具维护和查询知识库的标准工作流 | GBrain MCP 服务 |

### 前置要求

| 组件 | 最低版本 | 说明 |
|------|---------|------|
| Windows | 10 20H2+ / 11 | x64 或 ARM64 |
| PowerShell | 5.1+ | 系统自带 |
| API Key | — | [智谱 AI](https://open.bigmodel.cn/) + [DeepSeek](https://platform.deepseek.com/) |

### 目录结构

```
openclaw-windows-deploy/
├── deploy.ps1              # ★ 一键部署脚本
├── install-skills.ps1      # ★ 技能装配脚本
├── deploy.bat              # 批处理启动器
├── config/
│   ├── env.example.ps1     # 环境变量模板
│   └── openclaw.base.json  # OpenClaw 配置模板
├── skills/                 # 预打包技能包
│   ├── manifest.json       # 技能清单
│   ├── read-image/
│   ├── latex-tikz-figures/
│   ├── evidence-ledger/
│   ├── anti-drift-governance/
│   └── gbrain-knowledge-workflow/
├── scripts/
│   ├── check-env.ps1       # 环境检测
│   └── healthcheck.ps1     # 健康检查
├── docs/
│   ├── INSTALL.zh-CN.md    # 详细安装说明
│   ├── QUICKSTART.md       # 快速入门
│   ├── CONFIGURATION.md    # 配置参考
│   └── FAQ.md              # 常见问题
└── examples/
    └── advanced-config.json
```

### 许可证

MIT

---

## English

One-click deployment toolkit for OpenClaw v2026.6.11 on Windows 10/11. Includes 5 optional skill packs.

### Features

- 🚀 **One-Click Install**: Node.js → OpenClaw → model config → Gateway service
- 🧠 **Dual Model Engine**: GLM-5.2 (primary) + DeepSeek-V4 (fallback) with auto-failover
- 📦 **5 Optional Skill Packs**: OCR, LaTeX checker, anti-drift governance, knowledge workflow (auto-installs deps)
- 🛡️ **Secure**: API keys via environment variables
- ✅ **Post-deployment Health Check**
- 🔧 **Fully Automated**: Node.js, Python 3, Ollama, pip packages, LaTeX auto-detected and installed

### Quick Start

```powershell
git clone https://github.com/YOUR_ORG/openclaw-windows-deploy.git
cd openclaw-windows-deploy

copy config\env.example.ps1 config\env.ps1
notepad config\env.ps1   # Fill in API keys

Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
.\deploy.ps1

# Install skill packs (optional)
.\install-skills.ps1 -List
.\install-skills.ps1 -Install read-image,evidence-ledger
```

### License

MIT
