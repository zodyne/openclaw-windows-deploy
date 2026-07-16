---
name: evidence-ledger
description: 为跨多会话的长期项目建立防漂移治理系统：哈希锁定的目标宪章、证据分档状态账本、声明-证据绑定校验器、只能由脚本生成的进度汇报、换脑审计。Use this skill whenever 用户要启动、管理或整顿一个多会话工程项目（移植、迁移、重构、数据管道、合规、benchmark 复现等）；用户抱怨 agent 虚报进度、验证对不上、"说完成了其实没做"、目标漂移、记忆不可靠；用户提到项目治理、进度追踪、状态盘点、验收、审计、Golden 验证、防漂移。即使用户没有说"治理"或"skill"，只要涉及长期项目启动或进度可信性问题，都应使用本技能。
---

# Evidence Ledger — 项目防漂移治理

## 何时不用（适用门槛）
单会话可完成、产出用户一眼可验、没有外部验证资产的任务，装本系统是纯开销，直接做即可。
本系统的甜点区：多会话、验证密集、声明可被外部资产证伪的工程。

## 系统不变量（安装进项目后长期成立）
1. 权威状态在仓库文件（governance/），不在对话记忆。
2. 任何"完成"声明 = 证据文件 + 可复跑命令，由 validate_status.py 机器校验。
3. 证据档位是宪章里哈希锁定的封闭枚举；档位含义被稀释时校验器直接拒绝
   （evidence_must_reference 机制）。
4. 替代数据源/方法/阈值 = 范围变更（CR）；静默顶替是最严重违规。

## 定位：本技能是"安装器 + 审计器"，不是运行时
初始化时把 templates/ 实例化、把 scripts/ 复制进目标项目；此后项目日常运转只依赖
项目内文件 + python3 + PyYAML，本技能不在场也照常工作。日常规则靠写入项目
AGENTS.md 的 R1–R8 生效，不依赖本技能被触发。

## 工作流选择
| 情形 | 工作流 |
|---|---|
| 新项目从零建立 | init |
| 项目已跑了一段、状态可疑或已漂移 | retrofit（= init + 诚实回填 + 记忆消毒） |
| 周期性核查既有账本 | audit |

## Workflow: init
1. 访谈固化四件事：目标原文、完成定义（DoD 逐条）、非目标、覆盖集合
   （哪些资产目录必须被全部消费）。
2. 设计证据档位阶梯：先读 references/tier-ladder-patterns.md，为本项目提出
   3–5 个 verified 档 + not_started + blocked；每档写可操作定义；能给的都填
   evidence_must_reference（防稀释关键字段）。以 CR-000 写入 DECISIONS.md
   （状态: pending）。**CR-000 未获用户批准前，不得给任何条目升到 verified 档
   （校验器强制拦截）。**
3. 盘点：`ls -laR` 所有相关目录 → `evidence/inventory/*.txt`。后续 items 与
   coverage_sets 清单**只能**从盘点文件抄录，禁止凭记忆或既往会话填写。
4. 实例化模板：templates/ 五件 → 项目 `governance/`，替换占位符：
   {{PROJECT_NAME}} {{GOAL_TEXT}} {{DOD_LIST}} {{NON_GOALS}} {{TIERS_YAML}}
   {{TIER_IDS}} {{COVERAGE_SETS}} {{DATE}}。
5. 复制本技能 scripts/*.py → 项目 `governance/scripts/`。
6. STATUS.yaml：全部条目缺省 not_started / used_by: null。
7. `python3 governance/scripts/validate_status.py` 跑到通过（首跑生成 charter.lock）。
8. 把 AGENTS_RULES（替换占位符后）追加进项目 AGENTS.md；生成首份
   gen_report.py 输出，连同 pending CR 清单一并交用户。

## Workflow: retrofit（已漂移项目）
在 init 全部步骤之上追加：
9. 诚实回填：逐条目重判——仅当验证产物**现在存在且可复跑**：原样复跑一次、
   输出存 evidence/<id>/、填 verify_cmd，方可升档；既往声明拿不出可复跑证据的
   一律降级。原则：**宁可降级，不可无据升级。** 涉及未批准阈值（CR pending）
   的判定 → blocked。
10. 记忆消毒：清除 MEMORY.md 等长期记忆中关于本项目的一切结论性状态
    （通过/完成/✅/百分比），替换为一行指针（R7 原文），前后 diff 存
    evidence/inventory/memory_diff.txt。
11. 向用户交付降级清单：哪些条目从什么声明降到什么档、原因。

## Workflow: audit
在**全新会话**（不携带历史上下文与记忆）中执行项目的
governance/AUDIT_PROMPT.md。审计产出的降级直接改账本，无需实施 agent 同意。
建议接入 OpenClaw 的 cron/heartbeat 每周触发一次。

## 执行纪律（对使用本技能的 agent）
- 一切清单来自盘点文件；一切完成性声明只能是 gen_report.py 输出原文。
- 本技能自身的初始化/回填工作同样要交证据（命令输出、退出码），不得自评"完成"。
- 首次使用前读一遍 references/failure-modes.md，识别七种病理的早期信号。
