# Stage 2.5 固化执行套件(Execution Kit)

配套 `openclaw-harness-stage2.5-consolidation.md` 的**可落地产物**。设计目标:把方案里的五条工作流做成能直接拖进 `~/.openclaw` 跑的脚本 + runbook,而不是又一份文档。

> ⚠ 我(Claude)这边**连不到实时 `~/.openclaw`**,只能在规划目录里造件+在沙箱用 mock 数据自测。所以这里的代码是「已在沙箱验证逻辑、留一个 OpenClaw 接缝待你接真机」的状态,不是"已在你的活系统上跑过"。接真机的地方都已明确标注。

## 目录与落地位置

| 文件 | 工作流 | 落地到 | 状态 |
|---|---|---|---|
| `eval/schema.sql` | A | `~/.openclaw/eval/golden/` | ✅ 沙箱验证 |
| `eval/replay.py` | A | 同上 | ✅ 跑通(mock 11/12);`run_agent` 是唯一待接真机接缝 |
| `eval/cases/*.yaml` | A | 同上 | 编码类真种子 + 其余类模板+采集说明 |
| `eval/fixtures/` | A | 同上 | mock 响应 + 一个编码 fixture 范例 |
| `eval/README.md` | A | 同上 | 用法 / 养集 / 接 Heartbeat / 接 Stage 5 门禁 |
| `hooks/pre-commit` | C | `~/.openclaw/.git/hooks/` | ✅ 实测拦截密钥、放行 allowlist |
| `scripts/scan-credentials.sh` | C | 随处运行 | ✅ 实测命中+JSON 容错 |
| `scripts/killswitch-probe.sh` | C/D | Heartbeat/LaunchAgent | ✅ 语法验证(macOS 运行时) |
| `scripts/analyze-429.py` | D | 随处运行 | ✅ 合成数据验证 |
| `scripts/kb-completeness-check.sh` | E | 随处运行 | ✅ 合成目录验证 |
| `runbooks/revoke-discord-tokens.md` | C·P0 | — | 你亲自执行 |
| `runbooks/taskflow-recovery-test.md` | B·P0 | — | 你在真机执行 |
| `runbooks/ops-and-kb.md` | D/E | — | 决策+命令 |

## 建议执行顺序(对齐方案 §3 优先级)

**P0(先做、可并行)**
1. **A 评估飞轮**:`eval/README.md` 快速开始 → 跑通 mock → 接 `run_agent` 真机 → 出各类基线。
2. **B TaskFlow 恢复**:按 `runbooks/taskflow-recovery-test.md` 三项测试,尤其 **T2 熔断计数跨重启**(最关键)。
3. **C·token 吊销(你执行)**:`runbooks/revoke-discord-tokens.md`——时间敏感,越早越好。

**P1**
4. **C 机制化**:装 `hooks/pre-commit` + 跑 `scan-credentials.sh` + 挂 `killswitch-probe.sh`。
5. **D 韧性**:`analyze-429.py` 特征化 → 按 `runbooks/ops-and-kb.md` 选策略 → 并入晨报。

**P2**
6. **E 知识库**:`kb-completeness-check.sh` 终检 → 按 runbook 拍板旧目录处置。

## 完成后

回到方案 §4「固化完成标准」逐条勾选;全绿后用**评估飞轮数据 + 是否真有外部应用需求**,决定下一步走 Stage 3(接 MCP)还是 Stage 4(多角色),并记入 `IMPLEMENTATION-LOG.md`。

## 什么没做 / 需要你

- 一切需要活系统的动作(接 `run_agent`、跑恢复测试、吊销 token、真机扫描)由你或 openclaw 侧执行。
- 若把 `~/.openclaw` 挂进来,我可以接上 `run_agent`、代跑扫描/分析、把基线与 429 特征跑出真数,并据此更新方案与日志。
