#!/usr/bin/env bats
# tests/test_limit_watchdog.bats
load 'helpers/setup'

# --- Detection ---
@test "exits 0 silently when stdin JSON has no transcript_path" {
  echo '{}' | bash scripts/limit-watchdog.sh
  [ $? -eq 0 ]
}

@test "exits 0 silently when transcript has no limit message" {
  echo "normal session output" > "$TMP_PROJECT/transcript.txt"
  echo "{\"transcript_path\":\"$TMP_PROJECT/transcript.txt\",\"cwd\":\"$TMP_PROJECT\"}" \
    | bash scripts/limit-watchdog.sh
  [ ! -f "$TMP_HOME/.claude/.ollama-override" ]
}

@test "detects 'hit your limit' phrase in transcript" {
  echo "You've hit your limit · resets 12:30am" > "$TMP_PROJECT/transcript.txt"
  echo "{\"transcript_path\":\"$TMP_PROJECT/transcript.txt\",\"cwd\":\"$TMP_PROJECT\"}" \
    | bash scripts/limit-watchdog.sh
  [ -f "$TMP_HOME/.claude/.ollama-override" ]
}

@test "detects 'resets HH:MMam' pattern and extracts time" {
  echo "Usage limit reached. resets 1:45am" > "$TMP_PROJECT/transcript.txt"
  echo "{\"transcript_path\":\"$TMP_PROJECT/transcript.txt\",\"cwd\":\"$TMP_PROJECT\"}" \
    | bash scripts/limit-watchdog.sh
  [ -f "$TMP_HOME/.claude/.ollama-override" ]
}

# --- Override file contents ---
@test "writes ANTHROPIC_AUTH_TOKEN=ollama to override file" {
  echo "hit your limit · resets 12:30am" > "$TMP_PROJECT/transcript.txt"
  echo "{\"transcript_path\":\"$TMP_PROJECT/transcript.txt\",\"cwd\":\"$TMP_PROJECT\"}" \
    | bash scripts/limit-watchdog.sh
  grep -q 'ANTHROPIC_AUTH_TOKEN=ollama' "$TMP_HOME/.claude/.ollama-override"
}

@test "writes ANTHROPIC_API_KEY as explicitly empty string (not unset)" {
  echo "hit your limit · resets 12:30am" > "$TMP_PROJECT/transcript.txt"
  echo "{\"transcript_path\":\"$TMP_PROJECT/transcript.txt\",\"cwd\":\"$TMP_PROJECT\"}" \
    | bash scripts/limit-watchdog.sh
  grep -q 'ANTHROPIC_API_KEY=""' "$TMP_HOME/.claude/.ollama-override"
}

@test "writes ANTHROPIC_BASE_URL pointing to localhost:11434" {
  echo "hit your limit · resets 12:30am" > "$TMP_PROJECT/transcript.txt"
  echo "{\"transcript_path\":\"$TMP_PROJECT/transcript.txt\",\"cwd\":\"$TMP_PROJECT\"}" \
    | bash scripts/limit-watchdog.sh
  grep -q 'ANTHROPIC_BASE_URL="http://localhost:11434' "$TMP_HOME/.claude/.ollama-override"
}

# --- Handover marker ---
@test "writes tasks/.session-handover inside project CWD" {
  echo "hit your limit · resets 12:30am" > "$TMP_PROJECT/transcript.txt"
  echo "{\"transcript_path\":\"$TMP_PROJECT/transcript.txt\",\"cwd\":\"$TMP_PROJECT\"}" \
    | bash scripts/limit-watchdog.sh
  [ -f "$TMP_PROJECT/tasks/.session-handover" ]
}

@test "creates tasks/ dir if it does not exist" {
  rm -rf "$TMP_PROJECT/tasks"
  echo "hit your limit · resets 12:30am" > "$TMP_PROJECT/transcript.txt"
  echo "{\"transcript_path\":\"$TMP_PROJECT/transcript.txt\",\"cwd\":\"$TMP_PROJECT\"}" \
    | bash scripts/limit-watchdog.sh
  [ -d "$TMP_PROJECT/tasks" ]
  [ -f "$TMP_PROJECT/tasks/.session-handover" ]
}

# --- Scheduling ---
@test "proceeds without error when launchctl is unavailable" {
  # Hide launchctl by removing the mock — PATH no longer has a launchctl binary
  rm -f "$TMP_HOME/bin/launchctl"
  echo "hit your limit · resets 12:30am" > "$TMP_PROJECT/transcript.txt"
  echo "{\"transcript_path\":\"$TMP_PROJECT/transcript.txt\",\"cwd\":\"$TMP_PROJECT\"}" \
    | bash scripts/limit-watchdog.sh
  [ $? -eq 0 ]
}

# --- Model name sanitization ---
@test "LW-SAN-01: unsafe model name is stripped of shell-injection characters" {
  printf 'bad model; rm -rf /' > "$TMP_HOME/.claude/.ollama-model"
  echo "hit your limit · resets 12:30am" > "$TMP_PROJECT/transcript.txt"
  echo "{\"transcript_path\":\"$TMP_PROJECT/transcript.txt\",\"cwd\":\"$TMP_PROJECT\"}" \
    | bash scripts/limit-watchdog.sh
  # The override file must NOT contain semicolons, spaces, or forward-slashes in OLLAMA_MODEL value
  val=$(grep '^export OLLAMA_MODEL=' "$TMP_HOME/.claude/.ollama-override" | sed 's/^export OLLAMA_MODEL=//' | tr -d '"')
  [[ "$val" != *";"* ]]
  [[ "$val" != *" "* ]]
  [[ "$val" != *"/"* ]]
}

@test "LW-SAN-02: whitespace-only model name falls back to kimi-k2.5:cloud" {
  printf '   \n\t\n' > "$TMP_HOME/.claude/.ollama-model"
  echo "hit your limit · resets 12:30am" > "$TMP_PROJECT/transcript.txt"
  echo "{\"transcript_path\":\"$TMP_PROJECT/transcript.txt\",\"cwd\":\"$TMP_PROJECT\"}" \
    | bash scripts/limit-watchdog.sh
  grep -q 'OLLAMA_MODEL="kimi-k2.5:cloud"' "$TMP_HOME/.claude/.ollama-override"
}

@test "LW-SAN-03: model name with only unsafe chars falls back to kimi-k2.5:cloud" {
  printf '$();{}' > "$TMP_HOME/.claude/.ollama-model"
  echo "hit your limit · resets 12:30am" > "$TMP_PROJECT/transcript.txt"
  echo "{\"transcript_path\":\"$TMP_PROJECT/transcript.txt\",\"cwd\":\"$TMP_PROJECT\"}" \
    | bash scripts/limit-watchdog.sh
  grep -q 'OLLAMA_MODEL="kimi-k2.5:cloud"' "$TMP_HOME/.claude/.ollama-override"
}

# --- history.jsonl primary detection ---
@test "LW-HIST-01: detects limit via history.jsonl /rate-limit-options entry (primary path)" {
  # Write a synthetic history.jsonl with a /rate-limit-options entry for our session
  local sid="test-session-abc123"
  local now_ms
  now_ms=$(python3 -c "import time; print(int(time.time()*1000))")
  printf '{"display":"/rate-limit-options","sessionId":"%s","project":"%s","timestamp":%s}\n' \
    "$sid" "$TMP_PROJECT" "$now_ms" > "$TMP_HOME/.claude/history.jsonl"
  # stdin JSON has NO limit phrase — only the history.jsonl entry should trigger
  echo "{\"session_id\":\"$sid\",\"last_assistant_message\":\"normal response\",\"transcript_path\":\"/dev/null\",\"cwd\":\"$TMP_PROJECT\"}" \
    | bash scripts/limit-watchdog.sh
  [ -f "$TMP_HOME/.claude/.ollama-override" ]
}

@test "LW-HIST-02: does NOT trigger if history.jsonl entry is for a different session" {
  local sid_other="other-session-xyz"
  local sid_ours="our-session-abc"
  local now_ms
  now_ms=$(python3 -c "import time; print(int(time.time()*1000))")
  # Entry belongs to a different session
  printf '{"display":"/rate-limit-options","sessionId":"%s","project":"%s","timestamp":%s}\n' \
    "$sid_other" "$TMP_PROJECT" "$now_ms" > "$TMP_HOME/.claude/history.jsonl"
  # Our session has no limit phrase and no matching history entry
  echo "{\"session_id\":\"$sid_ours\",\"last_assistant_message\":\"normal response\",\"transcript_path\":\"/dev/null\",\"cwd\":\"$TMP_PROJECT\"}" \
    | bash scripts/limit-watchdog.sh
  [ ! -f "$TMP_HOME/.claude/.ollama-override" ]
}

@test "LW-HIST-03: does NOT trigger if history.jsonl entry is older than 120 seconds" {
  local sid="test-session-old"
  local old_ms
  # 200 seconds ago — outside the 120s detection window
  old_ms=$(python3 -c "import time; print(int(time.time()*1000) - 200000)")
  printf '{"display":"/rate-limit-options","sessionId":"%s","project":"%s","timestamp":%s}\n' \
    "$sid" "$TMP_PROJECT" "$old_ms" > "$TMP_HOME/.claude/history.jsonl"
  echo "{\"session_id\":\"$sid\",\"last_assistant_message\":\"normal response\",\"transcript_path\":\"/dev/null\",\"cwd\":\"$TMP_PROJECT\"}" \
    | bash scripts/limit-watchdog.sh
  [ ! -f "$TMP_HOME/.claude/.ollama-override" ]
}
