# Quick Start Guide

## 5-Minute Setup

### Prerequisites

1. **API Keys** (sign up before starting):
   - Zhipu AI: https://open.bigmodel.cn/ → API Keys → get your key
   - DeepSeek: https://platform.deepseek.com/ → API Keys → get your key

### Step 1: Download

```powershell
git clone https://github.com/YOUR_ORG/openclaw-windows-deploy.git
cd openclaw-windows-deploy
```

Or download the ZIP from [Releases](https://github.com/YOUR_ORG/openclaw-windows-deploy/releases).

### Step 2: Configure API Keys

```powershell
copy config\env.example.ps1 config\env.ps1
notepad config\env.ps1
```

Fill in your actual API keys:
```powershell
$env:ZHIPU_API_KEY = "sk-xxxxxxxxxxxxxxxx"
$env:DEEPSEEK_API_KEY = "sk-xxxxxxxxxxxxxxxx"
```

### Step 3: Deploy

```powershell
# Run PowerShell as Administrator
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
.\deploy.ps1
```

### Step 4: Verify

Open **http://127.0.0.1:18789/** in your browser.

### Step 5: Start Chatting

Use the WebChat interface at the Control UI, or configure messaging channels (Telegram, Discord, Slack, etc.) in the settings.

---

## Key Commands

```powershell
openclaw gateway status       # Check gateway status
openclaw gateway restart      # Restart gateway
openclaw config validate      # Validate configuration
openclaw doctor               # Run diagnostics
.\scripts\healthcheck.ps1     # Health check script
```

## Directory Layout

```
%USERPROFILE%\.openclaw\
├── openclaw.json          # Main configuration
├── workspace\             # Agent workspace
│   ├── AGENTS.md          # Agent rules
│   ├── SOUL.md            # Persona settings
│   ├── USER.md            # User profile
│   ├── HEARTBEAT.md       # Scheduled tasks
│   └── memory\            # Memory storage
├── state\                 # Runtime state
└── exec-approvals.json    # Execution allowlist
```
