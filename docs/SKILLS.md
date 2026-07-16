# Skills & SOP 参考手册

本仓库预打包了 5 个技能包，覆盖工具、治理和知识管理三大类别。所有技能都是可选的——按需装配。

## 装配方式

```powershell
# 查看全部
.\install-skills.ps1 -List

# 按需安装
.\install-skills.ps1 -Install read-image,latex-tikz-figures

# 全部安装
.\install-skills.ps1 -All

# 覆盖更新
.\install-skills.ps1 -Install read-image -Force
```

装配后技能位于 `%USERPROFILE%\.openclaw\workspace\skills\<name>\`，OpenClaw Agent 在匹配触发词时自动加载。

---

## 工具类

### read-image

**用途：** 离线 OCR 图片文字提取

纯文本模型（GLM-5.2 / DeepSeek）无法直接处理图片。此技能通过 RapidOCR 将图片转为纯文字输出，完全离线、CPU 运行、中英文支持。

**依赖：** `pip install rapidocr-onnxruntime`

**用法：**
```bash
# 单张
python skills/read-image/read-image.py screenshot.png

# 批量（共享一次模型加载）
python skills/read-image/read-image.py a.png b.png c.png

# 大结果写入文件
python skills/read-image/read-image.py --out result.txt scan.png
```

**触发词：** 读图、OCR、识别图片文字、extract text from image、screenshot text

---

### latex-tikz-figures

**用途：** LaTeX/TikZ 编译检查与视觉缺陷检测

纯文本模型无法看到渲染后的 PDF。此技能将视觉问题（字体缺失、箭头交叉、标签溢出）转化为可 grep 的编译日志信号。

**依赖：** `xelatex`（TeX Live / MiKTeX）+ `pdftoppm`（poppler）

**用法：**
```bash
# 编译检查（两遍 xelatex + 信号检测）
bash skills/latex-tikz-figures/scripts/latex-figure-check.sh report.tex

# 编译 + 渲染 PNG（交由视觉模型/人眼做最终检查）
bash skills/latex-tikz-figures/scripts/latex-figure-check.sh --render report.tex

# 仅渲染指定页面
bash skills/latex-tikz-figures/scripts/latex-figure-check.sh --render --pages 8-11 report.tex
```

**检测信号：**
- Undefined control sequence（坏宏/图标名 → PDF 截断）
- Missing character（CJK 在 texttt/path 中渲染空白）
- Not allowed in LR mode（TikZ 节点缺 align=center）
- TikZ/PGF Error（缺分号等）
- Overfull boxes（文本溢出）

**触发词：** latex、tikz、xelatex、编译 latex、流程图、架构构图

---

## 治理类

### evidence-ledger

**用途：** 项目防漂移治理系统

为多会话工程项目建立证据驱动的状态追踪：
- **宪章哈希锁**：项目目标和验收标准锁定，agent 不可单方面修改
- **证据分档账本**：`not_started → compiled_only → verified_synthetic → verified_reference → verified_golden`
- **声明-证据绑定**：一切"完成"声明必须附可复跑命令 + 证据文件，脚本自动校验
- **换脑审计**：全新会话中独立审计，降级直接改账本

**适用场景：** 库移植、系统迁移、benchmark 复现、合规审计——任何声明需要被证伪的长期工程。

**依赖：** `pip install pyyaml`

**部署到项目：** 见 `skills/evidence-ledger/SKILL.md` 的 init / retrofit / audit 工作流。

**核心规则（R1-R8 摘要）：**
- R1: 每次会话先跑校验器，向用户复述档位和阻塞
- R2: 汇报只能粘贴脚本输出，不附加人工结论
- R3: 升级必须举证（跑验证 + 存证据 + 填命令）
- R5: 换数据源/方法/阈值 = 变更申请，不能静默执行
- R7: 长期记忆中不写结论性状态

### anti-drift-governance

**用途：** 五角色证据驱动治理

在 evidence-ledger 基础上增加**五角色审查环**：

```
部署者 ──→ 调查者 ──→ 复核者 ──→ 汇报者
              │                      │
              └──── 审计者 ←─────────┘
                    （每次新会话）
```

每个角色独立视角、独立判据、交叉验证。同一 agent 执行全部角色，但每次只带一个角色的方法论。

**与 evidence-ledger 的关系：** 互补。evidence-ledger 是通用框架（档位阶梯、证据校验器、宪章模板），anti-drift-governance 增加了多角色审查流程和更丰富的部署工作流。可单独使用或组合使用。

---

## 知识管理类

### gbrain-knowledge-workflow

**用途：** 知识图谱维护和查询的标准操作流程

定义了通过 GBrain MCP 工具（`mcp__gbrain__*`）操作知识库的标准方式：
- 双引擎分工（memory_search 精确查找 → GBrain 综合推理）
- 写入纪律（put_page 不自动建边，必须手动 add_link）
- provenance 标记规则（observed / confirmed / inferred / imported）
- CLI 禁令（PGLite 单写锁，禁止 CLI 直连 DB）
- 视觉内容规则（纯文本模型不描述看不到的图片）

**前提条件：** 需要部署 GBrain MCP 服务（PGLite + nomic-embed-text）。

**适用场景：** 已部署 GBrain 或类似知识图谱系统，需要标准化操作流程的团队。

---

## 技能开发

如需开发自定义技能，参考 OpenClaw 官方文档：
- [Skill Workshop](https://docs.openclaw.ai/skills/workshop)
- [Skill Creator](https://docs.openclaw.ai/skills/creator)

技能的基本结构：
```
my-skill/
├── SKILL.md          # 技能定义（YAML frontmatter + Markdown 正文）
├── scripts/          # 可选：脚本工具
├── templates/        # 可选：模板文件
└── references/       # 可选：参考文档
```

SKILL.md 的 YAML frontmatter：
```yaml
---
name: "my-skill"
description: "一句话描述技能用途"
triggers:
  - 触发词1
  - 触发词2
---
```
