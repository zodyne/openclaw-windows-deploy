#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""evidence-ledger 账本校验器。任何违规 -> 非零退出。
用法: python3 governance/scripts/validate_status.py
档位定义从宪章 TIERS 块读取（受 charter.lock 哈希保护），
并与 STATUS.yaml 的 status_levels 交叉核对——防稀释的机器执行点。
"""
import os
import sys

import yaml

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ledger_lib as L  # noqa: E402

SCRIPTS = os.path.dirname(os.path.abspath(__file__))
GOV = os.path.dirname(SCRIPTS)
ROOT = os.path.dirname(GOV)
CHARTER = os.path.join(GOV, "PROJECT_CHARTER.md")
LOCK = os.path.join(GOV, "charter.lock")
STATUS = os.path.join(GOV, "STATUS.yaml")
DECISIONS = os.path.join(GOV, "DECISIONS.md")

errors = []


def err(msg):
    errors.append(msg)


def main():
    if not os.path.exists(CHARTER):
        print("FATAL: 找不到 %s" % CHARTER)
        return 1
    try:
        tiers = L.load_tiers(CHARTER)
    except Exception as e:
        print("FATAL: 档位定义解析失败: %s" % e)
        return 1
    tier_ids = [t["id"] for t in tiers]
    verified_ids = {t["id"] for t in tiers if t.get("verified")}
    must_ref = {t["id"]: (t.get("evidence_must_reference") or []) for t in tiers}

    # 1. 宪章哈希锁（档位定义在宪章内，篡改档位即破坏锁）
    cur = L.sha256_of(CHARTER)
    if not os.path.exists(LOCK):
        with open(LOCK, "w") as f:
            f.write(cur + "\n")
        print("[init] charter.lock 已生成: %s..." % cur[:16])
    else:
        locked = open(LOCK).read().strip()
        if locked != cur:
            err("PROJECT_CHARTER.md 与 charter.lock 不一致（疑似未经批准的修改，"
                "含档位定义）。已批准变更须先记 DECISIONS 决议再更新 lock。")

    # 2. 载入账本
    try:
        with open(STATUS, encoding="utf-8") as f:
            data = yaml.safe_load(f)
    except Exception as e:
        print("FATAL: STATUS.yaml 解析失败: %s" % e)
        return 1

    declared = data.get("status_levels") or []
    if declared != tier_ids:
        err("STATUS.status_levels 与宪章档位不一致。宪章=%s STATUS=%s"
            "（档位为封闭枚举，改动走 CR）" % (tier_ids, declared))

    decisions = L.load_decisions(DECISIONS)
    cr000_status = decisions.get("CR-000", ("missing", ""))[0]

    def check_evidence_ref(iid, st, ev_path, vc):
        """防稀释：该档位要求证据链引用特定路径片段。"""
        frags = must_ref.get(st) or []
        if not frags:
            return
        hay = vc or ""
        if any(f in hay for f in frags):
            return
        content = ""
        full = os.path.join(ROOT, ev_path) if ev_path else ""
        if full and os.path.exists(full):
            try:
                content = open(full, encoding="utf-8", errors="ignore").read()
            except Exception:
                content = ""
        if not any(f in content for f in frags):
            err("[item:%s] 档位 %s 要求证据链引用 %s 之一，但 verify_cmd 与 "
                "evidence 内容均未出现（防稀释校验）" % (iid, st, frags))

    # 3. items 校验
    seen = set()
    for it in (data.get("items") or []):
        iid = it.get("id") or "?"
        if iid in seen:
            err("[item:%s] id 重复" % iid)
        seen.add(iid)
        st = it.get("status")
        if st not in tier_ids:
            err("[item:%s] 非法 status: %r（禁止合并/自造档位）" % (iid, st))
            continue
        if st in verified_ids:
            if cr000_status != "approved":
                err("[item:%s] CR-000(证据档位阶梯)状态=%s，批准前任何条目"
                    "不得置于 verified 档" % (iid, cr000_status))
            ev, vc = it.get("evidence"), it.get("verify_cmd")
            if not ev:
                err("[item:%s] status=%s 但 evidence 为空" % (iid, st))
            elif not os.path.exists(os.path.join(ROOT, ev)):
                err("[item:%s] evidence 文件不存在: %s" % (iid, ev))
            if not vc:
                err("[item:%s] status=%s 但缺少可复跑 verify_cmd" % (iid, st))
            check_evidence_ref(iid, st, ev, vc)
        if st == "blocked" and not it.get("blocker"):
            err("[item:%s] status=blocked 但未填 blocker" % iid)

    # 4. 覆盖集合校验
    for cs in (data.get("coverage_sets") or []):
        name = cs.get("name", "?")
        for d in (cs.get("files") or []):
            fn, ub, ex = d.get("file", "?"), d.get("used_by"), d.get("exempt_cr")
            if ub and not os.path.exists(os.path.join(ROOT, ub)):
                err("[coverage:%s:%s] used_by 指向不存在的 evidence: %s"
                    % (name, fn, ub))
            if ex:
                st_cr = decisions.get(ex, ("missing", ""))[0]
                if st_cr != "approved":
                    err("[coverage:%s:%s] 豁免引用 %s 状态=%s，只有 approved "
                        "的 CR 才能豁免" % (name, fn, ex, st_cr))

    if errors:
        print("== 校验失败 (%d 项) ==" % len(errors))
        for e in errors:
            print(" - " + e)
        return 1
    print("== 校验通过 ==")
    return 0


if __name__ == "__main__":
    sys.exit(main())
