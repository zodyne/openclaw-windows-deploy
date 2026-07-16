# 证据档位阶梯设计判例库

## 设计规则
1. verified 档 3–5 个为宜，按置信度从高到低排列；每档给可操作定义
   （和什么比、怎么算通过），不写形容词。
2. 能填 evidence_must_reference 的都填：它是防稀释的机器执行点——该档证据链
   里必须出现的路径片段（如金标数据目录名）。填不了的档位，稀释只能靠
   审计兜底。
3. 必含 not_started 与 blocked；blocked 是"做不动时的合法出口"，没有它，
   agent 只剩静默顶替一条路。
4. 阶梯定稿必须以 CR-000 让用户签字（校验器强制）；阶梯设计是稀释被预防
   还是被固化的分水岭。
5. 顶层档位命名独占项目里的荣誉词（如"Golden"），宪章写明该词只指这一档。

## 判例 1：移植/迁移类（硬件金标）
```yaml
tiers:
  - id: verified_hw_log
    verified: true
    label: Golden(硬件日志)验证
    definition: 与 testlogs/ 硬件运行日志逐值对比，容差见已批准 CR
    evidence_must_reference: ["testlogs/"]
  - id: verified_vendor_testdata
    verified: true
    label: 厂商测试数据验证
    definition: 与 unit_test/testdata/ 下厂商 .bin 参考数据对比
    evidence_must_reference: ["testdata/"]
  - id: verified_synthetic
    verified: true
    label: 合成数据验证
    definition: 与本项目自生成参考数据对比
  - id: compiled_only
    verified: false
    label: 仅编译通过
  - id: not_started
    verified: false
  - id: blocked
    verified: false
```

## 判例 2：数据管道类
verified_prod_snapshot（对生产快照回放，must_reference: ["snapshots/prod"]）
> verified_staging_sample > verified_unit_fixture > runs_locally
> not_started / blocked

## 判例 3：文档 / 合规类
reviewed_by_owner（责任人签字记录为证据）> cross_checked_secondary_source
> self_reviewed > drafted > not_started / blocked

## 判例 4：benchmark 复现类
matched_paper_numbers（与论文表格数值对比，must_reference: ["paper_tables/"]）
> matched_within_tolerance > runs_end_to_end > env_ready
> not_started / blocked
