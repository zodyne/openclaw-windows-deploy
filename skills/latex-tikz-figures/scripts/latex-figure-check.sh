#!/bin/sh
# latex-figure-check — compile a LaTeX (xelatex) doc and surface the
# text-detectable failure signals that a vision-blind model cannot see by
# looking at the PDF. Optionally rasterize figure pages to PNG so a
# vision-capable agent (or human) can do the final "is it chaotic?" check.
#
# WHY THIS EXISTS: OpenClaw's models are text-only. They cannot look at a
# rendered figure to tell whether arrows cross, labels collide, or a node
# overflows. This script converts those visual failures into grep-able text:
# undefined glyphs, missing CJK chars, LR-mode errors, overfull boxes, and
# tikz "forgot a semicolon" errors are ALL detectable from the compile log
# without eyes. The remaining truly-visual checks are delegated via --render.
#
# Usage:
#   latex-figure-check <file.tex>              # compile x2, report signals
#   latex-figure-check --render <file.tex>     # + rasterize each page to PNG
#   latex-figure-check --render --pages 8-11 <file.tex>   # only these pages
#   latex-figure-check --overfull 20 <file.tex>           # overfull threshold pt (default 15)
#
# Exit code: 0 = clean (no hard errors), 1 = hard errors present, 2 = usage/tool error.

set -eu

OVERFULL_PT=15
RENDER=0
PAGES=""
TEX=""

usage() {
  sed -n '2,25p' "$0"
  exit 2
}

while [ $# -gt 0 ]; do
  case "$1" in
    --render)   RENDER=1; shift ;;
    --pages)    PAGES="${2:-}"; shift 2 ;;
    --overfull) OVERFULL_PT="${2:-15}"; shift 2 ;;
    -h|--help)  usage ;;
    -*)         echo "unknown flag: $1" >&2; usage ;;
    *)          TEX="$1"; shift ;;
  esac
done

[ -n "$TEX" ] || usage
[ -f "$TEX" ] || { echo "no such file: $TEX" >&2; exit 2; }
command -v xelatex >/dev/null 2>&1 || { echo "xelatex not found in PATH" >&2; exit 2; }

DIR=$(cd "$(dirname "$TEX")" && pwd)
BASE=$(basename "$TEX" .tex)
LOG="$DIR/$BASE.log"
PDF="$DIR/$BASE.pdf"

echo "== compiling $BASE (xelatex, 2 passes) =="
# Two passes so \tableofcontents / \label / \ref / cleveref resolve. Capture the
# 2nd-pass log; -interaction=nonstopmode keeps going so we see ALL errors, not
# just the first. We deliberately do NOT use -halt-on-error here.
( cd "$DIR" && xelatex -interaction=nonstopmode "$BASE.tex" >/dev/null 2>&1 ) || true
( cd "$DIR" && xelatex -interaction=nonstopmode "$BASE.tex" >/dev/null 2>&1 ) || true

[ -f "$LOG" ] || { echo "no log produced — compile aborted hard" >&2; exit 1; }

HARD=0

# --- Signal 1: undefined control sequences (bad icon name, stray macro,
#     \enspace etc. inside a hyperref pdfstring). This is a HARD failure —
#     it usually truncates the PDF at the offending page.
N_UNDEF=$(grep -c "Undefined control sequence" "$LOG" || true)
if [ "$N_UNDEF" -gt 0 ]; then
  HARD=1
  echo
  echo "!! [$N_UNDEF] Undefined control sequence — bad macro/icon name:"
  grep -A2 "Undefined control sequence" "$LOG" | grep -oE '\\[a-zA-Z@]+' | sort -u | head -20 | sed 's/^/     /'
fi

# --- Signal 2: font glyph missing. Two flavors:
#     (a) fontawesome "icon X was not found" — the icon name is wrong for the
#         installed fontawesome5 version.
#     (b) "Missing character: There is no <char>" — usually CJK that landed in a
#         monospace/verbatim context (\texttt, \path/\url) where the CJK fallback
#         font is not active. Renders BLANK — invisible unless you check the log.
N_ICON=$(grep -c "was not found" "$LOG" || true)
if [ "$N_ICON" -gt 0 ]; then
  HARD=1
  echo
  echo "!! [$N_ICON] icon/font not found:"
  grep "was not found" "$LOG" | sort -u | head -10 | sed 's/^/     /'
fi
N_MISS=$(grep -c "Missing character" "$LOG" || true)
if [ "$N_MISS" -gt 0 ]; then
  HARD=1
  echo
  printf '!! [%s] Missing character (renders BLANK — often CJK inside texttt / path / url):\n' "$N_MISS"
  grep "Missing character" "$LOG" | grep -oE "no . \(U\+[0-9A-Fa-f]+\) in font [^:]*" | sort | uniq -c | head -12 | sed 's/^/     /'
fi

# --- Signal 3: "Not allowed in LR mode" — a \\ line break inside a TikZ node
#     that lacks align=center / text width. Cascades into a pile of follow-on
#     errors, so catch it explicitly.
N_LR=$(grep -c "Not allowed in LR mode" "$LOG" || true)
if [ "$N_LR" -gt 0 ]; then
  HARD=1
  echo
  echo "!! [$N_LR] 'Not allowed in LR mode' — a TikZ node uses \\\\ but lacks align=center/text width."
fi

# --- Signal 4: tikz path errors (forgot a semicolon, bad coordinate).
N_TIKZ=$(grep -c "Package tikz Error\|Package pgf .* Error" "$LOG" || true)
if [ "$N_TIKZ" -gt 0 ]; then
  HARD=1
  echo
  echo "!! [$N_TIKZ] TikZ/PGF path error (often a missing semicolon):"
  grep "Package tikz Error\|Package pgf .* Error" "$LOG" | sort -u | head -6 | sed 's/^/     /'
fi

# --- Signal 5: any other LaTeX Error line not already covered.
N_LATEX=$(grep -c "^! LaTeX Error" "$LOG" || true)
if [ "$N_LATEX" -gt 0 ]; then
  # Only flag ones we haven't already surfaced via LR mode.
  OTHER=$(grep "^! LaTeX Error" "$LOG" | grep -v "Not allowed in LR mode" | sort -u | head -8 || true)
  if [ -n "$OTHER" ]; then
    HARD=1
    echo
    echo "!! other LaTeX errors:"
    echo "$OTHER" | sed 's/^/     /'
  fi
fi

# --- Signal 6: overfull boxes above threshold — a node/table overflowing its
#     box. NOT fatal, but a strong "layout is chaotic / text spills out" hint,
#     which is exactly what a text-only model cannot see. Report the worst few.
#     Portable: grep the pt magnitudes, filter by threshold in awk (2-arg only).
echo
echo "== overfull boxes > ${OVERFULL_PT}pt (layout overflow — text may spill) =="
OVER=$(grep -oE "Overfull \\\\[hv]box \([0-9.]+pt" "$LOG" \
         | sed -E 's/.*\(//; s/pt//' \
         | awk -v thr="$OVERFULL_PT" '$1+0>thr' | sort -rn | head -8 || true)
if [ -n "$OVER" ]; then
  echo "$OVER" | sed 's/^/   over by /; s/$/pt/'
else
  echo "   (none above threshold — good)"
fi

# --- Page count ---
PAGES_OUT=$(grep -oE "Output written on .* \([0-9]+ pages?" "$LOG" | grep -oE "[0-9]+ pages?" | head -1 || true)
echo
echo "== result: ${PAGES_OUT:-unknown page count} =="

# --- Optional: rasterize pages for a vision agent to inspect ---
if [ "$RENDER" -eq 1 ]; then
  [ -f "$PDF" ] || { echo "no PDF to render" >&2; exit 1; }
  command -v pdftoppm >/dev/null 2>&1 || { echo "pdftoppm not found (install poppler)" >&2; exit 2; }
  OUT="$DIR/${BASE}-figcheck"
  RANGE=""
  if [ -n "$PAGES" ]; then
    F=${PAGES%-*}; L=${PAGES#*-}
    RANGE="-f $F -l $L"
  fi
  echo
  echo "== rendering pages to PNG for vision review: ${OUT}-NN.png =="
  # shellcheck disable=SC2086
  ( cd "$DIR" && pdftoppm -png -r 110 $RANGE "$BASE.pdf" "${BASE}-figcheck" )
  ls "$DIR"/"${BASE}-figcheck"*.png 2>/dev/null | sed 's/^/   /'
  echo
  echo "NEXT: hand these PNGs to a VISION-capable agent (Claude Code, not a text-only"
  echo "OpenClaw model) and ask: 'Do any arrows cross nodes? Any labels overlapping a"
  echo "box or each other? Any node text spilling its border?' — that is the one check"
  echo "this script cannot do from the log."
fi

exit $HARD
