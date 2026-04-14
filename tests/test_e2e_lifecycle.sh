#!/usr/bin/env bash
# tests/test_e2e_lifecycle.sh
# Full end-to-end lifecycle tests for the Ollama switchover system.
# Sandboxed — uses a temp HOME, never touches the real ~/.claude/.
#
# Usage:
#   bash tests/test_e2e_lifecycle.sh          # run all tests, clean up after
#   bash tests/test_e2e_lifecycle.sh --keep   # keep sandbox dir for inspection
#
# Requirements: bash 4+, python3, curl

set -o pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
KEEP="${1:-}"

# ── Colours ───────────────────────────────────────────────────────────────────
if [ -t 1 ]; then
  RED='\033[0;31m'; GREEN='\033[0;32m'; YLW='\033[1;33m'
  CYN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
else
  RED=''; GREEN=''; YLW=''; CYN=''; BOLD=''; NC=''
fi

# ── Counters ──────────────────────────────────────────────────────────────────
PASS=0; FAIL=0; SKIP=0

ok()   { echo -e "  ${GREEN}PASS${NC} $1"; PASS=$((PASS+1)); }
fail() { echo -e "  ${RED}FAIL${NC} $1\n       ${RED}→${NC} $2"; FAIL=$((FAIL+1)); }
skip() { echo -e "  ${YLW}SKIP${NC} $1 ($2)"; SKIP=$((SKIP+1)); }
hdr()  { echo -e "\n${BOLD}${CYN}── $1 ──${NC}"; }

# ── Sandbox ───────────────────────────────────────────────────────────────────
SB="$(mktemp -d /tmp/claude-e2e.XXXXXX)"
H="$SB/home"          # fake HOME
BIN="$SB/bin"         # fake binaries
PROJ="$SB/project"    # fake project dir
CALL_LOG="$SB/calls"  # records fake claude invocations

mkdir -p "$H/.claude/scripts" "$BIN" "$PROJ/tasks" "$PROJ/docs"

# Copy real scripts into sandbox
cp "$REPO_ROOT/scripts/limit-watchdog.sh"        "$H/.claude/scripts/"
cp "$REPO_ROOT/scripts/switch-to-ollama.sh"      "$H/.claude/scripts/"
cp "$REPO_ROOT/scripts/switch-to-anthropic.sh"   "$H/.claude/scripts/"

# Minimal ollama.conf
cat > "$H/.claude/ollama.conf" <<'EOF'
OLLAMA_HOST="http://localhost:11434"
OLLAMA_DEFAULT_MODEL="smollm2:360m"
EOF

# Empty history.jsonl
touch "$H/.claude/history.jsonl"

# Fake claude binary — records calls
cat > "$BIN/claude" <<FAKE
#!/usr/bin/env bash
echo "claude \$*" >> "$CALL_LOG"
exit 0
FAKE
chmod +x "$BIN/claude"

# Fake osascript — no-op (no macOS desktop notifications in CI)
printf '#!/bin/bash\nexit 0\n' > "$BIN/osascript"; chmod +x "$BIN/osascript"

# Extract shell functions from install.sh (the live source of truth)
FUNCS="$SB/functions.sh"
awk '/^_claude_notify\(\) \{/{p=1} /^ZSHBLOCK$/{p=0} p' "$REPO_ROOT/install.sh" > "$FUNCS"
if [ ! -s "$FUNCS" ]; then
  echo "ERROR: could not extract shell functions from install.sh"; exit 1
fi

# ── Helpers ───────────────────────────────────────────────────────────────────
reset_state() {
  rm -f \
    "$H/.claude/.ollama-override"    \
    "$H/.claude/.ollama-reset-time"  \
    "$H/.claude/.ollama-manual"      \
    "$H/.claude/.pre-switchback"     \
    "$H/.claude/.ollama-anthropic-key-backup" \
    "$H/.claude/.active-projects"    \
    "$H/.claude/.ollama-model"       \
    "$PROJ/tasks/.session-handover"  \
    "$CALL_LOG"
  true > "$H/.claude/history.jsonl"
}

write_history() {  # write_history <session_id>
  local sid="$1" ts
  ts=$(python3 -c "import time; print(int(time.time()*1000))")
  printf '{"display":"/rate-limit-options","sessionId":"%s","project":"%s","timestamp":%s}\n' \
    "$sid" "$PROJ" "$ts" >> "$H/.claude/history.jsonl"
}

run_watchdog() {  # run_watchdog <json>
  HOME="$H" ANTHROPIC_API_KEY="sk-ant-testkey" \
    bash "$H/.claude/scripts/limit-watchdog.sh" <<< "$1" 2>/dev/null
}

run_wrapper() {  # run_wrapper <stdin_char> [extra_env_assignments]
  local input="$1"; shift
  (
    export HOME="$H"
    export PATH="$BIN:$PATH"
    eval "${1:-true}"
    # shellcheck disable=SC1090
    source "$FUNCS"
    echo "$input" | claude 2>/dev/null
  )
}

run_switch_back() {
  (
    export HOME="$H"
    export PATH="$BIN:$PATH"
    # shellcheck disable=SC1090
    source "$FUNCS"
    switch-back 2>/dev/null
    echo "KEY:${ANTHROPIC_API_KEY:-}"
  )
}

OLLAMA_RUNNING=0
curl -sf "http://localhost:11434/api/tags" >/dev/null 2>&1 && OLLAMA_RUNNING=1

echo -e "${BOLD}Ollama Switchover — End-to-End Lifecycle Tests${NC}"
echo "Repo:    $REPO_ROOT"
echo "Sandbox: $SB"
echo "Ollama:  $([ "$OLLAMA_RUNNING" -eq 1 ] && echo 'running' || echo 'not running (routing tests skipped)')"

# ════════════════════════════════════════════════════════════════════════════
hdr "1. limit-watchdog.sh — PRIMARY detection"

# T01: history match → .ollama-override written
reset_state
SID="t01-$(date +%s%N)"
write_history "$SID"
run_watchdog "{\"session_id\":\"$SID\",\"last_assistant_message\":\"\",\"transcript_path\":\"\",\"cwd\":\"$PROJ\"}"
[ -f "$H/.claude/.ollama-override" ] \
  && ok "T01: history.jsonl match → .ollama-override written" \
  || fail "T01: history.jsonl match → .ollama-override written" ".ollama-override not created"

# T02: override contains correct env exports
if [ -f "$H/.claude/.ollama-override" ]; then
  OVR=$(cat "$H/.claude/.ollama-override")
  if echo "$OVR" | grep -q 'ANTHROPIC_AUTH_TOKEN=ollama' && \
     echo "$OVR" | grep -q 'ANTHROPIC_API_KEY=""' && \
     echo "$OVR" | grep -q 'ANTHROPIC_BASE_URL='; then
    ok "T02: .ollama-override has correct exports"
  else
    fail "T02: .ollama-override has correct exports" "content: $OVR"
  fi
else
  skip "T02: .ollama-override contents" "T01 failed"
fi

# T03: API key backed up
[ -f "$H/.claude/.ollama-anthropic-key-backup" ] \
  && [ "$(cat "$H/.claude/.ollama-anthropic-key-backup")" = "sk-ant-testkey" ] \
  && ok "T03: API key backed up to .ollama-anthropic-key-backup" \
  || fail "T03: API key backed up to .ollama-anthropic-key-backup" "file missing or wrong content"

# T04: .session-handover written in project
[ -f "$PROJ/tasks/.session-handover" ] \
  && ok "T04: tasks/.session-handover created" \
  || fail "T04: tasks/.session-handover created" "file not found"

# T05: .active-projects updated with project path
grep -q "$PROJ" "$H/.claude/.active-projects" 2>/dev/null \
  && ok "T05: project CWD appended to .active-projects" \
  || fail "T05: project CWD appended to .active-projects" "path not in registry"

# T06: wrong session_id → no FP
reset_state
write_history "other-session"
run_watchdog "{\"session_id\":\"wrong-session\",\"last_assistant_message\":\"\",\"transcript_path\":\"\",\"cwd\":\"$PROJ\"}"
[ ! -f "$H/.claude/.ollama-override" ] \
  && ok "T06: wrong session_id → no FP, .ollama-override NOT written" \
  || fail "T06: wrong session_id → no FP" "FP triggered for wrong session_id"

# T07: stale history entry (>120s old) → no FP
reset_state
OLD_SID="t07-$(date +%s%N)"
OLD_MS=$(python3 -c "import time; print(int((time.time()-200)*1000))")
printf '{"display":"/rate-limit-options","sessionId":"%s","project":"%s","timestamp":%s}\n' \
  "$OLD_SID" "$PROJ" "$OLD_MS" >> "$H/.claude/history.jsonl"
run_watchdog "{\"session_id\":\"$OLD_SID\",\"last_assistant_message\":\"\",\"transcript_path\":\"\",\"cwd\":\"$PROJ\"}"
[ ! -f "$H/.claude/.ollama-override" ] \
  && ok "T07: stale history entry (>120s) → no FP" \
  || fail "T07: stale history entry (>120s) → no FP" "FP from old timestamp"

# T08: empty history + no text detection → no override
reset_state
run_watchdog "{\"session_id\":\"nosession\",\"last_assistant_message\":\"You have hit your limit. Resets 3:00pm\",\"transcript_path\":\"\",\"cwd\":\"$PROJ\"}"
[ ! -f "$H/.claude/.ollama-override" ] \
  && ok "T08: SECONDARY detection disabled by default → limit phrase does NOT trigger" \
  || fail "T08: SECONDARY detection disabled by default" "FP: text detection fired when it should be off"

# T09: SECONDARY detection enabled → pattern match triggers
reset_state
ENABLE_TEXT_DETECTION=true HOME="$H" ANTHROPIC_API_KEY="sk-ant-testkey" \
  bash "$H/.claude/scripts/limit-watchdog.sh" \
  <<< "{\"session_id\":\"t09\",\"last_assistant_message\":\"You have hit your limit. Resets 3:00pm\",\"transcript_path\":\"\",\"cwd\":\"$PROJ\"}" 2>/dev/null
[ -f "$H/.claude/.ollama-override" ] \
  && ok "T09: SECONDARY detection enabled → limit phrase triggers override" \
  || fail "T09: SECONDARY detection enabled" "override not written with ENABLE_TEXT_DETECTION=true"

# ════════════════════════════════════════════════════════════════════════════
hdr "2. switch-to-anthropic.sh — cleanup and key restoration"

# T10: all sentinel files removed
reset_state
touch "$H/.claude/.ollama-override" "$H/.claude/.ollama-reset-time" \
      "$H/.claude/.pre-switchback"   "$H/.claude/.ollama-manual"
printf 'sk-ant-backup' > "$H/.claude/.ollama-anthropic-key-backup"
HOME="$H" PATH="$BIN:$PATH" bash "$H/.claude/scripts/switch-to-anthropic.sh" >/dev/null 2>&1
CLEAN=1
for F in .ollama-override .ollama-reset-time .pre-switchback .ollama-manual .ollama-anthropic-key-backup; do
  [ -f "$H/.claude/$F" ] && CLEAN=0 && break
done
[ "$CLEAN" -eq 1 ] \
  && ok "T10: switch-to-anthropic.sh removes all sentinel files" \
  || fail "T10: switch-to-anthropic.sh removes all sentinel files" "some files remain"

# T11: key restored from .ollama-anthropic-key-backup (sourced)
reset_state
printf 'sk-ant-restored' > "$H/.claude/.ollama-anthropic-key-backup"
RESTORED=$(HOME="$H" PATH="$BIN:$PATH" bash -c "
  source '$H/.claude/scripts/switch-to-anthropic.sh' >/dev/null 2>&1
  echo \"\$ANTHROPIC_API_KEY\"
")
[ "$RESTORED" = "sk-ant-restored" ] \
  && ok "T11: key restored from backup file when sourced" \
  || fail "T11: key restored from backup file when sourced" "got: '$RESTORED'"

# T12: key restored from .credentials (Linux store)
reset_state
printf '{"anthropicApiKey":"sk-ant-creds"}' > "$H/.claude/.credentials"
RESTORED=$(HOME="$H" PATH="$BIN:$PATH" bash -c "
  source '$H/.claude/scripts/switch-to-anthropic.sh' >/dev/null 2>&1
  echo \"\$ANTHROPIC_API_KEY\"
")
rm -f "$H/.claude/.credentials"
[ "$RESTORED" = "sk-ant-creds" ] \
  && ok "T12: key restored from .credentials (Linux credential store)" \
  || fail "T12: key restored from .credentials" "got: '$RESTORED'"

# ════════════════════════════════════════════════════════════════════════════
hdr "3. switch-to-ollama.sh"

# T13: fails cleanly when Ollama not reachable
reset_state
set +e
OUT=$(HOME="$H" OLLAMA_HOST="http://localhost:19999" \
  bash "$H/.claude/scripts/switch-to-ollama.sh" 2>&1)
EC=$?
set -o pipefail
[ "$EC" -ne 0 ] && echo "$OUT" | grep -q "not running" \
  && ok "T13: switch-to-ollama.sh exits non-zero with 'not running' message when Ollama absent" \
  || fail "T13: switch-to-ollama.sh error on Ollama absent" "exit=$EC output=$OUT"

# T14: writes override + .ollama-manual (real Ollama)
if [ "$OLLAMA_RUNNING" -eq 1 ]; then
  reset_state
  echo "" | HOME="$H" ANTHROPIC_API_KEY="sk-ant-testkey" \
    bash "$H/.claude/scripts/switch-to-ollama.sh" >/dev/null 2>&1
  [ -f "$H/.claude/.ollama-override" ] && [ -f "$H/.claude/.ollama-manual" ] \
    && ok "T14: switch-to-ollama.sh writes .ollama-override + .ollama-manual" \
    || fail "T14: switch-to-ollama.sh writes override + manual flag" \
            "override=$([ -f "$H/.claude/.ollama-override" ] && echo Y || echo N) manual=$([ -f "$H/.claude/.ollama-manual" ] && echo Y || echo N)"
else
  skip "T14: switch-to-ollama.sh writes override + manual flag" "Ollama not running"
fi

# ════════════════════════════════════════════════════════════════════════════
hdr "4. claude() wrapper — routing logic"

# T15: no override → fake claude called directly (Anthropic path)
reset_state
run_wrapper "" >/dev/null 2>&1
[ -f "$CALL_LOG" ] && grep -q "claude" "$CALL_LOG" \
  && ok "T15: no override → fake claude called (Anthropic path)" \
  || fail "T15: no override → fake claude called" "call log empty"

# T16: override + past reset_epoch → auto-cleanup, no prompt
reset_state
touch "$H/.claude/.ollama-override"
echo "1" > "$H/.claude/.ollama-reset-time"  # epoch 1 = Jan 1970, definitely past
run_wrapper "" >/dev/null 2>&1
[ ! -f "$H/.claude/.ollama-override" ] \
  && ok "T16: past reset_epoch → auto-cleanup, override deleted (no prompt)" \
  || fail "T16: past reset_epoch → auto-cleanup" ".ollama-override still present"

# T17: override, no reset-time, age >5h, no manual flag → auto-cleanup
reset_state
touch "$H/.claude/.ollama-override"
STALE=$(python3 -c "import datetime; t=datetime.datetime.now()-datetime.timedelta(hours=6); print(t.strftime('%Y%m%d%H%M.%S'))")
touch -t "$STALE" "$H/.claude/.ollama-override"
run_wrapper "" >/dev/null 2>&1
[ ! -f "$H/.claude/.ollama-override" ] \
  && ok "T17: override >5h old, no reset-time, no manual → auto-cleanup" \
  || fail "T17: override >5h old auto-cleanup" ".ollama-override still present"

# T18: override >5h old BUT .ollama-manual present → prompt shown (no auto-cleanup)
reset_state
touch "$H/.claude/.ollama-override" "$H/.claude/.ollama-manual"
touch -t "$STALE" "$H/.claude/.ollama-override"
FUTURE=$(python3 -c "import time; print(int(time.time())+7200)")
echo "$FUTURE" > "$H/.claude/.ollama-reset-time"
run_wrapper "r" >/dev/null 2>&1  # user answers 'r' → should clean up via prompt
[ ! -f "$H/.claude/.ollama-override" ] \
  && ok "T18: manual flag suppresses 5h auto-cleanup → prompt shown → 'r' cleans up" \
  || fail "T18: manual flag suppresses 5h auto-cleanup" "override still present after 'r'"

# T19: user enters 'r' → override deleted, Anthropic launch
reset_state
touch "$H/.claude/.ollama-override"
FUTURE=$(python3 -c "import time; print(int(time.time())+7200)")
echo "$FUTURE" > "$H/.claude/.ollama-reset-time"
run_wrapper "r" >/dev/null 2>&1
[ ! -f "$H/.claude/.ollama-override" ] \
  && ok "T19: user enters 'r' → override deleted" \
  || fail "T19: user enters 'r' → override deleted" ".ollama-override still present"

# T20: Ollama unreachable → wrapper returns non-zero, does not crash
reset_state
cat > "$H/.claude/.ollama-override" <<'OVR'
export ANTHROPIC_AUTH_TOKEN=ollama
export ANTHROPIC_API_KEY=""
export ANTHROPIC_BASE_URL="http://localhost:19999/v1"
export OLLAMA_MODEL="smollm2:360m"
OVR
echo 'OLLAMA_HOST="http://localhost:19999"' > "$H/.claude/ollama.conf"
FUTURE=$(python3 -c "import time; print(int(time.time())+7200)")
echo "$FUTURE" > "$H/.claude/.ollama-reset-time"
set +e
run_wrapper "Y" >/dev/null 2>&1
WEC=$?
set -o pipefail
# Restore ollama.conf
printf 'OLLAMA_HOST="http://localhost:11434"\nOLLAMA_DEFAULT_MODEL="smollm2:360m"\n' > "$H/.claude/ollama.conf"
[ "$WEC" -ne 0 ] \
  && ok "T20: Ollama unreachable → wrapper exits non-zero (no crash)" \
  || fail "T20: Ollama unreachable → wrapper exits non-zero" "exit was 0 — expected failure"

# ════════════════════════════════════════════════════════════════════════════
hdr "5. switch-back function"

# T21: no override → runs without error (idempotent)
reset_state
set +e; run_switch_back >/dev/null 2>&1; SB_EC=$?; set -o pipefail
[ "$SB_EC" -eq 0 ] \
  && ok "T21: switch-back with no override → exits 0 (idempotent)" \
  || fail "T21: switch-back idempotent" "exit code: $SB_EC"

# T22: all sentinel files cleaned
reset_state
touch "$H/.claude/.ollama-override" "$H/.claude/.ollama-reset-time" \
      "$H/.claude/.pre-switchback"   "$H/.claude/.ollama-manual"
run_switch_back >/dev/null 2>&1
CLEAN=1
for F in .ollama-override .ollama-reset-time .pre-switchback .ollama-manual; do
  [ -f "$H/.claude/$F" ] && CLEAN=0 && break
done
[ "$CLEAN" -eq 1 ] \
  && ok "T22: switch-back removes all sentinel files" \
  || fail "T22: switch-back removes all sentinel files" "files remain"

# T23: API key restored from backup
reset_state
printf 'sk-ant-sb-key' > "$H/.claude/.ollama-anthropic-key-backup"
touch "$H/.claude/.ollama-override"
RESULT=$(run_switch_back 2>/dev/null | grep '^KEY:' | cut -d: -f2-)
[ "$RESULT" = "sk-ant-sb-key" ] \
  && ok "T23: switch-back restores ANTHROPIC_API_KEY from backup file" \
  || fail "T23: switch-back restores API key" "got: '$RESULT'"

# ════════════════════════════════════════════════════════════════════════════
hdr "6. SessionStart auto-expire hook"

SESSION_HOOK='
  OVR="$HOME/.claude/.ollama-override"
  RST="$HOME/.claude/.ollama-reset-time"
  if [ -f "$OVR" ] && [ -f "$RST" ]; then
    EP=$(cat "$RST" | tr -d "[:space:]")
    NOW=$(date "+%s")
    if [[ "$EP" =~ ^[0-9]+$ ]] && [ "$NOW" -ge "$EP" ]; then
      rm -f "$OVR" "$RST"
      echo "[info] Anthropic limit has reset — Ollama override cleared automatically."
    fi
  fi
'

# T24: both files + past epoch → auto-expired
reset_state
touch "$H/.claude/.ollama-override"
echo "1" > "$H/.claude/.ollama-reset-time"
HOME="$H" bash -c "$SESSION_HOOK" 2>/dev/null
[ ! -f "$H/.claude/.ollama-override" ] && [ ! -f "$H/.claude/.ollama-reset-time" ] \
  && ok "T24: SessionStart hook + past epoch → sentinel files auto-removed" \
  || fail "T24: SessionStart hook + past epoch" "files not removed"

# T25: both files + future epoch → files kept
reset_state
touch "$H/.claude/.ollama-override"
FUTURE=$(python3 -c "import time; print(int(time.time())+3600)")
echo "$FUTURE" > "$H/.claude/.ollama-reset-time"
HOME="$H" bash -c "$SESSION_HOOK" 2>/dev/null
[ -f "$H/.claude/.ollama-override" ] \
  && ok "T25: SessionStart hook + future epoch → files kept (limit still active)" \
  || fail "T25: SessionStart hook + future epoch" "override incorrectly removed"

# T26: override only (no reset-time) → no action
reset_state
touch "$H/.claude/.ollama-override"
HOME="$H" bash -c "$SESSION_HOOK" 2>/dev/null
[ -f "$H/.claude/.ollama-override" ] \
  && ok "T26: SessionStart hook + no reset-time file → override untouched" \
  || fail "T26: SessionStart hook + no reset-time" "override incorrectly removed"

# ════════════════════════════════════════════════════════════════════════════
hdr "7. Full lifecycle simulations"

# T27: limit hit → watchdog writes state → time passes → wrapper auto-cleans
reset_state
SID="lc-$(date +%s%N)"
write_history "$SID"
run_watchdog "{\"session_id\":\"$SID\",\"last_assistant_message\":\"\",\"transcript_path\":\"\",\"cwd\":\"$PROJ\"}"
P1=0
[ -f "$H/.claude/.ollama-override" ] && [ -f "$H/.claude/.ollama-anthropic-key-backup" ] \
  && [ -f "$PROJ/tasks/.session-handover" ] && P1=1
if [ "$P1" -eq 1 ]; then
  echo "1" > "$H/.claude/.ollama-reset-time"   # simulate time passing
  run_wrapper "" >/dev/null 2>&1
  [ ! -f "$H/.claude/.ollama-override" ] && [ ! -f "$H/.claude/.ollama-reset-time" ] \
    && ok "T27: full lifecycle — watchdog writes → time passes → wrapper auto-cleans" \
    || fail "T27: lifecycle wrapper auto-cleanup phase" "sentinel files not cleaned"
else
  fail "T27: full lifecycle" "watchdog phase failed — override/backup/handover not all written"
fi

# T28: manual lifecycle — switch-to-anthropic cleans up manual Ollama session
reset_state
cat > "$H/.claude/.ollama-override" <<'OVR'
export ANTHROPIC_AUTH_TOKEN=ollama
export ANTHROPIC_API_KEY=""
export ANTHROPIC_BASE_URL="http://localhost:11434/v1"
export OLLAMA_MODEL="smollm2:360m"
OVR
touch "$H/.claude/.ollama-manual"
printf 'sk-ant-manual' > "$H/.claude/.ollama-anthropic-key-backup"
FUTURE=$(python3 -c "import time; print(int(time.time())+3600)")
echo "$FUTURE" > "$H/.claude/.ollama-reset-time"
HOME="$H" PATH="$BIN:$PATH" bash "$H/.claude/scripts/switch-to-anthropic.sh" >/dev/null 2>&1
CLEAN=1
for F in .ollama-override .ollama-reset-time .ollama-manual .ollama-anthropic-key-backup; do
  [ -f "$H/.claude/$F" ] && CLEAN=0 && break
done
[ "$CLEAN" -eq 1 ] \
  && ok "T28: manual lifecycle — switch-to-anthropic.sh restores clean state" \
  || fail "T28: manual lifecycle cleanup" "some sentinel files remain"

# T29: dedup in .active-projects — same CWD appended twice → only one line
reset_state
SID_A="dup-a-$(date +%s%N)"; SID_B="dup-b-$(date +%s%N)"
write_history "$SID_A"
run_watchdog "{\"session_id\":\"$SID_A\",\"last_assistant_message\":\"\",\"transcript_path\":\"\",\"cwd\":\"$PROJ\"}"
true > "$H/.claude/history.jsonl"
write_history "$SID_B"
run_watchdog "{\"session_id\":\"$SID_B\",\"last_assistant_message\":\"\",\"transcript_path\":\"\",\"cwd\":\"$PROJ\"}"
COUNT=$(grep -c "$PROJ" "$H/.claude/.active-projects" 2>/dev/null || echo "0")
[ "$COUNT" -eq 1 ] \
  && ok "T29: duplicate CWD in .active-projects deduped — only one line" \
  || fail "T29: dedup in .active-projects" "found $COUNT occurrences, expected 1"

# ════════════════════════════════════════════════════════════════════════════
# Teardown
[ "$KEEP" = "--keep" ] && echo -e "\nSandbox kept: $SB" || rm -rf "$SB"

# Summary
TOTAL=$(( PASS + FAIL + SKIP ))
echo ""
echo -e "${BOLD}Results:${NC} ${GREEN}$PASS passed${NC} / ${RED}$FAIL failed${NC} / ${YLW}$SKIP skipped${NC} / $TOTAL total"
[ "$FAIL" -gt 0 ] && exit 1 || exit 0
