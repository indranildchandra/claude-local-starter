#!/usr/bin/env bats
# tests/test_shell_functions.bats
# Unit tests for claude(), switch-back, and _claude_pick_model shell functions.
# Tests cover the NEXT_STEPS.md T1-T8, T11 scenarios.

SHELL_FN="$BATS_TEST_DIRNAME/helpers/shell_functions.sh"

setup() {
  TMP_HOME=$(mktemp -d)
  export TMP_HOME
  export HOME="$TMP_HOME"
  mkdir -p "$TMP_HOME/.claude"
  mkdir -p "$TMP_HOME/bin"
  export PATH="$TMP_HOME/bin:$PATH"
  export SWITCHBACK_DELAY=0

  # Mock: claude binary (called by `command claude` inside the wrapper)
  printf '#!/bin/bash\necho "MOCK_CLAUDE: $*"\nexit 0\n' > "$TMP_HOME/bin/claude"
  chmod +x "$TMP_HOME/bin/claude"

  # Mock: osascript (no-op notification)
  printf '#!/bin/bash\nexit 0\n' > "$TMP_HOME/bin/osascript"
  chmod +x "$TMP_HOME/bin/osascript"

  # Mock: curl — default FAIL (Ollama not running)
  printf '#!/bin/bash\nexit 1\n' > "$TMP_HOME/bin/curl"
  chmod +x "$TMP_HOME/bin/curl"

  # Mock: ollama — default returns header only (no models)
  printf '#!/bin/bash\necho "NAME    ID    SIZE"\nexit 0\n' > "$TMP_HOME/bin/ollama"
  chmod +x "$TMP_HOME/bin/ollama"
}

teardown() {
  rm -rf "$TMP_HOME"
}

# ── Helper ───────────────────────────────────────────────────────────────────
# Run a function from shell_functions.sh in a subshell with optional stdin input.
# Usage: _run_fn "stdin_input" "bash_code_to_run_after_source"
_run_fn() {
  local stdin_input="$1"
  local code="$2"
  # PATH: $TMP_HOME and $PATH expand at definition time (outer shell, double-quoted string).
  # Inner bash gets a literal resolved PATH including /usr/bin, /bin, etc.
  # Mock binaries in $TMP_HOME/bin take precedence; system commands remain available.
  bash -c "
    HOME='$TMP_HOME'
    PATH='$TMP_HOME/bin:$PATH'
    source '$SHELL_FN'
    $code
  " <<< "$stdin_input"
}

# ── SF-01: No override → Anthropic path ──────────────────────────────────────
@test "SF-01: no override file → calls mock claude directly (Anthropic path)" {
  # No state files at all
  run bash -c "
    HOME='$TMP_HOME'
    PATH='$TMP_HOME/bin:$PATH'
    source '$SHELL_FN'
    claude
  " <<< ""
  [ "$status" -eq 0 ]
  [[ "$output" == *"MOCK_CLAUDE"* ]]
  # Should NOT print any Ollama-related routing message
  [[ "$output" != *"Routing to Ollama"* ]]
}

# ── SF-02: Override + past epoch + Y → switches back ─────────────────────────
@test "SF-02: override + past reset epoch + answer Y → deletes override, calls Anthropic" {
  local past_epoch=$(( $(date +%s) - 3600 ))
  touch "$TMP_HOME/.claude/.ollama-override"
  echo "$past_epoch" > "$TMP_HOME/.claude/.ollama-reset-time"

  run bash -c "
    HOME='$TMP_HOME'
    PATH='$TMP_HOME/bin:$PATH'
    source '$SHELL_FN'
    claude
  " <<< "Y"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Switched back to Anthropic"* ]]
  [ ! -f "$TMP_HOME/.claude/.ollama-override" ]
  [ ! -f "$TMP_HOME/.claude/.ollama-reset-time" ]
}

# ── SF-03: Override + past epoch + N → stays on Ollama ───────────────────────
@test "SF-03: override + past reset epoch + answer N → stays on Ollama path" {
  local past_epoch=$(( $(date +%s) - 3600 ))
  touch "$TMP_HOME/.claude/.ollama-override"
  echo "$past_epoch" > "$TMP_HOME/.claude/.ollama-reset-time"
  # curl still fails (Ollama not running), second read answers Y to fallback
  run bash -c "
    HOME='$TMP_HOME'
    PATH='$TMP_HOME/bin:$PATH'
    source '$SHELL_FN'
    claude
  " <<< $'N\nY'
  [ "$status" -eq 0 ]
  [[ "$output" == *"Staying on Ollama"* ]]
  # Override should still exist (not deleted)
  [ -f "$TMP_HOME/.claude/.ollama-override" ]
}

# ── SF-04: Override + future epoch → skips prompt, health check ──────────────
@test "SF-04: override + future reset epoch → no switch-back prompt shown" {
  local future_epoch=$(( $(date +%s) + 86400 ))
  # Write a minimal override file
  printf 'export ANTHROPIC_BASE_URL=http://localhost:11434/v1\nexport ANTHROPIC_AUTH_TOKEN=ollama\nexport OLLAMA_MODEL=kimi-k2.5:cloud\n' \
    > "$TMP_HOME/.claude/.ollama-override"
  echo "$future_epoch" > "$TMP_HOME/.claude/.ollama-reset-time"
  # curl succeeds (Ollama "running"), no models listed
  printf '#!/bin/bash\nexit 0\n' > "$TMP_HOME/bin/curl"

  run bash -c "
    HOME='$TMP_HOME'
    PATH='$TMP_HOME/bin:$PATH'
    source '$SHELL_FN'
    claude
  " <<< ""
  [ "$status" -eq 0 ]
  [[ "$output" != *"Switch back to Anthropic"* ]]
  [[ "$output" == *"Routing to Ollama"* ]]
}

# ── SF-05: Override + no reset-time file → warns ─────────────────────────────
@test "SF-05: override active but no .ollama-reset-time → warns about missing reset time" {
  printf 'export ANTHROPIC_BASE_URL=http://localhost:11434/v1\nexport ANTHROPIC_AUTH_TOKEN=ollama\n' \
    > "$TMP_HOME/.claude/.ollama-override"
  # No .ollama-reset-time file
  # curl succeeds
  printf '#!/bin/bash\nexit 0\n' > "$TMP_HOME/bin/curl"

  run bash -c "
    HOME='$TMP_HOME'
    PATH='$TMP_HOME/bin:$PATH'
    source '$SHELL_FN'
    claude
  " <<< ""
  [ "$status" -eq 0 ]
  [[ "$output" == *"no reset time was recorded"* ]]
}

# ── SF-06: Override + Ollama not running + Y → Anthropic fallback ────────────
@test "SF-06: override + Ollama not running + answer Y → falls back to Anthropic" {
  local future_epoch=$(( $(date +%s) + 86400 ))
  touch "$TMP_HOME/.claude/.ollama-override"
  echo "$future_epoch" > "$TMP_HOME/.claude/.ollama-reset-time"
  # curl FAILS (default mock)

  run bash -c "
    HOME='$TMP_HOME'
    PATH='$TMP_HOME/bin:$PATH'
    source '$SHELL_FN'
    claude
  " <<< "Y"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Ollama is not running"* ]]
  [[ "$output" == *"Falling back to Anthropic"* ]]
  [[ "$output" == *"MOCK_CLAUDE"* ]]
}

# ── SF-07: switch-back with backup file → restores key + cleans files ────────
@test "SF-07: switch-back with backup file → restores API key and removes state files" {
  printf 'sk-ant-testkey123' > "$TMP_HOME/.claude/.ollama-anthropic-key-backup"
  chmod 600 "$TMP_HOME/.claude/.ollama-anthropic-key-backup"
  touch "$TMP_HOME/.claude/.ollama-override"
  echo "12345" > "$TMP_HOME/.claude/.ollama-reset-time"
  touch "$TMP_HOME/.claude/.pre-switchback"

  run bash -c "
    HOME='$TMP_HOME'
    PATH='$TMP_HOME/bin:$PATH'
    source '$SHELL_FN'
    switch-back
    echo \"KEY=\$ANTHROPIC_API_KEY\"
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"ANTHROPIC_API_KEY restored"* ]]
  [[ "$output" == *"KEY=sk-ant-testkey123"* ]]
  [ ! -f "$TMP_HOME/.claude/.ollama-override" ]
  [ ! -f "$TMP_HOME/.claude/.ollama-reset-time" ]
  [ ! -f "$TMP_HOME/.claude/.pre-switchback" ]
  [ ! -f "$TMP_HOME/.claude/.ollama-anthropic-key-backup" ]
}

# ── SF-08: switch-back without backup file → warns user ──────────────────────
@test "SF-08: switch-back with no backup file → warns about missing API key" {
  touch "$TMP_HOME/.claude/.ollama-override"
  # No key backup, no security binary

  run bash -c "
    HOME='$TMP_HOME'
    PATH='$TMP_HOME/bin:$PATH'
    source '$SHELL_FN'
    switch-back
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"Could not restore API key automatically"* ]]
  # Override should still be cleaned up
  [ ! -f "$TMP_HOME/.claude/.ollama-override" ]
}

# ── SF-09: _claude_pick_model uses saved model ────────────────────────────────
@test "SF-09: _claude_pick_model uses saved .ollama-model when ollama not available" {
  echo "my-saved-model" > "$TMP_HOME/.claude/.ollama-model"
  # ollama not in PATH (remove mock so command -v ollama fails)
  rm "$TMP_HOME/bin/ollama"

  run bash -c "
    HOME='$TMP_HOME'
    PATH='$TMP_HOME/bin:$PATH'
    source '$SHELL_FN'
    _claude_pick_model
    echo \"MODEL=\$OLLAMA_MODEL\"
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"MODEL=my-saved-model"* ]]
}

# ── SF-10: _claude_pick_model falls back to default when no saved model ───────
@test "SF-10: _claude_pick_model defaults to kimi-k2.5:cloud when no saved model and ollama absent" {
  # No .ollama-model, no ollama binary
  rm "$TMP_HOME/bin/ollama"

  run bash -c "
    HOME='$TMP_HOME'
    PATH='$TMP_HOME/bin:$PATH'
    source '$SHELL_FN'
    _claude_pick_model
    echo \"MODEL=\$OLLAMA_MODEL\"
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"MODEL=kimi-k2.5:cloud"* ]]
}

# ── SF-11: switch-back removes PWD from registry ─────────────────────────────
@test "SF-11: switch-back removes current PWD from .active-projects registry" {
  local test_dir
  test_dir=$(mktemp -d)
  printf '%s\n%s\n' "$test_dir" "/some/other/project" > "$TMP_HOME/.claude/.active-projects"
  touch "$TMP_HOME/.claude/.ollama-override"

  run bash -c "
    HOME='$TMP_HOME'
    PATH='$TMP_HOME/bin:$PATH'
    cd '$test_dir'
    source '$SHELL_FN'
    switch-back
  "
  [ "$status" -eq 0 ]
  # test_dir should be removed; other project should remain
  grep -qxF "/some/other/project" "$TMP_HOME/.claude/.active-projects"
  ! grep -qxF "$test_dir" "$TMP_HOME/.claude/.active-projects"
  rm -rf "$test_dir"
}

# ── SF-12: claude() with no override removes PWD from registry (cleanup) ─────
@test "SF-12: no override path removes PWD from registry on fresh Anthropic start" {
  local test_dir
  test_dir=$(mktemp -d)
  printf '%s\n/other/project\n' "$test_dir" > "$TMP_HOME/.claude/.active-projects"
  # No override file

  run bash -c "
    HOME='$TMP_HOME'
    PATH='$TMP_HOME/bin:$PATH'
    cd '$test_dir'
    source '$SHELL_FN'
    claude
  " <<< ""
  [ "$status" -eq 0 ]
  ! grep -qxF "$test_dir" "$TMP_HOME/.claude/.active-projects"
  rm -rf "$test_dir"
}

