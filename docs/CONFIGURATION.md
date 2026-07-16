# Configuration Reference

## Configuration File

Location: `%USERPROFILE%\.openclaw\openclaw.json`

## Model Providers

### GLM-5.2 (Primary — Zhipu AI)

```json
{
  "models": {
    "providers": {
      "zai": {
        "baseUrl": "https://open.bigmodel.cn/api/anthropic",
        "apiKey": "your-zhipu-api-key",
        "api": "anthropic-messages",
        "models": [{
          "id": "glm-5.2",
          "name": "GLM-5.2",
          "reasoning": true,
          "input": ["text"],
          "contextWindow": 200000,
          "maxTokens": 32768
        }]
      }
    }
  }
}
```

**Pricing** (as of 2026-07): Check https://open.bigmodel.cn/pricing for current rates.

### DeepSeek V4 (Fallback)

```json
{
  "models": {
    "providers": {
      "novasky": {
        "baseUrl": "https://api.deepseek.com/v1",
        "apiKey": "your-deepseek-api-key",
        "api": "openai-completions",
        "models": [{
          "id": "deepseek-v4-pro",
          "name": "DeepSeek V4 Pro",
          "reasoning": true,
          "input": ["text"],
          "contextWindow": 1000000,
          "maxTokens": 128000,
          "compat": { "supportsDeveloperRole": false }
        }]
      }
    }
  }
}
```

### Adding Custom Providers

Add entries under `models.providers`:

```json
{
  "models": {
    "providers": {
      "my-provider": {
        "baseUrl": "https://api.example.com/v1",
        "apiKey": "your-key",
        "api": "openai-completions",
        "models": [
          { "id": "model-name", "name": "Display Name", "input": ["text"] }
        ]
      }
    }
  }
}
```

Use the model as `my-provider/model-name` in `agents.defaults.model`.

## Model Routing

```json
{
  "agents": {
    "defaults": {
      "model": {
        "primary": "zai/glm-5.2",
        "fallbacks": ["novasky/deepseek-v4-pro"]
      }
    }
  }
}
```

- `primary`: Default model for all agent tasks
- `fallbacks`: Ordered fallback chain when primary is unavailable
- Models auto-failover; no manual intervention needed

## Gateway Configuration

```json
{
  "gateway": {
    "port": 18789,
    "mode": "local",
    "bind": "loopback",
    "auth": {
      "mode": "token",
      "token": "your-gateway-token"
    }
  }
}
```

| Field | Default | Description |
|-------|---------|-------------|
| `port` | 18789 | Gateway HTTP/WebSocket port |
| `mode` | "local" | "local" (single-user) or "remote" (multi-user) |
| `bind` | "loopback" | "loopback" (127.0.0.1 only) or "lan" (network-accessible) |
| `auth.mode` | "token" | "token" (Bearer auth) or "none" (insecure) |

⚠️ **Security**: Use `bind: "loopback"` unless you have firewall rules and understand the risks. Use `auth.mode: "token"` always.

## Memory Search

```json
{
  "agents": {
    "defaults": {
      "memorySearch": {
        "enabled": true,
        "provider": "openai",
        "model": "bge-m3",
        "outputDimensionality": 1024,
        "remote": {
          "baseUrl": "http://127.0.0.1:11434/v1",
          "apiKey": "ollama"
        },
        "extraPaths": [
          "C:\\Users\\YourName\\.openclaw\\workspace\\knowledge-base\\vault"
        ]
      }
    }
  }
}
```

Requires Ollama running locally with `bge-m3` model pulled.

## Sub-agents

```json
{
  "agents": {
    "defaults": {
      "subagents": {
        "delegationMode": "suggest",
        "maxConcurrent": 1,
        "maxSpawnDepth": 1,
        "maxChildrenPerAgent": 3,
        "archiveAfterMinutes": 60
      }
    }
  }
}
```

| Field | Default | Description |
|-------|---------|-------------|
| `delegationMode` | "suggest" | "auto" (agent decides), "suggest" (prompts user), "disabled" |
| `maxConcurrent` | 1 | Max parallel sub-agents |
| `maxSpawnDepth` | 1 | Max nesting depth |
| `maxChildrenPerAgent` | 3 | Max children per parent |

## Context Limits

```json
{
  "agents": {
    "defaults": {
      "contextLimits": {
        "toolResultMaxChars": 50000,
        "memoryGetMaxChars": 30000,
        "postCompactionMaxChars": 12000
      }
    }
  }
}
```

Controls token/context budget to prevent context overflow.

## Plugins

```json
{
  "plugins": {
    "entries": {
      "memory-core": { "config": {} },
      "acpx": {
        "enabled": false,
        "config": {
          "permissionMode": "approve-reads",
          "timeoutSeconds": 120
        }
      },
      "codex-supervisor": { "enabled": true }
    },
    "allow": ["acpx", "codex-supervisor", "memory-core"]
  }
}
```

| Plugin | Description | Default |
|--------|-------------|---------|
| `memory-core` | Semantic memory indexing and search | enabled |
| `acpx` | ACP Harness for Claude Code/Gemini CLI | disabled |
| `codex-supervisor` | Codex session supervisor | enabled |

## ACP Harness (for Claude Code)

To enable Claude Code integration:

1. Install Claude Code on Windows (via WSL or native)
2. Update config:

```json
{
  "acp": {
    "enabled": true,
    "defaultAgent": "claude",
    "allowedAgents": ["claude", "codex"]
  },
  "plugins": {
    "entries": {
      "acpx": {
        "enabled": true,
        "config": {
          "permissionMode": "approve-reads",
          "timeoutSeconds": 120,
          "agents": {
            "claude": {
              "command": "claude"
            }
          }
        }
      }
    }
  }
}
```

## MCP Servers

Add Model Context Protocol servers:

```json
{
  "mcp": {
    "servers": {
      "my-tool": {
        "url": "http://localhost:3000/mcp",
        "transport": "streamable-http",
        "headers": {
          "Authorization": "Bearer token"
        }
      }
    }
  }
}
```

## Environment Variables

Set via `config/env.ps1` (loaded by deploy script) or directly in system environment:

| Variable | Required | Description |
|----------|----------|-------------|
| `ZHIPU_API_KEY` | Yes | Zhipu AI API key for GLM-5.2 |
| `DEEPSEEK_API_KEY` | Yes | DeepSeek API key for fallback |
| `OLLAMA_ENABLED` | No | Set to "1" to enable local memory search |
| `GITLAB_TOKEN` | No | GitLab personal access token |
| `GITLAB_URL` | No | GitLab instance URL |
| `ANTHROPIC_API_KEY` | No | Anthropic API key (for Claude Code) |

## Validation

```powershell
# Always validate after editing config
openclaw config validate

# Restart to apply changes
openclaw gateway restart
```
