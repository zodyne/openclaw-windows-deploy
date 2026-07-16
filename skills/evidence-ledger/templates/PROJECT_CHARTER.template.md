# {{PROJECT_NAME}} 项目宪章
版本: 1.0（{{DATE}}）。本文件对 agent 只读；任何修改必须先在 DECISIONS.md
提交变更申请（CR）、获得用户批准后，方可修改并同步更新 charter.lock。

## 1. 目标原文
{{GOAL_TEXT}}

## 2. 证据档位定义（防稀释条款）
档位为封闭枚举，含义在所有会话、汇报、记忆中唯一，禁止扩大解释或合并计数。
校验器直接读取下方 TIERS 块；改动本块 = 改动宪章 = 触发哈希锁。

<!-- TIERS-BEGIN -->
```yaml
{{TIERS_YAML}}
```
<!-- TIERS-END -->

字段说明：id（档位名）/ verified（true 则升档需 evidence+verify_cmd）/
label（汇报显示名）/ definition（可操作定义：和什么比、怎么算通过）/
evidence_must_reference（证据链中必须出现的路径片段列表——防稀释关键字段）。
档位必须包含 not_started 与 blocked。

## 3. 验收清单（Definition of Done）
{{DOD_LIST}}
（任何一条的范围调整走 CR，不得由 agent 单方面判定"目标之外"。）

## 4. 非目标
{{NON_GOALS}}

## 5. 覆盖集合
下列资产集合中每个文件必须被消费（used_by 非空）或经 approved CR 豁免：
{{COVERAGE_SETS}}

## 6. 附录：量化阈值
所有容差/阈值的初始值以 CR 形式提交（状态: pending）；
未批准前，涉及该阈值判定的升档一律置 blocked。
