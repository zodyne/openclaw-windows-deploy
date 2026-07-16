# ACP Claude Code 接入知识库方案

> **日期**：2026-07-06 | **目标**：让 `sessions_spawn(runtime="acp")` 启动的 Claude Code 也能访问知识库
> **前置依赖**：GBrain 已安装并初始化

> ⚠️ **2026-07-08 校正（本文以下内容含过时信息，勿照抄）**
> 1. **工具名错**：文中 `gbrain_search`/`gbrain_query`/`gbrain_find_page`/`gbrain_graph_query`/`gbrain_put_page` 等**不存在**。真实 MCP 工具名无 `gbrain_` 前缀，在 Claude Code 中为 `mcp__gbrain__<name>`：`query`/`search`/`get_page`/`traverse_graph`/`list_pages`/`get_links`/`get_backlinks`/`put_page`/`add_link`/`add_tag`。
> 2. **注册路径错**：`~/.claude/.mcp.json` 是**非标准路径，Claude Code 不加载**。真实生效为 **user scope 的 `~/.claude.json`**，命令指向 `~/brain/gbrain-mcp.sh`（自带 env）。
> 3. **权威验证**：以 `claude mcp get gbrain` 显示 `✔ Connected` 为准。详见 `~/.claude/.../memory/gbrain-claude-mcp-fix.md`。

---

## 一、原理分析

### 1.1 ACP Claude Code 的启动链路

```
sessions_spawn(runtime="acp") 
    │
    ▼
OpenClaw ACP Harness
    │
    ├── 读取 claude-agent-acp-wrapper.mjs（桥接脚本）
    ├── 设置 cwd、环境变量
    ├── 注入 CLAUDE.md / AGENTS.md 上下文
    └── spawn: claude --prompt "..." --project-dir /path/to/project
            │
            ▼
        Claude Code 进程启动
            │
            ├── 读取 ~/.claude/.mcp.json        ← MCP 服务器配置（全局）
            ├── 读取 <project>/.mcp.json          ← MCP 服务器配置（项目级）
            ├── 读取 CLAUDE.md                    ← 项目上下文
            └── 连接所有注册的 MCP server          ← 这里接入 GBrain
```

### 1.2 关键机制：Claude Code MCP 配置是全局的

Claude Code 的 MCP 配置存储在 `~/.claude/.mcp.json` 中，**所有 Claude Code 实例共享同一份配置**——无论是手动 `claude` 启动的还是 ACP 通过 `sessions_spawn` 启动的。

**这意味着**：只要在全局配置中注册了 GBrain MCP，ACP-spawned 的 Claude Code 自动拥有知识库访问能力。

### 1.3 接入方式对比

| 方式 | 作用范围 | 配置位置 | ACP-spawned 可见？ | 推荐 |
|---|---|---|---|---|
| `claude mcp add gbrain -- gbrain serve` | **全局** | `~/.claude/.mcp.json` | ✅ 是 | **用这个** |
| 项目 `.mcp.json` | 单项目 | `<project>/.mcp.json` | ⚠️ 取决于 ACP 的 project-dir | 不推荐 |
| ACP wrapper 注入 | 仅 ACP | 需改 wrapper 脚本 | ✅ | 复杂，维护成本高 |

---

## 二、接入方案

### 2.1 方案：全局 MCP 注册（推荐，一行命令）

**前提**：GBrain 已安装（`gbrain --version` 可用）且大脑已初始化（`gbrain doctor` 显示 healthy）

```bash
# 在全局注册 GBrain MCP server（stdio 模式）
claude mcp add gbrain -- gbrain serve

# 验证注册成功
claude mcp list
# 预期输出中包含 gbrain 及其提供的工具列表
```

**生效范围**：
- 手动启动的 `claude` → ✅ 可用
- `sessions_spawn(runtime="acp")` 启动的 Claude Code → ✅ 可用
- Claude Desktop App → ✅ 可用
- 任何本机上的 Claude Code 实例 → ✅ 可用

### 2.2 原理：stdio MCP 的自动生命周期

```
claude mcp add gbrain -- gbrain serve
│
└── 写入 ~/.claude/.mcp.json:
    {
      "mcpServers": {
        "gbrain": {
          "type": "stdio",
          "command": "gbrain",
          "args": ["serve"]
        }
      }
    }

Claude Code 启动时：
  1. 读取 ~/.claude/.mcp.json
  2. spawn "gbrain serve" 作为子进程
  3. 通过 stdin/stdout 进行 MCP 协议通信
  4. Claude Code 退出时自动终止 gbrain serve

ACP 启动的 Claude Code 同样走这个流程——完全透明。
```

### 2.3 ACP-spawned Claude Code 使用 GBrain 的示例流程

```
用户 → OpenClaw → sessions_spawn(runtime="acp", task="修复 <your-project> 暗室测角 bug")

ACP Harness 启动 Claude Code:
  ├── cwd: ~/.openclaw/projects/ucm221-fix/
  ├── CLAUDE.md: 注入任务描述 + 项目上下文
  └── spawn: claude --prompt "修复 <your-project> 暗室测角 bug..."

Claude Code 启动：
  ├── 读取 ~/.claude/.mcp.json
  ├── 发现 gbrain MCP server → spawn "gbrain serve"
  └── MCP 工具就绪：
      gbrain_search, gbrain_query, gbrain_find_page,
      gbrain_graph_query, gbrain_put_page, ...

Claude Code 执行流程：
  Step 1: gbrain_search "<your-project> 暗室测角 bug" → 找到相关页面
  Step 2: gbrain_query → 综合答案：
    "暗室测角模块由 用户负责，上次讨论相位校准(6/15)。
     相关文件: angle_calibration.m, phase_error_analysis.py"
  Step 3: 基于知识库上下文，定位并修复代码
  Step 4: gbrain_put_page → 记录修复决策和发现
  Step 5: 返回结果给 OpenClaw
```

### 2.4 ACP 中 Claude Code 的完整工具集

接入 GBrain MCP 后，ACP-spawned Claude Code 拥有的工具：

| 工具来源 | 工具 | 用途 |
|---|---|---|
| **Claude Code 内置** | Bash, Read, Write, Edit, Glob, Grep | 代码编辑 |
| **Claude Code 内置** | Task, TodoWrite, WebSearch | 任务管理、搜索 |
| **GBrain MCP（新增）** | `gbrain_search` | 混合搜索知识库 |
| **GBrain MCP（新增）** | `gbrain_query` | LLM 综合答案 + 缺口分析 |
| **GBrain MCP（新增）** | `gbrain_find_page` | 精确查找页面 |
| **GBrain MCP（新增）** | `gbrain_graph_query` | 图遍历查询实体关系 |
| **GBrain MCP（新增）** | `gbrain_put_page` | 将发现/决策写回大脑 |
| **GBrain MCP（新增）** | `gbrain_list_pages` | 列出所有页面 |
| **GBrain MCP（新增）** | `gbrain_get_links` | 查询页面关联关系 |

---

## 三、脑优先行为（注入 CLAUDE.md）

为了让 ACP-spawned Claude Code 主动使用知识库（而不是等用户提醒），需要在 ACP 注入的 CLAUDE.md 中加入行为规范。

### 3.1 在 ACP wrapper 或项目模板中注入

在对应项目的 `CLAUDE.md` 或 ACP 上下文注入模板中添加：

```markdown
## Knowledge Base Protocol (GBrain)

You have access to the user's personal knowledge brain via MCP tools (gbrain_*).
The brain is a self-wiring knowledge graph with hybrid search, synthesis, and gap analysis.

### When to query the brain

BEFORE writing any code for a project/task mentioned by the user:
  1. gbrain_search for the project name + task keywords
  2. If relevant pages exist, gbrain_query for a synthesized answer
  3. For module/people relationships, gbrain_graph_query

### When to write to the brain

AFTER completing significant work:
  1. gbrain_put_page to record decisions, findings, new context
  2. Especially: anything the brain's gap analysis flagged as missing
  3. Use the slug convention: projects/<name>/<topic>

### Trust the brain

The brain is the ground truth for:
- Project context and architecture decisions
- Module/people relationships and responsibilities
- Meeting outcomes and pending action items
- What's NOT known (gap analysis)

If the brain contradicts your assumptions, trust the brain.
```

### 3.2 方案：在 ACP 配置中添加全局 CLAUDE.md 注入

可以在 OpenClaw ACP 配置中设置全局 CLAUDE.md 模板，自动注入到每个 ACP-spawned Claude Code 会话：

```json
// openclaw.json 中的 ACP 配置
{
  "acp": {
    "claudeContext": {
      "prependFiles": [
        "~/.openclaw/workspace/memory/claude-brain-protocol.md"
      ]
    }
  }
}
```

---

## 四、接入验证

### 4.1 手动验证（先在终端测试）

```bash
# 1. 确认 Claude Code 已安装
claude --version

# 2. 注册 GBrain MCP
claude mcp add gbrain -- gbrain serve

# 3. 查看注册的工具
claude mcp list
# 预期：显示 gbrain 及其 tools 列表

# 4. 在 Claude Code 中测试
claude --prompt "用 gbrain_search 搜索 <your-project> 项目"
# 预期：Claude Code 调用 MCP 并返回知识库结果

# 5. 测试写回
claude --prompt "用 gbrain_put_page 在测试页面写一条测试记录"
# 预期：写入成功
```

### 4.2 ACP 验证（通过 OpenClaw）

```
# 在 OpenClaw 中：
sessions_spawn(
  runtime="acp",
  agentId="claude",
  task="用 gbrain_search 搜索 <your-project>，然后告诉我结果"
)
# 预期：ACP-spawned Claude Code 成功调用 GBrain MCP 并返回结果
```

### 4.3 验收清单

| # | 检查项 | 通过标准 |
|---|---|---|
| V1 | 全局 MCP 注册 | `claude mcp list` 显示 gbrain |
| V2 | 手动 Claude Code 可搜索 | `claude --prompt "gbrain_search test"` 返回结果 |
| V3 | 手动 Claude Code 可写 | `gbrain_put_page` 写入成功 |
| V4 | ACP Claude Code 可搜索 | sessions_spawn + gbrain_search 返回结果 |
| V5 | ACP Claude Code 可写 | sessions_spawn + gbrain_put_page 写入成功 |
| V6 | 脑优先行为生效 | Claude Code 自动查脑再编码 |

---

## 五、故障排查

| 问题 | 原因 | 解决 |
|---|---|---|
| `gbrain: command not found` | ACP spawn 的环境没有 `PATH` 包含 bun/bin | 在 ACP wrapper 中 `export PATH="$HOME/.bun/bin:$PATH"` |
| `gbrain serve` 启动失败 | PGLite 数据库被锁定 | 确认无其他进程持有 `~/brain/gbrain.db`，杀掉残留 `gbrain serve` |
| Claude Code 不调用 gbrain 工具 | CLAUDE.md 中没有脑优先指令 | 按第三节注入 CLAUDE.md |
| MCP 工具超时 | 嵌入未完成或并发过高 | `gbrain doctor` 检查健康状态 |
| `database is locked` | PGLite 并发写入冲突 | 等几秒自动恢复（SQLite 级别 WAL 模式） |

---

## 六、总结

**接入复杂度：1 条命令**

```bash
claude mcp add gbrain -- gbrain serve
```

**原理**：Claude Code 的 MCP 配置是全局的（`~/.claude/.mcp.json`），所有 Claude Code 实例——手动启动的、ACP spawn 的、Desktop App 的——共享同一份配置。注册一次，全局生效。

**增量步骤**：
1. 确保 GBrain 已安装 + 大脑已初始化（按 `gbrain-plan.md` Phase A）
2. `claude mcp add gbrain -- gbrain serve`
3. 在 ACP 注入的 CLAUDE.md 中追加脑优先行为规范

**ACP-spawned Claude Code 即可自动拥有**：搜索、综合回答、图谱查询、知识写入——全部 MCP 工具。
