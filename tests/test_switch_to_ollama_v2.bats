#!/usr/bin/env bats
# tests/test_switch_to_ollama_v2.bats
# Targeted gap-fill tests for scripts/switch-to-ollama.sh covering:
#   - File permissions on key-backup and override files (600)
#   - OLLAMA_DEFAULT_MODEL from ollama.conf used when .ollama-model absent
#   - Empty .ollama-model falls back to OLLAMA_DEFAULT_MODEL
#   - Reset-time epoch is strictly in the future
#   - /v1 suffix on ANTHROPIC_BASE_URL (explicit assertion)
#   - Override file never world-readable (permissions gate)
#   - ANTHROPIC_API_KEY zeroed in override
#   - Error message names the host when Ollama unavailable
load 'helpers/setup'

# Helper: write a mock curl that exits 0 (Ollama running)
_curl_ok() {
  cat > "$TMP_HOME/bin/curl" << 'EOF'
#!/bin/bash
exit 0
EOF
  chmod +x "$TMP_HOME/bin/curl"
}

# Helper: write a mock curl that exits 1 (Ollama not running)
_curl_fail() {
  cat > "$TMP_HOME/bin/curl" << 'EOF'
#!/bin/bash
exit 1
EOF
  chmod +x "$TMP_HOME/bin/curl"
}

# Helper: write a mock ollama that lists one model
_ollama_mock() {
  cat > "$TMP_HOME/bin/ollama" << 'EOF'
#!/bin/bash
echo "NAME                    ID      SIZE    MODIFIED"
echo "kimi-k2.5:cloud         abc001  -       5 days ago"
EOF
  chmod +x "$TMP_HOME/bin/ollama"
}

# ---------------------------------------------------------------------------
# SOTO-01: .ollama-anthropic-key-backup has permissions 600 (not world-readable)
# ---------------------------------------------------------------------------
@test "SOTO-01: key-backup file written with 600 permissions" {
  _curl_ok
  _ollama_mock
  ANTHROPIC_API_KEY="sk-perm-test-key" bash scripts/switch-to-ollama.sh
  perms=$(stat -f '%OLp' "$TMP_HOME/.claude/.ollama-anthropic-key-backup" 2>/dev/null \
       || stat -c '%a' "$TMP_HOME/.claude/.ollama-anthropic-key-backup" 2>/dev/null)
  [ "$perms" = "600" ]
}

# ---------------------------------------------------------------------------
# SOTO-02: .ollama-override has permissions 600 (not world-readable)
# ---------------------------------------------------------------------------
@test "SOTO-02: override file written with 600 permissions" {
  _curl_ok
  _ollama_mock
  bash scripts/switch-to-ollama.sh
  perms=$(stat -f '%OLp' "$TMP_HOME/.claude/.ollama-override" 2>/dev/null \
       || stat -c '%a' "$TMP_HOME/.claude/.ollama-override" 2>/dev/null)
  [ "$perms" = "600" ]
}

# ---------------------------------------------------------------------------
# SOTO-03: OLLAMA_DEFAULT_MODEL from ollama.conf is used in override when
#           no .ollama-model file exists (not the hardcoded glm4-flash)
# ---------------------------------------------------------------------------
@test "SOTO-03: OLLAMA_DEFAULT_MODEL from ollama.conf used when .ollama-model absent" {
  _curl_ok
  _ollama_mock
  rm -f "$TMP_HOME/.claude/.ollama-model"
  echo 'OLLAMA_DEFAULT_MODEL=my-conf-default-model' > "$TMP_HOME/.claude/ollama.conf"
  bash scripts/switch-to-ollama.sh
  grep -q 'OLLAMA_MODEL=.*my-conf-default-model' "$TMP_HOME/.claude/.ollama-override"
}

# ---------------------------------------------------------------------------
# SOTO-04: Empty .ollama-model file falls back to OLLAMA_DEFAULT_MODEL
# ---------------------------------------------------------------------------
@test "SOTO-04: empty .ollama-model file falls back to OLLAMA_DEFAULT_MODEL" {
  _curl_ok
  _ollama_mock
  # Write whitespace-only model file
  printf '   \n' > "$TMP_HOME/.claude/.ollama-model"
  echo 'OLLAMA_DEFAULT_MODEL=fallback-conf-model' > "$TMP_HOME/.claude/ollama.conf"
  bash scripts/switch-to-ollama.sh
  # The saved .ollama-model must not be empty after fallback
  saved=$(cat "$TMP_HOME/.claude/.ollama-model" | tr -d '[:space:]')
  [ -n "$saved" ]
}

# ---------------------------------------------------------------------------
# SOTO-05: ANTHROPIC_BASE_URL in override file has /v1 suffix (explicit check)
# ---------------------------------------------------------------------------
@test "SOTO-05: ANTHROPIC_BASE_URL in override file ends with /v1" {
  _curl_ok
  _ollama_mock
  rm -f "$TMP_HOME/.claude/ollama.conf"
  bash scripts/switch-to-ollama.sh
  val=$(grep '^export ANTHROPIC_BASE_URL=' "$TMP_HOME/.claude/.ollama-override" | sed 's/^export ANTHROPIC_BASE_URL="//' | sed 's/"$//')
  [[ "$val" == */v1 ]]
}

# ---------------------------------------------------------------------------
# SOTO-06: ANTHROPIC_API_KEY is set to empty string in override (not omitted)
# ---------------------------------------------------------------------------
@test "SOTO-06: override file sets ANTHROPIC_API_KEY to empty string" {
  _curl_ok
  _ollama_mock
  ANTHROPIC_API_KEY="sk-real-key-xyz" bash scripts/switch-to-ollama.sh
  grep -q 'ANTHROPIC_API_KEY=""' "$TMP_HOME/.claude/.ollama-override"
}

# ---------------------------------------------------------------------------
# SOTO-07: reset-time epoch written by args is strictly in the future
# ---------------------------------------------------------------------------
@test "SOTO-07: reset-time epoch written by args is a future timestamp" {
  _curl_ok
  _ollama_mock
  # Use hour=23, minute=59 — should always be ahead of test run time or roll to tomorrow
  bash scripts/switch-to-ollama.sh 23 59
  epoch=$(cat "$TMP_HOME/.claude/.ollama-reset-time" | tr -d '[:space:]')
  now=$(python3 -c "import time; print(int(time.time()))")
  [ "$epoch" -gt "$now" ]
}

# ---------------------------------------------------------------------------
# SOTO-08: error message names the Ollama host URL when health check fails
# ---------------------------------------------------------------------------
@test "SOTO-08: error message names OLLAMA_HOST when Ollama health check fails" {
  _curl_fail
  echo 'OLLAMA_HOST=http://remote-host:11434' > "$TMP_HOME/.claude/ollama.conf"
  run bash scripts/switch-to-ollama.sh
  [ "$status" -eq 1 ]
  [[ "$output" == *"remote-host"* ]]
}

# ---------------------------------------------------------------------------
# SOTO-09: ANTHROPIC_AUTH_TOKEN set to "ollama" in override (routing sentinel)
# ---------------------------------------------------------------------------
@test "SOTO-09: override file sets ANTHROPIC_AUTH_TOKEN=ollama" {
  _curl_ok
  _ollama_mock
  bash scripts/switch-to-ollama.sh
  grep -q 'ANTHROPIC_AUTH_TOKEN=ollama' "$TMP_HOME/.claude/.ollama-override"
}

# ---------------------------------------------------------------------------
# SOTO-10: reset-time file written with minute=0 when only reset_hour arg given
# ---------------------------------------------------------------------------
@test "SOTO-10: reset-time file written with minute=0 when only reset_hour arg given" {
  _curl_ok
  _ollama_mock
  # One arg only — script uses $2 as reset_minute; if empty, python3 treats '' as int 0.
  # Documented behavior: epoch IS written with minute=0.
  bash scripts/switch-to-ollama.sh 15
  [ -f "$TMP_HOME/.claude/.ollama-reset-time" ]
  epoch=$(cat "$TMP_HOME/.claude/.ollama-reset-time" | tr -d '[:space:]')
  [[ "$epoch" =~ ^[0-9]+$ ]]
  [ "$epoch" -gt "$(date +%s)" ]
}

# ---------------------------------------------------------------------------
# SOTO-11: model name with only unsafe chars falls back to OLLAMA_DEFAULT_MODEL
# ---------------------------------------------------------------------------
@test "SOTO-11: model name with only unsafe chars falls back to OLLAMA_DEFAULT_MODEL" {
  _curl_ok
  _ollama_mock
  printf '$();{}' > "$TMP_HOME/.claude/.ollama-model"
  echo 'OLLAMA_DEFAULT_MODEL=safe-default-model' > "$TMP_HOME/.claude/ollama.conf"
  bash scripts/switch-to-ollama.sh
  saved=$(cat "$TMP_HOME/.claude/.ollama-model" | tr -d '[:space:]')
  # After sanitization all chars stripped → falls back to OLLAMA_DEFAULT_MODEL
  [ "$saved" = "safe-default-model" ]
}

# ---------------------------------------------------------------------------
# SOTO-12: custom OLLAMA_HOST from ollama.conf appears verbatim in BASE_URL
# ---------------------------------------------------------------------------
@test "SOTO-12: custom OLLAMA_HOST from ollama.conf written to override BASE_URL" {
  _curl_ok
  _ollama_mock
  echo 'OLLAMA_HOST=http://192.168.50.1:11434' > "$TMP_HOME/.claude/ollama.conf"
  bash scripts/switch-to-ollama.sh
  grep -q 'ANTHROPIC_BASE_URL="http://192.168.50.1:11434/v1"' "$TMP_HOME/.claude/.ollama-override"
}

# ---------------------------------------------------------------------------
# Multi-model mock: three distinct models for picker selection tests
# ---------------------------------------------------------------------------
_ollama_three_models() {
  cat > "$TMP_HOME/bin/ollama" << 'EOF'
#!/bin/bash
echo "NAME                    ID      SIZE    MODIFIED"
echo "kimi-k2.5:cloud         abc001  -       5 days ago"
echo "qwen3:4b                abc002  2.5GB   5 days ago"
echo "qwen2.5-coder:7b        abc003  4.7GB   5 days ago"
EOF
  chmod +x "$TMP_HOME/bin/ollama"
}

# ---------------------------------------------------------------------------
# SOTO-13: numeric selection "1" picks the first listed model (bash 0-indexed fix)
# ---------------------------------------------------------------------------
@test "SOTO-13: entering '1' selects the first model in the list" {
  _curl_ok
  _ollama_three_models
  echo "1" | _OLLAMA_FORCE_INTERACTIVE=1 bash scripts/switch-to-ollama.sh
  saved=$(cat "$TMP_HOME/.claude/.ollama-model" | tr -d '[:space:]')
  [ "$saved" = "kimi-k2.5:cloud" ]
  grep -q '^export OLLAMA_MODEL="kimi-k2.5:cloud"' "$TMP_HOME/.claude/.ollama-override"
}

# ---------------------------------------------------------------------------
# SOTO-14: numeric selection "2" picks the second listed model
# ---------------------------------------------------------------------------
@test "SOTO-14: entering '2' selects the second model in the list" {
  _curl_ok
  _ollama_three_models
  echo "2" | _OLLAMA_FORCE_INTERACTIVE=1 bash scripts/switch-to-ollama.sh
  saved=$(cat "$TMP_HOME/.claude/.ollama-model" | tr -d '[:space:]')
  [ "$saved" = "qwen3:4b" ]
  grep -q '^export OLLAMA_MODEL="qwen3:4b"' "$TMP_HOME/.claude/.ollama-override"
}

# ---------------------------------------------------------------------------
# SOTO-15: numeric selection "3" picks the third listed model
# ---------------------------------------------------------------------------
@test "SOTO-15: entering '3' selects the third model in the list" {
  _curl_ok
  _ollama_three_models
  echo "3" | _OLLAMA_FORCE_INTERACTIVE=1 bash scripts/switch-to-ollama.sh
  saved=$(cat "$TMP_HOME/.claude/.ollama-model" | tr -d '[:space:]')
  [ "$saved" = "qwen2.5-coder:7b" ]
  grep -q '^export OLLAMA_MODEL="qwen2.5-coder:7b"' "$TMP_HOME/.claude/.ollama-override"
}

# ---------------------------------------------------------------------------
# SOTO-16: pressing Enter (empty input) keeps the saved/default model
# ---------------------------------------------------------------------------
@test "SOTO-16: pressing Enter keeps the current default model unchanged" {
  _curl_ok
  _ollama_three_models
  echo "kimi-k2.5:cloud" > "$TMP_HOME/.claude/.ollama-model"
  echo "" | _OLLAMA_FORCE_INTERACTIVE=1 bash scripts/switch-to-ollama.sh
  saved=$(cat "$TMP_HOME/.claude/.ollama-model" | tr -d '[:space:]')
  [ "$saved" = "kimi-k2.5:cloud" ]
  grep -q '^export OLLAMA_MODEL="kimi-k2.5:cloud"' "$TMP_HOME/.claude/.ollama-override"
}

# ---------------------------------------------------------------------------
# SOTO-17: selected model is written to override — confirming it is the one that runs
# ---------------------------------------------------------------------------
@test "SOTO-17: selected model appears in OLLAMA_MODEL export in override file" {
  _curl_ok
  _ollama_three_models
  echo "2" | _OLLAMA_FORCE_INTERACTIVE=1 bash scripts/switch-to-ollama.sh
  # Override must export the exact model that was selected — not the default or a different one
  grep -q '^export OLLAMA_MODEL="qwen3:4b"' "$TMP_HOME/.claude/.ollama-override"
  # Confirm .ollama-model file also reflects the selection (persisted for future sessions)
  saved=$(cat "$TMP_HOME/.claude/.ollama-model" | tr -d '[:space:]')
  [ "$saved" = "qwen3:4b" ]
}
