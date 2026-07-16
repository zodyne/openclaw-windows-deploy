# OpenClaw 环境变量配置
# 复制此文件为 env.ps1 并填入实际的 API Key
# cp config\env.example.ps1 config\env.ps1

# ═══ 模型 API 密钥 ═══

# 智谱 AI (GLM-5.2) — 主模型，必填
# 获取地址: https://open.bigmodel.cn/  → API Keys
$env:ZHIPU_API_KEY = "你的智谱API密钥"

# DeepSeek V4 — 回退模型，必填
# 获取地址: https://platform.deepseek.com/  → API Keys
$env:DEEPSEEK_API_KEY = "你的DeepSeek API密钥"

# ═══ 可选：Ollama 本地记忆搜索 ═══
# 设为 1 启用本地语义搜索（需要安装 Ollama，约 2GB 磁盘空间）
$env:OLLAMA_ENABLED = "0"

# ═══ 可选：GitLab 集成 ═══
# $env:GITLAB_TOKEN = "你的GitLab Token"
# $env:GITLAB_URL = "https://gitlab.example.com"

# ═══ 可选：Anthropic API（如需 Claude Code） ═══
# $env:ANTHROPIC_API_KEY = "你的Anthropic API密钥"
# $env:ANTHROPIC_BASE_URL = "https://api.anthropic.com"
