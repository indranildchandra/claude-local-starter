# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

> **Note:** `install.sh` copies `claude-md-master/CLAUDE.md` to `~/.claude/CLAUDE.md` on every run (always overwrites). The "Global Claude Code Configuration" section below is kept in sync manually — edit `claude-md-master/CLAUDE.md` to change what gets installed globally.

## Repository Overview

`claude-local-starter` is a single-script bootstrap installer that replicates a full Claude Code environment onto any machine. It is not a library or application — the primary deliverable is `install.sh`.

### Key Files

| File | Purpose |
|------|---------|
| `install.sh` | The installer — idempotent, safe to re-run |
| `scripts/limit-watchdog.sh` | Stop hook: detects Anthropic limits, writes override + epoch reset-time file (no launchd) |
| `scripts/switch-to-anthropic.sh` | Full restore: 3-path key recovery (backup file → Linux `.credentials` → macOS Keychain), cleans all sentinel files, desktop notification |
| `scripts/switch-to-ollama.sh` | Manually activate Ollama routing: health check → model picker → write override + reset-time + `.ollama-manual` flag |
| `scripts/aidlc-guard.sh` | Stop hook: enforces AIDLC tracking discipline (non-fatal) |
| `scripts/claudeignore-guard.sh` | PreToolUse hook: blocks Read/Edit/Write on patterns in `.claudeignore` files |
| `scripts/setup-ollama.sh` | Installs Ollama and pulls models — run once per machine |
| `scripts/token-audit.sh` | Snapshot + restore extension states for token cost measurement |
| `scripts/enable-safe-yolo.sh` | Add auto-approve permissions + `auto` mode to a repo |
| `scripts/disable-safe-yolo.sh` | Remove safe-yolo permissions from a repo |
| `scripts/config/claude-safe-yolo-permissions.txt` | Single source of truth for safe-yolo allow/deny/defaultMode |
| `ollama.conf` | Template config for Ollama routing — deployed to `~/.claude/ollama.conf` on first install |
| `claude-md-master/CLAUDE.md` | Source of truth for `~/.claude/CLAUDE.md` — always overwrites on install |
| `settings.json` | Source of truth for plugins, env vars, MCP servers, hooks — merged into `~/.claude/settings.json` |
| `commands/` | Slash command definitions synced to `~/.claude/commands/` |
| `skills/` | Custom skill directories synced to `~/.claude/skills/` |
| `claude-local-starter.html` | Visual dashboard — open from `~/.claude/` after install (data is injected there) |
| `OLLAMA-SETUP-GUIDE.md` | Model comparison, prerequisites, and Ollama setup reference |
| `LOCAL-MODEL-SWITCHOVER-DESIGN.md` | Architecture reference + full sequence diagrams for the switchover system |

### Installer Modes

```bash
bash install.sh                  # safe update — merges, never overwrites
bash install.sh --clean-install  # full overwrite from repo (backs up first)
bash install.sh --dry-run        # preview all actions, no changes written
```

### What install.sh Does (in order)

1. Pre-flight checks (git, node, npm, python3, bun)
2. Interactive prompts — preserve CLAUDE.md? preserve MCP/plugin/skill states? (update mode only)
3. Backup mutable components (only on `--clean-install`)
4. Create `~/.claude/` directory structure
5. Install/merge `settings.json`
6. Install `CLAUDE.md` from `claude-md-master/` (always overwrites)
7. Install skills via `npx skills add` (patched with `disable-model-invocation: true`)
8. Clone/update `blader/humanizer` skill
9. Install `uipro-cli` globally
10. Install LSP binaries (typescript-language-server, pyright, gopls, rust-analyzer, jdtls) — pyright-lsp and typescript-lsp enabled by default; others installed but disabled
11. Install `@playwright/cli`, run `playwright-cli install --skills`, install Chromium
12. Register MCP servers via `npx gitnexus setup`
13. Write `~/.claude/plugin_commands.sh` (manual paste into Claude Code)
14. Create `~/.claude-work/` structure and templates
15. Remove stale launchd switchback plist (v1 artifact cleanup)
16. Write shell aliases/functions to `~/.zshrc` / `~/.bashrc` (includes `_claude_notify`, `_claude_pick_model`, `claude()` wrapper, `switch-back`)
17. Sync `commands/`, `skills/`, HTML dashboard → `~/.claude/`; deploy all hook scripts → `~/.claude/scripts/`; write `ollama.conf` and `.claudeignore` if not present

### Shell Functions Installed

After running the installer, these functions are available in your shell:

- `claude` — wrapper: lazy reset-time check → user prompt → Ollama health check → model picker → launch; falls back to Anthropic if Ollama is unreachable
- `switch-back` — restore Anthropic env vars in the current terminal; reads API key from backup file first, then Keychain
- `_claude_notify` — desktop notification helper (macOS + Linux + terminal echo fallback)
- `_claude_pick_model` — interactive Ollama model picker (zsh-compatible); reads `ollama.conf` for default model
- `cw` / `claude-work` — launch Claude with `~/.claude-work` context (exit and run `claude` to go without)
- `enable-skill <name>` / `disable-skill <name>` — toggle `disable-model-invocation` in SKILL.md
- `list-skills` — show all skills with context-on/off state
- `enable-plugin <name>` / `disable-plugin <name>` — toggle `enabledPlugins` in settings.json
- `list-plugins` — show all plugins with enabled/disabled state
- `enable-mcp <name>` / `disable-mcp <name>` — toggle `disabled` flag in settings.json mcpServers
- `list-mcps` — show all MCP servers with enabled/disabled state
- `list-commands` — list all slash commands

### MCP Servers Configured

All disabled by default except `context7`. Use `enable-mcp <name>` to activate.

| Server | Type | Purpose |
|--------|------|---------|
| `context7` | URL | Live documentation fetching (enabled by default) |
| `gitnexus` | Command | Codebase knowledge graph (run `npx gitnexus analyze` per repo) |
| `context-mode` | Command | Context-mode plugin support |
| `claude-mem` | URL | Session memory (requires claude-mem plugin) |
| `filesystem` | Command | Local file access (`${HOME}`) |
| `supabase` | URL | Database queries |
| `vercel` | URL | Deploy and logs |

### Source of Truth Rule — Repo First, Then Sync

**All changes to skills, commands, settings, and personas must be made in the repo first, then synced to `~/.claude/`.**

| What you want to change | Edit here (repo) | Then sync via |
|------------------------|-----------------|---------------|
| Skills (new or modified) | `skills/<name>/` | `bash install.sh` or manual `cp -r skills/<name> ~/.claude/skills/` |
| Slash commands | `commands/<name>.md` | `bash install.sh` or manual `cp commands/<name>.md ~/.claude/commands/` |
| Review council personas | `skills/review-council/standard-personas/` | `bash install.sh` or manual `cp` to `~/.claude/skills/review-council/standard-personas/` |
| Hook settings / MCP config | `settings.json` | `bash install.sh` (merges) |
| Global CLAUDE.md | `claude-md-master/CLAUDE.md` | `bash install.sh` (always overwrites) |

**Never edit `~/.claude/` directly** — changes made there are lost on the next `install.sh` run. The repo is the single source of truth; `~/.claude/` is a deployment target.

### Adding Custom Skills

Place skill directories under `skills/` — each needs a `SKILL.md`. The installer syncs them to `~/.claude/skills/` without overwriting existing customisations.

### Bundled Skills

| Skill | Purpose |
|-------|---------|
| `aidlc-tracking` | Canonical formats for all project tracking files |
| `review-council` | Multi-persona architecture review council |
| `codereview-roasted` | Linus-style opinionated code review — data structures first, 7 scenarios, no flattery |
| `frontend-design-review` | Five-step surgical UI audit — visual hierarchy, typography, whitespace, color/contrast, production quality |
| `karpathy-guidelines` | Coding behaviour guardrails — think before coding, simplicity first, surgical changes, goal-driven execution |
| `emil-design-eng` | Design engineering from Emil Kowalski — easing, timing, motion, micro-interactions that feel intentional |
| `impeccable` | 18 design commands (`/audit`, `/polish`, `/typeset`, `/animate`…) that eliminate AI-slop aesthetics |
| `taste-skill` | Three configurable design dials (variance, motion, density) to stop AI shipping generic centred layouts |

### Adding Custom Commands

Place `.md` files under `commands/` — they sync to `~/.claude/commands/` and become available as `/command-name` inside Claude Code.

### Bundled Commands

| Command | Purpose |
|---------|---------|
| `/init-repo` | Bootstrap gitnexus + CLAUDE.md + AIDLC tracking files for a new repo |
| `/design-review` | Trigger the `review-council` skill for a full architectural review |
| `/log-context` | Write a pre-compact session snapshot to `tasks/tracker.md` |
| `/frontend-design-review` | Five-step visual design audit — hierarchy, typography, spacing, color, production quality |

---

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
- Use subagents liberally to keep main context window clean
- Offload research, exploration, and parallel analysis to subagents
- For complex problems, throw more compute at it via subagents
- One task per subagent for focused execution

### 3. External Integration Research
- For ANY external third-party system (APIs, SDKs, cloud services, auth providers):
  spawn a dedicated subagent to fetch live documentation via Context7 FIRST
- Never rely on training data for external APIs -- they change frequently
- This does NOT apply to internal microservices -- use the codebase directly

### 4. Codebase Awareness
- Before touching an unfamiliar codebase: run `npx gitnexus analyze` to build the graph
- Use gitnexus impact and context tools to trace dependencies before any edit
- Read sub-module CLAUDE.md files before working in any sub-directory
- Create sub-module CLAUDE.md files progressively as you explore new directories
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
- When given a bug report: just fix it. Don't ask for hand-holding
- Point at logs, errors, failing tests -- then resolve them
- Zero context switching required from the user
- Go fix failing CI tests without being told how

### 9. Progressive Discovery (Token Budget)
- Load only what you need, when you need it -- never pre-load entire codebases
- Read sub-module CLAUDE.md summaries before opening source files
- Use gitnexus search and context tools before reaching for Read or Grep
- Use ctx_search (context-mode) before reading raw files when available
- Prefer targeted reads (specific functions, line ranges) over whole-file reads
- Ask: "what is the minimum context needed to answer this correctly?"
- Before starting any task, run `/context` and note the exact token count
- If context usage exceeds 50%, spawn a fresh subagent rather than continuing in the main session
- If context usage exceeds 70%, run `/log-context` then `/compact` immediately before proceeding

## Task Management

1. **Plan First**: Write plan to `tasks/todo.md` with checkable items
2. **Log to docs/plan.md**: Append intent and tradeoffs before implementation (pre-hook)
3. **Verify Plan**: Check in before starting implementation
4. **Track Progress**: Mark items complete as you go in `tasks/todo.md`
5. **Explain Changes**: High-level summary at each step
6. **Simplify**: Run `/simplify` on the changed code before logging — reviews the delta for reuse, quality, and efficiency; fixes issues found
7. **Log to audit/changelog.md**: Append what changed after implementation (post-hook)
8. **Log to tasks/tracker.md**: Append task completion entry after each task (post-hook)
9. **Capture Lessons**: Update `tasks/lessons.md` after corrections

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

## Pre-Compact Rule

Before running or suggesting `/compact`:
1. Run `/log-context` to write a pre-compact snapshot to `tasks/tracker.md`
2. Then proceed with `/compact`

When context auto-compaction is imminent (≥70%), always run `/log-context` first.

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
