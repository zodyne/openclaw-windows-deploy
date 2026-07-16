# v3 Stage 0 从零重建 — 手动步骤清单

> 2026-07-02 | 旧配置已完整备份于 `backups/openclaw-config-backup-20260702-112336.tar.gz`
> `~/.openclaw` 已清空并植入 Stage 0 脚手架(SOUL/AGENTS/HEARTBEAT/memory/governance/eval)

## 需要你本人执行(按顺序)

**1. 立即停掉 Gateway**(它还在运行,正往清空后的目录回写运行时文件)

```bash
openclaw gateway stop
```

停掉后告诉我,我会清掉它回写的残留(agents/、workspace-agents/、openclaw-weixin/ 等)并做 Git 初始提交。

**2. 确认/升级 OpenClaw 版本**(v3 基线要求 ≥ 2026.6.11)

```bash
openclaw --version && openclaw doctor
```

**3. 补齐模型配置**(✅ 主配置已由 Claude 生成并通过 9 项静态验证:回环监听、单 main agent、subagent 受限、渠道/插件/MCP/网搜全关、token 不入 Git)

```bash
openclaw doctor          # 先用安装版本校验生成的配置
openclaw models add      # 只需补:1 个主 provider + 1 个回退(凭据走环境变量)
```

如 doctor 报字段不兼容,以其提示为准修正(配置按 2026.6 版 schema 编写)。

**4. 接入 1 个 IM 渠道**(建议先只接你最常用的一个;9 个 Discord bot 的旧结构不恢复)

**5. 启动并验证**

```bash
openclaw gateway start && openclaw gateway status
```

验证三件事:发消息能回复;08:30 心跳出治理摘要(见 workspace/HEARTBEAT.md);让它做一个"高风险动作"(如让它发一条外部消息),确认它先写 `governance/approvals/queue.md` 而不是直接执行。

## 我已就位的部分(无需你动)

| 位置 | 内容 |
|---|---|
| `workspace/SOUL.md` | 人设 + 硬边界(高风险动作强制审批清单) |
| `workspace/AGENTS.md` | 治理规约:记忆 provenance 标签、审批流程、成本纪律、上下文纪律 |
| `workspace/HEARTBEAT.md` | 唯一心跳任务:每日治理摘要(控制 token 消耗) |
| `workspace/memory/` | 四个核心记忆块 + pending_review 缓冲区(空,带格式约定) |
| `governance/` | 审批队列/决议留痕/成本记录约定 |
| `eval/golden/` | 基准用例库结构 + 模板(Stage 2 开始积累) |

## 网络共存架构(2026-07-02 新增:VPN 与内网兼顾)

三层机制,自动协作,无需人工切换:

| 层 | 组件 | 职责 |
|---|---|---|
| 1 | NordVPN Local Network Discovery(设置里开启) | 常态放行局域网,首选路径 |
| 2 | LAN 路由守护(`ensure-lan-route.sh`,LaunchDaemon,root) | VPN 重连/开关抢占路由时,自动把 <your-subnet>/24 钉回有线接口;网络配置一变立即触发 |
| 3 | 模型路由切换器(`route-openclaw-model.cjs`,LaunchAgent) | 前两层都救不回时(如拔线),30 秒内把模型路由降级 GLM→GPT;恢复后自动升回 novasky |

安装(前两条 sudo,LaunchDaemon 需 root 权限执行 route 命令):

```bash
sudo cp ~/.openclaw/service-env/ai.openclaw.lan-route.plist /Library/LaunchDaemons/
sudo launchctl load /Library/LaunchDaemons/ai.openclaw.lan-route.plist
mkdir -p ~/Library/Logs/openclaw
cp ~/.openclaw/service-env/ai.openclaw.{model-route,novasky-proxy}.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/ai.openclaw.model-route.plist
launchctl load ~/Library/LaunchAgents/ai.openclaw.novasky-proxy.plist
```

验证:`log show --last 5m --predicate 'eventMessage contains "openclaw-lan-route"'` 看守护动作;`cat ~/.openclaw/state/model-route.json` 看当前模型路由态。若日志出现 "still unreachable - check NordVPN kill-switch",去 NordVPN 关闭 kill-switch 对局域网的拦截或开启 Local Network Discovery。

## Stage 0 完成标准(全部满足才进 Stage 1)

- [ ] Gateway 稳定运行 ≥ 3 天无重启
- [ ] 心跳治理摘要正常产出
- [ ] 审批流程实测有效(高风险动作被拦截进队列)
- [ ] 回环监听确认(`lsof -i -P | grep openclaw` 无 0.0.0.0)
- [ ] `~/.openclaw` Git 初始提交完成(我来做)
