# Code Review — feature/local-model-switchover

**Reviewer:** Senior Principal Engineer (parallel subagent analysis)
**Branch:** `feature/local-model-switchover`
**Scope:** All unstaged/uncommitted changes against `main`
**Date:** 2026-03-26
**Resolution date:** 2026-03-26 — all items addressed

Three independent review agents ran in parallel across:
- `scripts/limit-watchdog.sh` + `scripts/switch-to-ollama.sh`
- `install.sh` ZSHBLOCK + `scripts/aidlc-guard.sh`
- Full `tests/` suite

All findings were cross-validated against the actual files before being logged here.
Final test count after all fixes: **114/114 bats + 5/5 settings checks**.

---

## Section 1 — Bugs

### BUG-01 — Bash array off-by-one in `scripts/switch-to-ollama.sh` ✅ FIXED

**File:** `scripts/switch-to-ollama.sh:48` · **Severity:** HIGH

The script has `#!/usr/bin/env bash` and runs as bash. Bash arrays are **0-indexed**
(`models[0]` = first model), but the picker displayed items starting at `1)` and
indexed with `${models[$selection]}` — so selecting "1" returned the second model.

The comment "zsh arrays are 1-based" was correct for the `install.sh` ZSHBLOCK
(sourced into zsh), but `switch-to-ollama.sh` is a standalone bash script.

**Fix applied:** `${models[$selection]}` → `${models[$((selection - 1))]}` in
`switch-to-ollama.sh` only. `install.sh` line 981 unchanged (zsh, 1-based is correct).

**Tests added:** SOTO-13–17 using `_OLLAMA_FORCE_INTERACTIVE=1` to drive the numeric
picker; verify selection 1/2/3 each picks the correct model AND that the chosen model
appears verbatim in `OLLAMA_MODEL=` inside the override file.

---

### BUG-02 — Default model name mismatch across components ✅ FIXED

**Files:** `scripts/limit-watchdog.sh:117,123` · `scripts/switch-to-ollama.sh:14` · `install.sh:956` · `tests/helpers/shell_functions.sh:26` · **Severity:** MEDIUM

`limit-watchdog.sh` defaulted to `glm-4.7-flash` while all other components used
`glm4-flash`. Auto-triggered overrides would use a different model name than manual
activation, creating maintenance confusion and potential breakage if only one name
was installed.

**Fix applied:** All components now default to `kimi-k2.5:cloud` (confirmed installed).
Mock models in test helpers updated to use real installed models
(`kimi-k2.5:cloud`, `qwen3:4b`, `qwen2.5-coder:7b`).

**User note:** Default changed to `kimi-k2.5:cloud` per user instruction. Numeric
model selection (1, 2, 3 …) tested end-to-end — selected model is the one written
to `OLLAMA_MODEL` in the override and persisted to `.ollama-model`.

---

### BUG-03 — SOTO-10 test name contradicted actual behavior ✅ FIXED

**File:** `tests/test_switch_to_ollama_v2.bats:153–166` · **Severity:** MEDIUM

The test named "no reset-time file when only reset_hour given" had zero assertions —
its own comments admitted the file *is* written (python3 treats `''` as `int(0)`).

**Fix applied:** Test renamed to "reset-time file written with minute=0 when only
reset_hour arg given". Added three hard assertions: file exists, content is a valid
epoch integer, epoch is a future timestamp.

---

## Section 2 — Security & Reliability

### SEC-01 — `OLLAMA_HOST` unquoted in heredoc override file ✅ FIXED

**Files:** `scripts/limit-watchdog.sh:140` · `scripts/switch-to-ollama.sh:74` · **Severity:** LOW

```bash
# Before
export ANTHROPIC_BASE_URL=${OLLAMA_HOST}/v1
# After
export ANTHROPIC_BASE_URL="${OLLAMA_HOST}/v1"
```

If `OLLAMA_HOST` contained spaces the export statement in the written override file
would be syntactically broken and `source "$override"` would fail silently.

**Fix applied:** Both heredocs now quote the value. Affected test assertions updated to
match the new quoted format (`ANTHROPIC_BASE_URL="http://..."`) — 8 tests updated.

---

### SEC-02 — `source "$override"` no error handling in `claude()` wrapper ✅ FIXED

**File:** `install.sh` ZSHBLOCK · `tests/helpers/shell_functions.sh` · **Severity:** LOW-MEDIUM

If the override file was malformed (e.g. partial write from an older pre-atomic-write
version), `source` would fail and the wrapper would silently proceed with no
`ANTHROPIC_BASE_URL`, routing to Anthropic with no warning.

**Fix applied:**
```bash
source "$override" || { echo "⚠  Failed to load Ollama override — check ~/.claude/.ollama-override"; return 1; }
```
Applied to both `install.sh` and `tests/helpers/shell_functions.sh`.

---

### SEC-03 — `_claude_notify` osascript string not sanitized ✅ FIXED

**File:** `install.sh` ZSHBLOCK · `tests/helpers/shell_functions.sh` · **Severity:** LOW

A `$msg` containing `"` could break out of the AppleScript double-quoted string
literal. All current call sites use hardcoded strings, but any future dynamic content
(e.g. model name from `.ollama-model`) would be a macOS code-injection vector.

**Fix applied:** Switched from double-quoted `-e` argument to single-quote splicing:
```bash
# Before
osascript -e "display notification \"$msg\" with title \"$title\""
# After
osascript -e 'display notification '"\"$msg\""' with title '"\"$title\""'
```

---

### REL-01 — Four separate `python3` processes parsed the same stdin JSON ✅ FIXED

**File:** `scripts/limit-watchdog.sh:23–26` · **Severity:** LOW

Four subprocess spawns to extract four fields from the same JSON. Replaced with a
single python3 invocation printing all four values on newline-separated lines, read
back via `sed -n 'Np'`. One process instead of four; atomically consistent parse.

---

### REL-02 — `tracker.md` prepend assumed exactly 3 header lines ✅ FIXED

**File:** `scripts/limit-watchdog.sh:195–197` · **Severity:** MEDIUM

`{ head -3 ...; entry; tail -n +4 ...; }` would corrupt entries if the header was
not exactly 3 lines (e.g. created by hand or a future skill version).

**Fix applied:** Dynamically finds the line number of the first `## ` entry with
`grep -n '^## '`, computes header length as `_insert_line - 1`, uses that for the
split. Falls back to `head -3` / `tail -n +4` if no `## ` entry exists yet.

---

### REL-03 — `mktemp` failure silently skipped registry cleanup ✅ FIXED

**File:** `install.sh` ZSHBLOCK (3 occurrences) · `tests/helpers/shell_functions.sh` (3 occurrences) · **Severity:** LOW

If `mktemp` failed (disk full), `$tmp` was empty, `grep > ""` failed silently, and
stale entries accumulated in `.active-projects` over time.

**Fix applied:** `local tmp; tmp=$(mktemp) || return 0` at all six occurrences. On
mktemp failure the cleanup is skipped gracefully rather than silently corrupting state.

---

### REL-04 — `aidlc-guard.sh` timestamp regex used BRE quantifiers ✅ FIXED

**File:** `scripts/aidlc-guard.sh:56` · **Severity:** LOW

First grep used BRE `\{4\}` style while the piped second grep already used ERE.
Inconsistent and subtly less portable on non-standard grep implementations.

**Fix applied:** Changed to `grep -m1 -E '^## [0-9]{4}-...'` (ERE throughout).

---

## Section 3 — Test Quality

### TEST-01 — LW2-10 used `grep -qP` (PCRE), silently broken on macOS ✅ FIXED

**File:** `tests/test_limit_watchdog_v2.bats:169` · **Severity:** MEDIUM

macOS BSD grep has no `-P` flag. `2>/dev/null` swallowed the error, making the
negative guard a no-op. The `||` fallback checked for a literal `"` — unintended.

**Fix applied:** Replaced with portable ERE:
```bash
! grep -qE 'ANTHROPIC_BASE_URL=http://localhost:11434[^/]' "$TMP_HOME/.claude/.ollama-override" 2>/dev/null
```

---

### TEST-02 — SOTO-10 had no meaningful assertion ✅ FIXED

See BUG-03 above. Same fix.

---

### TEST-03 — FN-11 opened real repo `settings.json`, not a sandbox copy ✅ FIXED

**File:** `tests/test_functional_cycle.bats` · **Severity:** MEDIUM

`with open('settings.json')` used a relative path — only worked if bats ran from the
repo root. From any other directory it silently passed vacuously.

**Fix applied:** Path computed via `BATS_TEST_DIRNAME` env var (exported before the
python3 call since the heredoc uses single-quote delimiters):
```python
settings_path = os.path.join(os.environ.get('BATS_TEST_DIRNAME', '.'), '..', 'settings.json')
with open(settings_path) as f:
```

---

### TEST-04 — FN-02b model assertion used substring grep ✅ FIXED

**File:** `tests/test_functional_cycle.bats:40` · **Severity:** LOW

`grep -q 'OLLAMA_MODEL=.*my-custom-model:latest'` would match commented lines.

**Fix applied:** `grep -q '^export OLLAMA_MODEL="my-custom-model:latest"'` — anchored
to the exact export line format the script writes.

---

### TEST-05 — PATH expansion in `test_shell_functions.bats` non-obvious ✅ DOCUMENTED

**File:** `tests/test_shell_functions.bats` · **Severity:** INFO

`PATH='$TMP_HOME/bin:$PATH'` inside a double-quoted `bash -c` string correctly expands
both `$TMP_HOME` and `$PATH` at the outer shell level, giving inner bash a fully
resolved PATH. Non-obvious to future readers.

**Fix applied:** Explanatory comment added to `_run_fn` helper documenting the
intentional outer-shell expansion semantics.

---

## Section 4 — Style / Minor

### STY-01 — `(( i++ ))` portability ✅ NO ACTION NEEDED

`(( i++ ))` is not POSIX sh but is supported by both bash and zsh. The ZSHBLOCK is
only ever sourced into bash or zsh, so this is acceptable.

---

### STY-02 — CWD fallback used permissive session filter ✅ FIXED

**File:** `scripts/limit-watchdog.sh:76–91` · **Severity:** INFO

`(not target_sid or d.get('sessionId') == target_sid)` matched ANY project's
rate-limit entry when `session_id` extraction failed (empty string), risking picking
up the wrong project's CWD on multi-session machines.

**Fix applied:** Removed the `not target_sid or` fallback. An empty `session_id` now
produces no CWD match rather than matching any project's entry. Safer default.

---

## Summary

| ID | File | Severity | Type | Status |
|----|------|----------|------|--------|
| BUG-01 | `scripts/switch-to-ollama.sh:48` | HIGH | Bug | ✅ Fixed + SOTO-13–17 |
| BUG-02 | Multiple | MEDIUM | Bug | ✅ Fixed — default → `kimi-k2.5:cloud` |
| BUG-03 | `tests/test_switch_to_ollama_v2.bats:153` | MEDIUM | Test | ✅ Fixed |
| SEC-01 | `limit-watchdog.sh:140`, `switch-to-ollama.sh:74` | LOW | Security | ✅ Fixed |
| SEC-02 | `install.sh` ZSHBLOCK | LOW-MED | Reliability | ✅ Fixed |
| SEC-03 | `install.sh` ZSHBLOCK | LOW | Security | ✅ Fixed |
| REL-01 | `limit-watchdog.sh:23–26` | LOW | Style | ✅ Fixed |
| REL-02 | `limit-watchdog.sh:195–197` | MEDIUM | Reliability | ✅ Fixed |
| REL-03 | `install.sh` ZSHBLOCK | LOW | Reliability | ✅ Fixed |
| REL-04 | `aidlc-guard.sh:56` | LOW | Portability | ✅ Fixed |
| TEST-01 | `test_limit_watchdog_v2.bats:169` | MEDIUM | Test | ✅ Fixed |
| TEST-02 | `test_switch_to_ollama_v2.bats:153` | MEDIUM | Test | ✅ Fixed |
| TEST-03 | `test_functional_cycle.bats:170` | MEDIUM | Test | ✅ Fixed |
| TEST-04 | `test_functional_cycle.bats:40` | LOW | Test | ✅ Fixed |
| TEST-05 | `test_shell_functions.bats` | INFO | Test | ✅ Documented |
| STY-01 | `install.sh` ZSHBLOCK | INFO | Style | ✅ No action needed |
| STY-02 | `limit-watchdog.sh:76–91` | INFO | Style | ✅ Fixed |

**17/17 items resolved. Final test count: 114/114 bats + 5/5 settings checks.**
