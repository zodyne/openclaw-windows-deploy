#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""STATUS.yaml 一致性校验器。任何违规 -> 非零退出。
用法: python3 scripts/validate_status.py
"""
import hashlib, os, sys
try:
 import yaml
except ImportError:
 print("FATAL: PyYAML 未安装。执行: pip install pyyaml"); sys.exit(1)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GOV = os.path.join(ROOT, "governance")
STATUS_PATH = os.path.join(GOV, "STATUS.yaml")
CHARTER_PATH = os.path.join(GOV, "PROJECT_CHARTER.md")
LOCK_PATH = os.path.join(GOV, "charter.lock")

LEVELS = {"verified_golden", "verified_reference", "verified_synthetic",
 "compiled_only", "not_started", "blocked"}
VERIFIED = {"verified_golden", "verified_reference", "verified_synthetic"}
errors = []

def err(msg): errors.append(msg)

def sha256_of(path):
 h = hashlib.sha256()
 with open(path, "rb") as f:
 for chunk in iter(lambda: f.read(8192), b""): h.update(chunk)
 return h.hexdigest()

def main():
 if not os.path.exists(CHARTER_PATH):
 err("governance/PROJECT_CHARTER.md 不存在")
 else:
 cur = sha256_of(CHARTER_PATH)
 if not os.path.exists(LOCK_PATH):
 with open(LOCK_PATH, "w") as f: f.write(cur + "\n")
 print("[init] charter.lock: %s..." % cur[:16])
 else:
 locked = open(LOCK_PATH).read().strip()
 if locked != cur:
 err("charter.lock 不一致（疑似未批准修改）。")

 if not os.path.exists(STATUS_PATH):
 print("FATAL: governance/STATUS.yaml 不存在"); return 1
 try:
 with open(STATUS_PATH, encoding="utf-8") as f: data = yaml.safe_load(f)
 except Exception as e:
 print("FATAL: STATUS.yaml 解析失败: %s" % e); return 1

 if data is None: err("STATUS.yaml 为空")
 elif not isinstance(data, dict): err("STATUS.yaml 顶层必须是 dict")
 else: _validate(data)

 if errors:
 print("== 校验失败 (%d 项) ==" % len(errors))
 for e in errors: print(" - " + e)
 return 1
 print("== 校验通过 ==")
 return 0

def _validate(data):
 declared = data.get("status_levels") or []
 if set(declared) != LEVELS:
 err("status_levels 枚举被改动。当前: %s, 期望: %s" % (sorted(declared), sorted(LEVELS)))

 def check_item(kind, it):
 if not isinstance(it, dict): err("[%s] 不是字典: %r" % (kind, it)); return
 iid = it.get("id") or it.get("file") or "?"
 st = it.get("status")
 if st is None: err("[%s:%s] 缺少 status" % (kind, iid)); return
 if st not in LEVELS:
 err("[%s:%s] 非法 status: %r（合法值: %s）" % (kind, iid, st, sorted(LEVELS))); return
 if st in VERIFIED:
 ev, vc = it.get("evidence"), it.get("verify_cmd")
 if not ev: err("[%s:%s] evidence 为空" % (kind, iid))
 elif not os.path.exists(os.path.join(ROOT, ev)): err("[%s:%s] evidence 不存在: %s" % (kind, iid, ev))
 if not vc: err("[%s:%s] 缺少 verify_cmd" % (kind, iid))
 if st == "blocked" and not it.get("blocker"): err("[%s:%s] blocked 但未填 blocker" % (kind, iid))

 for m in (data.get("modules") or []): check_item("module", m)
 for t in (data.get("unit_tests") or []): check_item("unit_test", t)

 cov = data.get("data_coverage") or {}
 for section in cov:
 for d in (cov.get(section) or []):
 if isinstance(d, dict) and d.get("used_by"):
 if not os.path.exists(os.path.join(ROOT, d["used_by"])):
 err("[coverage:%s] %s: used_by 不存在: %s" % (section, d.get("file", "?"), d["used_by"]))

if __name__ == "__main__": sys.exit(main())
