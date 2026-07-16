---
name: "anti-drift-governance"
description: "Multi-role evidence-driven governance: charter hash-lock, STATUS.yaml, R1-R8 rules, 5-role review loop (deploy→investigate→review→audit→report)."
---

# Anti-Drift Governance — 全局反漂移治理系统

为任意项目部署多角色证据驱动治理：宪章哈希锁定、STATUS.yaml 单信源、自动化校验/审计/汇报脚本、声明与证据强制绑定纪律。内置 **五角色审查环**（部署者→调查者→复核者→审计者→汇报者），每个角色独立视角、独立判据，交叉验证。

## 何时触发

- 用户说"部署治理系统""加防漂移""需要证伪机制""防止声明与证据脱钩""多角色审查"
- 新项目启动，需要建立证据驱动的验证体系
- 既有项目出现声明与证据不符的信任危机，需恢复可信状态
- 用户引用本技能或关键词：anti-drift, governance, 反漂移, STATUS.yaml, charter.lock, 多角色审计

## 设计公理（四条）

| # | 公理 | 含义 |
|---|---|---|
| 1 | 文件 > 记忆 | 目标在 `PROJECT_CHARTER.md`（哈希锁定），状态在 `STATUS.yaml`（机器可读）。对话记忆不是权威。 |
| 2 | 声明 = 证据 + 命令 | 任何"完成"声明必须绑定证据文件路径 + 可复跑命令，由脚本校验，非零退出=声明无效。 |
| 3 | 档位封闭 | 验证档位是固定枚举，禁止合并、禁止自造、禁止在任何文字中并称"已通过 X 和 Y"。 |
| 4 | 替代 = 变更 | 更换数据源/方法/容差/验收项=范围变更。立即停下写 CR，相关条目置 blocked，不得静默执行。 |

## 治理规则（R1-R8，不可协商）

部署时追加到项目 `AGENTS.md`，后续所有工作会话强制执行。

- **R1 会话启动仪式**：涉及项目的工作前，必须先跑 `python3 scripts/validate_status.py && python3 scripts/gen_report.py`，≤10 行向用户复述：目标、DoD、各档位计数、blocker。校验失败不得开工。
- **R2 汇报纪律**：一切进度/状态汇报**原样粘贴** gen_report.py 输出。脚本输出之外的文字禁止出现完成性结论（✅/通过/完成/Golden）。
- **R3 升级须举证**：STATUS.yaml 中 status 升级必须 (a) 实际运行验证并存证到 `evidence/<id>/` (b) 填写可复跑 verify_cmd (c) 跑通 validate_status.py。降级随时可做无需批准；无据升级禁止。
- **R4 档位纪律**：status 只能取封闭枚举值。禁止合并档位。"Golden"一词只能指 `verified_golden`。
- **R5 替代即变更**：更换验证数据源/方法/容差，或将 charter §3 验收项解释为"目标之外"=范围变更。立即停止相关工作，写 CR，条目置 blocked。
- **R6 宪章只读**：不修改 PROJECT_CHARTER.md 与 charter.lock。修改意愿走 R5。
- **R7 记忆纪律**：长期记忆禁止写入结论性状态（✅/通过/完成/百分比）。只写指针："项目状态以 governance/STATUS.yaml 为准，汇报用 scripts/gen_report.py。"
- **R8 阻塞上行**：遇到做不了的事，正确动作=置 blocked + 写 CR 上报，不是换一条容易路径继续报绿。

## 五角色审查环（核心机制）

每个部署/运转周期中，agent 依次切换五个角色视角。角色之间**禁止共享信任**——每个角色独立验证，交叉发现偏差。同一 agent 执行全部角色，但每次只带一个角色的方法论。

```
部署者 ──→ 调查者 ──→ 复核者 ──→ 汇报者
  │                      │
  └── 部署骨架           └── 交叉自检
              │                      │
              └──── 审计者 ←─────────┘
                    （每次新会话）
```

### 角色 1：部署者（Deployer）

**职责**：创建治理骨架，不评价内容质量。

- 步骤 1（盘点）：`ls -laR` 纯机械采集，输出存入 `evidence/inventory/`。**不分析、不判断、不采信记忆。**
- 步骤 2（建档）：按模板逐文件创建，占位符用盘点结果填充。**所有条目缺省 not_started / used_by: null。**
- 交付物：`find governance scripts evidence -type f` 清单。

🔒 **切换门禁**：全部文件创建完成 + 目录结构符合预期 → 显式声明"部署者角色完成，切换调查者"。

### 角色 2：调查者（Investigator）

**职责**：诚实回填状态，**宁可降级不可无据升级**。

- 逐条目检查：是否存在可复跑的验证产物？
  - 存在 → 原样复跑一次，输出存入 `evidence/<id>/`，填 verify_cmd，升级到对应档位
  - 不存在 → 降级（有编译产物 `compiled_only`，否则 `not_started`）
- 对既往声明过但拿不出证据的条目：**一律降级**，notes 注明"既往声明 X，当前无复跑证据，已降级"
- 涉及未批准容差的升级 → 置 `blocked`，blocker 写"等待 CR-XXX"
- 交付物：被降级条目的清单 + 原因；STATUS.yaml diff。

🔒 **切换门禁**：所有条目按规则重判完毕，无凭记忆的残留状态 → 显式声明"调查者角色完成，切换复核者"。

### 角色 3：复核者（Reviewer）

**职责**：以上帝视角交叉验证前两角色的工作。

- 对每个回填为 `verified_*` 的条目：
  - evidence 文件是否确实可打开、内容是否为对比输出（不是描述性文字）？
  - verify_cmd 是否可原样复跑？（随机抽 3 个实际跑一次）
- 盘点文件 vs STATUS.yaml 清单：条目数一致？无遗漏？无凭空出现？
- 篡改测试：手工把任一 not_started 改 verified_golden（不加 evidence）→ validate 非零退出？→ gen_report 拒绝出报？
- 交付物：复核通过/失败清单。

🔒 **切换门禁**：全部交叉检查通过 + validate_status.py 退出码 0 → 显式声明"复核者角色完成，切换汇报者"。

### 角色 4：审计者（Auditor）

**职责**：独立第三方审计，与实施者无关，没有为既往声明辩护的义务。**在全新会话中执行。**

- 依据：PROJECT_CHARTER.md、STATUS.yaml、evidence/、DECISIONS.md。不携带历史对话记忆。
- ① 对每个 `verified_*` 条目，确认 evidence 存在且为对比输出。
- ② 随机抽 3 个 `verified_*` 条目，实际复跑 verify_cmd，比对结论与 evidence 一致。
- ③ 核对档位未被稀释——verified_golden 的证据是否涉及 golden 数据源？
- ④ `ls` 数据目录，确认账本条目与磁盘文件一一对应。
- 输出：差异清单（条目/声明/实证/结论=维持/降级/需人工），禁止"总体良好"类判断。

**触发周期**：每周或每 5 个工作会话。审计者发现的降级直接改账本，无需实施 agent 同意。

### 角色 5：汇报者（Reporter）

**职责**：只搬运 gen_report.py 输出，不附加任何结论。

- 向用户提交：① gen_report.py 输出原文 ② `find governance scripts evidence -type f` ③ validate 退出码 ④ 待决 CR 列表 ⑤ 降级条目清单
- **禁止**在交付物中出现脚本输出之外的任何完成性结论。
- 汇报格式：先贴脚本输出，再列 CR 和降级清单，最后一行写"以上为 gen_report.py 输出 + CR/降级补充，不包含独立判断。"

## 部署工作流（六步）

### 前置条件

- 项目仓库根目录可写
- `python3` + `PyYAML`（`pip install pyyaml`）

### 步骤 1：盘点（部署者）

```bash
ls -laR <源码目录>             > evidence/inventory/src.txt
ls -laR <测试目录>             > evidence/inventory/tests.txt
ls -la  <测试数据目录>          > evidence/inventory/testdata.txt
ls -laR <参考数据/日志目录>      > evidence/inventory/reference.txt
```

STATUS.yaml 的模块清单、数据文件清单、测试清单、参考数据清单**只能从此抄录**，禁止凭记忆或既往会话填写。

### 步骤 2：建档（部署者）

按模板创建文件。模板从 `assets/` 读取，替换 `{{PLACEHOLDER}}` 占位符。

部署后的目录结构：
```
REPO_ROOT/
├── AGENTS.md                     # 追加 R1-R8 治理规则
├── governance/
│   ├── PROJECT_CHARTER.md        # 宪章（哈希锁定，agent 只读）
│   ├── charter.lock              # charter sha256
│   ├── STATUS.yaml               # 唯一权威状态账本
│   ├── DECISIONS.md              # 变更申请与决议日志
│   └── AUDIT_PROMPT.md           # 换脑审计提示词
├── scripts/
│   ├── validate_status.py        # 账本校验器
│   └── gen_report.py             # 汇报生成器
└── evidence/
    ├── inventory/                 # 盘点结果
    └── <id>/...                   # 验证证据
```

### 步骤 3：诚实回填（调查者）

逐条目按 R3 重判——只认现在存在且可复跑的证据。**宁可降级，不可无据升级。**

### 步骤 4：自检与出报（复核者 → 汇报者）

复核者交叉检查 → `validate_status.py` 通过 → 汇报者用 `gen_report.py` 生成首份报告。

### 步骤 5：记忆消毒（部署者）

检查 MEMORY.md 及长期记忆，删除本项目的结论性状态（✅/通过/完成/百分比），替换为 R7 指针句。删除 diff 存入 `evidence/inventory/memory_diff.txt`。

### 步骤 6：交付（汇报者）

向用户提交 gen_report 输出原文 + 文件清单 + validate 退出码 + CR 列表 + 降级清单。禁止出现脚本输出之外的任何完成性结论。

## 封闭枚举定义

```yaml
status_levels:
  - verified_golden       # 与 gold_truth 参考源逐条对比通过（唯一可称 Golden）
  - verified_reference    # 与 reference 参考数据对比通过
  - verified_synthetic    # 仅与自生成数据对比通过（禁止与前两档合并汇报）
  - compiled_only         # 仅编译/构建通过，未经任何数据验证
  - not_started
  - blocked               # 必须填 blocker + 关联 CR
```

部署到具体项目时，按实际数据源含义映射档位含义。`verified_synthetic` 在任何汇报中不得与上两档合并计数或混称"验证通过"。

## STATUS.yaml Schema 约束

- 每模块必填: `id`, `src`, `status`
- `status` 为 `verified_*` 时必填: `evidence`（仓库内相对路径）、`verify_cmd`（可原样复跑的命令行）
- `status` 为 `blocked` 时必填: `blocker`（阻塞原因，关联 CR 编号）
- `status_levels` 枚举封闭，禁止增删

## 模板占位符说明

| 占位符 | 含义 | 示例值 |
|---|---|---|
| `{{PROJECT_NAME}}` | 项目名 | `mmwavelib_migration` |
| `{{CHARTER_TARGET}}` | 项目目标摘要 | 将 XX 库从 A 移植到 B |
| `{{CHARTER_NONGOALS}}` | 明确非目标 | 修改算法逻辑 |
| `{{GOLD_SOURCE_DESC}}` | golden 数据源描述 | `testlogs/` 硬件日志 |
| `{{REF_SOURCE_DESC}}` | reference 数据源描述 | `testdata/*.bin` |
| `{{GOLD_SOURCE_DIR}}` | golden 数据目录 | `testlogs/` |
| `{{REF_SOURCE_DIR}}` | reference 数据目录 | `testdata/` |
| `{{SRC_DIR}}` | 源码目录 | `src/` |
| `{{TEST_DIR}}` | 测试目录 | `unit_test/` |
| `{{MODULE_LIST}}` | 模块清单 YAML | 从盘点抄录 |
| `{{TEST_FILES}}` | 测试文件清单 YAML | 从盘点抄录 |
| `{{DATA_COVERAGE_SECTIONS}}` | 数据覆盖段 YAML | 从盘点抄录 |
| `{{USER_APPROVAL_TODO}}` | 待批 CR 描述 | CR-001 容差提案 |

## 日常运转

- **每个工作会话**: R1 启动仪式 → 干活 → 升级取证（调查者视角）→ 汇报（贴脚本输出）
- **每次升级**: 调查者独立验证 → 复核者抽查（≥3 个）→ 汇报者出报
- **每周审计**: 新会话 + AUDIT_PROMPT.md（审计者视角），降级直接改账本
- **用户验收**: 亲自跑 validate + gen_report + 篡改测试 + 随机抽查 evidence

## 文件模板

完整模板在 `assets/` 支持文件中：
- `PROJECT_CHARTER.md.tmpl` — 宪章模板（通用占位符）
- `STATUS.yaml.tmpl` — 状态账本模板（通用枚举）
- `DECISIONS.md.tmpl` — 变更申请日志模板
- `AUDIT_PROMPT.md.tmpl` — 换脑审计提示词
- `governance-rules.md.tmpl` — R1-R8 规则段（通用版）

部署时从 `scripts/` 支持文件复制 `validate_status.py` 和 `gen_report.py` 到项目。
