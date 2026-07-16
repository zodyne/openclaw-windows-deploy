#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""evidence-ledger 汇报生成器。汇报只能由本脚本产出（规则 R2）。
先跑校验器，账本不干净则拒绝出报。
"""
import os
import subprocess
import sys
from collections import OrderedDict

import yaml

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ledger_lib as L  # noqa: E402

SCRIPTS = os.path.dirname(os.path.abspath(__file__))
GOV = os.path.dirname(SCRIPTS)


def main():
    rc = subprocess.run(
        [sys.executable, os.path.join(SCRIPTS, "validate_status.py")],
        capture_output=True, text=True)
    if rc.returncode != 0:
        print("!! 账本校验失败，拒绝生成汇报。先修复以下问题：")
        print(rc.stdout + rc.stderr)
        return 1

    tiers = L.load_tiers(os.path.join(GOV, "PROJECT_CHARTER.md"))
    with open(os.path.join(GOV, "STATUS.yaml"), encoding="utf-8") as f:
        data = yaml.safe_load(f)

    items = data.get("items") or []
    groups = OrderedDict((t["id"], []) for t in tiers)
    for it in items:
        groups[it["status"]].append(it.get("id", "?"))
    label = {t["id"]: (t.get("label") or t["id"]) for t in tiers}

    meta = data.get("meta") or {}
    print("# %s 状态汇报（gen_report.py 生成）" % meta.get("project", ""))
    print()
    print("## 条目档位（%d 项，档位互斥、禁止合并）" % len(items))
    print()
    print("| 档位 | 数量 | 条目 |")
    print("|---|---:|---|")
    for t in tiers:
        ids = groups[t["id"]]
        print("| %s | %d | %s |" % (label[t["id"]], len(ids),
                                    ", ".join(ids) if ids else "—"))
    print()

    for cs in (data.get("coverage_sets") or []):
        files = cs.get("files") or []
        used = [d for d in files if d.get("used_by")]
        exempt = [d for d in files if not d.get("used_by") and d.get("exempt_cr")]
        unused = [d for d in files
                  if not d.get("used_by") and not d.get("exempt_cr")]
        print("## 覆盖集合: %s — 已用 %d / 豁免 %d / 未用 %d / 共 %d"
              % (cs.get("name"), len(used), len(exempt), len(unused), len(files)))
        if unused:
            print()
            print("**未使用清单（%d 项）：**" % len(unused))
            for d in unused:
                print("- %s" % d.get("file"))
        if exempt:
            print()
            print("**已豁免（CR）：** " + ", ".join(
                "%s(%s)" % (d.get("file"), d.get("exempt_cr")) for d in exempt))
        print()

    blocked = [(it.get("id"), it.get("blocker")) for it in items
               if it.get("status") == "blocked"]
    print("## 阻塞项（%d）" % len(blocked))
    for iid, why in blocked:
        print("- %s: %s" % (iid, why))
    print()

    dec = L.load_decisions(os.path.join(GOV, "DECISIONS.md"))
    pending = [title for cr, (st, title) in dec.items() if st == "pending"]
    print("## 待用户决策的变更申请（%d）" % len(pending))
    for p in pending:
        print("- " + p)
    print()
    print("---")
    print("*本报告由 governance/scripts/gen_report.py 从 STATUS.yaml 生成。"
          "任何未出现在本报告中的完成性声明一律无效。*")
    return 0


if __name__ == "__main__":
    sys.exit(main())
