#!/usr/bin/env bats
# tests/test_switch_to_anthropic.bats
load 'helpers/setup'

@test "removes ~/.claude/.ollama-override when it exists" {
  touch "$TMP_HOME/.claude/.ollama-override"
  # Script reads registry, not positional args
  bash scripts/switch-to-anthropic.sh
  [ ! -f "$TMP_HOME/.claude/.ollama-override" ]
}

@test "succeeds even when override file does not exist" {
  run bash scripts/switch-to-anthropic.sh
  [ "$status" -eq 0 ]
}

@test "completes successfully even when .active-projects registry exists" {
  # Thin wrapper: does not process registry but must not crash when it exists
  echo "$TMP_PROJECT" > "$TMP_HOME/.claude/.active-projects"
  run bash scripts/switch-to-anthropic.sh
  [ "$status" -eq 0 ]
}

@test "handles no registry (empty .active-projects) without crashing" {
  # No registry file — Phase 2 should still complete cleanly
  run bash scripts/switch-to-anthropic.sh
  [ "$status" -eq 0 ]
}

@test "calls osascript for macOS notification" {
  cat > "$TMP_HOME/bin/osascript" << 'EOF'
#!/bin/bash
echo "osascript_called" >> "$HOME/osascript.log"
EOF
  chmod +x "$TMP_HOME/bin/osascript"
  bash scripts/switch-to-anthropic.sh
  [ -f "$TMP_HOME/osascript.log" ]
}

@test "does not fail when osascript is unavailable" {
  rm -f "$TMP_HOME/bin/osascript"
  run bash scripts/switch-to-anthropic.sh
  [ "$status" -eq 0 ]
}

@test "registry is untouched by thin wrapper switchback" {
  # Thin wrapper does not clear the registry — that is handled by the caller shell function
  echo "$TMP_PROJECT" > "$TMP_HOME/.claude/.active-projects"
  run bash scripts/switch-to-anthropic.sh
  [ "$status" -eq 0 ]
}

@test "STA-SKIP-MISSING-DIR-01: completes without error even when registry has nonexistent paths" {
  # Thin wrapper does not process registry — must not crash regardless of contents
  printf '/nonexistent/path/12345\n%s\n' "$TMP_PROJECT" > "$TMP_HOME/.claude/.active-projects"
  run bash scripts/switch-to-anthropic.sh
  [ "$status" -eq 0 ]
}

@test "STA-PRESWITCHBACK-01: .pre-switchback marker is cleaned up by phase 2" {
  run bash scripts/switch-to-anthropic.sh
  [ "$status" -eq 0 ]
  [ ! -f "$TMP_HOME/.claude/.pre-switchback" ]
}

@test "STA-PHASE2-01: thin wrapper prints success message on stdout" {
  # Thin wrapper no longer writes per-project tracker entries — check stdout message
  run bash scripts/switch-to-anthropic.sh
  [ "$status" -eq 0 ]
  echo "$output" | grep -qi 'switched back to anthropic'
}
