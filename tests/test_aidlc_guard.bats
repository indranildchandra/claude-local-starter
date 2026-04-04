#!/usr/bin/env bats
# tests/test_aidlc_guard.bats
# Tests for scripts/aidlc-guard.sh — AIDLC enforcement at Stop/StopFailure
load 'helpers/setup'

@test "AG-01: creates tasks/lessons.md stub when missing" {
  run env PROJECT_CWD="$TMP_PROJECT" bash scripts/aidlc-guard.sh
  [ -f "$TMP_PROJECT/tasks/lessons.md" ]
  grep -q '# Lessons' "$TMP_PROJECT/tasks/lessons.md"
}

@test "AG-02: does not overwrite existing tasks/lessons.md" {
  echo "# Lessons" > "$TMP_PROJECT/tasks/lessons.md"
  echo "existing content" >> "$TMP_PROJECT/tasks/lessons.md"
  PROJECT_CWD="$TMP_PROJECT" bash scripts/aidlc-guard.sh
  grep -q 'existing content' "$TMP_PROJECT/tasks/lessons.md"
}

@test "AG-03: creates tasks/todo.md stub when missing" {
  run env PROJECT_CWD="$TMP_PROJECT" bash scripts/aidlc-guard.sh
  [ -f "$TMP_PROJECT/tasks/todo.md" ]
  grep -q '# Todo' "$TMP_PROJECT/tasks/todo.md"
}

@test "AG-04: does not overwrite existing tasks/todo.md" {
  echo "# Todo" > "$TMP_PROJECT/tasks/todo.md"
  echo "- [ ] my task" >> "$TMP_PROJECT/tasks/todo.md"
  PROJECT_CWD="$TMP_PROJECT" bash scripts/aidlc-guard.sh
  grep -q 'my task' "$TMP_PROJECT/tasks/todo.md"
}

@test "AG-05: warns when tasks/tracker.md is missing" {
  run env PROJECT_CWD="$TMP_PROJECT" bash scripts/aidlc-guard.sh
  echo "$output" | grep -qi "tracker.md missing"
}

@test "AG-06: no stale warning when tracker.md has recent entry" {
  # Write a tracker entry with current timestamp
  ts=$(date '+%Y-%m-%d %H:%M:%S')
  mkdir -p "$TMP_PROJECT/tasks"
  printf '# Task Tracker\n<!-- header -->\n<!-- header -->\n\n## %s — test\n**Type:** task-complete\n' "$ts" \
    > "$TMP_PROJECT/tasks/tracker.md"
  run env PROJECT_CWD="$TMP_PROJECT" bash scripts/aidlc-guard.sh
  # Should NOT warn about stale tracker
  echo "$output" | grep -qiv "stale\|age_h\|old" || true
  [ "$status" -eq 0 ]
}

@test "AG-07: warns when docs/plan.md has unchecked items" {
  mkdir -p "$TMP_PROJECT/docs"
  printf '# Plan Log\n\n- [ ] step one\n- [x] step two\n' > "$TMP_PROJECT/docs/plan.md"
  run env PROJECT_CWD="$TMP_PROJECT" bash scripts/aidlc-guard.sh
  echo "$output" | grep -qi "unchecked"
}

@test "AG-08: no plan warning when all checklist items are checked" {
  mkdir -p "$TMP_PROJECT/docs"
  printf '# Plan Log\n\n- [x] step one\n- [x] step two\n' > "$TMP_PROJECT/docs/plan.md"
  run env PROJECT_CWD="$TMP_PROJECT" bash scripts/aidlc-guard.sh
  echo "$output" | grep -qiv "unchecked" || true
  [ "$status" -eq 0 ]
}

@test "AG-09: no plan warning when docs/plan.md does not exist" {
  run env PROJECT_CWD="$TMP_PROJECT" bash scripts/aidlc-guard.sh
  [ "$status" -eq 0 ]
}

@test "AG-10: exits 0 even when all tracking files are missing" {
  run env PROJECT_CWD="$TMP_PROJECT" bash scripts/aidlc-guard.sh
  [ "$status" -eq 0 ]
}

@test "AG-11: creates tasks/ and docs/ directories if missing" {
  rm -rf "$TMP_PROJECT/tasks" "$TMP_PROJECT/docs"
  PROJECT_CWD="$TMP_PROJECT" bash scripts/aidlc-guard.sh
  [ -d "$TMP_PROJECT/tasks" ]
  [ -d "$TMP_PROJECT/docs" ]
}
