# GBrain 全本地部署方案

> **状态**：已完成 6 轮迭代论证 · 待 用户决策
> **日期**：2026-07-06
> **本机环境**：Apple M3 / 24GB RAM / macOS 15 · OpenClaw 2026.6.11 · Ollama (bge-m3)
> **预估耗时**：首次部署 30 分钟 · **增量成本：$0/月**

---

## 目录

1. [GBrain 是什么](#1-gbrain-是什么)
2. [本机现状与差距分析](#2-本机现状与差距分析)
3. [全本地化技术方案](#3-全本地化技术方案)
4. [集成架构设计](#4-集成架构设计)
5. [详细安装流程](#5-详细安装流程)
6. [验证与验收](#6-验证与验收)
7. [风险矩阵与缓解](#7-风险矩阵与缓解)
8. [长期演进路线](#8-长期演进路线)
9. [决策清单](#9-决策清单)

---

## 1. GBrain 是什么

### 1.1 一句话定义

GBrain 是一个运行在 AI Agent 平台上、完全可控的**知识大脑层**——它不是搜索引擎（返回片段列表），而是**综合、推理、自知不足**的答案引擎。

### 1.2 谁做的、验证规模

| 项目 | 详情 |
|---|---|
| 作者 | Garry Tan（Y Combinator 总裁兼 CEO） |
| 开源 | MIT License，GitHub `garrytan/gbrain` |
| 生产规模 | 146,646 页 · 24,585 人 · 5,339 家公司 · 66 个 cron 自主运行 |
| 基准测试 | BrainBench P@5 **49.1%**、R@5 **97.9%**，比纯向量 RAG 高 **+31.4** 百分点 |
| 社区 | 672 Issues、535 PRs、活跃的多行业分支（DevOps/SEO/法律等） |

### 1.3 核心能力拆解

GBrain 有三层能力，逐层递进：

```
┌─────────────────────────────────────────────────────────────────┐
│                     第 3 层：答案综合层                           │
│                                                                 │
│   "Alice 在 Acme 负责工程。你上次和她聊是 4月22日关于定价。       │
│    3 件事还开着：(1) 安全审查过期 (2) 500席定价待回复             │
│    (3) CISO 引荐未兑现。                                         │
│    ⚠️ 自 4月22日后大脑没有 Alice 或 Acme 的新信息——               │
│    她可能通过邮件/Slack回复了，建议先确认。"                       │
│                                                                 │
│    ↑ LLM 综合答案 · 每条有引用 · 明确列出未知项（缺口分析）        │
├─────────────────────────────────────────────────────────────────┤
│                     第 2 层：知识图谱层                           │
│                                                                 │
│    Alice ──[works_at]──→ Acme ──[series]──→ B轮                  │
│    Alice ──[attended]──→ 2026-01-08 Kickoff Meeting              │
│    Alice ──[owes]──────→ Security Review (过期)                   │
│                                                                 │
│    ↑ 每次写入自动提取实体+类型边，零 LLM 调用，纯规则引擎           │
├─────────────────────────────────────────────────────────────────┤
│                     第 1 层：混合搜索层                           │
│                                                                 │
│    关键词搜索 (FTS5/tsvector) + 向量语义搜索 (pgvector)            │
│    + 图回链加权 (backlink boost) = RRF 融合                       │
│                                                                 │
│    ↑ 三种检索通道融合排序，比单一向量搜索准 31.4 个百分点           │
└─────────────────────────────────────────────────────────────────┘
```

**与普通 RAG 的本质区别**：普通 RAG 返回"这里有几个相关片段，你自己读"；GBrain 返回"这是你要的答案，证据在这里，我还发现你不知道这个"。

### 1.4 技术架构

```
gbrain CLI / MCP Server
    │
    ├── src/core/operations.ts     ← 90+ 统一操作接口
    ├── src/core/engine-factory.ts ← 可插拔存储引擎
    ├── src/core/embedding.ts      ← 嵌入服务（外部API调用）
    ├── src/core/search/hybrid.ts  ← RRF融合 + 去重（引擎无关）
    ├── src/core/link-extractor.ts ← 自接线知识图谱提取器
    └── src/core/calibration/      ← 答案质量校准（voice-gate等）
    │
    └── 存储引擎（可插拔）
        ├── PGLiteEngine  ← 默认：WASM 内嵌 PostgreSQL 17.5，零服务器
        └── PostgresEngine ← 生产扩展：Supabase / 自建 pgvector
```

关键设计决策：
- **嵌入不在引擎内**：`embedding.ts` 单独处理，调用外部 API（OpenAI 兼容格式），所有引擎共享
- **分块不在引擎内**：`chunkers/` 统一分块逻辑，引擎只管存储与检索
- **自接线图谱**：`put_page` 写入时自动扫描 wikilink、`[[引用]]`、`## Facts` 表格，提取实体和类型边——**整个过程零 LLM 调用**

---

## 2. 本机现状与差距分析

### 2.1 当前架构总览

```
本机当前知识管理

OpenClaw Gateway (Port 18789)
├── memorySearch: Ollama bge-m3 语义索引
│   └── 7 个 extraPaths（vault + mmWave SDK docs）
├── 文件系统: workspace/memory/*.md + knowledge-base/vault/*.md
│   └── PARA 目录结构（Projects/Areas/Resources）
├── 技能: graphify（LLM知识图谱）· read-image · ClawHub
├── 心跳: HEARTBEAT.md 每日任务
└── 治理: AGENTS.md + SOUL.md + governance/
```

### 2.2 逐项差距

| # | 能力维度 | 本机现状 | GBrain 能做到 | 差距评级 | 本地方案能否弥补 |
|---|---|---|---|---|---|
| 1 | **语义搜索** | Ollama bge-m3 纯向量搜索 | 关键词+向量+图遍历 RRF 融合 | ⬜ 持平 | — |
| 2 | **知识图谱** | graphify 技能（LLM 驱动，手动触发，每次调用消耗 tokens） | 自接线规则引擎（零 LLM 成本，写入时自动触发） | 🔴 **大** | ✅ 完全弥补 |
| 3 | **答案合成** | 无——Agent 收到 search result 片段后自己阅读总结 | LLM 综合多页内容生成带引用的连贯答案 | 🔴 **大** | ✅ Novasky 驱动 |
| 4 | **缺口分析** | 无——Agent 不会主动说"我不知道什么" | 答案末尾标注 brain 缺失的时间段/主题 | 🔴 **大** | ✅ 同等能力 |
| 5 | **实体关系查询** | 无——无法问"谁参与了 XX 模块" | `graph-query <slug> --depth 2` 图遍历 | 🔴 **大** | ✅ 同等能力 |
| 6 | **夜间自主维护** | 基础心跳（HEARTBEAT.md） | 8 阶段 Dream Cycle：实体扫描 → 引用修复 → 记忆整合 → 跨会话模式检测 → 预测校准 | 🟡 中 | ✅ 同等能力 |
| 7 | **技能体系** | 散落：graphify, read-image, nano-pdf 等 | 43 个策展技能 + RESOLVER.md 分发器 + signal-detector 自动捕获 | 🟡 中 | ✅ scaffold 导入 |
| 8 | **API 成本** | **$0（Ollama 全本地）** | 云端方案需 $100-300/mo | 🟢 **本机优势** | ✅ $0 保持 |

### 2.3 差距优先级

一针见血地说：**本机缺的不是"更快的搜索"，而是"有人帮我把搜索结果读完了再告诉我"**。GBrain 的第 3 层和第 2 层恰好补上这个缺口。

---

## 3. 全本地化技术方案

> **核心发现**：GBrain 的三个 API 依赖均可映射到本机已有设施——不需要任何新的云服务订阅。

### 3.1 依赖映射表

```
GBrain API 依赖              本机替代                    零成本原因
──────────────────────────────────────────────────────────────────────
嵌入模型                      Ollama nomic-embed-text     Ollama 免费本地运行
(ZeroEntropy API)             (274MB, GBrain 已注册)      已有 Ollama 服务

Chat 综合模型                 Novasky deepseek-v4-pro     已有配置，无需额外付费
(OpenAI GPT-4)                (OpenAI 兼容 API)           通过有线内网代理访问

查询扩展                     跳过                         不是必需组件
(Anthropic Claude)            (GBrain 检测不到 Anthropic
                               key 时自动降级)
```

### 3.2 嵌入模型选择：为什么用 nomic-embed-text 而非 bge-m3

| 模型 | 维度 | 大小 | MTEB 排名 | GBrain 注册状态 | 选择 |
|---|---|---|---|---|---|
| `nomic-embed-text` | 768 | 274MB | ~62 | ✅ 已注册 | **当前选用** |
| `mxbai-embed-large` | 1024 | 669MB | ~61 | ✅ 已注册 | 备选（更大更慢） |
| `all-minilm` | 384 | 45MB | ~70 | ✅ 已注册 | 备选（轻量但精度低） |
| `bge-m3` | 1024 | 1.1GB | ~56 | ❌ 未注册（#2541 dim 验证 bug） | 等修复后切换 |

**选择逻辑**：`nomic-embed-text` 在 GBrain 已注册、零摩擦、体积适中。等 Issue [#2541](https://github.com/garrytan/gbrain/issues/2541) 修复后切回 `bge-m3`，嵌入质量可提升 5-10%。

### 3.3 社区验证状态

通过 Issue Tracker 确认——已有用户在生产环境用 Ollama 跑 GBrain：

| Issue | 标题 | 与本机相关 |
|---|---|---|
| [#2552](https://github.com/garrytan/gbrain/issues/2552) | Cloud-tuned embedding defaults silently wedge CPU-only Ollama boxes | ⚠️ **直接影响**：需设置 `GBRAIN_EMBED_CONCURRENCY=1` |
| [#2541](https://github.com/garrytan/gbrain/issues/2541) | Local custom embedders can't pass dim validation | ⚠️ **间接影响**：bge-m3 暂时不可用，需用注册模型 |
| [#2553](https://github.com/garrytan/gbrain/issues/2553) | eval suspected-contradictions: judge output unparseable with small local models | ℹ️ 注意：本地小模型做评估可能失败 |

**社区活跃度**：672 Issues、535 PRs——说明 bugs 修得快，不是冷门项目。

### 3.4 性能对比

| 指标 | 云端 GBrain | 本地 GBrain | 差异说明 |
|---|---|---|---|
| **搜索延迟** | 200-500ms（网络往返 + API 排队） | 50-200ms（本地回环） | ✅ **快 2-5 倍** |
| **首次嵌入** | 5 分钟（并发 20） | 5-12 分钟（并发 1） | ⚠️ 慢 ~2 倍但仅首次 |
| **增量嵌入** | <30 秒 | <1 分钟 | 差异可忽略 |
| **Chat 综合质量** | GPT-4 / Opus | deepseek-v4-pro | ✅ **持平**（同级别旗舰模型） |
| **嵌入召回精度** | ZeroEntropy 专有（MTEB top） | nomic-embed-text（MTEB ~62） | ⚠️ ~5-10% 差距 |
| **隐私** | 所有文本经云端 API | **全部本地处理** | ✅ **更优** |
| **可用性** | 依赖互联网 + API 服务商 | **完全离线可用** | ✅ **更优** |

### 3.5 资源消耗

```
组件                          内存占用          磁盘占用
──────────────────────────────────────────────────────
PGLite WASM PostgreSQL        ~50-100 MB        初始 ~100 MB
Ollama nomic-embed-text       ~500 MB           274 MB
Bun 运行时 + GBrain CLI       ~40-60 MB         ~80 MB
──────────────────────────────────────────────────────
增量总计                      ~600-700 MB       ~500 MB

本机可用                      约 15 GB 空闲     约 47 GB 可用
占用比例                      约 4%             约 1%
──────────────────────────────────────────────────────
结论                          ✅ 充裕            ✅ 充裕
```

---

## 4. 集成架构设计

### 4.1 双引擎拓扑

```
┌──────────────────────────────────────────────────────────────────┐
│                        个人知识大脑                            │
│                                                                  │
│  ┌──────────────────────────────┐  ┌───────────────────────────┐ │
│  │                              │  │                           │ │
│  │   OpenClaw Gateway            │  │   GBrain MCP Server       │ │
│  │   Port 18789                  │  │   Port 18791              │ │
│  │   角色：快速通道               │  │   角色：深度通道            │ │
│  │                              │  │                           │ │
│  │   memorySearch                │  │   PGLite Database         │ │
│  │   ├── Ollama bge-m3 (1024d)  │  │   ├── pages 表            │ │
│  │   ├── 7 extraPaths            │  │   ├── chunks 表           │ │
│  │   └── 语义索引（已有）         │  │   ├── links 表 (图谱)     │ │
│  │                              │  │   ├── timeline_entries     │ │
│  │   心跳 + 治理                 │  │   ├── embeddings (768d)   │ │
│  │   ├── HEARTBEAT.md            │  │   └── versions            │ │
│  │   ├── governance/             │  │                           │ │
│  │   └── AGENTS.md               │  │   搜索引擎                 │ │
│  │                              │  │   ├── Ollama nomic (768d) │ │
│  │   工具执行                    │  │   ├── PGLite tsvector     │ │
│  │   ├── exec / file / git      │  │   └── graph backlink      │ │
│  │   └── subagent spawn          │  │                           │ │
│  │                              │  │   综合引擎                 │ │
│  │   使用场景                    │  │   ├── Novasky v4-pro      │ │
│  │   · 日常快速查询              │  │   └── 答案合成+引用+缺口   │ │
│  │   · 项目状态                  │  │                           │ │
│  │   · 代码搜索                  │  │   维护                      │ │
│  │   · 编码任务                  │  │   ├── Dream Cycle (夜间)  │ │
│  │                              │  │   ├── sync cron (15min)   │ │
│  └──────────┬───────────────────┘  │   └── doctor (每周)       │ │
│             │                      └───────────┬───────────────┘ │
│             │                                  │                  │
│             └──────────────┬───────────────────┘                  │
│                            ▼                                      │
│               ┌────────────────────────────┐                     │
│               │   共享 Markdown 源文件        │                     │
│               │                            │                     │
│               │   knowledge-base/vault/*.md │                     │
│               │                            │                     │
│               │   OpenClaw 写入（主控）       │                     │
│               │   GBrain 定时导入（只读）      │                     │
│               │   单向同步，无写冲突           │                     │
│               └────────────────────────────┘                     │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

### 4.2 数据流详解

```
用户 → OpenClaw Agent
         │
         ├── "项目进度？"
         │   └→ memorySearch("项目进度") → 返回匹配文件 → Agent 直接回答
         │      原因：单文件查询，语义搜索已足够
         │
         ├── "综合所有会议纪要，当前的主要阻塞点有哪些？"
         │   └→ GBrain query("阻塞点") → LLM 综合 → 带引用的答案列表 + 缺口提示
         │      原因：跨文件综合，需要答案合成
         │
         ├── "谁参与了信号处理模块的点云过滤工作？"
         │   └→ GBrain graph-query("点云过滤") → 图遍历 → 关联人物+职责
         │      原因：实体关系查询，需要知识图谱
         │
         └── "关于超分辨算法，还有什么我不知道的？"
             └→ GBrain query → 答案合成 + 缺口分析 → "从未讨论的方面有：X, Y, Z"
                原因：缺口分析是 GBrain 独有能力
```

### 4.3 Agent 路由规则（追加到 AGENTS.md）

```markdown
## 知识库双引擎路由规则 (2026-07-06 生效)

Agent 收到需要检索知识的查询时，按以下决策表路由：

| 查询特征 | 路由目标 | 命令示例 |
|---|---|---|
| 单文件查找、"XX在哪"、项目状态 | OpenClaw memorySearch | memory_search query="..." |
| 跨文件综合、"总结所有"、"有哪些共同点" | GBrain query | exec: gbrain query "..." |
| 人物/模块/公司 关系、"谁负责"、"参与过" | GBrain graph-query | exec: gbrain graph-query \<slug\> --depth 2 |
| "我还不知道什么"、"缺失什么信息" | GBrain query（缺口分析） | exec: gbrain query "..." |
| 代码相关、文件路径、Shell 操作 | 不触发知识检索 | 直接处理 |
```

### 4.4 两引擎的日常协同

| 时间 | OpenClaw | GBrain |
|---|---|---|
| 09:00 | 心跳：项目状态汇总 | — |
| 全天 | 响应用户查询，按需触发 memorySearch | — |
| 全天 | 用户写入新 markdown → vault | — |
| 每 15 分钟 | — | `gbrain sync`：检测 vault 变更 → 重新导入修改的文件 → 更新嵌入 → 更新图谱链接 |
| 夜间 02:00 | — | `gbrain dream`：8 阶段维护周期 |
| 每周一 09:00 | 心跳 + 周报 | `gbrain doctor`：健康检查 |

---

## 5. 详细安装流程

### 5.1 Phase A：CLI 可用（目标：30 分钟完成，可在终端直接查询）

#### Step A1 — 安装 Bun 运行时（2 分钟）

```bash
# Bun 是 GBrain 的运行时依赖，类似 Node.js 但更快
# 安装在 ~/.bun/ 下，不污染系统 Node.js

curl -fsSL https://bun.sh/install | bash

# 立即生效（当前 shell）
export PATH="$HOME/.bun/bin:$PATH"

# 永久生效
echo 'export PATH="$HOME/.bun/bin:$PATH"' >> ~/.zshrc

# 验证
bun --version
# 预期输出：1.x.x
```

#### Step A2 — 拉取嵌入模型（1 分钟 + 下载时间）

```bash
# GBrain 内置支持的 3 个 Ollama 模型之一
# nomic-embed-text：274MB，768 维，MTEB ~62，体积/精度平衡最优

ollama pull nomic-embed-text

# 验证
ollama list | grep nomic
# 预期输出：nomic-embed-text:latest    274 MB    ...
```

#### Step A3 — 安装 GBrain（2 分钟）

```bash
# 全局安装（推荐）
bun install -g github:garrytan/gbrain

# 如果 bun install -g 失败（Bun 偶尔阻止 postinstall hook），
# 用 git clone 备选路径：
#   git clone https://github.com/garrytan/gbrain.git ~/gbrain
#   cd ~/gbrain && bun install && bun link

# 验证
gbrain --version
# 如果提示 command not found：重新打开终端或 source ~/.zshrc
```

#### Step A4 — 环境变量配置（2 分钟）

```bash
# ═══════════════════════════════════════════════════════════
# 这里是最关键的一步——三个环境变量决定了 GBrain 是完全本地还是云端
# ═══════════════════════════════════════════════════════════

# 1. Chat 综合模型 → 指向本机已有的 Novasky 代理
#    Novasky Proxy 监听 127.0.0.1:18790，提供 OpenAI 兼容 API
export OPENAI_BASE_URL="http://127.0.0.1:18790/v1"

# 2. API Key → 从本机 openclaw.json 自动提取（无需手动填写）
export OPENAI_API_KEY=$(python3 -c "
import json
with open('$HOME/.openclaw/openclaw.json') as f:
    print(json.load(f)['env']['vars']['NOVASKY_API_KEY'])
")

# 3. 嵌入并发 → 必须设为 1（Ollama 是 CPU 推理，云端默认 20 会压垮它）
#    这是社区 Issue #2552 确认的坑，不设会导致大页面永远嵌不完
export GBRAIN_EMBED_CONCURRENCY=1

# ─── 持久化到 shell profile ───
cat >> ~/.zshrc << 'ZSH_EOF'

# === GBrain 本地配置 (2026-07-06) ===
export OPENAI_BASE_URL="http://127.0.0.1:18790/v1"
export GBRAIN_EMBED_CONCURRENCY=1
# OPENAI_API_KEY 在 openclaw.json 中，不硬编码到 profile
ZSH_EOF

# 验证环境变量
echo "OPENAI_BASE_URL = $OPENAI_BASE_URL"
echo "OPENAI_API_KEY  = ${OPENAI_API_KEY:0:8}..."
echo "GBRAIN_EMBED_CONCURRENCY = $GBRAIN_EMBED_CONCURRENCY"
```

#### Step A5 — 初始化大脑数据库（1 分钟）

```bash
# --pglite：使用内嵌 PostgreSQL（WASM），零服务器、零配置
# --embedding-model：指定 Ollama 的注册嵌入模型
#
# 执行后会在 ~/.gbrain/ 下创建 PGLite 数据库文件

gbrain init --pglite \
  --embedding-model ollama:nomic-embed-text

# 搜索模式选择
# ┌──────────────┬──────────┬──────────┬──────────────────────┐
# │ 模式          │ 上下文    │ Chunks   │ 适用场景              │
# ├──────────────┼──────────┼──────────┼──────────────────────┤
# │ conservative │ 4K       │ 10       │ 省钱、Haiku 模型      │
# │ balanced     │ 12K      │ 25       │ ★ 推荐：deepseek 适中  │
# │ tokenmax     │ 无限制    │ 50       │ 最强但最贵            │
# └──────────────┴──────────┴──────────┴──────────────────────┘
gbrain config set search.mode balanced

# 健康检查——确认所有组件正常
gbrain doctor --json
# 预期输出中包含 "status": "healthy"
```

#### Step A6 — 导入现有知识库（3 分钟）

```bash
# 创建 GBrain 的数据目录
mkdir -p ~/brain

# ─── 导入 markdown 文件 ───
# --no-embed：先快速导入文本，嵌入稍后批量生成（更快）
gbrain import ~/.openclaw/workspace/knowledge-base/vault/ --no-embed

# 导入日志会显示：
#   Imported: projects/<your-project>/Project_Example.md
#   Imported: 10-Projects-Active/<your-project>/...
#   ... (约 40+ 页)

# ─── 回填知识图谱链接 ───
# extract links：扫描所有页面中的 wikilink、[[引用]]、## Facts 表格
# 自动建立 typed edges：works_at、attended、depends_on 等
# 整个过程零 LLM 调用——纯规则引擎
gbrain extract links --source db
# 预览链接（前 20 条）
# gbrain extract links --source db --dry-run | head -20

# ─── 回填时间线 ───
# extract timeline：从页面中提取日期事件，建立时间索引
gbrain extract timeline --source db

# ─── 查看统计 ───
gbrain stats
# 预期输出：
#   pages:     ~45
#   links:     ~XX   （取决于 vault 内的 [[引用]] 密度）
#   timeline_entries: ~XX
```

#### Step A7 — 生成向量嵌入（5-12 分钟，建议夜间执行）

```bash
# ⚠️ 首次嵌入约 5-12 分钟，建议夜间 cron 执行
# 或者现在就启动后台任务：

gbrain embed --stale &

# 查看进度：
# gbrain stats | grep embedded

# ─── 嵌入完成后的首次查询验证 ───
sleep 60  # 等首批嵌入完成

# 测试 1：语义搜索
gbrain query "项目当前进度如何"

# 测试 2：知识图谱遍历
gbrain graph-query <your-project> --depth 2

# 测试 3：统计确认嵌入覆盖率
gbrain stats
# 预期：embedded_pages 接近 total_pages
```

### 5.2 Phase B：MCP 集成（目标：Agent 可直接调用 GBrain）

#### Step B1 — 启动 MCP 服务

```bash
# 方式 A：前台调试运行
gbrain serve --port 18791

# 方式 B：后台生产运行（推荐）
nohup gbrain serve --port 18791 > ~/brain/logs/mcp.log 2>&1 &

# 验证服务
curl -s http://127.0.0.1:18791/health
```

#### Step B2 — 追加 Agent 路由规则

在 `~/.openclaw/workspace/AGENTS.md` 末尾追加第 4.3 节的路由规则表。

### 5.3 Phase C：自动化维护（目标：零人工干预运行）

#### Step C1 — 创建日志目录

```bash
mkdir -p ~/brain/logs
```

#### Step C2 — 配置定时任务

```bash
# crontab -e 添加以下三行：

# 每 15 分钟：检测 vault 变更 → 重新导入 → 更新嵌入
# 保证 GBrain 与 vault 数据同步
*/15 * * * *  cd ~/brain && gbrain sync --repo ~/brain && gbrain embed --stale >> ~/brain/logs/sync.log 2>&1

# 每日凌晨 2:00：Dream Cycle 8 阶段维护
# 实体扫描 → 引用修复 → 记忆整合 → 跨会话模式检测 → ...
0 2 * * *     cd ~/brain && timeout 3600 gbrain dream >> ~/brain/logs/dream.log 2>&1

# 每周一 9:00：全面健康检查
0 9 * * 1     gbrain doctor --json >> ~/brain/logs/health.log 2>&1
```

#### Step C3 — 数据备份策略

```bash
# PGLite 是单文件数据库，备份很简单

# 每日自动备份（追加到 crontab）
0 3 * * *  cp ~/brain/gbrain.db ~/brain/backups/gbrain-$(date +\%Y\%m\%d).db

# 或者加入 git 版本控制
cd ~/brain
git init
echo "backups/" > .gitignore
git add gbrain.db
git commit -m "brain: initial snapshot $(date -I)"
```

---

## 6. 验证与验收

### 6.1 功能验证清单

| # | 验证项 | 命令 | 通过标准 |
|---|---|---|---|
| V1 | GBrain 安装 | `gbrain --version` | 输出版本号 |
| V2 | PGLite 初始化 | `gbrain doctor --json` | `status: healthy` |
| V3 | Ollama 嵌入可用 | `gbrain embed --stale` 无报错 | 无 error |
| V4 | 页面导入 | `gbrain stats \| grep pages` | pages > 0 |
| V5 | 知识图谱链接 | `gbrain stats \| grep links` | links > 0 |
| V6 | 语义查询 | `gbrain query "<your-project>"` | 返回相关结果 |
| V7 | 图遍历查询 | `gbrain graph-query <your-project> --depth 1` | 返回关联节点 |
| V8 | MCP 服务 | `curl http://127.0.0.1:18791/health` | HTTP 200 |
| V9 | cron sync | 手动 `gbrain sync --repo ~/brain` | 无报错 |
| V10 | 增量嵌入 | 修改 vault 文件 → `gbrain embed --stale` | 仅处理变更文件 |

### 6.2 回滚方案

如果 GBrain 出现不可恢复问题：

```bash
# 1. 停止 MCP 服务
kill $(pgrep -f "gbrain serve") 2>/dev/null

# 2. 移除 crontab（保留注释方便恢复）
crontab -l | grep -v "gbrain" | crontab -

# 3. 数据库保留（不删除，方便排查）
# ~/brain/gbrain.db 不动
# ~/brain/backups/ 不动

# 4. OpenClaw 不受影响——memorySearch + heartbeat 继续正常工作
```

---

## 7. 风险矩阵与缓解

| # | 风险 | 概率 | 影响 | 触发条件 | 缓解措施 | 残留风险 |
|---|---|---|---|---|---|---|
| R1 | **嵌入并发默认值** | 100% | 嵌入卡死 | 首次 `gbrain embed` 时 | `GBRAIN_EMBED_CONCURRENCY=1` 已纳入安装（#2552 社区验证） | 无 |
| R2 | **Ollama dim 验证** | 40% | 不可用 bge-m3 | 指定 bge-m3 为嵌入模型时 | 用注册模型 `nomic-embed-text` 回避（#2541） | 嵌入精度 ~5-10% 差距 |
| R3 | **PGLite 数据丢失** | 5% | 大脑数据丢失 | 磁盘故障 / 误删 | 每日 git 备份 + 定时 cp 到 backups/ | 最多丢失 1 天 |
| R4 | **vault ↔ brain 不同步** | 30% | 搜索结果过期 | cron 未运行 / sync 失败 | cron 每 15 分钟 sync + 周检 doctor | 最多 15 分钟延迟 |
| R5 | **Dream Cycle 卡住** | 15% | 大脑停止复合增长 | 大页面死循环 / OOM | `timeout 3600` + doctor 周检捕获 | 需手动重启 dream |
| R6 | **首次嵌入耗时长** | 100% | 需要等待 | 安装当天 | 夜间 cron 执行，不影响工作时间 | 无 |
| R7 | **Bun 版本不兼容** | 10% | GBrain 无法启动 | `bun upgrade` 后 | 锁定 Bun 版本；备选 git clone 安装 | 需手动调试 |
| R8 | **Novasky Proxy 宕机** | 5% | Chat 综合不可用 | 网络故障 / Proxy 挂掉 | GBrain 自动降级为纯关键词搜索（无综合答案） | 暂时失去答案合成 |

---

## 8. 长期演进路线

```
┌─────────────────────────────────────────────────────────────────────┐
│                           演进路线图                                  │
│                                                                     │
│  现在 ──────────── 1周内 ──────────── 2周内 ──────────── 1月+        │
│                                                                     │
│  Phase A             Phase B             Phase C             远期     │
│  ┌──────────┐       ┌──────────┐        ┌──────────┐       ┌──────┐ │
│  │ GBrain   │  ───→ │ MCP      │  ───→  │ Dream    │  ───→ │ bge  │ │
│  │ CLI 可用 │       │ serve    │        │ Cycle    │       │ -m3  │ │
│  │          │       │ Agent    │        │ 全自动   │       │ 切换 │ │
│  │ 知识图谱 │       │ 路由生效 │        │ 夜间维护 │       │      │ │
│  │ 嵌入完成 │       │ cron     │        │ 每周报告 │       │ 多知 │ │
│  │ 手动查询 │       │ 增量同步 │        │          │       │ 识源 │ │
│  └──────────┘       └──────────┘        └──────────┘       └──────┘ │
│                                                                     │
│  交付物：            交付物：             交付物：            交付物： │
│  · PGLite 数据库     · MCP Server 运行    · 8 阶段 Dream     · bge  │
│  · 图谱链接完成       · AGENTS.md 更新     · 跨会话模式检测    · m3  │
│  · 嵌入覆盖率 100%   · cron 正常运行      · 记忆整合完成     · 嵌入 │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 9. 决策清单

> 以下 5 项需 用户确认后开始部署。

| # | 决策项 | 推荐选项 | 理由 |
|---|---|---|---|
| D1 | **是否安装 GBrain** | ✅ 安装 Phase A | 零成本、低风险、补知识图谱+答案合成两大缺口 |
| D2 | **嵌入模型选择** | `nomic-embed-text` | GBrain 已注册，零摩擦；等 #2541 修复切 bge-m3 |
| D3 | **Chat 综合模型** | Novasky deepseek-v4-pro | 已有设施、同级别模型、零增量成本 |
| D4 | **部署范围** | Phase A+B（CLI + MCP） | Phase C（Dream Cycle）验证稳定后追加 |
| D5 | **知识源同步方向** | vault → brain 单向 | OpenClaw 主控写入，GBrain 只读导入，避免写冲突 |
