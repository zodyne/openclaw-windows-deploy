# GBrain 共享 HTTP Serve 架构（PGLite 单写锁的正解）

> [imported 2026-07-08] 类型：架构设计 + 维护复盘。配套操作手册见 [[system-knowledge-system/gbrain_knowledge_workflow_sop]]。本页讲**为什么是这个架构、怎么一步步演进到这里**；SOP 讲**日常怎么操作**。

## 一句话

[observed 2026-07-08] GBrain 底层是 PGLite（单写者，文件锁）——**同一时刻只有一个进程能持有 DB 锁**。原来 Claude Code 和 OpenClaw 各自 spawn 自己的 `gbrain serve` 抢同一把锁 → 必然死锁。正解：**launchd 常驻单个 `gbrain serve --http`（唯一持锁进程），两个消费者都通过 HTTP MCP 连它**，共享一把锁，零 CLI 写 DB。

## 问题：一把锁，两个消费者

```
PGLite = 单写者，文件锁，同一时刻仅一个进程可持有
   消费者 A: Claude Code（我）
   消费者 B: OpenClaw 主 agent / ACP 子会话 / cron
```

冲突不是"MCP 不能共享"，而是"**两个 `gbrain serve` 进程同时抢同一把 PGLite 锁**"。任何另起的 `gbrain` CLI 碰 DB（`import`/`embed`/`extract`/`link`/`orphans`/`health`/`query`）都会撞正在持锁的 serve → `Timed out waiting for PGLite lock`（exit 143）。`gbrain link` 每条重试 3× × 2s，24 条链接批处理卡几分钟后全失败。

## 演进：连错两次，第三次才挖到根

修这个问题时，同一个根因让方案错了两次：

| 轮次 | 当时的方案 | 为什么错 |
|---|---|---|
| 第一次 | "serve 运行 → 停 serve 跑 CLI 批处理" | CLI 撞锁死；且 OpenClaw 自主模式不能停 serve |
| 第二次 | "serve 运行 → 一切走 MCP" | 那 MCP 是 **Claude Code 私有的 stdio serve**，OpenClaw 主 agent `mcp.servers: {}` 为空，根本够不着 |
| 第三次（正解） | **launchd 常驻单个 `serve --http`，两客户端共享** | 单一持锁进程 + HTTP 多客户端，冲突根除 |

**根因（第三次才看清）**：
1. **stdio serve 是点对点、私有的**——只有 spawn 它的那个客户端能通过 stdin/stdout 跟它说话。我能用 `mcp__gbrain__*`，纯粹因为我这个 Claude Code 会话开机时私有 spawn 了一个 stdio serve（它持锁、活到我会话结束）。
2. **OpenClaw 主 agent 没有 gbrain MCP**——`openclaw.json` 的 `mcp.servers: {}` 是空的。它唯一的路是 CLI，而 CLI 撞我 serve 的锁。
3. 所以"serve 运行 → 走 MCP"这条建议**只对 Claude Code 成立，对 OpenClaw 是死路**（无 MCP + CLI 被锁挡）。这是架构缺口，光改文档修不了。

> 教训：连错两次不能再打补丁，必须挖根因。前两次都栽在"没查证 OpenClaw 到底怎么访问 brain"，一直假设它和我走同一条路。关键证据 `openclaw.json → mcp.servers: {}` 一读就真相大白。

## 目标架构（已于 2026-07-08 落地 ✅）

```
launchd ai.openclaw.gbrain-serve → gbrain serve --http --port 18795   （唯一碰 PGLite 的进程）
   ├── OpenClaw 主 agent → openclaw.json mcp.servers.gbrain (streamable-http + bearer) → mcp__gbrain__*
   └── Claude Code       → ~/.claude.json user-scope http MCP (bearer)                 → mcp__gbrain__*
```

统一铁律，对两个消费者终于都成立：

> **所有 brain 读写走 MCP 工具（`mcp__gbrain__*`）打共享 HTTP serve。绝不 shell 调 `gbrain` CLI 碰 DB——它会像当年 stdio 一样撞锁。**

## 落地事实（供重建 / 排障）

| 项 | 值 |
|---|---|
| launchd | `~/Library/LaunchAgents/ai.openclaw.gbrain-serve.plist`（KeepAlive + RunAtLoad） |
| wrapper | `~/brain/gbrain-http.sh`：`source ~/brain/gbrain-env.sh; exec gbrain serve --http --port 18795` |
| 端点 | `http://127.0.0.1:18795/mcp`（`/mcp` 后缀必带；健康路径是 `/health` 非 `/healthz`） |
| token | bearer，`gbrain auth create openclaw-http`；值存于 openclaw.json + ~/.claude.json；撤销 `gbrain auth revoke openclaw-http` |
| Claude Code 接入 | `claude mcp add gbrain -s user -t http .../mcp -H 'Authorization: Bearer …'` → `✔ Connected` |
| OpenClaw 接入 | `openclaw.json` → `mcp.servers.gbrain = {url, transport:"streamable-http", headers.Authorization}`；gateway **热加载**生效（无需重启） |
| 备份 | `~/.openclaw/openclaw.json.bak-pre-gbrain-http` |

### 两个非显然的坑

1. **必须用 wrapper 脚本，不能用 plist EnvironmentVariables**：`gbrain-env.sh` 里 `OPENAI_API_KEY` 是 `$(python3 ...)` 命令替换，launchd 的 env 字典执行不了命令替换（同 [[openclaw-budget-plist-label-trap]] 的 env 块教训）。wrapper 先 source 再 exec 才对，也顺带避免把 key 明文烤进 plist。
2. **迁移临界序列**（每步 CLI 都要碰锁，必须在"无 serve 持锁"窗口做）：
   `claude mcp remove gbrain -s user`（防 harness 重 spawn stdio）→ kill 持锁 stdio serve → **无锁窗口** `gbrain auth create` 发 token → `launchctl load` HTTP serve 抢锁 → 注册两客户端。stdio serve 是 Claude Code 会话私有子进程，kill 会断本会话 stdio MCP（全程用 Bash 故可接受）。

## 附带修复的三个知识库导入缺陷

这次排查同时暴露并在 SOP 里根治了三个更早的失败模式：

1. **图谱构建缺失**：SOP 原来只到 import→embed→query 就停，没有建图谱边这一步，导致导入页全孤儿。已加"建边"环节 + 全 slug wikilink 规范（相对文件名 `docs-index.md` 不解析成边）。
2. **链接范围跑偏**：OpenClaw 曾建 ~140 条边却全加在旧簇上，本次导入的正主仍孤儿、时间线全跳过。已加 **Import Batch Scope Discipline**：每次导入后只对 `get_ingest_log` 最新批次的 `pages_updated` 建边/加时间线/验证；验收判据钉死"`orphan_pages` 应下降 ~len(BATCH)"。
3. **文本模型无法识图 → 臆造描述污染**：OpenClaw 主 agent 是纯文本 LLM（无视觉）。文本/检索/query/建边/嵌入（本地 `bge-m3`）全不受影响；唯一受影响的是**从图里抽知识**——TI 文档的高价值信息大量藏在信号链框图、DDM 时序图、天线方向图、DCA1000 接线图里。文本模型看不到这些，若强行让它总结会**臆造出看似合理实则错误的描述**，比缺失更糟（沉默污染）。已加 **Visual Content Rule**：文本层照抽 / 图像与扫描件委派视觉 agent 或 OCR / **读不到的图宁可标 `[figure not extracted — needs vision pass]` 也禁止臆造**；核心知识就是图的页无视觉 pass 时记为待抽取目标而非建"看似完整"的页。

## 已知遗留

[observed 2026-07-08] PGLite 下 **job 队列无 worker**（`gbrain jobs work` 是 Postgres-only），submit 的 backlinks/extract job 永远 `waiting`（实测 job id 1 挂了一天 0 attempts）。所以建图谱边只能逐条 MCP `add_link`，不能指望 `submit_job`。若未来迁到 Postgres，此约束解除。

## 关联

- 操作手册：[[system-knowledge-system/gbrain_knowledge_workflow_sop]]
- 同源坑：[[openclaw-budget-plist-label-trap]]（launchd plist env 块 / Label 陷阱）
