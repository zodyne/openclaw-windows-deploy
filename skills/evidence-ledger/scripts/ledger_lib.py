#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""evidence-ledger 共享库：宪章档位解析 / DECISIONS 解析 / 哈希。"""
import hashlib
import os
import re

import yaml

TIERS_RE = re.compile(r"<!--\s*TIERS-BEGIN\s*-->\s*```yaml\s*(.*?)```", re.S)


def sha256_of(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(8192), b""):
            h.update(chunk)
    return h.hexdigest()


def load_tiers(charter_path):
    """从宪章 TIERS 块读取档位定义。
    返回列表 [dict(id, verified, label?, definition?, evidence_must_reference?)]。
    """
    text = open(charter_path, encoding="utf-8").read()
    m = TIERS_RE.search(text)
    if not m:
        raise ValueError("宪章中找不到 <!-- TIERS-BEGIN --> 档位定义块")
    data = yaml.safe_load(m.group(1))
    tiers = data.get("tiers") or []
    ids = [t.get("id") for t in tiers]
    if not ids or None in ids:
        raise ValueError("TIERS 块中存在缺少 id 的档位")
    if len(ids) != len(set(ids)):
        raise ValueError("档位 id 重复")
    for required in ("not_started", "blocked"):
        if required not in ids:
            raise ValueError("档位定义必须包含 %s" % required)
    return tiers


def load_decisions(path):
    """解析 DECISIONS.md。返回 {CR-id: (状态, 标题)}。"""
    out = {}
    if not os.path.exists(path):
        return out
    txt = open(path, encoding="utf-8").read()
    for block in re.split(r"(?m)^## ", txt)[1:]:
        lines = block.splitlines()
        title = lines[0].strip() if lines else ""
        cr = title.split()[0] if title else ""
        m = re.search(r"(?m)^状态:\s*(\S+)", block)
        if cr:
            out[cr] = (m.group(1) if m else "unknown", title)
    return out
