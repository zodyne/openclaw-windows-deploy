#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""从 STATUS.yaml 生成状态汇报。汇报只能由本脚本产出（规则 R2）。"""
import os, re, subprocess, sys
from collections import OrderedDict
try:
 import yaml
except ImportError:
 print("FATAL: PyYAML 未安装。执行: pip install pyyaml"); sys.exit(1)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GOV = os.path.join(ROOT, "governance")

LEVELS = ["verified_golden", "verified_reference", "verified_synthetic",
 "compiled_only", "not_started", "blocked"]
LABEL = {
 "verified_golden": "Golden 验证",
 "verified_reference": "参考数据验证",
 "verified_synthetic": "合成数据验证",
 "compiled_only": "仅构建通过",
 "not_started": "未开始",
 "blocked": "阻塞",
}

def main():
 rc = subprocess.run([sys.executable,
 os.path.join(ROOT, "scripts", "validate_status.py")],
 capture_output=True, text=True)
 if rc.returncode != 0:
 print("!! 账本校验失败，拒绝生成汇报。先修复以下问题：")
 print(rc.stdout.rstrip())
 if rc.stderr: print(rc.stderr.rstrip())
 return 1

 with open(os.path.join(GOV, "STATUS.yaml"), encoding="utf-8") as f:
 data = yaml.safe_load(f)

 project = (data.get("meta") or {}).get("project", "项目")
 modules = data.get("modules") or []
 tiers = OrderedDict((lv, []) for lv in LEVELS)
 for m in modules:
 tiers[m.get("status", "?")].append(m.get("id", "?"))

 print("# %s 状态汇报（gen_report.py 生成）" % project)
 print()
 print("## 模块验证档位（%d 个模块，档位互斥、禁止合并）" % len(modules))
 print()
 print("| 档位 | 数量 | 模块 |")
 print("|---|---:|---|")
 for lv in LEVELS:
 ids = tiers[lv]
 print("| %s | %d | %s |" % (LABEL[lv], len(ids),
 ", ".join(ids) if ids else "—"))
 print()

 cov = data.get("data_coverage") or {}
 if cov:
 COV_TITLES = {"golden_data": "Golden 参考数据", "reference_data": "参考数据",
 "testdata": "测试数据", "testdata_bins": "测试数据 (.bin)",
 "testlogs": "参考日志", "benchmarks": "基准数据"}
 for section in cov:
 items = cov.get(section) or []
 used = [d for d in items if isinstance(d, dict) and d.get("used_by")]
 unused = [d for d in items if isinstance(d, dict) and not d.get("used_by")]
 title = COV_TITLES.get(section, section)
 print("## 数据覆盖：%s — 已用 %d / %d" % (title, len(used), len(items)))
 if unused:
 print()
 print("**未使用（%d 项）：**" % len(unused))
 for d in unused: print("- %s" % d.get("file", "?"))
 print()

 tests = data.get("unit_tests") or []
 if tests:
 passed = [t for t in tests if isinstance(t, dict)
 and (t.get("status") or "").startswith("verified")]
 print("## 单元测试 — 通过 %d / %d" % (len(passed), len(tests)))
 for t in tests:
 if isinstance(t, dict) and not (t.get("status") or "").startswith("verified"):
 print("- [%s] %s" % (t.get("status", "?"), t.get("file", "?")))
 print()

 blocked = [(m.get("id"), m.get("blocker")) for m in modules
 if isinstance(m, dict) and m.get("status") == "blocked"]
 blocked += [(t.get("file"), t.get("blocker")) for t in tests
 if isinstance(t, dict) and t.get("status") == "blocked"]
 print("## 阻塞项（%d）" % len(blocked))
 if blocked:
 for iid, why in blocked: print("- %s: %s" % (iid, why))
 else: print("（无）")
 print()

 dec_path = os.path.join(GOV, "DECISIONS.md")
 pending = []
 if os.path.exists(dec_path):
 txt = open(dec_path, encoding="utf-8").read()
 for block in re.split(r"(?m)^## ", txt)[1:]:
 title = block.splitlines()[0].strip()
 m = re.search(r"(?m)^状态:\s*(\S+)", block)
 if m and m.group(1) == "pending": pending.append(title)
 print("## 待用户决策的变更申请（%d）" % len(pending))
 if pending:
 for p in pending: print("- " + p)
 else: print("（无）")
 print()
 print("---")
 print("*本报告由 scripts/gen_report.py 从 governance/STATUS.yaml 生成。"
 "任何未出现在本报告中的完成性声明一律无效。*")
 return 0

if __name__ == "__main__": sys.exit(main())
