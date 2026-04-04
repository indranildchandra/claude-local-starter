#!/usr/bin/env bash
# scripts/aidlc-guard.sh
# Runs at every Stop/StopFailure — enforces AIDLC tracking discipline.
# Creates missing tracking files, warns when context is stale, warns when
# docs/plan.md has unchecked items. Non-fatal: never aborts the session.
#
# Called by settings.json Stop and StopFailure hooks alongside limit-watchdog.sh.
# Each hook entry in the Stop array receives its own fresh stdin copy.

set +e  # Non-fatal guard — all failures are soft

# ── Resolve project CWD ────────────────────────────────────────────────────
# PROJECT_CWD env var overrides PWD — used in tests to point at TMP_PROJECT.
# In production (hook invocation), PROJECT_CWD is not set; $PWD is the session CWD.
if [ -n "${PROJECT_CWD:-}" ] && [ -d "$PROJECT_CWD" ]; then
  _guard_cwd="$PROJECT_CWD"
else
  _guard_cwd="${PWD}"
fi

# ── Ensure required directories exist ─────────────────────────────────────
mkdir -p "$_guard_cwd/tasks" "$_guard_cwd/docs" "$_guard_cwd/audit"

# ── Create tasks/lessons.md stub if missing ────────────────────────────────
if [ ! -f "$_guard_cwd/tasks/lessons.md" ]; then
  cat > "$_guard_cwd/tasks/lessons.md" <<'LESSONS_HEADER'
# Lessons
<!-- Append-only. Newest at TOP. Per-repo scope. -->
<!-- Format: ## YYYY-MM-DD — <title> -->
<!-- Rule | Why | Trigger | Applies to -->
LESSONS_HEADER
  echo "AIDLC: tasks/lessons.md created — add at least one lesson entry with /log-context before ending this session"
fi

# ── Create tasks/todo.md stub if missing ───────────────────────────────────
if [ ! -f "$_guard_cwd/tasks/todo.md" ]; then
  cat > "$_guard_cwd/tasks/todo.md" <<'TODO_HEADER'
# Todo
<!-- Ephemeral. Rewrite as work evolves. NOT append-only. -->

## In Progress

## Up Next

## Done (this session)
TODO_HEADER
  echo "AIDLC: tasks/todo.md created"
fi

# ── Warn if tasks/tracker.md is stale or missing ──────────────────────────
if [ ! -f "$_guard_cwd/tasks/tracker.md" ]; then
  echo "AIDLC WARNING: tasks/tracker.md missing — run /log-context to capture session state before handover"
else
  # Extract timestamp from the top entry header: ## YYYY-MM-DD HH:MM:SS
  _top_ts=$(grep -m1 -E '^## [0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}' \
    "$_guard_cwd/tasks/tracker.md" 2>/dev/null \
    | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}' | head -1)
  if [ -n "$_top_ts" ]; then
    # macOS: date -j -f; GNU (Linux): date -d — both fallback gracefully
    _top_epoch=$(date -j -f '%Y-%m-%d %H:%M:%S' "$_top_ts" '+%s' 2>/dev/null) \
      || _top_epoch=$(date -d "$_top_ts" '+%s' 2>/dev/null) \
      || _top_epoch=0
    _now_epoch=$(date '+%s')
    # Guard: skip comparison if _top_epoch is 0 (both date commands failed) — would produce a
    # meaningless ~466000h age and trigger a spurious stale-tracker warning every session.
    _age_min=0
    [ "$_top_epoch" -gt 0 ] && _age_min=$(( (_now_epoch - _top_epoch) / 60 ))
    if [ "$_age_min" -gt 120 ]; then
      _age_h=$((_age_min / 60))
      echo "AIDLC WARNING: tasks/tracker.md last entry is ${_age_h}h old — run /log-context to preserve current session state for next handover"
    fi
  fi
fi

# ── Warn if docs/plan.md has unchecked checklist items ────────────────────
if [ -f "$_guard_cwd/docs/plan.md" ]; then
  _unchecked=$(grep -c '^- \[ \]' "$_guard_cwd/docs/plan.md" 2>/dev/null) || _unchecked=0
  if [ "$_unchecked" -gt 0 ]; then
    echo "AIDLC WARNING: docs/plan.md has ${_unchecked} unchecked step(s) — mark completed items as [x] to keep the plan accurate"
  fi
fi
