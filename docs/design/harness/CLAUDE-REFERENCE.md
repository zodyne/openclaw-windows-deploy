# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this directory is

This is **not a software codebase** — there is no source code, build system, linter, or test suite here. This directory holds the architecture/planning documents and a config backup for **OpenClaw**, a personal AI-agent runtime the user operates. The actual live system it describes runs separately at `~/.openclaw` (its own git repo). There are no build/lint/test commands to run in this directory.

## Document map and how they relate

- **`openclaw-harness-v3-unified.md`** — the design/plan document (v3.0). It is an *upgrade proposal* written against two prior versions (v1.0 `openclaw-harness-system-design.md`, v2.0 `openclaw-harness-v2-distributed.md`) that are **not present in this directory** (they exist only as session-uploaded reference material). Treat this file as the aspirational architecture, not necessarily what's actually deployed — cross-check against IMPLEMENTATION-LOG.md for real status.
- **`IMPLEMENTATION-LOG.md`** — the **source of truth for current state**. Tracks which stages of the v3 roadmap are actually done (Stage 0-2 complete, Stage 3 paused by user decision, Stages 4-6 not started), real infrastructure decisions (network failover, model routing, channel setup), and key decisions/known issues. When the plan doc and the log disagree, the log wins.
- **`SETUP-CHECKLIST.md`** — one-time manual setup steps for the Stage 0 rebuild of `~/.openclaw`. Largely historical/already executed; useful for understanding what was done and why, and for re-running verification steps if the gateway needs to be rebuilt.
- **`backups/api-routing-baseline-20260702.md`** — a frozen snapshot of the **old, now-deprecated** architecture (9-bot Discord multi-account setup) taken right before the from-scratch v3 rebuild. Historical reference only; the current architecture is a single WebChat channel with one main agent.
- **`backups/openclaw-config-backup-20260702-112336.tar.gz`** — full backup of the pre-rebuild `~/.openclaw` config, **contains credentials**. Never commit this to a public remote, upload it to third-party tools, or extract/inspect it without a clear reason tied to a user request.

## Key architectural context (from the v3 plan)

The v3 design's throughline: prefer OpenClaw's native capabilities (TaskFlow orchestration, memory provenance tagging, signed skill manifests + eBPF enforcement, runtime-swappable model providers) over bespoke reimplementations, gate all self-evolution (skills/memory/workflows) behind an evaluation/regression layer before promotion, and grow the deployment through three stable topology stages (single-machine → state-externalized docker-compose → split services) rather than jumping straight to Kubernetes. A unified approval queue collects all high-risk-action confirmations into one channel rather than scattering them.

## Working in this directory

- Documents are written in Chinese; match that when editing them.
- Do not treat statements in the plan doc (`openclaw-harness-v3-unified.md`) as current fact — verify against `IMPLEMENTATION-LOG.md` or the live `~/.openclaw` config first.
- Never commit or transmit credentials from `backups/`.
