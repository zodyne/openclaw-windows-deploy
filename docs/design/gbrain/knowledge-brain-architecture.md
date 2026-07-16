# 知识大脑架构 — 部署记录与配置总览

> provenance: [confirmed] 2026-07-07 部署完成，用户批准
> 关联设计：memory/gbrain-plan.md, memory/gbrain-claude-code-integration.md, memory/gbrain-acp-claude-integration.md

---

## 一、架构拓扑

```
个人知识大脑
│
├── OpenClaw Gateway (18789)
│   ├── memorySearch (Ollama bge-m3, 1024d) ← 快速通道：单文件查找、项目状态
│   ├── AGENTS.md § 知识优先推理协议       ← 推理前强制检索
│   └── HEARTBEAT.md                       ← 每日晨报集成 GBrain 状态
│
├── GBrain v0.42.57.0 (CLI + MCP)
│   ├── PGLite WASM (~/.gbrain/brain.pglite, 75MB)
│   ├── Ollama nomic-embed-text (768d)     ← 混合搜索：关键词+向量+图 RRF 融合
│   ├── Novasky deepseek-v4-pro (via 18789)← 答案合成+引用+缺口分析
│   └── 89 页 / 783 chunks / 100% 嵌入覆盖
│
├── Claude Code 2.1.201 (via ACP)
│   ├── ~/.claude.json(user)→ gbrain-mcp.sh ← MCP mcp__gbrain__*，编码时自动查知识库
│   └── CLAUDE.md § Brain-First Protocol  ← 编码前查→编码后写
│
└── 维护平面
    ├── 系统 crontab: 每日 02:00 增量导入+嵌入
    ├── 系统 crontab: 每周一 09:00 健康检查
    └── OpenClaw cron: 工作日 09:05 GBrain 状态入晨报
```

---

## 二、GBrain 部署详情

### 2.1 安装信息

| 项目 | 值 |
|---|---|
| 版本 | 0.42.57.0 (MIT, garrytan/gbrain) |
| 运行时 | Bun 1.3.14 |
| 存储引擎 | PGLite WASM PostgreSQL 17.5 |
| 数据库路径 | `~/.gbrain/brain.pglite` (75MB) |
| Schema 版本 | 122 (latest) |
| Schema Pack | gbrain-base-v2 |
| 搜索模式 | balanced (12K context / 25 chunks) |

### 2.2 嵌入配置

| 项目 | 值 |
|---|---|
| 嵌入模型 | Ollama nomic-embed-text (274MB, 768d, MTEB ~62) |
| 嵌入并发 | 1（Issue #2552 社区确认：CPU Ollama 必须单线程） |
| 增量嵌入 | `gbrain embed --stale`，仅处理变更 chunks |
| 延迟 | ~73ms/次 |

### 2.3 Chat 综合配置

| 项目 | 值 |
|---|---|
| 模型 | deepseek-v4-pro（via OpenClaw Gateway 18789） |
| 端点 | `http://127.0.0.1:18789/v1`（OpenAI 兼容） |
| API Key | 从 `openclaw.json` 的 `env.vars.NOVASKY_API_KEY` 动态提取 |
| 注意 | 原计划端口 18790，实测绘得 chat/completions 仅 18789 可用 |

### 2.4 知识源

| 来源 | 页数 | 导入方式 |
|---|---|---|
| `knowledge-base/vault/` | 60 | 初始全量导入 |
| `workspace/memory/` | 12 | 初始全量导入（原计划遗漏，补充纳入） |
| `vault/System-Design/openclaw-plan/` | 17 | 按需追加 |
| **合计** | **89** | |

---

## 三、知识检索体系

### 3.1 双引擎分工

| 引擎 | 工具 | 维度 | 场景 |
|---|---|---|---|
| OpenClaw memorySearch | `memory_search` | bge-m3 1024d | 单文件查找、项目状态、联系人、偏好 |
| GBrain 混合搜索 | `exec: gbrain query "..."` | nomic 768d + FTS + RRF | 跨文件综合、答案合成、缺口分析、实体关系 |

### 3.2 推理触发规则（AGENTS.md § 知识优先推理协议）

| 场景 | 引擎 | 触发时机 |
|---|---|---|
| 项目编码任务 | memory_search → gbrain query | 编码前 |
| 跨模块影响分析 | gbrain query | 涉及多个模块时 |
| 历史决策回溯 | gbrain query | 需要了解原因时 |
| 人员/模块关系 | gbrain graph-query | 涉及分工时 |
| 缺口感知 | gbrain query | 主动发现未知 |
| 日常状态查询 | memory_search | 快速项目状态 |

### 3.3 降级链

```
gbrain exec 失败 → fallback memory_search → 告知"GBrain 离线，仅返回匹配文件"
```

### 3.4 写回规则

| 内容 | 目标 | 标签 |
|---|---|---|
| 重要技术决策+理由 | vault 对应项目文件 | `[confirmed]` |
| 新发现的模块/接口 | vault 对应项目文件 | `[observed]` |
| GBrain 缺口标记的信息 | 对应页面补充 | `[inferred]` → 先入 pending_review |

---

## 四、Claude Code MCP 集成

### 4.1 配置

| 文件 | 内容 |
|---|---|
| `~/.claude/.mcp.json` | 全局 MCP 注册：gbrain (stdio) + gitnexus |
| `~/brain/gbrain-mcp.sh` | MCP 启动 wrapper，安全注入 API key |
| `~/.claude/CLAUDE.md` | Brain-First Protocol：编码前自动查→编码后自动写 |

### 4.2 Brain-First Protocol 步骤

```
编码任务 →
  1. gbrain_search(项目名+关键词)        ← 搜索相关页面
  2. gbrain_query(综合问题)              ← 跨文件综合答案
  3. gbrain_graph_query(实体)            ← 人物/模块关系
  4. 引用出处 + 缺口告警                  ← 透明度
  5. 完成编码 →
  6. gbrain_put_page(决策+发现)          ← 写回大脑
```

### 4.3 生效范围

- 手动 `claude` 启动 → ✅ 可用
- `sessions_spawn(runtime="acp")` → ✅ 自动继承全局 MCP
- Claude Desktop → ✅ 同配置，格式稍异

---

## 五、自动化维护

### 5.1 系统 crontab

```
# 每日 02:00：增量导入+嵌入
0 2 * * * ~/brain/gbrain-cron.sh gbrain import vault/ memory/ && gbrain embed --stale

# 每周一 09:00：健康检查
0 9 * * 1 ~/brain/gbrain-cron.sh gbrain doctor
```

### 5.2 OpenClaw cron

| 任务 | 时间 | ID |
|---|---|---|
| GBrain 状态入晨报 | 工作日 09:05 | `gbrain-daily-status` |
| bge-m3 Issue 追踪 | 每周一 09:00 | `gbrain-bge-m3-tracker` |

### 5.3 辅助脚本

| 文件 | 用途 |
|---|---|
| `~/brain/gbrain-env.sh` | 环境变量（API key 动态注入，权限 700） |
| `~/brain/gbrain-cron.sh` | cron 包装器（日志+时间戳） |
| `~/brain/gbrain-mcp.sh` | MCP 启动包装器 |

---

## 六、关键配置文件

| 文件 | 作用 | 变更日期 |
|---|---|---|
| `~/.claude/.mcp.json` | Claude Code MCP 全局注册 | 2026-07-07 新建 |
| `~/.claude/CLAUDE.md` | Brain-First Protocol | 2026-07-07 追加 |
| `~/.openclaw/workspace/AGENTS.md` | 知识优先推理协议 + 架构状态 | 2026-07-07 追加 |
| `~/brain/gbrain-env.sh` | GBrain 环境变量 | 2026-07-07 新建 |
| `~/.gbrain/brain.pglite` | PGLite 数据库 | 2026-07-07 新建 |

---

## 七、已知限制与待办

| 限制 | 原因 | 缓解 |
|---|---|---|
| 知识图谱为空 (0 links) | vault 文件无 `[[wikilink]]` 格式 | 后续增量写入时自然生长 |
| Dream Cycle 不可用 | 需 Anthropic API Key | 基础 import+embed 足够 |
| bge-m3 不可用 | Issue #2170, #2541 未修复 | 每周一自动追踪 |
| MCP 仅 stdio | PGLite 单文件，不支持远程 | 如需要可配 `gbrain serve --http` |
| 磁盘占用 ~350MB | 正常水平 | 充足余量 |

---

## 八、回滚方案

```bash
# 1. 停止 cron
crontab -l | grep -v gbrain | crontab -

# 2. 移除 MCP 注册
rm ~/.claude/.mcp.json

# 3. 恢复 CLAUDE.md
# 删除 "Brain-First Protocol" 段落

# 4. 恢复 AGENTS.md
# 删除 "知识优先推理协议" 段落 + 恢复旧架构状态行

# 5. 保留数据库（不删除，方便恢复）
# ~/.gbrain/brain.pglite 不动
# ~/brain/ 目录不动

# OpenClaw memorySearch + HEARTBEAT 不受影响，继续正常工作
```
