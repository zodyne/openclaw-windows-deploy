# GBrain Knowledge Workflow SOP

[imported 2026-07-08] Purpose: standardize how OpenClaw uses GBrain and `memory_search` together when maintaining the local knowledge base.

## Core Principle

[observed 2026-07-08] Use OpenClaw `memory_search` to locate facts and files quickly. Use GBrain when the task requires cross-file synthesis, relationship reasoning, or gap analysis.

GBrain should not replace source inspection. Treat it as the synthesis layer: it reads across pages, proposes an answer, and highlights missing knowledge. Important claims still need source verification before being used for code, project decisions, or durable memory updates.

## Write-Path & Lock Model (READ FIRST — prevents deadlock)

[observed 2026-07-08] GBrain runs on PGLite, a **single-writer** store: exactly one process may hold the DB file lock at a time. Two facts that a naive SOP gets wrong:

1. **A `gbrain serve` in stdio mode is point-to-point and private to the client that spawned it.** stdio serves exactly one client — the process that spawned it, over stdin/stdout. No other process can reach it.
2. **The old failure:** OpenClaw's main agent had NO gbrain MCP (`openclaw.json` → `mcp.servers: {}` empty), so its only path was the `gbrain` CLI — which opens the PGLite file directly and collides with whatever `serve` holds the lock → `Timed out waiting for PGLite lock` (exit 143). Meanwhile Claude Code spawned its own private stdio serve holding that lock. Two consumers, one lock, no shared server → deadlock. `gbrain link` retries 3× × 2s, so a 24-edge batch stalled minutes then failed every edge.

"serve running → use MCP" was **wrong for OpenClaw** in that world: it had no MCP client, and the CLI was locked out. The fix below removes the whole conflict.

### Live architecture — one shared HTTP serve (migrated 2026-07-08 ✅)

A **single persistent `gbrain serve --http` (launchd `ai.openclaw.gbrain-serve`, port 18795) is the ONE lock holder**; both consumers connect over HTTP MCP, so nothing spawns a competing serve:

```
launchd ai.openclaw.gbrain-serve → gbrain serve --http --port 18795   (only process touching PGLite)
   ├── OpenClaw main agent → openclaw.json mcp.servers.gbrain (streamable-http + bearer) → mcp__gbrain__*
   └── Claude Code         → ~/.claude.json user-scope http MCP (bearer)                 → mcp__gbrain__*
```

The rule is now uniform and correct for both:

> **All brain reads/writes go through MCP tools (`mcp__gbrain__*`) against the shared HTTP serve. NEVER shell out to a `gbrain` CLI command that touches the DB — it collides with the HTTP serve's lock exactly like the old stdio case.**

- Graph edge → `add_link` (one call/edge; instant). Page → `put_page`. Timeline → `add_timeline_entry`. Tag → `add_tag`. Verify → `get_links`/`get_backlinks`/`get_health`/`query`.
- The **job queue has no worker under PGLite** (`gbrain jobs work` is Postgres-only; observed job id 1 stuck `waiting`, 0 attempts). Do NOT `submit_job` and expect it to run. Build edges yourself with `add_link`.
- CLI batch (`import`/`embed`/`extract all`) is an **operator maintenance-window activity only**: stop the HTTP serve (`launchctl unload`) → run CLI → reload. Never while the serve is up.

### Rebuild runbook (operator — only if the shared serve is lost/reprovisioned)

Already done once on 2026-07-08; kept for disaster recovery. Because every CLI step touches the lock, mint the token in the window when NO serve holds it.

```bash
source ~/brain/gbrain-env.sh
# 0. No serve may hold the lock (close Claude Code sessions / unload launchd; verify empty):
pgrep -fl "gbrain serve"

# 1. Mint bearer token in the lock-free window (confirm flags: gbrain auth --help):
gbrain auth create openclaw-http            # → prints TOKEN

# 2. launchd runs wrapper ~/brain/gbrain-http.sh (source gbrain-env.sh; exec gbrain serve --http --port 18795).
#    Use a wrapper, NOT plist EnvironmentVariables — gbrain-env.sh's OPENAI_API_KEY is a $(python3 …)
#    command-substitution that launchd's env dict cannot run.
launchctl load ~/Library/LaunchAgents/ai.openclaw.gbrain-serve.plist
curl -fsS http://127.0.0.1:18795/health && echo OK    # note: /health, not /healthz

# 3. OpenClaw: openclaw.json → mcp.servers.gbrain = {url:".../mcp", transport:"streamable-http",
#    headers.Authorization:"Bearer <TOKEN>"}. Gateway hot-reloads (no restart needed).

# 4. Claude Code: claude mcp add gbrain -s user -t http http://127.0.0.1:18795/mcp -H 'Authorization: Bearer <TOKEN>'

# 5. Verify BOTH resolve mcp__gbrain__* and pgrep shows exactly one serve.
```

## Import Batch Scope Discipline (READ — prevents linking the wrong pages)

[observed 2026-07-08] Failure seen when OpenClaw ran this SOP autonomously: it added ~140 edges, but almost all landed on **already-connected old clusters**, while the pages it had just imported (`ti-radar-toolbox-4.00.00.05/*`, `sdk-reference/*`) stayed **orphaned with zero backlinks**, and it added **zero timeline entries**. Work was done, but not the work the import required.

Root cause: "build the graph" was read as "link the whole vault." It is not. The scope of every post-import link/timeline/verify action is **exactly the pages that were just imported — nothing else.**

Mandatory procedure after any import:

1. **Get the batch.** Read `get_ingest_log` (limit 1..3) and take the `pages_updated` array of the most recent entry. That list — call it `BATCH` — is the ONLY set you operate on.
2. **Every page in BATCH must end non-orphan.** For each slug in `BATCH`, it must have at least one inbound OR outbound edge when you finish. Index/overview pages link down to their children; each child links back up to its overview/index. Cross-link to existing related pages only as a bonus, never as a substitute.
3. **Every page in BATCH gets a timeline entry.** At minimum `add_timeline_entry <slug> <import-date> "imported"`. `timeline_coverage` staying at 0 means this step was skipped.
4. **Verify against BATCH, not against global health.** Do NOT declare success from `brain_score` or total edge count — those move even when the new batch is untouched (that is exactly how the failure hid). Loop over `BATCH` and assert `get_backlinks` (or `get_links`) is non-empty for each. Any empty one is unfinished work.

Rule of thumb: `orphan_pages` must **drop by roughly len(BATCH)** after your run. If it barely moved, you linked the wrong pages.

## Decision Table

> **Precondition for everything below:** the MCP rows assume the shared HTTP serve (see Write-Path & Lock Model) is reachable — migrated 2026-07-08, OpenClaw has `mcp.servers.gbrain` registered and `mcp__gbrain__*` resolves. If the serve is ever down / unregistered (`mcp__gbrain__*` fails), OpenClaw has NO brain write path — do NOT fall back to CLI (it deadlocks on the lock); stop and flag the operator to restore the serve (see rebuild runbook).

| Need | First Tool | Follow-up |
|---|---|---|
| Find a file, current status, preference, exact note | `memory_search` | `memory_get` or direct file read |
| Synthesize across many pages | `gbrain query` | verify cited source pages |
| Relationship among entities/modules/people | `gbrain graph` / `gbrain graph-query` | inspect linked pages |
| Read exact page by slug | `gbrain get <slug>` | update vault if stale |
| Add/update a page (shared HTTP serve up) | `mcp__gbrain__put_page` | then `add_link` + `add_timeline_entry` (see below) |
| Build graph edges (shared HTTP serve up) | `mcp__gbrain__add_link` (one call per edge) | verify with `get_links` / `get_backlinks` |
| Bulk import a whole dir | operator maintenance window: stop the HTTP serve (no lock holder) → CLI `import`/`embed`/`extract all` → restart | never run CLI DB commands while any serve holds the lock |
| New durable observed finding | write Markdown in vault with `[observed]` | HTTP serve up: `put_page` + `add_link` (MCP); else operator CLI batch |
| User-confirmed rule or decision | write with `[confirmed]` | `put_page` + `add_link` / `add_tag` (MCP) |
| GBrain reports a knowledge gap | fill with source-backed `[observed]` content, or put `[inferred]` in pending review | re-query |

## Standard Query Workflow

1. Search first with OpenClaw `memory_search` using project name + task keywords.
2. If only one file is relevant, read that file directly.
3. If multiple files or concepts are involved, ask GBrain with `gbrain query`.
4. For relation-heavy tasks, identify a concrete page/entity first, then use `gbrain graph` or `gbrain graph-query`.
5. Verify critical claims against source files or vault pages.
6. Write durable conclusions back to the vault with provenance tags.
7. Sync to GBrain. **Pick the path by the lock holder** (see Write-Path & Lock Model). Scope every action to the just-imported batch (see Import Batch Scope Discipline — get the batch from `get_ingest_log` first):
   - **shared HTTP serve up (normal OpenClaw path, post-migration)** → via `mcp__gbrain__*`, no lock contention. For **each slug in BATCH**:
     - `put_page` if the page content changed
     - `add_link` so the page is non-orphan — index→child and child→index within BATCH; cross-link to existing pages only as a bonus
     - `add_timeline_entry` with the import date
   - **operator maintenance window (serve stopped, no lock holder)** → CLI batch is fine and faster for bulk:
     ```bash
     gbrain import ~/.openclaw/workspace/knowledge-base/vault --no-embed
     gbrain embed --stale
     gbrain extract all          # parse wikilinks/timeline into graph edges
     gbrain check-backlinks fix  # backfill missing reciprocal links
     ```
     Then restart the HTTP serve.
   - **shared serve unreachable (`mcp__gbrain__*` fails)** → OpenClaw has no MCP write path; CLI would deadlock against the lock holder. Stop and flag the operator to restore the serve — do NOT fall back to CLI.
8. Validate with one OpenClaw `memory_search` query and one GBrain `query`/`search` (MCP) using unique terms.
9. Verify against BATCH, not global health (see Import Batch Scope Discipline step 4) — always via MCP against the shared serve:
   - loop every slug in BATCH: `get_backlinks`/`get_links` must be non-empty; any empty one is unfinished
   - `get_health` → `orphan_pages` should drop by ~len(BATCH); `timeline_coverage` should rise off 0. If neither moved, you linked the wrong pages.

## When To Use `gbrain search`

Use `gbrain search` when you want ranked candidate pages but do not need an answer yet.

Good examples:

- "Radar Toolbox TLV parser"
- "AWR2x44p DDM rangeproc"
- "<your-project> 暗室测角"

## When To Use `gbrain query`

Use `gbrain query` when the answer depends on multiple pages, comparisons, or gaps.

Good examples:

- "Radar Toolbox 和 mmWave SDK 在 UART/TLV 输出格式上如何分工？"
- "当前知识库里 <your-project> 暗室测角还有哪些缺口？"
- "AWR2x44p DDM 处理链路和普通 TDM 链路差异是什么？"

## When To Use Graph Queries

Use graph traversal only when the question is explicitly relational.

Good examples:

- "哪些页面连接到 <your-project>？"
- "这个模块依赖哪些 DPU/API？"
- "某个负责人/模块/算法和哪些项目相关？"

Do not run graph traversal for simple fact lookup.

## Write-back Rules

- `[observed]`: directly verified from files, command output, source code, docs, or user-visible evidence.
- `[confirmed]`: explicitly confirmed by the user.
- `[inferred]`: reasoning result. If it changes future behavior, write to `memory/pending_review.md` first.
- `[imported]`: imported from an external corpus or migrated source.

## Link Format Rule (critical — prevents orphan pages)

[observed 2026-07-08] Writing pages is not enough. A page with no inbound/outbound graph edges is an orphan and drags brain health down (`link_coverage`, `no_orphans_score`). Two failure modes seen in practice:

1. Bare relative filenames like `[Docs](docs-index.md)` do NOT resolve to a slug during `gbrain extract`. They stay dangling.
2. Remote MCP `put_page` does not auto-link; the backlinks job has no worker. Nothing builds edges unless you run `extract` or add links explicitly.

Rules when authoring vault Markdown:

- Link with wikilinks using the **full slug**, not a bare filename: `[[30-resources/ti-radar-toolbox-4.00.00.05/docs-index]]`, not `[docs-index.md]`. Bare filenames never resolve to edges.
- An index/overview page must link to every child it introduces; each child should link back to its overview.
- **Building the edges depends on the lock holder** (see Write-Path & Lock Model):
  - shared HTTP serve up (normal) → vault wikilinks alone do nothing until edges exist; add each edge with `mcp__gbrain__add_link` (there is no MCP `extract`, and `submit_job` has no worker).
  - operator maintenance window (serve stopped, no lock holder) → CLI `gbrain extract all` converts the wikilinks in one pass, then restart the serve.
- If writing through `put_page`, ALWAYS follow with explicit `add_link` / `add_timeline_entry` — `put_page` alone creates an orphan, and nothing else will link it.
- Add at least one `add_timeline_entry` (e.g. import date) to new pages so `timeline_coverage` does not stay at 0.

## Vendor Package Ingestion Rule

For large vendor packages, do not add the whole directory to `memorySearch.extraPaths` or GBrain directly when it contains binaries, generated files, images, PDFs, and build outputs.

Preferred pattern:

1. Scan package shape and file types.
2. Identify entry docs, API headers, examples, parsers, manifests, and tuning guides.
3. Create curated Markdown index pages in `knowledge-base/vault/`, linking child pages to their overview with full-slug wikilinks (see Link Format Rule).
4. Land them in the brain and build edges — path depends on which serve is the lock holder (see Write-Path & Lock Model). Scope to the just-imported batch (see Import Batch Scope Discipline):
   - shared HTTP serve up (normal OpenClaw path, post-migration) → via `mcp__gbrain__*`, for each page in the batch: `put_page`, then `add_link` (index↔child within the batch) + `add_timeline_entry`.
   - operator maintenance window (HTTP serve stopped, no other serve holding the lock) → CLI `import` → `embed --stale` → `extract all`, then restart the HTTP serve.
   - shared serve unreachable (`mcp__gbrain__*` fails) → OpenClaw has no MCP write path and CLI would deadlock against the lock holder; stop and flag the operator to restore the serve (see rebuild runbook).
5. Verify against the batch, not global totals: loop every imported slug and assert `get_backlinks`/`get_links` is non-empty. `orphan_pages` should **drop by ~len(batch)** — if it barely moved, you linked old pages instead of the new ones (the exact failure seen 2026-07-08).
6. Use GBrain `query` to decide the next high-value extraction batch.

## Visual Content Rule (text-only model — no image understanding)

[observed 2026-07-08] OpenClaw's main agent runs a **text-only LLM (no vision)**. Text/retrieval/query/graph work is unaffected (embeddings use local `bge-m3`, a text model). The one place it bites is **extracting knowledge from images** — and TI radar docs hide high-value content in figures: signal-chain block diagrams, DDM timing charts, antenna radiation patterns, DCA1000 wiring diagrams. A text model cannot see these; asked to summarize one, it will **hallucinate** a plausible-but-wrong description, which is worse than a gap because it poisons the brain.

Rule when ingesting any doc with visual content:

| Content | Text model can handle? | Action |
|---|---|---|
| PDF/HTML/source with a text layer | ✅ yes | extract text directly (`pdftotext`, program parse) — no vision needed |
| Figures, block/timing diagrams, radiation patterns, scanned-image PDFs | ❌ no | OCR, or **delegate to a vision-capable agent** (see the `latex-tikz-figures` / image-pipeline pattern in memory) to produce a description, then ingest that |
| Mixed PDF (text + key figures) | ⚠️ partial | extract the text; route each figure through the vision path separately |

Hard constraints:

- **NEVER let the text model write a description of a figure it cannot read.** If no vision agent / OCR result is available, ingest the surrounding text and mark the figure explicitly: `[figure not extracted — needs vision pass]`. A labeled gap is recoverable; a fabricated description is silent corruption.
- When a page's core knowledge IS the figure (e.g. a wiring diagram) and no vision pass ran, do NOT create a confident page — record it as a pending extraction target (like the DCA1000 handbook / tuning-guide figures already flagged) rather than a page that reads as complete.
- Tag pages that still await a vision pass so a later pass (or an operator on a vision-capable model) can find them.

## Maintenance Checks

Which set to run depends on the lock holder (see Write-Path & Lock Model), not on a generic "is a serve up" check.

**Shared HTTP serve up (normal, post-migration) — via `mcp__gbrain__*`, never CLI DB commands:**

- `openclaw memory status --index --agent main` (touches the OpenClaw index, not PGLite — safe)
- MCP `query` / `search` with a unique term from a new page
- MCP `get_health` and `get_backlinks` on a sample new page

**Operator maintenance window (HTTP serve stopped, no stdio serve holding the lock) — CLI batch:**

```bash
source ~/brain/gbrain-env.sh
pgrep -fl "gbrain serve"   # must be empty — no lock holder — before continuing
gbrain import ~/.openclaw/workspace/knowledge-base/vault --no-embed
gbrain embed --stale
gbrain extract all
gbrain check-backlinks fix
gbrain search "unique term from new page"
# then restart the HTTP serve (launchd: ai.openclaw.gbrain-serve)
```

Do NOT run any CLI DB command while a serve (stdio OR http) holds the lock — it wastes minutes on lock-wait retries then fails (a 24-edge `gbrain link` batch = 24 × 3 retries × 2s before every edge errors).

Known local configuration notes:

- GBrain uses PGLite (single-writer, file-locked) and Ollama `nomic-embed-text` in the current setup. Exactly one process may hold the DB lock.
- A `gbrain serve` (stdio OR http) holds the PGLite lock for its whole lifetime; any concurrent CLI DB access times out. The Minions job worker (`gbrain jobs work`) is Postgres-only, so submitted jobs never run under PGLite — build edges with `add_link`, not `submit_job`.
- **stdio serve is private to its spawning client.** Claude Code spawns its own via `~/brain/gbrain-mcp.sh`; no other process can reach that MCP. This is why a shared `gbrain serve --http` is required for OpenClaw to have any MCP access (see migration runbook).
- OpenClaw `memory_search` uses the built-in memory index over workspace memory and `knowledge-base/vault` — independent of GBrain/PGLite, always safe.
- As of 2026-07-08 OpenClaw `mcp.servers` is EMPTY — the main agent has no `mcp__gbrain__*`. Post-migration, both Claude Code and OpenClaw reach the shared HTTP serve's MCP; that is then the ONLY safe write path.
