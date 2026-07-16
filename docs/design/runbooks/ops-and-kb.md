# Runbook · 运行韧性(D)与知识库收尾(E)

## D · GLM 429 特征化与路由加固(P1)

**1. 特征化(先有数)**
```bash
python3 scripts/analyze-429.py <你的成本账本.jsonl>
# 字段对不上就 --model/--status/--err/--ts 指定
```
看输出的「按小时分布」定性:是全天配额型,还是白天速率型。

**2. 按数选策略**

| 观察 | 策略 |
|---|---|
| 429 占比 >20%、全天均匀 | 申请智谱**配额上调**;命中回退前加**退避节流**(见编码种子 `coding-retry-backoff`) |
| 429 集中在白天某几小时 | **时段重路由**:峰段不让 GLM 独扛主位(Provider Manifest 运行时切换,v3 §0#6) |
| 仅偶发 | 维持现状,回退链(glm→gpt)接管即可,只做可见化 |

> 关键前提:novasky 本地(有线可达)才是首选,GLM 仅在**有线断降级态**才是主模型——429 影响集中在降级态。所以先判断"降级态占比"值不值得动配额,还是干脆让降级态回退链(→gpt)更早介入。

**3. 可见化**:把 429/小时、降级驻留时长并入晨报成本/质量摘要(复用晨报心跳),不再只埋日志。

**4. 物理层误诊防护**:已由 `scripts/killswitch-probe.sh` 覆盖——LAN 与推理同时断时,它先提示查物理层(网卡/网线,AX88179A 教训)而非直接归因 VPN。把该探测挂进 Heartbeat 定时跑。

## E · 知识库收尾(P2)

**1. 终检**
```bash
bash scripts/kb-completeness-check.sh \
  ~/.openclaw/workspace/knowledge-base/vault \
  ~/Knowledge        # 第二个参数给旧源目录才做差集
```
全绿(文件数≈94、INDEX 在位、<your-project> 在位、差集为空)才进下一步。

**2. 旧目录处置决策(你拍板)**

迁移已验证生效,旧 `~/Knowledge` 与 Neovim 工具链目前物理保留。推荐:

| 对象 | 推荐 | 理由 |
|---|---|---|
| `~/Knowledge` 正本 | **冷备一份(离线)后删除正本** | 消除"新 vault vs 旧目录"双份真相源漂移;冷备留退路 |
| Neovim 工具链(`~/.config/nvim/lua/configs/knowledge_*.lua`、`kb_engine/`) | **单独决定,openclaw 不主动删** | 与检索已解耦;你若还用 Neovim 读旧笔记可留 |

终检有 ⚠ 或你未定,就**保持现状**(日志已写明 openclaw 不主动删),不强推。

**3. 维护纳规复核**:确认后续检索/写回一律走 openclaw memory 治理(provenance + pending_review),边界在 `AGENTS.md`「知识库集成」章节——做一次复核即可,无需改动。

**4. 记录**:处置决定(删/留)写进 `IMPLEMENTATION-LOG.md` 知识库迁移段落收尾。
