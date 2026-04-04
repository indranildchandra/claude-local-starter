#!/usr/bin/env bats
# tests/test_switch_scripts_v2.bats
# Tests for switch-to-anthropic.sh and switch-to-ollama.sh
load 'helpers/setup'

# ============================================================
# switch-to-anthropic.sh
# ============================================================

@test "STA-V2-01: removes .ollama-override when it exists" {
  touch "$TMP_HOME/.claude/.ollama-override"
  HOME="$TMP_HOME" bash scripts/switch-to-anthropic.sh
  [ ! -f "$TMP_HOME/.claude/.ollama-override" ]
}

@test "STA-V2-02: removes .ollama-reset-time when it exists" {
  touch "$TMP_HOME/.claude/.ollama-reset-time"
  HOME="$TMP_HOME" bash scripts/switch-to-anthropic.sh
  [ ! -f "$TMP_HOME/.claude/.ollama-reset-time" ]
}

@test "STA-V2-03: removes .ollama-anthropic-key-backup after restoring key" {
  echo "sk-test-key-abc123" > "$TMP_HOME/.claude/.ollama-anthropic-key-backup"
  HOME="$TMP_HOME" bash scripts/switch-to-anthropic.sh
  [ ! -f "$TMP_HOME/.claude/.ollama-anthropic-key-backup" ]
}

@test "STA-V2-04: restores ANTHROPIC_API_KEY from backup file" {
  echo "sk-restored-key-xyz" > "$TMP_HOME/.claude/.ollama-anthropic-key-backup"
  # Source in a subshell; the final echo emits the key on its own line after script output.
  # We grep for the exact key value in the combined output.
  result=$(HOME="$TMP_HOME" bash -c 'source scripts/switch-to-anthropic.sh 2>/dev/null; echo "APIKEY:$ANTHROPIC_API_KEY"')
  echo "$result" | grep -q 'APIKEY:sk-restored-key-xyz'
}

@test "STA-V2-05: prints tip about switch-back when run directly (not sourced)" {
  run bash scripts/switch-to-anthropic.sh
  [[ "$output" == *"switch-back"* ]]
}

@test "STA-V2-06: does not fail when no backup file exists" {
  run bash scripts/switch-to-anthropic.sh
  [ "$status" -eq 0 ]
}

@test "STA-V2-07: does not fail when override file does not exist" {
  [ ! -f "$TMP_HOME/.claude/.ollama-override" ]
  run bash scripts/switch-to-anthropic.sh
  [ "$status" -eq 0 ]
}

@test "STA-V2-08: removes .pre-switchback marker if present" {
  touch "$TMP_HOME/.claude/.pre-switchback"
  HOME="$TMP_HOME" bash scripts/switch-to-anthropic.sh
  [ ! -f "$TMP_HOME/.claude/.pre-switchback" ]
}

@test "STA-V2-09: exits 0 with all files present simultaneously" {
  touch "$TMP_HOME/.claude/.ollama-override"
  touch "$TMP_HOME/.claude/.ollama-reset-time"
  echo "sk-key-multi" > "$TMP_HOME/.claude/.ollama-anthropic-key-backup"
  run bash scripts/switch-to-anthropic.sh
  [ "$status" -eq 0 ]
  [ ! -f "$TMP_HOME/.claude/.ollama-override" ]
  [ ! -f "$TMP_HOME/.claude/.ollama-reset-time" ]
  [ ! -f "$TMP_HOME/.claude/.ollama-anthropic-key-backup" ]
}

# ============================================================
# switch-to-ollama.sh
# ============================================================

# Helper: write a mock curl that exits 1 (Ollama not running)
_write_curl_fail() {
  cat > "$TMP_HOME/bin/curl" << 'EOF'
#!/bin/bash
exit 1
EOF
  chmod +x "$TMP_HOME/bin/curl"
}

# Helper: write a mock curl that exits 0 (Ollama running)
_write_curl_ok() {
  cat > "$TMP_HOME/bin/curl" << 'EOF'
#!/bin/bash
exit 0
EOF
  chmod +x "$TMP_HOME/bin/curl"
}

# Helper: write a mock ollama that lists one model
_write_ollama_mock() {
  cat > "$TMP_HOME/bin/ollama" << 'EOF'
#!/bin/bash
echo "NAME            ID      SIZE    MODIFIED"
echo "kimi-k2.5:cloud    abc001  -       5 days ago"
EOF
  chmod +x "$TMP_HOME/bin/ollama"
}

@test "STO-V2-01: exits 1 with error message when Ollama not running" {
  _write_curl_fail
  run bash scripts/switch-to-ollama.sh
  [ "$status" -eq 1 ]
  [[ "$output" == *"Ollama is not running"* ]]
}

@test "STO-V2-02: writes .ollama-override when Ollama is running (non-interactive)" {
  _write_curl_ok
  _write_ollama_mock
  # stdin not a tty in bats — non-interactive path taken automatically
  bash scripts/switch-to-ollama.sh
  [ -f "$TMP_HOME/.claude/.ollama-override" ]
}

@test "STO-V2-03: override file contains ANTHROPIC_AUTH_TOKEN=ollama" {
  _write_curl_ok
  _write_ollama_mock
  bash scripts/switch-to-ollama.sh
  grep -q 'ANTHROPIC_AUTH_TOKEN=ollama' "$TMP_HOME/.claude/.ollama-override"
}

@test "STO-V2-04: override ANTHROPIC_BASE_URL uses OLLAMA_HOST from ollama.conf" {
  _write_curl_ok
  _write_ollama_mock
  # Write ollama.conf with a custom host
  mkdir -p "$TMP_HOME/.claude"
  echo 'OLLAMA_HOST=http://192.168.1.50:11434' > "$TMP_HOME/.claude/ollama.conf"
  bash scripts/switch-to-ollama.sh
  grep -q 'ANTHROPIC_BASE_URL="http://192.168.1.50:11434/v1"' "$TMP_HOME/.claude/.ollama-override"
}

@test "STO-V2-05: backs up ANTHROPIC_API_KEY to .ollama-anthropic-key-backup when key is set" {
  _write_curl_ok
  _write_ollama_mock
  ANTHROPIC_API_KEY="sk-backup-test-key" bash scripts/switch-to-ollama.sh
  [ -f "$TMP_HOME/.claude/.ollama-anthropic-key-backup" ]
  content=$(cat "$TMP_HOME/.claude/.ollama-anthropic-key-backup")
  [ "$content" = "sk-backup-test-key" ]
}

@test "STO-V2-06: accepts reset_hour and reset_minute as args and writes .ollama-reset-time" {
  _write_curl_ok
  _write_ollama_mock
  # Pass a time far in the future (hour=23, minute=59)
  bash scripts/switch-to-ollama.sh 23 59
  [ -f "$TMP_HOME/.claude/.ollama-reset-time" ]
  epoch=$(cat "$TMP_HOME/.claude/.ollama-reset-time" | tr -d '[:space:]')
  # Verify it's a valid epoch integer
  [[ "$epoch" =~ ^[0-9]+$ ]]
}

@test "STO-V2-07: sanitizes model name — strips special chars to safe chars only" {
  _write_curl_ok
  _write_ollama_mock
  # Pre-write a .ollama-model with unsafe characters
  echo 'bad model; rm -rf /' > "$TMP_HOME/.claude/.ollama-model"
  bash scripts/switch-to-ollama.sh
  saved=$(cat "$TMP_HOME/.claude/.ollama-model")
  # Must not contain spaces, semicolons, slashes, or other shell-injection chars
  [[ "$saved" != *";"* ]]
  [[ "$saved" != *" "* ]]
  [[ "$saved" != *"/"* ]]
  [[ "$saved" != *"$"* ]]
}

@test "STO-V2-08: does not write .ollama-reset-time when no args given (non-interactive)" {
  _write_curl_ok
  _write_ollama_mock
  # No args, non-interactive (bats stdin is not a tty)
  bash scripts/switch-to-ollama.sh
  [ ! -f "$TMP_HOME/.claude/.ollama-reset-time" ]
}

@test "STO-V2-09: does not back up API key when ANTHROPIC_API_KEY is unset" {
  _write_curl_ok
  _write_ollama_mock
  unset ANTHROPIC_API_KEY
  bash scripts/switch-to-ollama.sh
  [ ! -f "$TMP_HOME/.claude/.ollama-anthropic-key-backup" ]
}

@test "STO-V2-10: override file ANTHROPIC_BASE_URL defaults to localhost:11434 when no conf" {
  _write_curl_ok
  _write_ollama_mock
  # No ollama.conf — should default to localhost:11434
  rm -f "$TMP_HOME/.claude/ollama.conf"
  bash scripts/switch-to-ollama.sh
  grep -q 'ANTHROPIC_BASE_URL="http://localhost:11434/v1"' "$TMP_HOME/.claude/.ollama-override"
}
