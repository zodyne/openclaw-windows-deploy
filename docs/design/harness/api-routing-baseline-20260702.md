# API 路由配置基线快照(历史存档)

> ⚠️ 2026-07-02 更新:本基线对应的旧架构已于当日整体废弃重建(从零构建 v3 Stage 0)。本文档降级为历史存档:9-bot Discord 多账号结构确认废弃,新架构为 WebChat 单渠道 + 单 main agent;模型路由(gpt-5.5 主 / glm-5.2 回退)在新配置中延续。旧 Discord bot token 曾明文存放且已随架构废弃,**建议前往 Discord 开发者后台吊销**。

> 快照时间:2026-07-02 11:23
> 来源:`~/.openclaw/openclaw.json`(未做任何修改,仅记录现状)
> 对应决议:v3.0 设计基线冻结 —— 本快照为实施期间路由配置的「保持现状」凭据
> **路由段指纹(models+bindings+agents 的 SHA256)**:
> `de4f29efcaded7a6ea28bb5a5f9d9f57671afb00c993043e514ec64c628a0c07`

## 1. 模型提供方(3 个,mode: replace)

| Provider | 端点 | 模型 | 说明 |
|---|---|---|---|
| `openai` | `https://api-cdn.owlai.tech`(openai-responses) | GPT-5.5(1M ctx / 128K out,支持图文) | **默认主模型** |
| `zai` | `https://open.bigmodel.cn/api/coding/paas/v4` | GLM-5.2(1M ctx,reasoning) | **默认回退模型** |
| `novasky` | `http://127.0.0.1:18790/v1`(本地有线局域网) | DeepSeek V4 Pro | 本地推理节点,经 `service-env/novasky-wired-proxy.cjs` 代理 |

API Key 类字段已从本快照中剔除,凭据仍在原配置/环境变量中,未入 Git。

## 2. Agent 模型路由

全部 10 个 agent(main/orchestrator/research/prototype/implementation/test/critic/visualization/reporter/memory)的 `model` 均为 `null`,**统一继承 defaults**:

```json
{ "primary": "openai/gpt-5.5", "fallbacks": ["zai/glm-5.2"] }
```

各 agent 独立 workspace(`workspace-agents/<id>`),main 使用 `~/.openclaw/workspace`。

## 3. 渠道绑定(9 条,均为 Discord,guild 1520435277695287418)

| Agent | Discord 账号 | 备注 |
|---|---|---|
| orchestrator | default | 任务编排频道 1520435278206996533 |
| research | research | @Research bot |
| prototype | proto | @Prototype bot |
| implementation | implementation | @Implementation bot |
| test | test | @Test bot |
| critic | critic | @Critic bot |
| visualization | visualization | @Visualization bot |
| reporter | reporter | @Reporter bot |
| memory | memory | @Memory bot |

## 4. 相关外围文件(已随配置备份归档)

- `service-env/ai.openclaw.model-route.plist` + `route-openclaw-model.cjs`(模型路由服务)
- `service-env/novasky-wired-proxy.cjs`(本地模型代理)
- `openclaw.json.last-good`(与当前 openclaw.json 同步,2026-07-02 11:05)

## 5. 漂移检测

实施期间任何阶段可用以下命令校验路由是否仍与基线一致(输出应等于上方指纹):

```bash
python3 -c "
import json, hashlib
d=json.load(open('%USERPROFILE%\.openclaw/openclaw.json'))
r={k:d[k] for k in ('models','bindings','agents') if k in d}
print(hashlib.sha256(json.dumps(r,sort_keys=True,ensure_ascii=False).encode()).hexdigest())
"
```

指纹不一致 = 路由发生变更,应先核对变更记录再继续实施。

## 6. 配套完整备份

- 归档:`backups/openclaw-config-backup-20260702-112336.tar.gz`(21MB,1201 个条目)
- SHA256:`ba345e5097e44205fcfbb935e55014768aea9046e87950a339647dc9b994422f`
- 包含:openclaw.json 及全部历史 .bak、SOUL/AGENTS/HEARTBEAT/TOOLS/MEMORY.md、10 个 agent 配置与记忆(不含 sessions 会话历史)、plugin-skills、extensions、service-env、credentials/identity/devices、exec-approvals
- 排除(可再生/运行时):agents/*/sessions、npm、cache、tmp、media、logs、internal-agent-runs、completions、Agent_Exploration、state、system_monitor.db、workspace/build、memory.db
- ⚠️ 归档内含 credentials/ 凭据目录:该备份文件请勿上传云端或提交 Git

恢复方式:`tar -xzf openclaw-config-backup-20260702-112336.tar.gz -C ~/ --strip-components=0`(解包出 `.openclaw/`,按需覆盖)
