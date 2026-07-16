---
name: "read-image"
description: "Extract text from images via RapidOCR (offline, CPU, Chinese+English) — bypasses text-only model image blindness."
triggers:
  - read image
  - OCR
  - extract text from image
  - screenshot text
  - 读图
  - 识别图片文字
---

# read-image

Turns image files into plain **text** so a text-only model can read them.
Uses **RapidOCR** (PaddleOCR models in ONNX) — offline, on CPU, no API key —
and handles **Chinese + English** out of the box.

## Hard rule (why this skill exists)

Always return the OCR result as **text on stdout**. Never hand the raw image
back into the conversation as an attachment or image block: OpenClaw sanitizes
image payloads, and on a non-vision model they collapse into an omitted-content
placeholder (the `(see attached image)` pollution). This skill bypasses that
path — image in, text out.

## When to use

- A screenshot, scan, photo, or diagram-with-text needs to be read.
- Exec/tool output showed up as an image and you need the underlying text.
- You are on a text-only model and cannot see images directly.

## Usage

```bash
./read-image <image> [image...]          # loads the model once, OCRs all images
./read-image --out result.txt scan.png   # write to file, print a short preview
./read-image --min-score 0.5 noisy.png   # drop low-confidence lines
python3 read-image page.png              # if the file is not marked executable
```

## Options

- `-o, --out <file>` — write the full text to a file and print only a short
  preview (keeps the transcript small).
- `--min-score <0-1>` — drop recognized lines below this confidence (default 0).

## Efficiency note

The OCR model loads once per process. Pass **all images in one call**
(`./read-image a.png b.png c.png`) so a batch pays the model-load cost only
once — that keeps this skill as fast as a long-running server for batch jobs.
Only switch to an MCP server if you need frequent one-image-at-a-time calls
across a session (a warm process avoids reloading the model each time).

## Keep the transcript clean

For large results use `--out result.txt` (or redirect `> out.txt`) and then
read/grep the file, instead of dumping thousands of OCR'd lines back into the
conversation — the exact problem this skill is meant to avoid.

## Requirements

Python 3 + RapidOCR (recognition models are bundled in the wheel, fully offline):

```bash
pip install rapidocr-onnxruntime
# managed/system Python: pip install --break-system-packages rapidocr-onnxruntime
```

First call spends a few seconds initializing the model; further images in the
same call are fast. PDFs are not images — rasterize first
(`pdftoppm -png in.pdf page`), then OCR the resulting PNGs.
