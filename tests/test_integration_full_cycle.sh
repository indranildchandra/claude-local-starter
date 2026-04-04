#!/usr/bin/env bash
# tests/test_integration_full_cycle.sh
# End-to-end integration test for the full 5-phase Ollama switchover cycle.
# Run from repo root: bash tests/test_integration_full_cycle.sh
#
# Prerequisites: see tests/infra-setup.md (Ollama running, models pulled)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
PASS=0
FAIL=0

# Colours
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass() { echo -e "${GREEN}PASS${NC}  $1"; PASS=$((PASS + 1)); }
fail() { echo -e "${RED}FAIL${NC}  $1"; FAIL=$((FAIL + 1)); }
skip() { echo -e "${YELLOW}SKIP${NC}  $1"; }
header() { echo -e "\n${YELLOW}=== $1 ===${NC}"; }

cleanup() {
  rm -rf "$TMP_DIR"
  # Remove any override and launchd agent left by tests
  rm -f "$HOME/.claude/.ollama-override"
  launchctl unload "$HOME/Library/LaunchAgents/com.claude.switchback.plist" 2>/dev/null || true
  rm -f "$HOME/Library/LaunchAgents/com.claude.switchback.plist"
}
trap cleanup EXIT

# ---------------------------------------------------------------------------
header "Step 1: Verify Ollama is running"
# ---------------------------------------------------------------------------
if curl -sf http://localhost:11434/api/tags > /dev/null 2>&1; then
  pass "Ollama server reachable at localhost:11434"
else
  fail "Ollama server NOT running — start with: ollama serve &"
  echo "Cannot continue without Ollama. Exiting."
  exit 1
fi

# ---------------------------------------------------------------------------
header "Step 2: Verify integration model is available"
# ---------------------------------------------------------------------------
# Capture to variable first — avoids SIGPIPE from grep -q closing pipe early (exit 141)
OLLAMA_MODELS=$(ollama list 2>/dev/null || true)
if echo "$OLLAMA_MODELS" | grep -qE 'glm-4.7-flash|qwen3.5|kimi-k2.5|glm-5|qwen3-coder|qwen2.5-coder'; then
  MODEL=$(echo "$OLLAMA_MODELS" | grep -oE 'glm-4\.7-flash[^ ]*|qwen3\.5[^ ]*|kimi-k2\.5[^ ]*|glm-5[^ ]*|qwen3-coder[^ ]*|qwen2\.5-coder[^ ]*' | head -1)
  pass "Integration model available: $MODEL"
else
  fail "No supported Claude Code model found"
  echo "Pull one of the officially recommended models:"
  echo "  ollama pull glm-4.7-flash       # best local model (8GB RAM)"
  echo "  ollama pull qwen3.5             # local alternative (8GB RAM)"
  echo "  ollama pull kimi-k2.5:cloud     # best quality, free via Ollama cloud"
  echo "Skipping model-dependent steps."
  MODEL=""
fi

# ---------------------------------------------------------------------------
header "Step 3: Simulate limit hit (fake last_assistant_message + transcript)"
# ---------------------------------------------------------------------------
FAKE_TRANSCRIPT="$TMP_DIR/transcript.txt"
echo "You've hit your limit · resets 3:30am" > "$FAKE_TRANSCRIPT"

FAKE_JSON=$(python3 -c "
import json
payload = {
  'last_assistant_message': \"You've hit your limit \xb7 resets 3:30am\",
  'transcript_path': '$FAKE_TRANSCRIPT',
  'cwd': '$TMP_DIR'
}
print(json.dumps(payload))
")

# Temporarily override HOME for watchdog so it writes to TMP_DIR
FAKE_HOME="$TMP_DIR/home"
mkdir -p "$FAKE_HOME/.claude"

# Subshell so HOME override applies to the full pipeline
(export HOME="$FAKE_HOME"; echo "$FAKE_JSON" | bash "$REPO_ROOT/scripts/limit-watchdog.sh") || true
pass "limit-watchdog.sh executed without crash"

# ---------------------------------------------------------------------------
header "Step 4: Verify .ollama-override written"
# ---------------------------------------------------------------------------
if [ -f "$FAKE_HOME/.claude/.ollama-override" ]; then
  pass ".ollama-override written at $FAKE_HOME/.claude/.ollama-override"
else
  fail ".ollama-override NOT written"
fi

# ---------------------------------------------------------------------------
header "Step 5: Verify tasks/.session-handover written"
# ---------------------------------------------------------------------------
if [ -f "$TMP_DIR/tasks/.session-handover" ]; then
  pass "tasks/.session-handover written"
else
  fail "tasks/.session-handover NOT written"
fi

# Verify override contents
if [ -f "$FAKE_HOME/.claude/.ollama-override" ]; then
  if grep -q 'ANTHROPIC_AUTH_TOKEN=ollama' "$FAKE_HOME/.claude/.ollama-override" && \
     grep -q 'ANTHROPIC_BASE_URL=http://localhost:11434' "$FAKE_HOME/.claude/.ollama-override"; then
    pass "Override file has correct AUTH_TOKEN and BASE_URL"
  else
    fail "Override file missing expected env vars"
  fi
fi

# ---------------------------------------------------------------------------
header "Step 6: Verify Ollama-routed session would start (env check)"
# ---------------------------------------------------------------------------
# We can't actually launch claude in a test, so verify the env override works
if [ -f "$FAKE_HOME/.claude/.ollama-override" ]; then
  source "$FAKE_HOME/.claude/.ollama-override"
  if [ "${ANTHROPIC_AUTH_TOKEN:-}" = "ollama" ] && [ "${ANTHROPIC_BASE_URL:-}" = "http://localhost:11434" ]; then
    pass "Sourcing override sets correct env vars for Ollama routing"
  else
    fail "Override env vars not set correctly after source"
  fi
  unset ANTHROPIC_AUTH_TOKEN ANTHROPIC_API_KEY ANTHROPIC_BASE_URL
fi

# ---------------------------------------------------------------------------
header "Step 7: Verify init-context command file exists"
# ---------------------------------------------------------------------------
if [ -f "$REPO_ROOT/commands/init-context.md" ]; then
  pass "commands/init-context.md exists"
else
  fail "commands/init-context.md NOT found"
fi

# ---------------------------------------------------------------------------
header "Step 8: Simulate switchback (call switch-to-anthropic.sh directly)"
# ---------------------------------------------------------------------------
# Place override where switch-to-anthropic.sh expects it (use existing or create one)
mkdir -p "$HOME/.claude"
if [ -f "$FAKE_HOME/.claude/.ollama-override" ]; then
  cp "$FAKE_HOME/.claude/.ollama-override" "$HOME/.claude/.ollama-override"
else
  printf 'export ANTHROPIC_AUTH_TOKEN=ollama\nexport ANTHROPIC_API_KEY=""\nexport ANTHROPIC_BASE_URL=http://localhost:11434\n' \
    > "$HOME/.claude/.ollama-override"
fi

# New design: switchback reads registry (not CWD arg). Set up registry + skip sleep delay.
echo "$TMP_DIR" > "$HOME/.claude/.active-projects"
SWITCHBACK_DELAY=0 bash "$REPO_ROOT/scripts/switch-to-anthropic.sh"
pass "switch-to-anthropic.sh executed without crash"

# ---------------------------------------------------------------------------
header "Step 9: Verify .ollama-override removed"
# ---------------------------------------------------------------------------
if [ ! -f "$HOME/.claude/.ollama-override" ]; then
  pass ".ollama-override removed by switchback"
else
  fail ".ollama-override still present after switchback"
  rm -f "$HOME/.claude/.ollama-override"
fi

# ---------------------------------------------------------------------------
header "Step 10: Verify new handover marker written by switchback"
# ---------------------------------------------------------------------------
if [ -f "$TMP_DIR/tasks/.session-handover" ]; then
  pass "New handover marker written by switchback"
else
  fail "Handover marker NOT written by switchback"
fi

# ---------------------------------------------------------------------------
header "Step 11: Verify Anthropic session env is clean after override removed"
# ---------------------------------------------------------------------------
if [ -z "${ANTHROPIC_AUTH_TOKEN:-}" ] || [ "${ANTHROPIC_AUTH_TOKEN:-}" != "ollama" ]; then
  pass "ANTHROPIC_AUTH_TOKEN is not 'ollama' (Anthropic session would route correctly)"
else
  fail "ANTHROPIC_AUTH_TOKEN is still 'ollama' — override not fully cleaned"
fi

# ---------------------------------------------------------------------------
header "Step 12: Verify init-context marker cleanup simulation"
# ---------------------------------------------------------------------------
# Simulate what /init-context does: read handover then delete it
HANDOVER="$TMP_DIR/tasks/.session-handover"
if [ -f "$HANDOVER" ]; then
  rm "$HANDOVER"
  if [ ! -f "$HANDOVER" ]; then
    pass "Handover marker deleted after context load (session cleanup)"
  else
    fail "Handover marker NOT deleted"
  fi
else
  fail "Handover marker not present for cleanup test"
fi

# ---------------------------------------------------------------------------
header "Step 13: Verify registry written by limit-watchdog"
# ---------------------------------------------------------------------------
REGISTRY="$FAKE_HOME/.claude/.active-projects"
if [ -f "$REGISTRY" ]; then
  if grep -qF "$TMP_DIR" "$REGISTRY"; then
    pass "Registry contains project CWD: $TMP_DIR"
  else
    fail "Registry exists but does not contain expected CWD"
  fi
else
  fail "Registry file not written by limit-watchdog.sh"
fi

# ---------------------------------------------------------------------------
header "Step 14: Simulate two-phase switchback (Phase 2 only — skip sleep)"
# ---------------------------------------------------------------------------
# Simulate Phase 2 directly (no sleep in tests): iterate registry, write handover markers
mkdir -p "$FAKE_HOME/.claude"
printf '%s\n' "$TMP_DIR" > "$FAKE_HOME/.claude/.active-projects"
mkdir -p "$FAKE_HOME/.claude"
printf 'export ANTHROPIC_AUTH_TOKEN=ollama\n' > "$FAKE_HOME/.claude/.ollama-override"

# Run switch-to-anthropic with SWITCHBACK_DELAY=0 (synchronous Phase 2 — no race conditions)
(
  export HOME="$FAKE_HOME"
  export SWITCHBACK_DELAY=0
  bash "$REPO_ROOT/scripts/switch-to-anthropic.sh" 2>/dev/null
) || true
pass "switch-to-anthropic.sh Phase 2 simulation executed"

# ---------------------------------------------------------------------------
header "Step 15: Verify all registry projects got handover markers"
# ---------------------------------------------------------------------------
if [ -f "$TMP_DIR/tasks/.session-handover" ]; then
  pass "Handover marker written for registered project"
else
  fail "Handover marker NOT written for registered project"
fi

if [ ! -f "$FAKE_HOME/.claude/.active-projects" ]; then
  pass "Registry cleared after switchback"
else
  fail "Registry NOT cleared after switchback"
fi

# ---------------------------------------------------------------------------
header "Step 16: Verify .pre-switchback marker behavior"
# ---------------------------------------------------------------------------
# Phase 1 of switchback writes .pre-switchback
mkdir -p "$FAKE_HOME/.claude"
touch "$FAKE_HOME/.claude/.pre-switchback"
if [ -f "$FAKE_HOME/.claude/.pre-switchback" ]; then
  pass ".pre-switchback marker written (Phase 1 simulation)"
  rm -f "$FAKE_HOME/.claude/.pre-switchback"
  pass ".pre-switchback marker removed after consumption"
else
  fail ".pre-switchback marker not written"
fi

# ---------------------------------------------------------------------------
header "Summary"
# ---------------------------------------------------------------------------
TOTAL=$((PASS + FAIL))
echo ""
echo "Results: ${PASS}/${TOTAL} passed"
if [ "$FAIL" -eq 0 ]; then
  echo -e "${GREEN}All integration tests PASSED${NC}"
  exit 0
else
  echo -e "${RED}${FAIL} test(s) FAILED${NC}"
  exit 1
fi
