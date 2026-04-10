# Global Claude Code Configuration

## Workflow Orchestration

### 1. Plan Mode Default
- Enter plan mode for ANY non-trivial task (3+ steps or architectural decisions)
- Use **ultrathinking** in plan mode -- extended reasoning before committing to any approach
- Log intent to `docs/plan.md` before implementation begins (pre-hook, append newest at top)
- If something goes sideways, STOP and re-plan immediately -- don't keep pushing
- Use plan mode for verification steps, not just building
- Write detailed specs upfront to reduce ambiguity

### 2. Subagent Strategy
- **Always parallelise** -- spawn subagents simultaneously wherever tasks are independent
- **Batch independent tool calls** -- never make sequential tool calls when results are not interdependent; fire all independent reads, searches, and fetches in a single message
- **Batch Bash commands** -- combine independent shell commands into a single Bash call using `&&` or `;`; never make sequential Bash calls when they can run together
- Use subagents liberally to keep main context window clean; one task per subagent
- Offload research, exploration, and parallel analysis to subagents
- For complex problems, throw more compute at it via subagents
- One task per subagent for focused execution
- **AIDLC in every subagent**: Every implementer subagent prompt MUST include: "After completing your task: (1) write a task-complete entry to `tasks/tracker.md` using the aidlc-tracking skill format; (2) mark the corresponding checklist item in `docs/plan.md` as `[x]`; (3) if you discovered a new pattern or fixed a bug, prepend a lesson to `tasks/lessons.md`."
- **Parent AIDLC responsibility**: After each subagent completes, the parent agent must verify the tracker/plan entries were written and fill any gaps manually

### 3. External Integration Research
- For ANY external third-party system (APIs, SDKs, cloud services, auth providers):
  spawn a dedicated subagent to fetch live documentation via Context7 FIRST
- Never rely on training data for external APIs -- they change frequently
- This does NOT apply to internal microservices -- use the codebase directly

### 4. Codebase Awareness
- Before touching an unfamiliar codebase: run `npx gitnexus analyze` to build the graph
- Use gitnexus impact and context tools to trace dependencies before any edit
- Read sub-module CLAUDE.md files before working in any sub-directory; create them progressively as you explore
- Run `/init-repo` once per project to scaffold everything at once

### 5. Self-Improvement Loop
- After ANY correction from the user: update `tasks/lessons.md` with the pattern
- Write rules for yourself that prevent the same mistake
- Ruthlessly iterate on these lessons until mistake rate drops
- Review lessons at session start for relevant project

### 6. Verification Before Done
- Never mark a task complete without proving it works
- Diff behavior between main and your changes when relevant
- Ask yourself: "Would a staff engineer approve this?"
- Run tests, check logs, demonstrate correctness

### 7. Demand Elegance (Balanced)
- For non-trivial changes: pause and ask "is there a more elegant way?"
- If a fix feels hacky: "Knowing everything I know now, implement the elegant solution"
- Skip this for simple, obvious fixes -- don't over-engineer
- Challenge your own work before presenting it

### 8. Autonomous Bug Fixing
- When given a bug report: just fix it -- point at logs, errors, failing tests and resolve them
- Don't ask for hand-holding; go fix failing CI tests without being told how

### 9. Progressive Discovery (Token Budget)
- Load only what you need, when you need it -- never pre-load entire codebases
- Read sub-module CLAUDE.md summaries before opening source files
- Use gitnexus `ctx_search` before reaching for Read or Grep -- returns summarized context, not raw file dumps
- For Grep: use `output_mode: "files_with_matches"` first (paths only), then targeted reads; always set `head_limit` to cap results -- raw Grep on a popular pattern can dump 10-50K tokens
- Prefer targeted reads with `offset`/`limit` over whole-file reads
- Ask: "what is the minimum context needed to answer this correctly?"
- Before starting any task, run `/context` and note the exact token count
- If context usage exceeds 50%, spawn a fresh subagent rather than continuing in the main session
- If context usage exceeds 70%, run `/log-context` then `/compact` immediately before proceeding

### 10. First-Principles Debugging
- Before jumping to a fix, **name the mechanism**: how is this feature actually supposed to work end-to-end? (e.g. "skills are filesystem-discovered from `~/.claude/skills/` at startup")
- **Enumerate all assumptions** and verify each one independently — never assume something is installed, sourced, or running
- **Build a gap inventory**: what exists vs. what should exist? A missing thing is different from a misconfigured thing
- **Follow the data path**: trace the signal from source → installer → destination → consumer; find exactly where it breaks
- **Distinguish by-design from broken**: routing to a secondary location by design is not a bug — activation of that location is the fix
- **Never fix symptoms** — find the root node in the causal chain; fixing downstream effects wastes time
- **Verify the fix closes the gap**: after any fix, re-check the original mechanism to confirm the signal now flows end-to-end
- Apply this to new tasks too: before implementing, reason through "what must be true for this to work?" and validate each precondition

## Task Management

1. **Plan First**: Write plan to `tasks/todo.md` with checkable items
2. **Log to docs/plan.md**: Append intent and tradeoffs before implementation (pre-hook)
3. **Verify Plan**: Check in before starting implementation
4. **Track Progress**: Mark items complete as you go in `tasks/todo.md`
5. **Explain Changes**: High-level summary at each step
6. **Log to audit/changelog.md**: Append what changed after implementation (post-hook)
7. **Log to tasks/tracker.md**: Append task completion entry after each task (post-hook)
8. **Capture Lessons**: Update `tasks/lessons.md` after corrections

## Tracking Discipline

All tracking files live inside the repo -- never in a global location.
Create at repo root on first use. Before writing to any tracking file, load the
corresponding format from the `aidlc-tracking` skill (`formats/<file>.md`) — never invent formats.

| File | Purpose | Write rule | Format file |
|------|---------|------------|-------------|
| `docs/plan.md` | Architectural intent, written **before** implementation | Append newest at top | `aidlc-tracking/formats/plan.md` |
| `tasks/todo.md` | Live execution tracking **during** a session | Rewrite as work evolves | `aidlc-tracking/formats/todo.md` |
| `tasks/tracker.md` | Append-only log of every task + pre-compact snapshots | Append newest at top | `aidlc-tracking/formats/tracker.md` |
| `tasks/lessons.md` | Per-repo learning log, one entry per lesson | Append newest at top | `aidlc-tracking/formats/lessons.md` |
| `audit/changelog.md` | What changed in the codebase, written **after** implementation | Append newest at top | `aidlc-tracking/formats/changelog.md` |
| `docs/design-review.md` | Council review output from `/design-review` | Append newest at top | `aidlc-tracking/formats/design-review.md` |

> Every tracking entry MUST include `**Session:** $CLAUDE_SESSION_ID`. When writing a `tracker.md` or `changelog.md` entry after an implementation task, include a `**Key change:**` block with the most significant diff or function signature (max 20 lines).

### Repo-First Rule (no exceptions)

All plan, todo, tracker, changelog, and lesson files MUST be written inside the active
repo (`$PWD`), never to `~/.claude/` or any global path.

- `docs/plan.md` — not `~/.claude/plans/*.md`
- `tasks/todo.md` — not `~/.claude/todos/*.md`
- `tasks/tracker.md` — not any global location

The plan-mode tool creates `~/.claude/plans/<name>.md` as a system default for the
approval workflow — this is acceptable. Once approved and implementation begins, write
the working plan to `docs/plan.md` in the repo and keep `~/.claude/plans/` as the
approval artifact only.

## Pre-Compact Rule

Before running or suggesting `/compact`, run `/log-context` first to write a snapshot to `tasks/tracker.md`. When context auto-compaction is imminent (≥70%), always run `/log-context` first.

## Compaction Instructions

When compacting (manual or auto), **preserve**:
1. The active task name and exact current step
2. Every file path modified or created this session
3. Key architectural decisions and the reasoning behind them
4. The precise next action to take
5. Any blocking issues or open questions

**Discard:** exploratory reads that led nowhere, failed attempts, verbose tool output no longer needed, and repetitive explanations.

## Core Principles

- **R-P-I (Reason, Plan, Implement)**: Before acting on anything non-trivial, reason through it first, write a plan, then implement. Never skip to implementation. Apply this to every decision, not just code.
- **Simplicity First**: Make every change as simple as possible. Impact minimal code.
- **No Laziness**: Find root causes. No temporary fixes. Senior developer standards.
- **Minimal Impact**: Changes should only touch what's necessary. Avoid introducing bugs.
- **Security Mindset**: Flag potential security issues. Never hardcode credentials.
