---
name: "gbrain-knowledge-workflow"
description: "Use GBrain via mcp__gbrain__* MCP tools (shared HTTP serve), forbid CLI DB access"
---

# GBrain Knowledge Workflow

Use this skill when maintaining or querying the local knowledge base with OpenClaw `memory_search` and GBrain MCP tools.

## Architecture (READ FIRST)

GBrain runs on **PGLite (single-writer, file-locked)**. Exactly one process may hold the DB lock. The live architecture:

```
launchd ai.openclaw.gbrain-serve → gbrain serve --http --port 18795   (ONLY process touching PGLite)
   ├── OpenClaw main agent → openclaw.json mcp.servers.gbrain (streamable-http + bearer) → mcp__gbrain__*
   └── Claude Code         → ~/.claude.json user-scope http MCP (bearer)                 → mcp__gbrain__*
```

**Hard rule**: All brain reads/writes go through MCP tools (`mcp__gbrain__*`) against the shared HTTP serve. **NEVER shell out to a `gbrain` CLI command that touches the DB** — it collides with the HTTP serve's PGLite lock and will time out (exit 143). This includes `gbrain import`, `gbrain embed`, `gbrain extract`, `gbrain link`, `gbrain orphans`, `gbrain health`, `gbrain query`.

## Principle

Use `memory_search` to locate facts and files quickly. Use GBrain MCP when the task needs cross-file synthesis, relationship reasoning, or gap analysis.

## Workflow

1. Start with `memory_search` for project name plus task keywords.
2. If one file is relevant, read it directly with `memory_get` or file tools.
3. If multiple files/concepts are involved, use GBrain `query` for synthesis.
4. For relationship questions, identify a concrete page/entity, then use `traverse_graph` or `query` with `relational: true`.
5. Verify critical claims against source files or vault pages.
6. Write durable conclusions back to the vault Markdown with provenance tags.
7. Sync to GBrain — **ALWAYS via MCP tools, never CLI**:
   - `put_page` to create/update the page
   - `add_link` for EVERY edge (one call per edge) — `put_page` does NOT auto-link
   - `add_timeline_entry` for every new or updated page
   - `get_backlinks` to verify each page is non-orphan
8. Validate with one `memory_search` query and one GBrain `query` or `search` using unique terms.

## Critical Rules (violating these causes silent failure)

### NO CLI That Touches DB

`gbrain import`, `gbrain embed`, `gbrain extract`, `gbrain link` — all open the PGLite file directly and collide with the shared HTTP serve's lock. **Do NOT run these while the serve is up.** CLI batch is an operator maintenance-window activity only (`launchctl unload` → run CLI → reload).

### put_page Does NOT Auto-link

`put_page` returns `auto_links: "skipped remote"` — no edges are built. You MUST follow every `put_page` with explicit `add_link` calls. Without them, the page is an orphan and nothing will link it (PGLite has no job worker).

### Full-Slug Wikilinks Only

When writing vault Markdown, use the **full slug** in wikilinks: `[[system-design/gbrain-shared-http-serve-architecture]]`, NOT bare filenames like `[docs-index.md]`. Bare filenames never resolve to graph edges.

### Import Batch Scope Discipline

After any import, operate ONLY on the pages that were just imported (get them from `get_ingest_log` → `pages_updated` of the most recent entry). Do NOT link the whole vault. Each page in the batch must end non-orphan (verified with `get_backlinks`) and with a timeline entry.

### Visual Content Rule

OpenClaw's main agent is a **text-only LLM (no vision)**. When ingesting docs with figures, diagrams, or scanned PDFs:
- Extract text layers directly (no vision needed).
- For figures/diagrams: delegate to a vision-capable agent or OCR; **NEVER let the text model describe what it cannot see**.
- Mark unextracted figures explicitly: `[figure not extracted — needs vision pass]`.
- A labeled gap is recoverable; a fabricated description is silent corruption.

### No submit_job (PGLite Has No Worker)

The Minions job worker (`gbrain jobs work`) is Postgres-only. `submit_job` returns `waiting` forever with 0 attempts. Build edges yourself with `add_link`; do not expect background jobs to run.

## Tool Choice (MCP-only write path)

| Need | Tool |
|---|---|
| Find exact file/fact/status | `memory_search` |
| Read exact memory excerpt | `memory_get` |
| Cross-page synthesis | GBrain `query` |
| Ranked candidate pages | GBrain `search` |
| Entity/module/person relationships | GBrain `query` with `relational: true` or `traverse_graph` |
| Exact brain page | `get_page` |
| Create/update a page | `put_page` → then `add_link` + `add_timeline_entry` + `get_backlinks` verify |
| Build graph edge | `add_link` (one call per edge) |
| Add timeline entry | `add_timeline_entry` |
| Verify non-orphan | `get_backlinks` / `get_links` |
| Brain health | `get_health` + `find_orphans` |

## Provenance Rules

- `[observed]`: directly verified from files, tool output, docs, or code.
- `[confirmed]`: explicitly confirmed by euly.
- `[inferred]`: reasoning result; if it affects future behavior, write to `memory/pending_review.md` first.
- `[imported]`: imported from an external corpus or migrated source.

## Vendor Package Rule

For large vendor packages, do not ingest the whole directory if it includes binaries, generated files, images, PDFs, or build outputs. Instead:

1. Scan package shape and file types.
2. Identify entry docs, API headers, examples, parsers, manifests, and tuning guides.
3. Create curated Markdown index pages in `knowledge-base/vault/` with full-slug wikilinks.
4. Land them in the brain via `put_page` → `add_link` (index↔child within the batch) → `add_timeline_entry` → verify `get_backlinks` non-empty.
5. Use GBrain `query` to choose the next extraction batch.

## Do Not

- Do NOT run `gbrain import`, `gbrain embed`, `gbrain extract`, `gbrain link`, or any CLI that touches the PGLite DB while the shared serve holds the lock.
- Do NOT assume `put_page` creates edges — it does not. Always follow with explicit `add_link`.
- Do NOT use bare filenames in Markdown links — full slug wikilinks only.
- Do NOT link the whole vault after an import — operate only on the just-imported batch.
- Do NOT let the text model describe images it cannot see — mark them `[needs vision pass]`.
- Do NOT `submit_job` and expect it to run (PGLite has no job worker).
- Do NOT treat GBrain synthesis as source truth without checking citations for critical work.
- Do NOT write inferred operational rules directly into active memory.
- Do NOT run graph traversal for simple fact lookup.
- Do NOT feed huge vendor trees directly into graph or memory systems without curation.
