# 预算熔断策略(2026-07-04 生效,07-07 更新)

**计量**:budget-watch 每 5 分钟统计当日 billable tokens(input+output+reasoning;cacheRead 单独记录不计费),台账 `ledger-<日期>.json`。

**上限(环境变量可调,改 plist 后 kickstart 生效)**
| 维度 | 当前值 | 变量 | 历史 |
|---|---|---|---|
| 当日总量 | 6,000,000 | BUDGET_DAILY_BILLABLE | 1.5M→3M(07-04)→6M(07-05 修复后,门禁冲刺期)→3M(07-07 观察期)→6M(07-07 晚,用户批准上调) |
| 单任务会话 | 1,000,000 | BUDGET_SESSION_BILLABLE | 0.3M→0.5M(07-04)→1M(07-05 修复后,门禁冲刺期)→0.5M(07-07 观察期)→1M(07-07 晚) |
| 主聊天会话(全天累积) | 3,000,000 | BUDGET_MAIN_SESSION_BILLABLE | 0.8M→1.5M(07-04)→3M(07-05 修复后,门禁冲刺期)→1.5M(07-07 观察期)→3M(07-07 晚) |

> **⚠️ 2026-07-07 修复的隐患**:此前**已安装的 LaunchAgent(`~/Library/LaunchAgents/ai.openclaw.budget-watch.plist`,Jul 4 版)缺失整个 `EnvironmentVariables` 块**,导致 budget-watch 实际一直跑**代码默认值(daily 1.5M / task 0.3M / main 0.8M)**,比文档记录的上限更紧,是近日反复 breach 的根因之一。本次已把带 env 块的 plist 重新安装并 kickstart,实测日志确认新 6M 上限已加载(“571% of daily”=34.2M/6M)。今后改上限务必核对**已安装**的 plist 而非仅 repo 内副本。

**熔断语义**:超限 → 写审批队列 + 落 `state/budget-breach.flag`。旗标存在期间,main 不得派发新任务/新 ACP 会话(见 HEARTBEAT 与派发前检查)。旗标只由 用户决策后手工删除(追加预算或终止任务),巡检不自动解除——这是"硬"的含义。

**已知校准数据**:2026-07-04 上午实测,重度工作日半天 ≈ 53 万 billable,主会话占九成;2026-07-07 当前上限 6M 足以覆盖重度日(含 L2 门禁冲刺)。
