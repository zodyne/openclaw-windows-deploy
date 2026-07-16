# Runbook · 断点/会话韧性实测(B,P0)— 真实命令版

> 目标:兑现决议 4「断点恢复未实测」,重点是**已真实咬过 2 次**的故障——`/new` 会话重置孤儿化在飞子任务(`backing session missing`)。命令已按你安装版本的真实 CLI 校准。

## 你系统里的真实机制(先理解再测)

- **flow 不是用 CLI 手动创建的**,是主 agent 跑多步任务时自动起的(TaskFlow 编排)。
- 查看:`openclaw tasks flow list --json`、`openclaw tasks flow show <flow_id> --json`、`openclaw tasks list --runtime subagent --status lost --json`。
- **检测**(只读):`openclaw tasks audit --json`,finding codes 含 `lost / stale_running / restore_failed / stale_waiting / stale_blocked / cancel_stuck / blocked_task_missing`——正是我们要看的故障态。
- **恢复/收编**:`openclaw tasks maintenance --apply`(reconciliation + cleanup + pruning)。
- 停/起:`openclaw gateway stop|start|status`。

## 前置

```bash
openclaw gateway status
git -C ~/.openclaw tag pre-recovery-test-$(date +%F)   # 可回退锚
openclaw tasks audit --json | tee /tmp/audit-before.json   # 基线:测前有无既存 lost/stale
```

## T1 · 进程 kill / restart 续跑

```bash
# 1) 起一个会生成多步 flow 的非关键任务(后台),让它进行到中段
openclaw agent --agent main --timeout 600 --message \
'分三步执行,每步汇报进度:①列出 ~/.openclaw/workspace/eval/golden 下所有 .yaml ②逐个写一句话摘要 ③汇总写入 ~/.openclaw/tmp/recovery-t1.md' &

sleep 25
openclaw tasks flow list --json          # 记下 flow_id 与 current_step(在推进中)

# 2) 硬停 + 重启(模拟崩溃)
openclaw gateway stop
openclaw gateway start && openclaw gateway status

# 3) 判定
openclaw tasks audit --json              # 是否出现 lost / stale_running / restore_failed
openclaw tasks flow show <flow_id> --json   # 是从 current_step 续跑,还是丢失/从头
# 若审计报可恢复:
openclaw tasks maintenance --apply        # 看能否把中断的 flow 收编/续跑
```

判定:**通过**=flow 从 checkpoint 续跑或经 maintenance 正确恢复,产出文件最终落盘且 step1/2 未重复;**失败(阻断级)**=flow 丢失且 maintenance 无法恢复 → 长任务在修复前不进无人值守,评估 v3 §3.1 自建调度后备。

## T2 · 会话 /new 孤儿化(★ 已真实发生 2 次)

```bash
# 1) 在某会话(微信/WebChat)起一个会 spawn 子代理的多步任务,进行中……
# 2) 在同一会话执行 /new(重开会话)——复现 07-03 上下文污染时的处置动作
# 3) 立刻查在飞子任务是否变孤儿
openclaw tasks list --runtime subagent --status running --json
openclaw tasks list --runtime subagent --status lost --json      # 期望能看到 backing session missing 类
openclaw tasks audit --code lost --json
# 4) 收编/清理
openclaw tasks maintenance --apply
openclaw tasks list --runtime subagent --status lost --json      # 应清零或被接管
```

判定:**通过**=/new 后在飞子任务被接管、或被干净标记并经 maintenance 清理,不残留僵尸;**失败**=孤儿长期 `lost` 且 maintenance 收不回。这条是本测最高价值项(真实发生过)。

## T3 · 熔断计数跨重启(防"重启再跑"绕过)

```bash
# 起一个逼近迭代/预算阈值的任务,在接近阈值时 kill + restart,再看计数
openclaw tasks show <task_id> --json      # 关注迭代/预算消耗字段是否跨重启保留
```

判定:**通过**=迭代计数与累计预算跨重启不清零;**失败(阻断级)**=任一被重置。

## 记录与回退

```bash
# 结果写入 learnings,更新决议 4
$EDITOR ~/.openclaw/workspace/memory/learnings.md
# 有问题回退
git -C ~/.openclaw reset --hard pre-recovery-test-$(date +%F)
```

记录模板(贴 learnings.md):
```md
## TaskFlow/会话 断点恢复实测(2026-07-0x)
- T1 进程 kill/restart:续跑=是/否;maintenance 可恢复=是/否
- T2 /new 孤儿化:子任务变 lost=是/否;maintenance 收编=是/否 —— 结论:<接管/清理/残留>
- T3 熔断跨重启:迭代计数保留=是/否;预算累计保留=是/否
- 恢复语义:<存活的状态> / <丢失的状态>;决议 4 → 实测<通过/缺陷>
```
