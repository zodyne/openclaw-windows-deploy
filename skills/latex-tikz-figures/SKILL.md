---
name: "latex-tikz-figures"
description: "Write and debug LaTeX/TikZ that compiles clean and renders readable figures — for text-only models that cannot see the PDF. Turns visual figure defects into grep-able compile signals, plus a render→vision-agent escape hatch."
triggers:
  - latex
  - tikz
  - xelatex
  - 编译 latex
  - 画图 latex
  - 流程图
  - 架构图
  - 图表混乱
  - figure chaotic
  - 生成 pdf 报告
---

# latex-tikz-figures

Produce correct LaTeX — especially TikZ diagrams — **when the model driving the
work has no vision** and cannot look at the rendered PDF. Every rule here comes
from a real failure fixed in this workspace, not theory.

## Hard rule (why this skill exists)

The models this system runs (`deepseek-v4-pro`, `glm-5.2`, `gpt-5.5`) are all
**text-only**. You cannot look at a figure to tell whether arrows cross nodes,
labels overlap, or text spills its box. So figure correctness must be reached
two ways, never by "looking":

1. **Detect from text.** Undefined glyphs, missing characters, LR-mode errors,
   overfull boxes, and tikz "forgot a semicolon" ALL appear in the `.log`. The
   bundled preflight greps them for you. Blank-rendering CJK and truncated PDFs
   are invisible in the output but loud in the log.
2. **Delegate the last mile.** The one check that truly needs eyes — "is it
   visually chaotic?" — must go to a **vision-capable agent**. This system's
   text-only models cannot do it; route rendered PNGs to Claude Code via ACP
   (`sessions_spawn runtime=acp`), or surface them to euly. Never claim a figure
   "looks clean" from a text-only model — you did not see it.

## Usage

Run the preflight after every figure edit:

```bash
skills/latex-tikz-figures/scripts/latex-figure-check.sh <file.tex>
skills/latex-tikz-figures/scripts/latex-figure-check.sh --render <file.tex>        # rasterize pages to PNG
skills/latex-tikz-figures/scripts/latex-figure-check.sh --render --pages 8-11 <file.tex>
```

Exit 0 = no hard errors. Exit 1 = hard errors (details printed). The `--render`
flag writes `<base>-figcheck-NN.png` per page — hand those to a vision agent.

## Compile blockers — the checklist (each bit us for real)

1. **fontawesome icon names drift by version.** `\faShieldAlt` is undefined in
   the installed fontawesome5 and **truncates the PDF** at that page ("Undefined
   control sequence"). Prefer stable names (`\faLock`, `\faCheckCircle`,
   `\faClock`, `\faInfoCircle`). Verify a new icon in a *written* test file, not
   a shell heredoc — heredocs eat `\f`.
2. **CJK inside `\texttt` / `\path` / `\url` renders BLANK.** `\path`/`\url`
   (and any `url`-backed `\sourcepath`) use monospace verbatim mode that bypasses
   xeCJK's CJK fallback → "Missing character … in font lmmono10". The Chinese
   silently vanishes. Fix: `\texttt{…}` handles CJK; or keep CJK out of verbatim
   path macros. (This exact bug hid 激活记录 in a filename.)
3. **`\\` in a TikZ node without `align=center`** → "Not allowed in LR mode",
   which cascades into many follow-on errors. Every multi-line node — including a
   standalone label node placed on a `\draw` — needs `align=center` or `text width`.
4. **A `\draw` missing its `;`** → "Package tikz Error: Giving up on this path.
   Did you forget a semicolon?" The reported line is the *end* of the picture;
   scan upward for the unterminated path.
5. **Fragile macros in captions/titles** (e.g. `\enspace`) break hyperref's
   PDF-bookmark expansion → "Undefined control sequence" at the caption. Keep
   captions plain; use ordinary punctuation, not spacing macros.
6. **Broken `literate=` in an unused listings style** maps chars to undefined
   control sequences. If `lstlisting` isn't used, delete the style block.

## Layout discipline — draw so you can reason, not so you must look

A text-only model must place nodes by **computable coordinates**, because it can
never discover the result by seeing it.

- **Use absolute coordinates (`\node (a) at (3,2){…}`), not relative
  positioning (`above right=of x`)**, for anything with feedback loops. You can
  reason about overlaps at fixed coordinates; you cannot with relative chains.
- **Route feedback/return arrows in the margins, never through the node field.**
  Exit to a clear coordinate beyond all nodes, run along the edge, come back:
  `(gov.south) -- ++(0,-0.7) -| (11.9,5) -- (main.east)`. Biggest single fix for
  arrow spaghetti.
- **Place edge labels on a deliberate coordinate** with `fill=white,
  align=center` (the white box masks the line beneath), not `node[pos=0.7]{…}`
  that lands wherever the arrow happens to pass.
- **Layered architecture → horizontal bands at fixed y**, main flow strictly
  vertical, the two feedback lines down the left and right outer edges. This was
  the exact fix that turned the unreadable L1–L6 topology into a legible diagram.
- **Stack parallel branches at distinct y-coordinates that then merge** — don't
  fan them with `above/below right`, which crams and overlaps them.
- Give nodes generous `text width`; an overfull hbox on a node = the log telling
  you text spilled the border.

## Iterating efficiently

- Compile `-interaction=nonstopmode` (NOT `-halt-on-error`) so one run shows all
  errors. Two passes resolve TOC/refs/cleveref (the preflight does both).
- Bisect a broken figure in a **standalone written .tex**, same packages — not a
  heredoc (control-char corruption).
- Clean `.aux .out .toc .log` when done; keep `.tex` + `.pdf`.

## Requirements

`xelatex` (TeX Live / MacTeX) on PATH; `pdftoppm` (poppler) for `--render`.
See the vault write-up: `knowledge-base/vault/System-Design/latex-tikz-figure-discipline.md`.
