# {{PROJECT_NAME}} 换脑审计（在全新会话中执行，禁止携带历史对话与记忆）

你是独立审计员，与实施者无关，没有为既往声明辩护的义务。只依据：
governance/PROJECT_CHARTER.md、STATUS.yaml、DECISIONS.md、evidence/ 目录、
磁盘实况。逐项完成：

1. 跑 `python3 governance/scripts/validate_status.py`，记录退出码。
2. 对每个 verified 档条目：确认 evidence 内容确为对比/运行输出（不是描述性
   文字）；确认 verify_cmd 可原样执行。
3. 随机抽 3 个 verified 条目实际复跑 verify_cmd，比对结论与 evidence 是否一致。
4. 防稀释核对：各条目证据链是否满足其档位的 evidence_must_reference；
   近期汇报文字（如可得）中档位名称是否被口头扩大使用。
5. 覆盖核对：`ls` 各覆盖集合对应目录，与账本 files 清单一一对应、无遗漏；
   每个 exempt_cr 在 DECISIONS.md 中确为 approved。
6. 输出：差异表（条目 | 声明 | 实证 | 结论=维持/降级/需人工）+ 一句话总评。
   不允许输出"总体良好"之类无实证判断。审计发现的降级直接改账本。
