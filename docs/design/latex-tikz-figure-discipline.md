# LaTeX / TikZ 图表纪律 —— 无视觉模型下的正确制图

> 来源：2026-07-08 优化 `openclaw_design_usage_20260708.tex` 的实战复盘。
> provenance：[observed] 全部规则来自本次真实编译失败与修复，非推测。
> 配套技能：`skills/latex-tikz-figures/`（含 `latex-figure-check.sh` 预检脚本）。

## 为什么这份经验重要

本系统模型（`deepseek-v4-pro` / `glm-5.2` / `gpt-5.5`）全部**纯文本、无视觉**。
制图时无法「看」渲染结果判断箭头是否穿节点、标签是否重叠、文字是否溢出。
本次能修好三张混乱图，是因为 **Claude Code（有视觉）渲染 PNG 后人眼核对**——
OpenClaw 自身 agent 做不到这一步。所以正确制图必须靠两条路，绝不靠「看」：

1. **从文本检测**：未定义字形、缺字、LR-mode、overfull、tikz 缺分号——全部落在
   `.log` 里，可 grep。空渲染 CJK 和被截断的 PDF 在输出里看不见，但在 log 里很吵。
2. **委派最后一公里**：唯一需要眼睛的「是否视觉混乱」检查，必须交给**有视觉的
   agent**（经 ACP 派发 Claude Code，或呈交用户）。纯文本模型不能声称「图看起来干净」。

## 六类编译阻断（每条都真实踩过）

| # | 症状 | 根因 | 修法 |
|---|---|---|---|
| 1 | `Undefined control sequence` 且 PDF 在该页截断 | fontawesome 图标名随版本漂移（`\faShieldAlt` 在本机 fontawesome5 不存在） | 用稳定名 `\faLock`/`\faCheckCircle`/`\faClock`/`\faInfoCircle`；新图标先在**写入的**测试文件里验证（勿用 heredoc，会吃掉 `\f`） |
| 2 | `Missing character … in font lmmono10`，中文**空白渲染** | CJK 落进 `\texttt`/`\path`/`\url`（`url` 支撑的 `\sourcepath`）的等宽 verbatim 模式，绕过 xeCJK 回退 | 含中文的路径用 `\texttt{…}`；或让 CJK 不进 verbatim 宏。本次 `激活记录` 文件名即因此隐形 |
| 3 | `Not allowed in LR mode`（并引发一连串后续错误） | TikZ 节点用了 `\\` 换行却缺 `align=center` | 每个多行节点（含挂在 `\draw` 上的独立标签节点）加 `align=center` 或 `text width` |
| 4 | `Package tikz Error: Giving up on this path. Did you forget a semicolon?` | 某条 `\draw` 漏了结尾 `;` | 报错行通常是图的**末尾**，向上扫找未结束的 path |
| 5 | 报错指向 caption 的 `Undefined control sequence` | caption/title 里的脆弱宏（如 `\enspace`）破坏 hyperref 书签字符串展开 | caption 保持纯文本，用普通标点，不用间距宏 |
| 6 | 无关的缺字 | 未使用的 `listings` 样式里 `literate=` 把字符映射到未定义控制序列 | 若没用 `lstlisting`，删掉整个样式块 |

## 布局纪律 —— 让「能推理」而非「必须看」

纯文本模型必须靠**可计算坐标**摆放节点，因为它永远无法靠看来发现结果。

- **有反馈环的图用绝对坐标 `\node (a) at (3,2){…}`，不用相对定位 `above right=of x`**。
  固定坐标能在脑中算重叠；相对链不能。
- **反馈/回流箭头走页边，绝不穿节点区**：出到所有节点之外的空坐标，沿边走，再回来：
  `(gov.south) -- ++(0,-0.7) -| (11.9,5) -- (main.east)`。这是「箭头面条」的头号修法。
- **边标签放在刻意选定的坐标**，配 `fill=white, align=center`（白底盖住线），
  不要用 `node[pos=0.7]{…}` 让它落在箭头恰好经过处。
- **分层架构 → 固定 y 的水平层带，主流严格竖直，两条反馈线走左右外缘**。
  这正是把混乱的 L1–L6 拓扑图变清晰的做法。
- **并列分支在不同 y 上竖直堆叠再汇合**，不要用 `above/below right` 扇出（会挤在一起重叠）。
- 节点给足 `text width`；节点上的 overfull hbox = log 在告诉你文字溢出了边框。

## 高效迭代

- `-interaction=nonstopmode`（**不用** `-halt-on-error`）让一次运行暴露全部错误。
  两遍编译解析 TOC/ref/cleveref。预检脚本已做两遍。
- 二分排查坏图：在**写入的**独立 .tex（相同宏包）里复现，不用 heredoc（控制字符污染）。
- 看图：`pdftoppm -png -r 110 -f <n> -l <n> doc.pdf out`，交有视觉的 agent 核对，
  明确问：「有箭头穿节点吗？标签重叠吗？文字溢出边框吗？」
- 收尾清理 `.aux .out .toc .log`，保留 `.tex` + `.pdf`。

## 预检脚本

`skills/latex-tikz-figures/scripts/latex-figure-check.sh <file.tex>`
两遍编译 + grep 上述 6 类信号 + overfull 阈值报告；`--render` 追加逐页 PNG 供视觉核对。
退出码 0=无硬错误，1=有硬错误。已对干净文档和注入故障的文档双向验证有效。

相关：本系统读图整体策略见 `[[read-image]]` 技能与 AGENTS.md「图片读取策略」。
