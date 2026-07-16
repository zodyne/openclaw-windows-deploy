# GBrain 接入 Claude Code 分析

> **状态**：3 轮迭代论证完成 · 待 用户决策
> **日期**：2026-07-06
> **分析范围**：GBrain + Claude Code MCP 集成，含本机 OpenClaw 三端协同

> ⚠️ **2026-07-08 校正（本文含过时信息，勿照抄工具名/路径）**
> - **工具名**：文中 `gbrain_search`/`gbrain_query`/`gbrain_put_page` 等**不存在**。真实 MCP 名无 `gbrain_` 前缀，在 Claude Code 中为 `mcp__gbrain__<name>`（`query`/`search`/`get_page`/`traverse_graph`/`list_pages`/`get_links`/`put_page`/`add_link`/`add_tag`）。
> - **注册**：不是 `~/.claude/.mcp.json`（不加载），而是 **user scope `~/.claude.json`**，命令 `~/brain/gbrain-mcp.sh`。以 `claude mcp get gbrain` = `✔ Connected` 为准。详见 `gbrain-claude-mcp-fix`（Claude 记忆）。

---

## 目录

1. [第 1 轮：能不能接？——MCP 协议与架构验证](#1-第-1-轮能不能接mcp-协议与架构验证)
2. [第 2 轮：接上之后什么样？——能力边界与信任模型](#2-第-2-轮接上之后什么样能力边界与信任模型)
3. [第 3 轮：怎么接？——三端协同策略与接入方案](#3-第-3-轮怎么接三端协同策略与接入方案)

---

## 1. 第 1 轮：能不能接？——MCP 协议与架构验证

### 1.1 结论先行：完全可以，这是 GBrain 的原生设计

GBrain 的 MCP 功能**不是事后嫁接的插件，而是与 CLI 共享同一套操作接口的原生能力**。`src/core/operations.ts` 定义约 90 个操作，CLI 和 MCP Server 从同一源生成。这意味着任何 MCP 兼容的客户端（Claude Code、Cursor、Codex、Windsurf 等）都可以直接使用 GBrain 的全部搜索和图谱能力。

### 1.2 两种接入路径

```
┌──────────────────────────────────────────────────────────────────┐
│                      路径 A：本地 stdio                            │
│                                                                  │
│   Claude Code ──stdio──→ gbrain serve (MCP Server)               │
│   (laptop)                └── PGLite DB (~/brain/gbrain.db)      │
│                                                                  │
│   命令：claude mcp add gbrain -- gbrain serve                     │
│   条件：Claude Code 和 GBrain 在同一台机器                         │
│   配置：零配置，无需 token，无需网络                                │
│                                                                  │
├──────────────────────────────────────────────────────────────────┤
│                      路径 B：远程 HTTP                            │
│                                                                  │
│   Claude Code ──HTTP/SSE──→ gbrain serve --http                  │
│   (anywhere)                └── OAuth 2.1 / Bearer Token         │
│                                 └── PGLite DB                    │
│                                                                  │
│   命令：claude mcp add --transport http gbrain <url>              │
│   条件：GBrain 主机需公网可达（或 Tailscale/ngrok 内网穿透）        │
│   配置：需要 --header "Authorization: Bearer <token>"             │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

### 1.3 MCP 协议层分析

GBrain MCP Server 暴露的操作（从 `operations.ts` 自动生成）：

| 操作 | 权限 | 说明 | Claude Code 可用 |
|---|---|---|---|
| `search` | read | 混合搜索（关键词+向量+图） | ✅ |
| `query` | read | LLM 综合答案 + 引用 + 缺口分析 | ✅ |
| `find_page` | read | 按 slug 精确查找页面 | ✅ |
| `list_pages` | read | 列出所有页面 | ✅ |
| `graph_query` | read | 图遍历查询实体关系 | ✅ |
| `get_links` | read | 获取页面链接关系 | ✅ |
| `put_page` | write | 写入/更新页面 | ✅ |
| `delete_page` | write | 删除页面 | ✅ |
| `add_tag` | write | 添加标签 | ✅ |
| `file_upload` | write | 文件上传 | ⚠️ 受限（remote=true 时文件系统受限） |
| `run_onboard` | admin | 大脑健康评估 | ⚠️ 需 admin scope |
| `synthesize` | protected | 内容综合（Dream Cycle 阶段） | ❌ 仅本地 CLI |
| `consolidate` | protected | 记忆整合（Dream Cycle 阶段） | ❌ 仅本地 CLI |

**关键发现**：所有**读操作**和**基础写操作**对 MCP 客户端完全开放，但 **Dream Cycle 的受保护阶段**（综合、整合）仅限本地 CLI 调用——这防止了远程 Agent 触发高成本的 LLM 批处理。

### 1.4 信任边界（必须理解）

```
                    Trusted (remote=false)           Untrusted (remote=true)
                    ─────────────────────            ──────────────────────
                    本地 CLI (gbrain query)           MCP Client (Claude Code)
                    本地 cron (gbrain dream)          MCP Client (Codex)
                    本地脚本                          MCP Client (Cursor)
                         │                                    │
                         ▼                                    ▼
                    所有操作可用                        读操作 + 基础写操作
                    含 Dream Cycle                     不含 protected/admin 操作
                    文件系统无限制                      file_upload 受限
```

**这意味着**：Claude Code 通过 MCP 可以搜索、查询、写页面、建图谱链接——但**不能触发 Dream Cycle**、**不能执行管理操作**。这是设计上的安全边界。

---

## 2. 第 2 轮：接上之后什么样？——能力边界与信任模型

### 2.1 Claude Code 接入后获得的能力

```
┌─────────────────────────────────────────────────────────────────┐
│              接入前：Claude Code 是"失忆的编程高手"               │
│                                                                 │
│   用户："帮我给 <your-project> 的点云过滤模块加个单元测试"                │
│   Claude Code：                                                  │
│     "好的，但我不了解 <your-project> 项目是什么、                       │
│      点云过滤的接口定义在哪、现有测试框架用什么。                  │
│      请把这些信息粘贴给我。"                                     │
│                                                                 │
├─────────────────────────────────────────────────────────────────┤
│              接入后：Claude Code 有"项目记忆"                     │
│                                                                 │
│   用户：同上                                                      │
│   Claude Code（自动查 GBrain）：                                 │
│     "根据知识库，<your-project> 是无人机避障雷达项目，                     │
│      点云质量过滤模块由 用户负责，                              │
│      接口定义在 point_cloud_filter.h，                           │
│      现有测试使用 MATLAB unittest 框架。                          │
│      我现在开始写测试。"                                          │
│                                                                 │
│   新增能力：                                                      │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │ ✅ 编码前自动查项目背景、模块归属、接口定义               │  │
│   │ ✅ 编码后自动把决策和发现写回大脑                          │  │
│   │ ✅ 引用的会议纪要和设计文档有出处                          │  │
│   │ ✅ 跨文件关联（"这个函数还被哪些模块调用？"）              │  │
│   │ ✅ 缺口感知（"大脑里没有这个模块的测试覆盖信息"）          │  │
│   └─────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

### 2.2 实际工作流示例

**场景：用户在 Claude Code 中编码，需要了解 <your-project> 背景**

```
User: "<your-project> 暗室测角模块有个 bug，帮我定位"

Claude Code 自动执行（通过 MCP → GBrain）：
  1. gbrain search "<your-project> 暗室测角"           → 找到相关页面
  2. gbrain find_page "projects/<your-project>"         → 项目总览
  3. gbrain graph_query "<your-project>" --depth 1      → 关联模块和人员
  4. 阅读返回的综合答案：
     "暗室测角模块由 用户负责，上次会议(6月15日)讨论过相位校准问题。
      相关文件: angle_calibration.m, phase_error_analysis.py。
      ⚠️ 知识库中自此之后无更新，可能有新的修复未被记录。"

Claude Code 回答：
  "根据项目记录，你上次在 6/15 讨论了相位校准问题。
   我先检查 angle_calibration.m 和 phase_error_analysis.py，
   看看是否有已知的校准偏移。
   
   顺便提一下——6/15 之后大脑里没有这个模块的新信息，
   如果你最近修过什么，我可能不知道。"
```

### 2.3 接入后的限制

| 能力 | Claude Code 能做什么 | Claude Code 不能做什么 |
|---|---|---|
| 知识搜索 | ✅ 搜索、查询、图遍历 | — |
| 知识写入 | ✅ 写新页面、更新已有页面 | ❌ 不能触发 bulk import |
| 图谱构建 | ✅ `put_page` 自动触发自接线 | ❌ 不能跑 `extract links --source db` |
| 嵌入生成 | — | ❌ 不能跑 `gbrain embed --stale` |
| Dream Cycle | — | ❌ 不能跑 `gbrain dream`（protected） |
| 管理操作 | — | ❌ 不能 `doctor --remediate`、`config set`、`auth create` |
| 文件系统 | ⚠️ `file_upload` 受限 | ❌ 不能自由读写磁盘 |

**这意味着**：Claude Code 是大脑的**日常使用者**——读知识、写笔记、建关联——但**维护任务**（嵌入、Dream、健康检查）仍需 OpenClaw 的 cron 或手动 CLI 执行。这是正确的关注点分离。

### 2.4 与 OpenClaw 的关系

```
┌─────────────────────────────────────────────────────────────────┐
│                      三端协同拓扑                                 │
│                                                                 │
│   ┌──────────────┐    ┌──────────────┐    ┌──────────────┐     │
│   │  OpenClaw    │    │  Claude Code │    │  cron/CLI    │     │
│   │  (主控平面)   │    │  (编码平面)   │    │  (维护平面)   │     │
│   │              │    │              │    │              │     │
│   │  · 对话管理  │    │  · 代码编辑  │    │  · gbrain     │     │
│   │  · 心跳任务  │    │  · Git 操作  │    │    dream     │     │
│   │  · 审批流程  │    │  · 调试      │    │  · gbrain     │     │
│   │  · 项目跟踪  │    │  · 测试      │    │    embed     │     │
│   │              │    │              │    │  · gbrain     │     │
│   │  知识访问:    │    │  知识访问:    │    │    doctor    │     │
│   │  memorySearch│    │  GBrain MCP  │    │              │     │
│   │  (语义搜索)   │    │  (混合搜索)   │    │              │     │
│   └──────┬───────┘    └──────┬───────┘    └──────┬───────┘     │
│          │                   │                   │              │
│          │    ┌──────────────┼───────────────────┘              │
│          │    │              │                                  │
│          ▼    ▼              ▼                                  │
│   ┌──────────────────────────────────────────────────┐        │
│   │              PGLite Database                       │        │
│   │              ~/brain/gbrain.db                    │        │
│   │              单一数据源                            │        │
│   └──────────────────────────────────────────────────┘        │
│                                                                 │
│   冲突处理：                                                     │
│   · OpenClaw 和 Claude Code 不会同时写同一页面（不同会话）       │
│   · PGLite 单文件数据库，SQLite 级别的并发控制                    │
│   · GBrain 的 put_page 是 upsert 语义（后写覆盖前写）            │
│   · 如有并发写冲突，后者胜出——但对知识库场景影响极小              │
└─────────────────────────────────────────────────────────────────┘
```

---

## 3. 第 3 轮：怎么接？——三端协同策略与接入方案

### 3.1 接入决策树

```
你要用 Claude Code 做什么？
│
├── 编码时查项目背景、接口文档、历史决策
│   └── → 接！1 条命令，零风险
│       claude mcp add gbrain -- gbrain serve
│
├── 编码时顺便把新发现、决策写回大脑
│   └── → 接！Claude Code 可以写页面
│       需在 CLAUDE.md 中加入"查脑→编码→写脑"的行为规范
│
├── 用 Claude Code 替代 OpenClaw 管理项目
│   └── → 不建议。Claude Code 专注编码，OpenClaw 专注管理和工作流
│
└── 从远程（另一台电脑、手机）访问大脑
    └── → 可以。需配置 gbrain serve --http + 公网可达
        复杂度增加，建议先走本地再扩展
```

### 3.2 本地 stdio 接入（推荐，零配置）

**前置条件**：GBrain 已安装并初始化（按 `gbrain-plan.md` Phase A 完成）

```bash
# 一条命令完成接入
claude mcp add gbrain -- gbrain serve

# Claude Code 现在可以用 MCP 工具了：
# gbrain_search, gbrain_query, gbrain_find_page,
# gbrain_graph_query, gbrain_put_page, ...
```

**工作原理**：`claude mcp add` 在 `~/.claude/.mcp.json` 中注册一个 stdio 类型的 MCP server。Claude Code 每次启动时自动 spawn `gbrain serve` 子进程，通过 stdin/stdout 通信。进程随 Claude Code 退出而终止。

**验证**：
```bash
# 在 Claude Code 中测试
> 用 gbrain_search 工具搜索 "<your-project>"

# 预期：Claude Code 调用 MCP 工具并返回知识库搜索结果
```

### 3.3 可选：配置 Claude Code 的脑优先行为

在 Claude Code 项目的 `CLAUDE.md` 或用户级 `~/.claude/CLAUDE.md` 中追加：

```markdown
## Brain-first protocol (GBrain MCP)

Before writing any code for a project mentioned by the user, check the brain:

1. `gbrain_search` for the project name + the task description
2. If relevant pages found, `gbrain_query` for a synthesized answer
3. If the task involves people/modules, `gbrain_graph_query` for relationships
4. Reference brain sources in your response (inline citations)
5. After completing significant work, `gbrain_put_page` to record decisions,
   findings, or new context — especially anything the brain's gap analysis
   flagged as missing.

The brain is at ~/brain/gbrain.db. It's the user's external memory.
Treat it as the ground truth for project context, past decisions, and
people/module relationships.
```

### 3.4 接入后的维护分工

| 任务 | 谁负责 | 频率 | 说明 |
|---|---|---|---|
| 知识写入（笔记、决策） | OpenClaw + Claude Code | 随时 | 两个 Agent 都可以写 |
| vault → brain 同步 | cron (`gbrain sync`) | 每 15 分钟 | 保证 markdown 变更进入大脑 |
| 向量嵌入更新 | cron (`gbrain embed`) | 每 15 分钟 | 新页面生成嵌入 |
| Dream Cycle | cron (`gbrain dream`) | 每日凌晨 | 8 阶段维护 |
| 健康检查 | cron (`gbrain doctor`) | 每周一 | 大脑健康报告 |
| MCP 进程管理 | Claude Code 自动 | 启动/退出时 | `claude mcp add` 后自动 spawn |

### 3.5 接入前验证清单

| # | 检查项 | 命令 | 通过标准 |
|---|---|---|---|
| C1 | GBrain 已安装 | `gbrain --version` | 输出版本号 |
| C2 | 大脑已初始化 | `gbrain doctor --json` | `status: healthy` |
| C3 | 知识库已导入 | `gbrain stats \| grep pages` | pages > 0 |
| C4 | Claude Code 已安装 | `claude --version` | 输出版本号 |
| C5 | MCP 注册成功 | `claude mcp list` | 显示 gbrain 条目 |
| C6 | 搜索可用 | 在 Claude Code 中 `gbrain_search "test"` | 返回结果 |
| C7 | 写操作可用 | 在 Claude Code 中 `gbrain_put_page "test/page"` | 写入成功 |

### 3.6 注意事项

| 注意点 | 说明 |
|---|---|
| **PGLite 并发** | PGLite 是单文件 WASM 数据库，同一时间只有一个进程写入。OpenClaw 和 Claude Code 通常不会同时操作，风险极低。如果遇到 `database is locked`，等几秒重试。 |
| **MCP 进程生命周期** | `gbrain serve` 作为 Claude Code 的子进程运行。关闭 Claude Code 后 MCP 连接断开，但数据库不受影响。 |
| **不要重复导入** | vault markdown 已通过 cron sync 自动导入。Claude Code 通过 MCP 直接写 `put_page` 到 PGLite，不需要再写 markdown 文件。 |
| **Claude Code vs Claude Desktop** | 上述方案针对 Claude Code（终端 CLI 工具）。Claude Desktop 也支持 MCP，但配置方式不同（`claude.app` 的 `mcpServers` 配置）。同一套 MCP server 可以同时给两者使用。 |

---

## 总结

| 轮次 | 分析内容 | 结论 |
|---|---|---|
| 第 1 轮 | MCP 协议兼容性 | ✅ 原生设计，CLI 和 MCP 共享同一操作层 |
| 第 2 轮 | 能力边界与信任模型 | ✅ 读+基础写开放，protected/admin 操作仅限本地 CLI——关注点分离正确 |
| 第 3 轮 | 接入方案与三端协同 | ✅ 1 条命令接入，OpenClaw(管理)+Claude Code(编码)+cron(维护) 分工明确 |

**核心结论：GBrain 接入 Claude Code 是零摩擦、零风险、高收益的集成。一条命令 `claude mcp add gbrain -- gbrain serve` 即可让 Claude Code 从"失忆的编程高手"变成"有项目记忆的编程搭档"。接入后不需要改变任何现有工作流——OpenClaw 继续做项目管理，Claude Code 继续做编码，两者共享同一份知识大脑。**
