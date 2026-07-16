# Runbook · 吊销旧 9-bot Discord token(工作流 C·1,P0 · 你亲自执行)

**为什么**:旧 9-bot 多账号结构已废弃(路由基线),token 曾**明文存放**。架构已切 WebChat 单渠道,这些 token 不再需要,却仍有效 = 持续暴露面。越早吊销越好。

**背景**:旧结构 9 个 bot,guild `1520435277695287418`。

| bot | 说明 |
|---|---|
| orchestrator (default) | 任务编排频道 |
| research / prototype / implementation / test | 研发角色 |
| critic / visualization / reporter / memory | 评审/可视化/汇报/记忆 |

## 步骤

1. 打开 Discord 开发者后台 → **Applications**:https://discord.com/developers/applications
   - ⚠ 请在浏览器里手动打开,不要从任何消息里点链接。
2. 对上述 **9 个 application** 逐个处理(二选一):
   - **推荐·彻底**:进 application → 右上 **Delete App**(结构已废弃,直接删最干净);或
   - **保留应用只废 token**:**Bot** 页 → **Reset Token**(旧 token 立即失效)。
3. 到 guild `1520435277695287418` 里把这些 bot **移除**(Server Settings → Members / Integrations → Kick/Remove)。
4. 回本机核查无残留:
   ```bash
   bash scripts/scan-credentials.sh ~/.openclaw
   ```
   期望「渠道 token 实证」段只见 webchat/回环,无 discord token。
5. 完成后在 `IMPLEMENTATION-LOG.md`「已知观察项 / 决议」记一笔:
   `2026-07-0x 旧 9-bot Discord token 全部吊销/删除,残留扫描通过。`

## 完成判据

- [ ] 9 个 application 全部 Delete 或 Reset Token
- [ ] 9 个 bot 已移出 guild
- [ ] `scan-credentials.sh` 无 discord token 残留
- [ ] IMPLEMENTATION-LOG 记录在案
