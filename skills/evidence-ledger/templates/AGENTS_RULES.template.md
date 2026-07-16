# ===== {{PROJECT_NAME}} 治理规则（不可协商，编号供引用） =====

R1 会话启动仪式：涉及本项目的任何工作开始前，先执行
   `python3 governance/scripts/validate_status.py && python3 governance/scripts/gen_report.py`，
   并用 ≤10 行向用户复述：目标、DoD、各档位计数、现有 blocker。
   校验失败先修账本，不得开工。

R2 汇报纪律：一切进度/状态汇报必须原样粘贴 gen_report.py 输出。脚本输出之外
   的文字中不得出现任何未在其中出现的完成性结论（✅/通过/完成）。

R3 升级须举证：STATUS.yaml 任何升档必须在同一次操作中：
   (a) 实跑验证并把输出存入 evidence/<id>/；
   (b) 填写任何人可原样复跑的 verify_cmd；
   (c) 跑通校验器。
   降级随时可做且无需批准；无据升级任何时候不允许。

R4 档位纪律：status 只能取宪章 TIERS 块枚举值；任何文字禁止合并档位；
   各档名称（尤其顶层荣誉词）只能按宪章定义使用。

R5 替代即变更：更换验证数据源、验证方法、阈值，或把宪章 DoD 任何一条重新
   解释为"目标之外"，都属范围变更：立即停止相关工作，在 DECISIONS.md 写
   CR（状态: pending）向用户申请，等待期间相关条目置 blocked。
   静默降级/顶替属最严重违规。

R6 宪章只读：不修改 PROJECT_CHARTER.md 与 charter.lock。修改意愿走 R5。

R7 记忆纪律：MEMORY.md 等长期记忆中，关于本项目禁止写入结论性状态
   （通过/完成/✅/百分比）。只允许指针："{{PROJECT_NAME}} 状态以
   governance/STATUS.yaml 为准，汇报用 governance/scripts/gen_report.py。"

R8 阻塞上行：遇到做不动的事（框架难移植、数据格式不明、环境缺失等），
   正确动作是置 blocked + 写 CR 上报，而不是换一条容易的路径继续报绿。
