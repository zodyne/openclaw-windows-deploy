# FAQ / 常见问题

## 安装与部署

### Q: 部署脚本报错 "无法加载 env.ps1"

**A:** 需要先创建环境变量配置文件：

```powershell
copy config\env.example.ps1 config\env.ps1
notepad config\env.ps1  # 填入真实的 API Key
```

### Q: "openclaw 不是内部或外部命令"

**A:** npm 全局安装目录未加入 PATH：

```powershell
# 查看 npm 全局目录
npm config get prefix

# 按 Win+R → sysdm.cpl → 高级 → 环境变量
# 在用户变量的 Path 中新建一条，填入 npm 全局目录路径
# 重启 PowerShell
```

### Q: 安装后访问 http://127.0.0.1:18789 无响应

**A:** 依次检查：

```powershell
# 1. Gateway 是否在运行
openclaw gateway status

# 2. 如果没有，手动启动
openclaw gateway run

# 3. 检查端口占用
netstat -ano | findstr 18789

# 4. 检查防火墙（如果 bind 不是 loopback）
# 通常不需要，默认 loopback 不受防火墙影响
```

### Q: Node.js 安装失败

**A:** 手动安装 Node.js 24 LTS：
1. 访问 https://nodejs.org/ 下载 Windows Installer
2. 安装时勾选 "Automatically install the necessary tools"
3. 重启 PowerShell 后重新运行 `.\deploy.ps1`

### Q: 可以在没有管理员权限的情况下部署吗？

**A:** 可以。使用 `.\deploy.ps1 -SkipGatewayService`，然后手动运行：

```powershell
openclaw gateway run
```

Gateway 将在当前终端前台运行，关闭终端即停止。

## 模型与 API

### Q: 模型调用返回 401/403 错误

**A:** API Key 不正确或已过期：
1. 检查 `config\env.ps1` 中的 Key 是否正确
2. 登录 API 控制台确认 Key 状态
3. 确认账户余额充足

### Q: 主模型（GLM-5.2）不可用时会怎样？

**A:** OpenClaw 自动切换到 fallback 模型（DeepSeek V4）。回退是无感的，除了响应可能略有不同。查看日志确认回退：

```powershell
openclaw gateway logs | findstr "fallback"
```

### Q: 可以只用 DeepSeek 不用 GLM 吗？

**A:** 可以。编辑 `openclaw.json`：

```json
{
  "agents": {
    "defaults": {
      "model": {
        "primary": "novasky/deepseek-v4-pro",
        "fallbacks": []
      }
    }
  }
}
```

然后重启：`openclaw gateway restart`

### Q: 如何添加 OpenAI 或其他模型？

**A:** 在 `openclaw.json` 的 `models.providers` 中添加：

```json
{
  "openai": {
    "baseUrl": "https://api.openai.com/v1",
    "apiKey": "sk-xxxx",
    "api": "openai-completions",
    "models": [
      { "id": "gpt-4o", "name": "GPT-4o", "input": ["text"] }
    ]
  }
}
```

参考 [CONFIGURATION.md](./CONFIGURATION.md) 了解更多。

## 记忆搜索

### Q: 记忆搜索需要什么？

**A:** 需要本地安装 Ollama 并拉取 bge-m3 模型：

```powershell
# 安装 Ollama：https://ollama.com/download/OllamaSetup.exe
ollama pull bge-m3

# 然后在 env.ps1 中设置 OLLAMA_ENABLED=1
# 重新运行部署脚本
```

### Q: 不启用 Ollama 能用吗？

**A:** 可以。将 `OLLAMA_ENABLED` 设为 `"0"`（默认），Core 功能完全正常使用，只是没有本地语义搜索。

## Gateway 服务

### Q: Gateway 开机自启如何配置？

**A:** 部署脚本已自动配置。如需手动：

```powershell
openclaw gateway install
openclaw gateway status
```

### Q: 如何在远程访问 Gateway？

**A:** 仅在了解安全风险时操作：

```json
{
  "gateway": {
    "bind": "lan",
    "auth": { "mode": "token" }
  }
}
```

确保配置了强 Token 和防火墙规则。

### Q: Gateway 日志在哪里？

```powershell
# 查看日志
openclaw gateway logs

# 日志文件位置
# %TEMP%\openclaw\
```

## 性能与资源

### Q: 内存占用高吗？

**A:** 典型占用：
- OpenClaw Gateway: ~100-200 MB
- Ollama (bge-m3): ~500 MB - 1 GB（仅启用记忆搜索时）
- Node.js: ~50 MB

总计约 200MB - 1.5GB，取决于是否启用 Ollama。

### Q: 可以同时运行多个 Gateway 吗？

**A:** 可以但通常不需要。OpenClaw 设计为单实例运行，通过并发处理多任务。如果需要多实例，使用不同端口。

## 升级

### Q: 如何升级 OpenClaw？

```powershell
# 升级到最新版
npm update -g openclaw

# 重启 Gateway
openclaw gateway restart

# 验证
openclaw --version
openclaw config validate
```

### Q: 升级后配置会丢失吗？

**A:** 不会。`%USERPROFILE%\.openclaw\` 下的配置文件在升级时保持不变。

## 故障排查

### Q: 如何重置到初始状态？

```powershell
# 1. 停止并卸载服务
openclaw gateway uninstall

# 2. 删除配置
Remove-Item -Recurse $env:USERPROFILE\.openclaw

# 3. 重新部署
.\deploy.ps1
```

### Q: 获取更多帮助

- 官方文档: https://docs.openclaw.ai
- GitHub Issues: https://github.com/openclaw/openclaw/issues
- 本仓库 Issues: https://github.com/YOUR_ORG/openclaw-windows-deploy/issues
