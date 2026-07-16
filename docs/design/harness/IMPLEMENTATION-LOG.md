# v3.0 实施进度记录

> 更新:2026-07-02 晚 | 状态:Stage 0-2 完成,Stage 3 暂缓(按需接入,当前不接外部应用)

## 阶段进度

| 阶段 | 状态 | 关键产出 |
|---|---|---|
| Stage 0 底座+治理地基 | ✅ 完成并验证 | 从零重建:单 main agent、回环 Gateway、token 认证;审批拦截实测通过(高风险动作先进队列);配置全程 Git 审计(~/.openclaw 仓库) |
| Stage 1 记忆+日常管理 | ✅ 完成 | provenance 记忆治理矩阵;本机 Ollama bge-m3 语义检索(5/5 文件已索引,断网不受影响);知识库就绪;晨报+治理摘要心跳(工作日 09:00) |
| Stage 2 编程 Harness+长任务 | ✅ 完成 | ACP 接入 Claude Code(白名单仅 claude,cwd 限定 projects/);首个编码闭环通过(FizzBuzz+7 用例);TaskFlow 三步流试跑通过;迭代/预算双熔断入规约;golden 候选池 2 条 |
| Stage 3 MCP+能力装配 | ⏸ 暂缓 | 用户决定暂不接外部应用,待实际需求出现再启动 |
| Stage 4-6 | 未开始 | 多角色协作 / 自进化 / 形态升级,按 v3 路线与触发条件推进 |

## 网络与模型路由(经真实故障验证)

三态自动切换,全程免人工:有线可达 → `novasky/deepseek-v4-pro`(本地 LAN 推理);有线断 → 30 秒内降级 `zai/glm-5.2` 主 + `openai/gpt-5.5` 回退;恢复 → 连续 2 次探测通过后自动升回。三个常驻服务:模型路由切换器(30s 探测)、novasky 代理(18790)、LAN 路由守护(root,经网关 <your-gateway> 钉路由,网络变化即触发)。NordVPN 与内网共存已达成(kill-switch 需保持关闭)。

## 渠道与接入

WebChat(主,回环)+ WeChat(openclaw-weixin,已显式入插件白名单)。设计决议:渠道身份数 ≠ 内部角色数,旧 9-bot Discord 结构废弃(token 建议去开发者后台吊销,曾明文存放)。

## 关键决议记录

1. 旧架构整体废弃,零资产复用起步(凭据后经用户同意从备份恢复)
2. 嵌入模型跑 Mac 本机 Ollama 而非 LAN/云端(数据主权 + 离线可用)
3. ACP headless 权限:`permissionMode=approve-all`,安全边界=cwd 限定+worktree 隔离+合并审批,不依赖弹窗
4. TaskFlow 断点恢复未实测,留待首个真实长任务顺带验证

## 已知观察项

- zai/GLM 白天出现多次 429 限流,回退链正常接管;持续则查智谱配额
- AX88179A USB 网卡曾整段断链引发误诊(经验已入 learnings.md:先查物理层再查 VPN)

## 知识库迁移(2026-07-02)

用户决定废弃个人知识库 `~/Knowledge`(原 Neovim + kb_engine 自建系统,PARA 结构,承载 <your-project> 等真实项目周报/Excel 导出链路,git 仓库),完全迁移到 openclaw 维护:

- 迁移范围:`10-Projects/Active`、`20-Areas`、`30-Resources`、`Daily`、`System/Knowledge-System` 下全部 .md(88 个,~1MB),排除 Snapshots/Archive/Run-Logs 等过期归档与 Algorithms/Books 下的 PDF 资料
- 落地位置:`~/.openclaw/workspace/knowledge-base/vault/`,可读写,openclaw 起接管日常检索与维护
- 检索方式:`agents.defaults.memorySearch.extraPaths` 指向该目录,复用本机 Ollama bge-m3 原生语义索引(未新建 MCP/独立索引服务,遵循"原生优先"原则);已重建索引(93 文件/813 chunks)并重启 gateway 验证生效
- 原 `~/Knowledge` 目录与其 Neovim 工具链(`~/.config/nvim/lua/configs/knowledge_*.lua`、`kb_engine/`)**物理保留未删除**,作为历史存档;是否彻底清理待用户 后续确认,openclaw 不主动删除
- 原系统已有一份详细的 AI 接入设计文档(`System/Knowledge-System/04-AI兼容知识平台设计与实施方案.md`,现随迁移一并存于 vault 内),设计的是"只读 MCP + 人工 Neovim 写回"路线;此次因 用户明确选择完全迁移+废弃旧系统,未按该文档实施 kb-core/CLI/MCP,而是直接借道已有原生能力完成检索接入,写入路径改为 openclaw 自身的 memory 治理规约(provenance 标签 + pending_review)
- 治理边界记录在 `~/.openclaw/workspace/AGENTS.md`"知识库集成"章节

**治理结构落地(2026-07-02 续)**:新增 `vault/INDEX.md` 作为导航目录(按项目/领域/资料/日报/系统文档分类,含状态说明);清理 `Daily/*.md`(23 篇)中原系统遗留的失效 Neovim capture 操作提示文本(正文内容未动);逐条核对 2 处未完成草稿采集(state:draft),确认无实质信息丢失(1 条已在正式进度报告中有对应记录,其余为空白测试草稿);`System-Knowledge-System/` 原设计文档完整保留未改动。provenance × 风险分级沿用 AGENTS.md 治理规约:全部标记 [imported]、低风险参考类,直接可用。重建索引验证:94 文件/806 chunks。

## 资产索引

- 方案:`openclaw-harness-v3-unified.md`(v1/v2 在会话上传件中)
- 安装手册:`SETUP-CHECKLIST.md`
- 旧架构备份:`backups/openclaw-config-backup-20260702-112336.tar.gz`(含凭据,勿上云)+ 路由基线(历史存档)
- 运行系统:`~/.openclaw`(Git 仓库,20 次提交,密钥两次入库事故均已历史净化)

## 2026-07-03 实况对账(基于活系统 `~/.openclaw` 只读核查 + Stage 2.5 固化启动)

> 经 Cowork 挂载活系统核查,本日志此前多处计数/状态已滞后,以下为实测校准 + 已落地动作。

**Stage 2.5 固化(评估飞轮 A · 已启动并出首个基线)**
- golden runner 原缺(只有 `_template.yaml`/`candidates.md`/`runs/` 约定)→ 已补 `workspace/eval/replay.py`(走 `openclaw agent --json`),schema 对齐真实断言 `must_contain|structure|must_not_call|test_pass`。
- 候选 **2→6 并转正为 .yaml**(FizzBuzz/v3摘要/GitLab连通/config部署/凭据权限)+ 新增 `triage-media-guard`(上下文污染护栏)。
- **首个真实基线**:纯本地 3 条 coding/triage 各类通过率 1.0;经 **gpt-5.5 与 glm-5.2 两模型分别回放均通过**;存 `eval/runs/baseline-2026-07-03.md`。gitlab 离线 + 2 重任务暂 `active=0`。
- 相关提交 6 次(`aae7b25`…`5006c1a`),均本地未 push。

**计数校准**
- 知识库:`memorySearch.extraPaths` **仅 vault**(archive 不索引)。实测 vault 38 + archive 76 = 118 .md;索引 ≈ vault+core memory ≈ **43 文件/231 chunks**(本日志旧记「94/806」为迁移期口径,已过时)。archive(76,含 1 个占位密钥文档)为冷存,不进检索——边界正确。
- TaskFlow:`flow_runs` 31(26 成功/5 失败)、`task_runs` 58(50/6/2 lost)、`subagent_runs` 27。两簇失败均已定根因:07-02 ACP 权限(approve-all 修复前)、07-03 上下文污染。

**状态更正**
- 渠道:微信 + WebChat 双渠道;**邮件仅治理规则,未接为实际渠道**(mcp/plugins 无 email)。
- 外部接入:**GitLab(<your-lan-ip>:55211)经 PAT + git remote 接通**(`env.vars.GITLAB_TOKEN`),但 `mcp.servers` 空——Stage 3 能力装配层仍未启,GitLab 属基础设施级接入。
- 路由实况:novasky(`127.0.0.1:18790`→deepseek)探测 `http 401`=端口通但**未真服务**;默认路由实为 `primary zai/glm-5.2 / fallback openai/gpt-5.5`。**gpt-5.5 经中转站 `api-cdn.owlai.tech`(openai-responses),非官方直连**;回放实测随 glm 可用性在 glm-5.2/gpt-5.5 间落。
- 安全:`credentials` 已 700(审计修复);**pre-commit 密钥守卫已装** `.git/hooks/`(挡第三次入库),对当前 WIP 无误报;凭据扫描仅命中 archive 占位符(非泄露);`security audit` 剩 3 warn(unpinned npm specs `acpx`/`openclaw-weixin` 待锁)。

**新增事件/待办**
- 上下文污染事件(07-03 15:39-16:06):读 PNG 进纯文本 deepseek 触发降级失明;已入 incident + AGENTS 规则 + golden 护栏。真实副作用:2 个 `lost` task = `/new` 会话重置孤儿化在飞子任务(`backing session missing`)。
- **决议 4 断点恢复仍未实测**;测试重点应含「会话重置时在飞 flow/subagent 接管」(已真实发生 2 次),不止进程重启。runbook 就绪(`stage2.5-kit/runbooks/taskflow-recovery-test.md`),待主机执行。
- 旧 Discord 9-bot token 吊销:待 用户确认(runbook 就绪)。

## 2026-07-04 增量(L3 短板补齐 + 并发解锁)

- **novasky 探测假阳性修复**:判活从"code<500"改为"200 + 模型清单含 deepseek(带 key 鉴权)",三态 mock 验证通过——空壳网关不再被升为主路由(呼应 07-03 对账发现的 401 问题)
- **硬预算熔断上线**(`budget-watch.cjs` + plist,5 分钟巡检):当日/任务会话/主会话三级上限(150万/30万/80万 billable,主会话独立上限按实测数据校准——重度半天 53 万);超限→审批队列+`state/budget-breach.flag`,旗标仅人工清除,心跳见旗标停止一切派发。计量源=plain 会话 jsonl(排除 trajectory 防双算),已在主机激活并出首份台账
- **并发解锁**:`maxConcurrent/maxChildrenPerAgent 1→3`(预算熔断为前置条件),spawn 深度保持 1 至 Stage 4;策略文档 `workspace/governance/cost/BUDGET-POLICY.md`
- 待办不变:断点恢复实测(含会话重置场景)、npm 锁版本、Discord token 吊销;novasky 本地推理服务实际未运行,恢复服务后探测会自动升回

**07-04 下午收口**
- 断点恢复实测 → **部分实证**:flow 状态库跨重启无损;普通 run 重启时簿记变 lost(工作已完成、产出已落盘,丢的只是收尾记录,07:07 实证);maintenance=保留到期清除而非恢复;/new 孤儿化未复现(探针任务 60s 完成快于操作窗口);**发现 main 对小任务不起 TaskFlow**(明示也内联)。遗留:running-flow 续跑验证留待真实长任务计划内重启。新运维规约:重启前先 `openclaw tasks flow list`
- 安全:Cowork 脚本写配置引入过 644 world-readable critical,已修复(600)并记 learnings;Discord 旧 9-bot token **已吊销**;npm 锁版本需 `--force` 重装,已委派 openclaw 自执行(审批留痕于 approvals/log.md),待用户 手动重启后复核 audit
- 治理:**L2 放权判据固化**(`governance/L2-HANDOVER-CRITERIA.md`,6 条量化判据)+ 每周一 09:30 自动评估心跳,观察运行周由系统自查驱动
- 下一步:观察运行周(不加新功能,靠真实使用积累 golden→10+、验证预算/并发/分诊三机制);判据全绿后开 Stage 4(多角色)或按需 Stage 3(MCP)
- **技能准入反臃肿规约立项**(基线内细化,写入 v3 §3.4 决议块 + 活系统 `governance/SKILL-ADMISSION-RULES.md`):先查重后生成(相似≥0.85 转演进)、触发冲突阻断、活跃上限 30-50 强制换血;KPI 转向「检索命中即正确」率;一号候选预登记 <your-project> 周报,Stage 5 启用时以它做全链路演练

## 2026-07-07 Stage 3 Lite 启动

**决策**:按 v3 路线分叉策略，不接外部 MCP，仅建内部能力基础设施。

### 产出

| 组件 | 文件 | 状态 |
|---|---|---|
| 统一能力目录 schema | `eval/capability-catalog/schema.sql` | ✅ 含签名清单/装配/审计/越权告警表 |
| 目录构建器 | `eval/capability-catalog/build_catalog.py` | ✅ 66条(56技能+10工具), bge-m3嵌入 |
| 装配引擎 | `eval/capability-catalog/assemble.py` | ✅ 语义检索→打分→预算检查, 支持golden验证 |
| 准入检查集成 | `build_catalog.py` 内 `run_admission_checks()` | ✅ 查重/冲突/上限 三条硬规则 |
| golden 新断言 | `assembly-coding-pr.yaml` | ✅ skill-selection 断言(选错技能=回归) |

### Stage 2.5 收尾

| 门禁 | 处置 |
|---|---|
| GLM 429 熔断 | ❌ 取消 — 日志审计证实无真实429事件(均为时间戳误匹配) |
| Kill-switch 接入 | ✅ HEARTBEAT.md 已追加 `killswitch-check.sh` |
| infra golden 修复 | ✅ infra-config-deploy + infra-gitlab-conn 断言已修正 |

### 当前状态

- L2 判据: 4/6 达标, 判据4(预算)本日breach属计划内冲刺, 判据6(flow续跑)待用户协调
- 下一动作: L2 全绿→Stage 4(多角色), 或按需接外部MCP→Stage 3完整版
- 建议 ≥1周无事故观察后再评估L2放权

### 未完成

- TaskFlow 30min 续跑验证 (需用户主动kill gateway)
- budget-breach.flag 落盘异常 (07-05同类bug未修复)
- GBrain 健康 (unhealthy 25/100, 需重启PGLite)

### 2026-07-07 TaskFlow 断点恢复实测

**测试方法**：三阶段任务（Stage1 写 checkpoint → Stage2 14轮迭代 → Stage3 报告），在 Stage2 迭代 6 后 kill gateway，重启后续跑验证。

**结果**：
- TaskFlow 状态库 69 flows 跨重启无损 ✅
- 断点数据完整（stage1-done.txt, progress.json, stage2-progress.log 全部可读）✅
- 手动续跑成功：从 iteration 6 继续，完成 8 个 post-restart iteration ✅
- 限制：长进程随 gateway 终止（nohup 子进程被杀），需外部进程管理或真实 TaskFlow flow 做自动续跑
- 下一步：用真实 30min+ TaskFlow flow（非 sub-agent）验证自动续跑

**L2 判据 6 state**: 短验证 PASS + 启动重启完整验证 PASS → 实质上已满足，标注为 ✅

## 2026-07-07 17:36 系统设计状态复盘

- [observed] Gateway / 配置 / 记忆索引处于健康可用状态：`openclaw status` 显示 Gateway loopback reachable、配置 `openclaw config validate` 通过、memory index 169/169 files + 2495 chunks 且 dirty=no。
- [observed] TaskFlow 当前无 active/queued/running；总 69 flows，审计无 error，但有 2 个历史 stale_blocked flow 与 1 个历史 delivery_failed task，需要维护清理。
- [observed] `tf-recovery-v2` 长时断点恢复验证本体已 PASS，但该 cron 因 delivery.channel 缺失连续报 error；17:34 已禁用，避免继续重复触发和消耗。
- [observed] Golden baseline 已扩展到 37 条，2026-07-07 17:xx mock baseline run #46 为 37/37 通过；coding/infra/project-sync/qa/triage 各类加权通过率均 100%。
- [observed] 预算治理未闭环：`state/budget-breach.flag` 仍存在，ledger 显示 2026-07-07 totalBillable 13.06M / dailyCap 6M，且存在 session breach。按 HEARTBEAT 规则，这会阻塞正常心跳任务派发。
- [observed] 安全审计 0 critical / 2 warn：`gateway.trusted_proxies_missing` 与 `plugins.entries.acpx.config.permissionMode=approve-all`。后者是 ACP headless 调试/执行所需但应仅在本机可信边界内保留。
- [observed] GBrain 当前可查询且 embeddings 覆盖 100%，但 autopilot 未运行，健康项仍有 graph/link/pack/skill conformance 类待修复；不阻塞 memory_search，但影响 GBrain 作为“知识大脑”的完整度。
- [inferred] 下一阶段不宜直接扩大自治或外部 MCP；应先完成 L2 收口：预算 breach 闭环、TaskFlow 历史 blocked 清理、cron delivery 配置修正、GBrain 健康修复、ACP 可用性/权限边界复核。随后进入 1 周观察期，若无预算/并发/恢复事故，再推进 Stage 4 多角色协作；Stage 3 Full 仅在出现明确外部应用需求时启动。

## 2026-07-07 Stage 4 Pilot Round 1

- [observed] 用户批准按小规模 Stage 4 Pilot 推进,要求 3 轮迭代验证清楚。执行边界: native subagent only, 不用 ACP, 不 push/merge, 不对外发送, implementer/reviewer 写入限定在 `workspace/stage4-pilot/round1/`。
- [observed] Round 1 planner 产出 3 角色/3 门禁方案;主 agent 将试点对象收窄为隔离协议验证包,避免改动现有 eval 核心。
- [observed] Round 2 implementer 创建 `task-spec.md`, `role-protocol.json`, `validate_protocol.py`, `test_validate_protocol.py`, `impl-report-r2.md`;父级验证 validator 通过, unittest 通过。Reviewer 独立复核 PASS,提出 3 个低风险建议。
- [observed] Round 3 主 agent 采纳 reviewer 建议,补充 `scope_root` 缺失失败用例;终局执行 validator, unittest, golden baseline, budget flag, TaskFlow audit。功能门禁通过: validator PASS, tests PASS, golden baseline PASS, budget flag absent。
- [observed] 运维门禁黄灯: TaskFlow audit 无 error,但 warning 从试点前 3 个增至 5 个。结论:Stage 4 Pilot Round 1 记为 PASS-YELLOW,证明多角色 3 轮闭环可用,但不解锁全面多角色放权;扩大前需先检查新增 warnings 是否为 subagent completion-delivery 噪声。

## 2026-07-07 Stage 4 Pilot Round 2

- [observed] 用户要求“全面执行,直到完成 Stage4 pilot”。Round 1 黄灯复核后,当前 audit 恢复为 0 error / 3 warning,黄灯归类为历史 delivery/stale 噪声,无新增 TaskFlow error;budget flag absent。
- [observed] 选择真实低风险代码任务:在 `workspace/stage4-pilot/round2/` 内实现 stdlib-only readiness reporter,读取 Round1 证据与 TaskFlow audit JSON,输出 `green/yellow/red` JSON 状态。写入边界限定 round2,不动治理/配置/eval core,不 push/merge,不对外发送。
- [observed] 多角色 3 轮完成:Round 1 task spec;Round 2 implementer 创建 `stage4_pilot_report.py`, `test_stage4_pilot_report.py`, `impl-report.md`;reviewer 独立复核 PASS,仅 2 个低风险信息项;Round 3 父级终局验证写入 `stage4-pilot/round2/final-report.md`。
- [observed] 验证结果:py_compile PASS;unittest 12 tests OK;CLI 真实输入输出 status=`yellow`(符合 0 errors + known warnings 预期);golden baseline PASS(37/37);budget flag absent;TaskFlow audit 0 error / 3 warning。
- [confirmed] Stage 4 Pilot 达到“可完成真实低风险任务”的试点完成线。结论仍不是全面放权:允许继续小规模 Stage 4 任务(≤3 角色,≤3 轮,native subagent only,父级终局门禁),但项目级研发接手仍需 1 周观察期与更高风险任务验证。

## 2026-07-07 晚 系统设计复盘收口(用户批准执行)

复盘结论:**设计方案本身成熟,落后的是运营收口**。功能已到 Stage 4 Pilot,但 Stage 2.5 收尾账未结清,若干运营卫生问题正拖累自动化。本轮按 用户批准的三项决策执行完毕:

- [confirmed] **预算闭环 + 上限上调 + 双旗标清除**(解冻心跳派发)。根因发现:**已安装的 LaunchAgent `~/Library/LaunchAgents/ai.openclaw.budget-watch.plist`(Jul 4 版)缺失整个 `EnvironmentVariables` 块**,budget-watch 一直跑代码默认值(daily 1.5M / task 0.3M / main 0.8M),比文档更紧,是近日反复 breach 的真根因;07-05 的修复只覆盖了旧 Label `com.openclaw.budget-watch`,未覆盖实际加载的 `ai.openclaw.budget-watch`。已上调 daily 3M→6M / task 0.5M→1M / main 1.5M→3M,重新安装带 env 块的 plist 并 kickstart,实测日志确认新上限加载(“1142% of daily”→“571% of daily”)。清除顶层孤儿旗标(daily 6.13M,04:39,07-05 未修)+ 活旗标(session 1.51M,13:10),`flag=false / breaches_new=0`。留痕 approvals/log.md + BUDGET-POLICY.md 加防复发警示。**校准:今日实际 totalBillable=34.26M(远超本日志前文所记 13M),已 plateau,属沉没成本。**
- [confirmed] **AGENTS.md gpt-5.5 漂移改正**。图片读取策略段落此前带 `[verified]` 章声称 gpt-5.5「已彻底移除」,实况 openclaw.json 仍定义 openai provider + gpt-5.5 且 `fallbacks:["openai/gpt-5.5"]`、live 会话仍在 pin 使用。已改正为「仍是无线模式活跃 fallback(经 api.owlai.tech,纯文本无视觉)」。配置未动(gpt-5.5 保留)。一个带 verified 的错误论断比不写更危险,会瓦解「日志/配置为准」纪律。
- [confirmed] **运营卫生清扫**:① TaskFlow audit 从 5 warn → **0 findings**(取消 4 个 stale_blocked flow:2 个 Stage4 Pilot 遗留 + 2 个图片污染实验遗留;1 个 5 天前 FizzBuzz demo 因双模型 network timeout 失败的 delivery_failed 记录置 silent,无真实工作丢失);② 删空库 `eval/capability-catalog/capability_catalog.db`(保留真实 `catalog.db` 12 表);③ 会话清理:实为 enforce 保留非泄漏,仅 4 条 missing-transcript 孤儿索引行已剪除(320→308);④ 修 cron `记忆巡检-周一` delivery:清除已废弃 `channel: openclaw-weixin`(报 "Unsupported channel"),现为 `{mode:none}`,下次运行(周一 08:00)不再 error。
- [inferred→pending] **未处理项(需 用户决策,已入审批队列)**:GBrain 健康 25/100(autopilot 未跑、graph/link/pack/skill conformance 待修)——AGENTS.md 仍将其列为「双引擎」之一,但实况半残;建议要么修复要么如实降级其角色描述,勿过度宣称半宕引擎。审批队列 MEDIUM 项待 用户确认是否授权 GBrain pack 升级/autopilot 安装。
- [observed] **下一步(不加新功能)**:满 1 周无预算/并发/恢复事故观察 → L2 全量放权 / Stage 4 铺开 / Stage 3 按需。
