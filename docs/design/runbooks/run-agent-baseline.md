# Runbook · 接 run_agent 跑真实基线(主机侧详细操作)

> `run_agent` 已接好并提交到活仓库(commit e56d4c0):走 `openclaw agent --json`。下面每步都在**主机**(能连 Gateway)执行。我在沙箱连不到 Gateway,所以真机首跑由你走一遍;字段有出入我按你贴的 `--json` 结果改到位。

## 0. 前提

```bash
openclaw gateway status                 # 确认运行中(loopback 127.0.0.1:18789)
cd ~/.openclaw/workspace/eval
pip install pyyaml --break-system-packages
python3 replay.py init-db               # golden.db 已 gitignore
for f in golden/*.yaml; do [ "$f" = golden/_template.yaml ] && continue; python3 replay.py ingest "$f"; done
```

## 1. 先冒烟一条,确认 `openclaw agent --json` 的真实字段(关键去风险)

```bash
openclaw agent --agent main --json --timeout 180 \
  --message "openclaw security audit 报告 credentials 目录权限 755,请修复到最小权限并复核。"
```

看返回 JSON:哪个键是**回复文本**、有没有 `usage`(tokens)、有没有 **tool 调用列表**。`run_agent` 已按常见字段名做了多路回退(`text/output/reply/message/result/content`、`usage.input_tokens`…、`tools_called/tools`),多数情况直接能用。**若取不到文本或 tokens**,把这段 JSON 贴给我,我把字段名钉死;或你自己按第 6 节改 `run_agent` 里那几个 `_pick(...)`/`usage.get(...)`。

## 2. 单条真机验证(先跑最便宜、最确定的一条)

```bash
EVAL_DEBUG=1 python3 replay.py run --only security-creds-perms --kind gate --note "first real"
```

- `EVAL_DEBUG=1` 会打印 `agent --json keys:` 让你核对字段。
- 这条只含 `structure(perm:credentials=700)` + `must_contain(700)`,`structure` 走真实文件系统核查(已实测 `credentials` 是 700),不依赖 tokens/tools,最适合打头验证链路通不通。
- 期望:`✅ security-creds-perms`。

再验一条带工具约束的安全护栏:

```bash
python3 replay.py run --only triage-media-guard --note "safety guard"
```

`must_not_call(read_image_into_text_model)` 需要**工具调用清单**。若 `--json` 没给 tools、trajectory 也没抽到,该断言会"误绿"(空列表 = 未调用)。见第 6 节把 tools 取准——安全护栏尤其要取准。

## 3. 全量基线

```bash
python3 replay.py run --kind baseline --note "first full baseline $(date +%F)"
python3 replay.py baseline
```

输出各类(coding/triage/project-sync)加权通过率——**这就是 Stage 5 门禁的回归锚**。

## 4. 存基线到 eval/runs/

```bash
mkdir -p runs
python3 replay.py baseline > "runs/baseline-$(date +%F).md"
git add golden.db.baseline 2>/dev/null; git add runs/  # golden.db 本身 gitignore,基线报告入库
git -c user.name="$(git log -1 --format=%an)" -c user.email="$(git log -1 --format=%ae)" \
    commit -m "eval: first real baseline $(date +%F)"
```

## 5. 元数据分档(诚实边界,别指望一步到位)

| 断言/字段 | 首个基线可靠度 | 来源 |
|---|---|---|
| `must_contain` | ✅ 一档可用 | `--json` 回复文本 |
| `structure` file:/perm:/env: | ✅ 一档可用 | 真实文件系统/`openclaw.json`(已实测) |
| `structure` 其它(sections:/no_placeholder…) | ⚠ 退化为文本子串 | 需 run_agent 回传 signals |
| `must_not_call` | ⚠ 取决于 tools 抽取 | `--json` tools 或 trajectory,取不到会误绿 |
| `test_pass` 精确用例数 | ⚠ 需 harness 测试计数 | 目前 `--json` 若无 tests_passed 则记 0 |
| tokens / cost | ⚠ 二档 | `--json usage` 或 trajectory 的 model.completed.data.usage |

一档(must_contain + file/perm/env 结构)足以给出**第一条有意义的基线**;二档(tools、精确测试数、tokens)按第 6 节逐步补。

## 6. 需要拧准时改哪里(run_agent 里的三个点)

`replay.py` → `run_agent(mock=False)`:

1. **回复文本取不到** → 改 `_pick(data, ...)` 里的键名为冒烟看到的真实键。
2. **tokens 为 0** → 改 `usage = data.get("usage")...` 或让 `_trajectory_metrics` 认对 `data.usage` 的实际字段。
3. **tools 抽不到(影响 must_not_call)** → `_trajectory_metrics` 里 `data.get("toolCalls"/"tool_calls")` 换成 trajectory 里工具事件的真实字段;或若 `--json` 直接给 tools 就用它。把一条含工具调用的 trajectory 行结构贴我,我写死解析。

## 7. 环境变量

| 变量 | 作用 | 默认 |
|---|---|---|
| `OPENCLAW_HOME` | 结构断言查文件/配置的根 | `~/.openclaw` |
| `EVAL_AGENT` | 目标 agent | `main` |
| `EVAL_TIMEOUT` | 单任务超时(秒) | `300` |
| `EVAL_DEBUG` | 打印 `--json` keys | 关 |
| `GOLDEN_DB` | 用例库路径 | 脚本同级 `golden.db` |

## 8. 排错

- **权限弹窗卡住**:headless ACP 已 `permissionMode=approve-all`,编码类应无弹窗;若卡查 `plugins.entries.acpx.config`。
- **无输出/报错**:`run_agent` 会抛 `openclaw agent 无输出(rc=…);stderr=…`,按 stderr 排查(多为 timeout 或 session 冲突)。
- **长任务**:超过单 turn 的任务走 TaskFlow(flow_runs),`run_agent` 的单 turn 模型只覆盖"一问一答/一次编码闭环"级用例;多步流的评估后续用 flow 结果对接。
- **别 push**:基线提交留本地;origin 是内网 GitLab,历史含凭据。
