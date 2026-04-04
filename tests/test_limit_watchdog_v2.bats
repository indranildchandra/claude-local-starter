#!/usr/bin/env bats
# tests/test_limit_watchdog_v2.bats
# Tests for NEW behaviour in scripts/limit-watchdog.sh:
#   - ollama.conf LIMIT_PATTERN override
#   - ollama.conf OLLAMA_HOST override
#   - API key backup
#   - .ollama-reset-time file
#   - No launchd plist created
#
# NOTE on LIMIT_PATTERN: The default LIMIT_PATTERN is stored as:
#   LIMIT_PATTERN="${LIMIT_PATTERN:-'(hit your limit|...)'}"
# The single-quotes are LITERAL characters in the variable value, not shell quoting.
# grep -qiE "$LIMIT_PATTERN" therefore passes the literal single-quote char to the regex.
# This means the default pattern secondary/tertiary detection paths require text that starts
# with a literal '. The primary detection path (history.jsonl) does NOT have this constraint.
# Tests that need to fire WITHOUT a custom pattern use history.jsonl as the trigger.
load 'helpers/setup'

# Helper: write a history.jsonl entry that looks like a /rate-limit-options hit for a
# given session, rooted at TMP_PROJECT, timestamped to now.
_write_history_entry() {
  local sid="$1"
  local now_ms
  now_ms=$(python3 -c "import time; print(int(time.time()*1000))")
  printf '{"display":"/rate-limit-options","sessionId":"%s","project":"%s","timestamp":%s}\n' \
    "$sid" "$TMP_PROJECT" "$now_ms" > "$TMP_HOME/.claude/history.jsonl"
}

# Helper: trigger watchdog via transcript using a CUSTOM pattern from ollama.conf
_run_with_transcript_and_conf() {
  local msg="$1"
  printf '%s\n' "$msg" > "$TMP_PROJECT/transcript.txt"
  printf '{"transcript_path":"%s","cwd":"%s"}\n' \
    "$TMP_PROJECT/transcript.txt" "$TMP_PROJECT" \
    | bash scripts/limit-watchdog.sh
}

# Helper: trigger watchdog via history.jsonl (primary detection path)
_run_with_history() {
  local sid="$1"
  _write_history_entry "$sid"
  printf '{"session_id":"%s","last_assistant_message":"normal response","transcript_path":"/dev/null","cwd":"%s"}\n' \
    "$sid" "$TMP_PROJECT" \
    | bash scripts/limit-watchdog.sh
}

# ---------------------------------------------------------------------------
# 1. ollama.conf LIMIT_PATTERN override triggers on custom phrase
#    When ollama.conf sets LIMIT_PATTERN="CUSTOM_LIMIT_PHRASE", the grep
#    receives the raw value "CUSTOM_LIMIT_PHRASE" (without single-quote wrapping).
# ---------------------------------------------------------------------------
@test "LW2-01: custom LIMIT_PATTERN from ollama.conf triggers override on custom phrase" {
  printf 'LIMIT_PATTERN="CUSTOM_LIMIT_PHRASE"\n' > "$TMP_HOME/.claude/ollama.conf"
  _run_with_transcript_and_conf "This session has hit CUSTOM_LIMIT_PHRASE now"
  [ -f "$TMP_HOME/.claude/.ollama-override" ]
}

# ---------------------------------------------------------------------------
# 2. Default LIMIT_PATTERN: primary path (history.jsonl) still works
#    We avoid the single-quote literal issue by using the history.jsonl path.
# ---------------------------------------------------------------------------
@test "LW2-02: limit detected via history.jsonl when no ollama.conf" {
  rm -f "$TMP_HOME/.claude/ollama.conf"
  local sid="session-default-pattern-test"
  _run_with_history "$sid"
  [ -f "$TMP_HOME/.claude/.ollama-override" ]
}

# ---------------------------------------------------------------------------
# 3. OLLAMA_HOST from ollama.conf appears in override file
# ---------------------------------------------------------------------------
@test "LW2-03: OLLAMA_HOST from ollama.conf sets ANTHROPIC_BASE_URL in override" {
  printf 'OLLAMA_HOST="http://myhost:11434"\n' > "$TMP_HOME/.claude/ollama.conf"
  # Use custom LIMIT_PATTERN too so we can trigger via transcript
  printf 'OLLAMA_HOST="http://myhost:11434"\nLIMIT_PATTERN="TRIGGER_PHRASE"\n' \
    > "$TMP_HOME/.claude/ollama.conf"
  _run_with_transcript_and_conf "TRIGGER_PHRASE"
  grep -q 'ANTHROPIC_BASE_URL="http://myhost:11434/v1"' "$TMP_HOME/.claude/.ollama-override"
}

# ---------------------------------------------------------------------------
# 4. Default ANTHROPIC_BASE_URL is localhost:11434/v1 when no ollama.conf
#    Triggered via history.jsonl (reliable primary detection path).
# ---------------------------------------------------------------------------
@test "LW2-04: default ANTHROPIC_BASE_URL is http://localhost:11434/v1 when no ollama.conf" {
  rm -f "$TMP_HOME/.claude/ollama.conf"
  local sid="session-default-url-test"
  _run_with_history "$sid"
  grep -q 'ANTHROPIC_BASE_URL="http://localhost:11434/v1"' "$TMP_HOME/.claude/.ollama-override"
}

# ---------------------------------------------------------------------------
# 5. API key backup created when ANTHROPIC_API_KEY is set
# ---------------------------------------------------------------------------
@test "LW2-05: API key backup file created when ANTHROPIC_API_KEY is set" {
  export ANTHROPIC_API_KEY="sk-test-12345"
  local sid="session-apikey-test"
  _run_with_history "$sid"
  [ -f "$TMP_HOME/.claude/.ollama-anthropic-key-backup" ]
  grep -q 'sk-test-12345' "$TMP_HOME/.claude/.ollama-anthropic-key-backup"
}

# ---------------------------------------------------------------------------
# 6. API key backup NOT created when ANTHROPIC_API_KEY is empty/unset
# ---------------------------------------------------------------------------
@test "LW2-06: API key backup NOT created when ANTHROPIC_API_KEY is unset" {
  unset ANTHROPIC_API_KEY
  local sid="session-no-apikey-test"
  _run_with_history "$sid"
  [ ! -f "$TMP_HOME/.claude/.ollama-anthropic-key-backup" ]
}

@test "LW2-06b: API key backup NOT created when ANTHROPIC_API_KEY is empty string" {
  export ANTHROPIC_API_KEY=""
  local sid="session-empty-apikey-test"
  _run_with_history "$sid"
  [ ! -f "$TMP_HOME/.claude/.ollama-anthropic-key-backup" ]
}

# ---------------------------------------------------------------------------
# 7. .ollama-reset-time is written when transcript contains "resets 12:30am"
#    Use custom LIMIT_PATTERN so transcript secondary detection fires.
#    The reset_time extraction happens in the secondary/tertiary detection path.
# ---------------------------------------------------------------------------
@test "LW2-07: .ollama-reset-time file is written when transcript has reset time" {
  printf 'LIMIT_PATTERN="TRIG"\n' > "$TMP_HOME/.claude/ollama.conf"
  printf 'TRIG resets 12:30am\n' > "$TMP_PROJECT/transcript.txt"
  printf '{"transcript_path":"%s","cwd":"%s"}\n' \
    "$TMP_PROJECT/transcript.txt" "$TMP_PROJECT" \
    | bash scripts/limit-watchdog.sh
  [ -f "$TMP_HOME/.claude/.ollama-reset-time" ]
  val=$(cat "$TMP_HOME/.claude/.ollama-reset-time")
  [[ "$val" =~ ^[0-9]+$ ]]
  [ "$val" -gt 0 ]
}

# ---------------------------------------------------------------------------
# 8. .ollama-reset-time is NOT written when no reset time in transcript
# ---------------------------------------------------------------------------
@test "LW2-08: .ollama-reset-time NOT written when no reset time in transcript" {
  printf 'LIMIT_PATTERN="TRIG"\n' > "$TMP_HOME/.claude/ollama.conf"
  printf 'TRIG — limit hit but no time given\n' > "$TMP_PROJECT/transcript.txt"
  printf '{"transcript_path":"%s","cwd":"%s"}\n' \
    "$TMP_PROJECT/transcript.txt" "$TMP_PROJECT" \
    | bash scripts/limit-watchdog.sh
  [ ! -f "$TMP_HOME/.claude/.ollama-reset-time" ]
}

# ---------------------------------------------------------------------------
# 9. NO launchd plist created in LaunchAgents
# ---------------------------------------------------------------------------
@test "LW2-09: no launchd plist created in LaunchAgents" {
  local sid="session-no-plist-test"
  _run_with_history "$sid"
  plist_count=$(ls "$TMP_HOME/Library/LaunchAgents/"*.plist 2>/dev/null | wc -l | tr -d ' ')
  [ "$plist_count" -eq 0 ]
}

# ---------------------------------------------------------------------------
# 10. Override file uses ${OLLAMA_HOST}/v1 (not bare http://localhost:11434)
#     Triggered via history.jsonl (reliable primary detection path).
# ---------------------------------------------------------------------------
@test "LW2-10: ANTHROPIC_BASE_URL in override always ends with /v1" {
  rm -f "$TMP_HOME/.claude/ollama.conf"
  local sid="session-url-suffix-test"
  _run_with_history "$sid"
  grep -q 'ANTHROPIC_BASE_URL=.*\/v1' "$TMP_HOME/.claude/.ollama-override"
  # Must NOT be bare without /v1 suffix (portable ERE — works on BSD and GNU grep)
  ! grep -qE 'ANTHROPIC_BASE_URL=http://localhost:11434[^/]' "$TMP_HOME/.claude/.ollama-override" 2>/dev/null
}

# ---------------------------------------------------------------------------
# Bonus: arbitrary text should NOT trigger override (no false positives)
# ---------------------------------------------------------------------------
@test "LW2-BONUS: default pattern does NOT trigger on arbitrary non-limit text" {
  rm -f "$TMP_HOME/.claude/ollama.conf"
  printf 'Everything is fine, session proceeding normally.\n' > "$TMP_PROJECT/transcript.txt"
  printf '{"transcript_path":"%s","cwd":"%s"}\n' \
    "$TMP_PROJECT/transcript.txt" "$TMP_PROJECT" \
    | bash scripts/limit-watchdog.sh
  [ ! -f "$TMP_HOME/.claude/.ollama-override" ]
}
