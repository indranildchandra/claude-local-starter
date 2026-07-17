# Solution Evolution Timeline — `claude/analyze-ollama-switchover-FPs8h`

This document reconstructs the full chain of activities on this branch, from its
divergence off `main` to its current state. It is the reference used to verify
that the branch's committed state matches its intended evolution, and to reconcile
the branch against `main` during sync.

Branch base (merge-base with `main`): `c3d27bc` — *"organized scripts/config, added defaultMode to safe-yolo"*
Commits unique to this branch: **20** (linear, no merge commits)

---

## Phase 1 — Local-model (Ollama) switchover system  _(the branch's namesake)_

The founding purpose: make Claude Code fall back to a locally-hosted Ollama model
automatically when Anthropic usage limits are hit, and restore Anthropic access
seamlessly once the limit resets.

| Commit | What landed |
|--------|-------------|
| `4562e8d` | **Core switchover system** — limit watchdog, override/reset-time sentinel files, safe-yolo improvements, test suite, `codereview-roasted` skill (npx). **Design decision: `ppt-creator` moved out of repo (installed externally).** |
| `fcf815b` | Stale-sentinel bugfix; clean statusline format; disable telemetry; no-flicker via `settings.json` |
| `592b350` | Bugfix: sentinel files persisting across terminals — always prompt on active override |
| `e6547db` | Rendering bugfix in MCP tab (HTML dashboard) |
| `dd168de` | Statusline: show time-elapsed % of the 5h window with threshold coloring |
| `26ac018` | Docs: Claude Code quick-reference cheatsheet |
| `044fb39` | Cheatsheet + `frontend-design-review` skill (PR #2) |
| `c14beb7` | Statusline configuration enhancements |
| `f0e4e97` | Updated Ollama default model choice |
| `9300b01` | **8h→5h auto-cleanup fix**; proper `switch-to-anthropic.sh` (3-path key recovery); `/switch-to-ollama` + `/switch-to-anthropic` slash commands |
| `4c7d327` | E2E lifecycle test suite; removed stale commands; rebuilt `tests/helpers/shell_functions.sh` from `install.sh` source of truth |
| `2d0c3e1` | Docs sync: updated all stale references after the switchover refactor |

**Key artifacts:** `scripts/limit-watchdog.sh`, `scripts/switch-to-ollama.sh`,
`scripts/switch-to-anthropic.sh`, `commands/switch-to-*.md`, `ollama.conf`,
`LOCAL-MODEL-SWITCHOVER-DESIGN.md`, `tests/test_e2e_lifecycle.sh`.

---

## Phase 2 — External design-skills expansion

| Commit | What landed |
|--------|-------------|
| `cb16710` | **`emil-design-eng`, `impeccable`, `taste-skill`** added via a new `clone_or_pull_skill()` helper in `install.sh` (git-clone + subdir sync + `disable-model-invocation` patch). Documented in root `CLAUDE.md` skills table, `README.md`, and the HTML dashboard. |

These three are **cloned at install time**, not vendored into `skills/` — consistent
with how community skills are handled (zero token cost via `disable-model-invocation: true`).

---

## Phase 3 — Coding discipline & workflow documentation

| Commit | What landed |
|--------|-------------|
| `f1fd2ab` | **§11 Karpathy Coding Discipline** added to `claude-md-master/CLAUDE.md` Workflow Orchestration + "Karpathy One-Pass Standard" in Core Principles |
| `3750ff3` | **`/init-agent-teams`** command — scaffolds parallel agent-team structure (`1-agent-teams/`…`4-hooks/`, orchestrator + per-domain specialists, `enable-flag.json`). Documented in `CLAUDE.md` + `README.md` |
| `194c8c1` | **Communication Standards** section (lead with answer, reverse-prompt on ambiguity, epistemic honesty, no prose-bloat) |
| `3fbf1ae` | **`lean-ctx`** added as an *optional external tool* — HTML dashboard only, deliberately **not** bundled (overlaps gitnexus + context-mode; 59 MCP tools; Rust dep) |

---

## Phase 4 — Spec-driven implementation-notes tracking artifact

A new "during-implementation" AIDLC layer sitting between `docs/plan.md` (before)
and `audit/changelog.md` (after), triggered by a `<SPEC>` block in a user message.

| Commit | What landed | Evolution |
|--------|-------------|-----------|
| `2cae418` | `impl-notes.html` introduced as the during-implementation artifact | Single HTML file per repo |
| `0914cca` | Refactor: **one file per spec per iteration**, local-timezone timestamp (`YYYY-MM-DDTHH-MM-SS_<slug>`) | Solves the multi-module overwrite problem; free chronological history via `ls` |
| `51dbdb4` | **Switch format HTML → Markdown** | Markdown edits in-place far better than HTML for files Claude rewrites repeatedly; HTML reserved for once-generated human-read artifacts |

Final format: `skills/aidlc-tracking/formats/impl-notes.md`, referenced by both
`CLAUDE.md` files in the tracking table and the `<SPEC>` Convention section.

---

## Phase 5 — Boris Cherny CLAUDE.md heuristics  _(current session)_

Three heuristics folded into the existing structure (no new sections):

1. **"If something goes sideways, STOP and re-plan immediately"** → §1 Plan Mode Default
2. **"Would a staff engineer approve this?"** → §6 Verification Before Done
3. **"Diff behavior between main and your changes when relevant"** → §6 Verification Before Done

Most other Boris content was already covered by existing rules; only these three were additive.

---

## Considered but explicitly rejected

These were evaluated during the chain and deliberately **not** incorporated (kept off to
avoid bloat / overlap):

- `/ghost`, `Exposed`, `Skill Critique`, `OODA`, `L99`, `/godmode` — user said *"drop it then, ignore"*
- **Hermes agent** (Nous Research) — research/discussion only; no code change
- **`lean-ctx` as a bundled MCP** — added to HTML as optional-external only, not wired into `install.sh`

---

## Divergence from `main` at sync time

`main` advanced by one commit after the branch forked:

- `3858970` — *"Added last30days and ddg-search skills"* — which also:
  - Adds `skills/ddg-search/` (bundled, force-synced) + `requirements.txt` (`ddgs`, `yt-dlp`)
  - Installs `last30days` via `install_skill` (npx)
  - Adds `ensure_python312()` auto-install to `install.sh`; switches `pip` → `python3 -m pip`
  - Adds a **"Bundled Skills"** table to both `CLAUDE.md` files listing `ppt-creator`, `last30days`, `ddg-search`
  - Adds `__pycache__/` to `.gitignore`

### ⚠️ Semantic divergence: `ppt-creator`

- **This branch** (`4562e8d`) **deliberately removed** `ppt-creator` — commit message:
  *"ppt-creator skill moved out of repo (installed externally)"*. Removal was clean
  (skill dir + `commands/create-ppt.md` + all doc references).
- **`main`** still ships `ppt-creator` bundled and its new "Bundled Skills" table documents it.

A naive merge keeps this branch's deletion (git resolves delete-vs-unchanged silently)
**but** pulls in `main`'s doc row → dangling reference.

**Resolution (merge `09dd533`): kept removed.** This branch's externalization was explicit
and documented; `main`'s inclusion was incidental (its Bundled Skills table was added in a
commit primarily about last30days/ddg-search). The merge drops `main`'s `ppt-creator`
files and doc rows so the branch stays internally consistent with "installed externally."
One-line reversible if the intent was actually to restore it.

### Merge conflict set (verified via dry-run)

`.gitignore`, `CLAUDE.md`, `README.md`, `claude-md-master/CLAUDE.md`, `install.sh`
(content conflicts); `claude-local-starter.html` auto-merges; `requirements.txt` +
`skills/ddg-search/*` add cleanly.

---

## Verification result — branch state vs. timeline

All Phase 1–5 deliverables are present and internally consistent on the branch:

- ✅ Ollama switchover: scripts, commands, `ollama.conf`, e2e tests all present
- ✅ Design skills: `clone_or_pull_skill` ×3 in `install.sh`; consistent in `CLAUDE.md`, `README.md`, HTML (7 refs)
- ✅ Karpathy §11 in both `CLAUDE.md` files
- ✅ `/init-agent-teams` command file exists + documented in `CLAUDE.md` + `README.md`
- ✅ Communication Standards in both `CLAUDE.md` files
- ✅ `lean-ctx` in HTML only (0 refs in `.md`/`.sh` — correct)
- ✅ `impl-notes.md` (Markdown) is the only format file; no lingering `.html` references
- ✅ Boris heuristics ×3 present in both `CLAUDE.md` files
- ✅ Every command referenced in docs has a backing file in `commands/`

**Pre-existing minor note:** `codereview-roasted` is listed under "Bundled Skills" but is
actually npx-installed (`openhands/extensions`), not vendored in `skills/`. Cosmetic
mislabel that predates this branch's work.

**Reconciliation result:** `main` synced in via merge `09dd533` (last30days, ddg-search,
`ensure_python312`, `requirements.txt`, `__pycache__/`). `ppt-creator` kept removed per this
branch's explicit externalization decision. All 5 conflicts resolved as unions of both sides'
intent; E2E lifecycle suite green (28/0/1-skip); HTML dashboard auto-merged cleanly with no
dangling references.
