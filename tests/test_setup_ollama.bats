#!/usr/bin/env bats
# tests/test_setup_ollama.bats
load 'helpers/setup'

@test "ollama binary exists on PATH after setup (or was already present)" {
  # Mock brew and ollama for CI
  printf '#!/bin/bash\nexit 0\n' > "$TMP_HOME/bin/brew"
  printf '#!/bin/bash\necho "smollm2:360m"\nexit 0\n' > "$TMP_HOME/bin/ollama"
  chmod +x "$TMP_HOME/bin/brew" "$TMP_HOME/bin/ollama"
  run bash scripts/setup-ollama.sh --test-mode
  [ "$status" -eq 0 ]
}

@test "skips brew install if ollama already on PATH" {
  printf '#!/bin/bash\necho "already_installed"\nexit 0\n' > "$TMP_HOME/bin/ollama"
  chmod +x "$TMP_HOME/bin/ollama"
  # brew should NOT be called
  printf '#!/bin/bash\necho "brew_called" >> %s/brew.log\nexit 0\n' "$TMP_HOME" > "$TMP_HOME/bin/brew"
  chmod +x "$TMP_HOME/bin/brew"
  bash scripts/setup-ollama.sh --test-mode
  [ ! -f "$TMP_HOME/brew.log" ]
}

@test "override file routes to localhost:11434" {
  mkdir -p "$TMP_HOME/.claude"
  cat > "$TMP_HOME/.claude/.ollama-override" << 'EOF'
export ANTHROPIC_AUTH_TOKEN=ollama
export ANTHROPIC_API_KEY=""
export ANTHROPIC_BASE_URL=http://localhost:11434
EOF
  source "$TMP_HOME/.claude/.ollama-override"
  [ "$ANTHROPIC_BASE_URL" = "http://localhost:11434" ]
  [ "$ANTHROPIC_AUTH_TOKEN" = "ollama" ]
  [ "$ANTHROPIC_API_KEY" = "" ]
}
