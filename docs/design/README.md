# System Design Documents

本目录收录 OpenClaw harness 在实际生产环境中沉淀的系统设计文档、架构决策记录和运维 runbook。来自真实部署经验的打磨，非理论推演。

## 目录索引

### Harness 架构 (`harness/`)

| 文件 | 内容 |
|------|------|
| `openclaw-harness-system-design.md` | 核心架构设计：Agent 运行时、Gateway、ACP Harness、模型路由、记忆系统的完整蓝图（650 行） |
| `openclaw-harness-v2-distributed.md` | v2 分布式架构：多节点、远程 Gateway、SSH 隧道、沙箱隔离设计（660 行） |
| `openclaw-harness-v3-unified.md` | v3 统一架构：收敛 Stage 0-3 的最终形态，治理增量，ACP 深度集成（336 行） |
| `openclaw-harness-stage2.5-consolidation.md` | Stage 2.5 巩固期：编码 Harness 接入、迭代/预算熔断、Golden 用例库（197 行） |
| `SETUP-CHECKLIST.md` | 部署检查清单：服务注册、网络、路由守护、MCP 连通性、安全性（81 行） |
| `IMPLEMENTATION-LOG.md` | 实施日志：三态模型切换、知识库迁移、配置灰度流程、事故复盘（176 行） |
| `CLAUDE-REFERENCE.md` | ACP Claude Code 子代理的 CLAUDE.md 配置参考（25 行） |
| `api-routing-baseline-20260702.md` | 模型路由基线：API endpoint 设计、provider 优先级、fallback 策略（74 行） |

### GBrain 知识图谱 (`gbrain/`)

| 文件 | 内容 |
|------|------|
| `knowledge-brain-architecture.md` | GBrain 架构：PGLite + nomic-embed-text，MCP 工具链，索引/查询/缺口分析（218 行） |
| `gbrain-shared-http-serve-architecture.md` | 共享 HTTP serve 架构：单写锁、多客户端（main agent + Claude Code）并发访问（81 行） |
| `gbrain-plan.md` | 完整建设计划：6 轮迭代论证，从需求到部署的全流程（639 行） |
| `gbrain-acp-claude-integration.md` | ACP Claude Code 与 GBrain 的 MCP 集成方案（278 行） |
| `gbrain-claude-code-integration.md` | Claude Code 知识库接入实战：user-scope MCP 配置、brain-first protocol（319 行） |
| `GBrain_Knowledge_Workflow_SOP.md` | 知识库工作流 SOP：写入纪律、provenance 规则、CLI 禁令（244 行） |

### 治理 (`governance/`)

| 文件 | 内容 |
|------|------|
| `L2-HANDOVER-CRITERIA.md` | L2 放权判据：Golden 用例数、基线通过率、预算、并发事故的量化标准 |
| `SKILL-ADMISSION-RULES.md` | 技能准入规则：新 Skill 的评审、验证、上线流程 |
| `BUDGET-POLICY.md` | 预算策略：成本追踪、熔断阈值、异常升级 |

### Runbooks (`runbooks/`)

| 文件 | 内容 |
|------|------|
| `ops-and-kb.md` | 运维 + 知识库日常操作手册 |
| `run-agent-baseline.md` | Agent 基线测试 runbook |
| `taskflow-recovery-test.md` | TaskFlow 故障恢复测试流程 |
| `revoke-discord-tokens.md` | Discord Token 撤销操作 |
| `stage2.5-kit-overview.md` | Stage 2.5 工具包总览 |

### 其他

| 文件 | 内容 |
|------|------|
| `latex-tikz-figure-discipline.md` | LaTeX/TikZ 图表纪律：纯文本模型如何产出可读图表的实战规范 |

## 使用方式

这些文档是**参考设计**，不是部署必需文件。阅读顺序建议：

1. **理解整体架构** → `harness/openclaw-harness-system-design.md`
2. **看落地路径** → `harness/openclaw-harness-v3-unified.md` + `harness/IMPLEMENTATION-LOG.md`
3. **按需深入** → GBrain / 治理 / Runbooks

文档中的架构决策来自真实生产环境的迭代，包含成功经验和踩过的坑。可直接借鉴但需根据自身环境调整。
