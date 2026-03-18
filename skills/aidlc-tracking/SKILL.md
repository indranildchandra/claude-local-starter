---
name: aidlc-tracking
description: AI Driven Development Lifecycle tracking — canonical formats for all project tracking files. Invoke before writing to any tracking file or before compaction.
disable-model-invocation: true
---

# AIDLC Tracking

## When to invoke this skill

- **Before writing to any tracking file** — load `formats.md` to get the exact template
- **Before running or suggesting `/compact`** — write a pre-compact snapshot first
- **When auto-compaction is detected** — immediately write a pre-compact snapshot to `tasks/tracker.md`
- **On `/init-repo`** — use formats to scaffold all tracking files; also run `npx gitnexus analyze`

## Tracking files and their purpose

| File | Purpose | Write rule |
|------|---------|------------|
| `docs/plan.md` | Architectural intent, before implementation | Append newest at TOP |
| `tasks/todo.md` | Live execution tracking during a session | Rewrite as work evolves |
| `tasks/tracker.md` | Append-only log of every task + session snapshot | Append newest at TOP |
| `audit/changelog.md` | What changed in the codebase, after implementation | Append newest at TOP |
| `docs/design-review.md` | Council review output from `/design-review` | Append newest at TOP |
| `tasks/lessons.md` | Per-repo learning log, one entry per lesson learned | Append newest at TOP |

## Core rules

1. **Never invent formats** — always load `formats.md` from this skill before creating or appending to a tracking file
2. **All files are per-repo** — never write tracking files to a global location
3. **Create on first use** — if a tracking file doesn't exist, create it with the header from `formats.md` before appending
4. **Append-only files are never edited** — tracker, plan, changelog, lessons are append-only; only todo is rewritten
5. **Timestamps always use** `YYYY-MM-DD HH:MM:SS` format

## Pre-compact protocol

Before running `/compact` or when context auto-compaction is imminent:
1. Invoke `/log-context` to write a pre-compact snapshot to `tasks/tracker.md`
2. The snapshot must capture enough detail for a cold-start in the next session
3. Then proceed with compaction

## Gitnexus integration

- On `init-repo`: run `npx gitnexus analyze` to build the initial code knowledge graph
- After major refactoring sessions: re-run `npx gitnexus analyze` to refresh the graph
- Use gitnexus context tools (`ctx_search`, impact analysis) before editing files in unfamiliar modules
- The gitnexus graph supplements but does not replace reading CLAUDE.md files

## Formats reference

Load **only the format file you need** — do not load all formats at once:

| Writing to | Load this file |
|------------|---------------|
| `tasks/tracker.md` | `aidlc-tracking/formats/tracker.md` |
| `tasks/todo.md` | `aidlc-tracking/formats/todo.md` |
| `tasks/lessons.md` | `aidlc-tracking/formats/lessons.md` |
| `docs/plan.md` | `aidlc-tracking/formats/plan.md` |
| `audit/changelog.md` | `aidlc-tracking/formats/changelog.md` |
| `docs/design-review.md` | `aidlc-tracking/formats/design-review.md` |

`formats.md` is kept as a combined reference for humans — use the individual files above in code.
