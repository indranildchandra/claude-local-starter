#!/usr/bin/env bats
# tests/test_functional_cycle.bats
# Functional tests: full state-machine transitions for the 5-phase switchover cycle.
load 'helpers/setup'

# ---------------------------------------------------------------------------
# FN-01: Normal session end (no limit) — no override written
# ---------------------------------------------------------------------------
@test "FN-01: normal session end writes no override file" {
  echo "Normal session completed successfully." > "$TMP_PROJECT/transcript.txt"
  echo "{\"transcript_path\":\"$TMP_PROJECT/transcript.txt\",\"cwd\":\"$TMP_PROJECT\"}" \
    | bash scripts/limit-watchdog.sh
  [ ! -f "$TMP_HOME/.claude/.ollama-override" ]
}

# ---------------------------------------------------------------------------
# FN-02: Limit hit → override file written with correct 3 env vars
# ---------------------------------------------------------------------------
@test "FN-02: limit hit writes override file with all four env vars including OLLAMA_MODEL" {
  echo "You've hit your limit · resets 2:30am" > "$TMP_PROJECT/transcript.txt"
  echo "{\"transcript_path\":\"$TMP_PROJECT/transcript.txt\",\"cwd\":\"$TMP_PROJECT\"}" \
    | bash scripts/limit-watchdog.sh

  [ -f "$TMP_HOME/.claude/.ollama-override" ]
  grep -q 'ANTHROPIC_AUTH_TOKEN=ollama' "$TMP_HOME/.claude/.ollama-override"
  grep -q 'ANTHROPIC_API_KEY=""' "$TMP_HOME/.claude/.ollama-override"
  grep -q 'ANTHROPIC_BASE_URL="http://localhost:11434/v1"' "$TMP_HOME/.claude/.ollama-override"
  grep -q 'OLLAMA_MODEL=' "$TMP_HOME/.claude/.ollama-override"
}

# ---------------------------------------------------------------------------
# FN-02b: ~/.ollama-model file respected when writing override
# ---------------------------------------------------------------------------
@test "FN-02b: custom model in ~/.claude/.ollama-model is used in override" {
  echo "my-custom-model:latest" > "$TMP_HOME/.claude/.ollama-model"
  echo "You've hit your limit · resets 2:30am" > "$TMP_PROJECT/transcript.txt"
  echo "{\"transcript_path\":\"$TMP_PROJECT/transcript.txt\",\"cwd\":\"$TMP_PROJECT\"}" \
    | bash scripts/limit-watchdog.sh

  grep -q '^export OLLAMA_MODEL="my-custom-model:latest"' "$TMP_HOME/.claude/.ollama-override"
}

# ---------------------------------------------------------------------------
# FN-03: Limit hit → handover marker written at $cwd/tasks/.session-handover
# ---------------------------------------------------------------------------
@test "FN-03: limit hit writes handover marker at tasks/.session-handover" {
  echo "You've hit your limit · resets 2:30am" > "$TMP_PROJECT/transcript.txt"
  echo "{\"transcript_path\":\"$TMP_PROJECT/transcript.txt\",\"cwd\":\"$TMP_PROJECT\"}" \
    | bash scripts/limit-watchdog.sh

  [ -f "$TMP_PROJECT/tasks/.session-handover" ]
}

# ---------------------------------------------------------------------------
# FN-04: Switchback removes override file
# ---------------------------------------------------------------------------
@test "FN-04: switch-to-anthropic.sh removes .ollama-override" {
  # Arrange: place an override file
  mkdir -p "$TMP_HOME/.claude"
  echo "export ANTHROPIC_AUTH_TOKEN=ollama" > "$TMP_HOME/.claude/.ollama-override"
  [ -f "$TMP_HOME/.claude/.ollama-override" ]

  HOME="$TMP_HOME" bash scripts/switch-to-anthropic.sh

  [ ! -f "$TMP_HOME/.claude/.ollama-override" ]
}

# ---------------------------------------------------------------------------
# FN-05: Switchback writes new handover marker (for Anthropic session to pick up)
# ---------------------------------------------------------------------------
@test "FN-05: switch-to-anthropic.sh (thin wrapper) completes without error and removes override" {
  mkdir -p "$TMP_HOME/.claude"
  echo "export ANTHROPIC_AUTH_TOKEN=ollama" > "$TMP_HOME/.claude/.ollama-override"
  echo "$TMP_PROJECT" > "$TMP_HOME/.claude/.active-projects"

  HOME="$TMP_HOME" run bash scripts/switch-to-anthropic.sh

  [ "$status" -eq 0 ]
  [ ! -f "$TMP_HOME/.claude/.ollama-override" ]
}

# ---------------------------------------------------------------------------
# FN-06: Handover marker absent → watchdog exits 0 without writing override
# ---------------------------------------------------------------------------
@test "FN-06: no handover marker and no limit message → no override written" {
  # Transcript with no limit phrase
  echo "Session completed cleanly." > "$TMP_PROJECT/transcript.txt"
  echo "{\"transcript_path\":\"$TMP_PROJECT/transcript.txt\",\"cwd\":\"$TMP_PROJECT\"}" \
    | bash scripts/limit-watchdog.sh

  [ ! -f "$TMP_HOME/.claude/.ollama-override" ]
  [ ! -f "$TMP_PROJECT/tasks/.session-handover" ]
}

# ---------------------------------------------------------------------------
# FN-07: Handover marker present → limit-watchdog still writes override on limit hit
# (marker presence doesn't gate the watchdog — it's for SessionStart hook)
# ---------------------------------------------------------------------------
@test "FN-07: pre-existing handover marker does not block new override on limit hit" {
  mkdir -p "$TMP_PROJECT/tasks"
  touch "$TMP_PROJECT/tasks/.session-handover"
  echo "hit your limit · resets 3:00am" > "$TMP_PROJECT/transcript.txt"
  echo "{\"transcript_path\":\"$TMP_PROJECT/transcript.txt\",\"cwd\":\"$TMP_PROJECT\"}" \
    | bash scripts/limit-watchdog.sh

  [ -f "$TMP_HOME/.claude/.ollama-override" ]
}

# ---------------------------------------------------------------------------
# FN-08: switch-to-anthropic.sh with no PROJECT_CWD arg → no crash, no marker
# ---------------------------------------------------------------------------
@test "FN-08: switch-to-anthropic.sh with no CWD arg completes without error" {
  mkdir -p "$TMP_HOME/.claude"
  echo "export ANTHROPIC_AUTH_TOKEN=ollama" > "$TMP_HOME/.claude/.ollama-override"

  HOME="$TMP_HOME" run bash scripts/switch-to-anthropic.sh
  [ "$status" -eq 0 ]
  [ ! -f "$TMP_HOME/.claude/.ollama-override" ]
}

# ---------------------------------------------------------------------------
# FN-09: last_assistant_message field in stdin JSON used for limit detection
# ---------------------------------------------------------------------------
@test "FN-09: limit detected via last_assistant_message field (no transcript)" {
  # No transcript file — detection must come from JSON field alone
  local json
  json=$(python3 -c "
import json, sys
payload = {
  'last_assistant_message': \"You've hit your limit · resets 4:00am\",
  'transcript_path': '/nonexistent/transcript.txt',
  'cwd': '$TMP_PROJECT'
}
print(json.dumps(payload))
")
  echo "$json" | bash scripts/limit-watchdog.sh

  [ -f "$TMP_HOME/.claude/.ollama-override" ]
}

# ---------------------------------------------------------------------------
# FN-10: StopFailure stdin JSON parsed correctly (same fields as Stop)
# ---------------------------------------------------------------------------
@test "FN-10: StopFailure JSON with last_assistant_message triggers override" {
  # StopFailure JSON format is same as Stop — script must handle both
  local json
  json=$(python3 -c "
import json
payload = {
  'hook_event_name': 'StopFailure',
  'last_assistant_message': 'You have hit your limit · resets 5:30am',
  'transcript_path': '$TMP_PROJECT/transcript.txt',
  'cwd': '$TMP_PROJECT'
}
print(json.dumps(payload))
")
  echo "placeholder" > "$TMP_PROJECT/transcript.txt"
  echo "$json" | bash scripts/limit-watchdog.sh

  [ -f "$TMP_HOME/.claude/.ollama-override" ]
}

# ---------------------------------------------------------------------------
# FN-11: settings.json has StopFailure hook entry alongside Stop
# ---------------------------------------------------------------------------
@test "FN-11: settings.json contains StopFailure hook pointing to limit-watchdog.sh" {
  export BATS_TEST_DIRNAME
  python3 - <<'PYEOF'
import json, sys, os

settings_path = os.path.join(os.environ.get('BATS_TEST_DIRNAME', '.'), '..', 'settings.json')
with open(settings_path) as f:
    settings = json.load(f)

hooks = settings.get('hooks', {})

assert 'Stop' in hooks, "Missing Stop hook in settings.json"
assert 'StopFailure' in hooks, "Missing StopFailure hook in settings.json"

stop_cmds = [h.get('command', '') for entry in hooks['Stop'] for h in entry.get('hooks', [])]
sf_cmds   = [h.get('command', '') for entry in hooks['StopFailure'] for h in entry.get('hooks', [])]

assert any('limit-watchdog' in c for c in stop_cmds), "Stop hook does not call limit-watchdog.sh"
assert any('limit-watchdog' in c for c in sf_cmds),   "StopFailure hook does not call limit-watchdog.sh"
PYEOF
}

# ---------------------------------------------------------------------------
# FN-12: Registry file gets CWD appended on limit hit
# ---------------------------------------------------------------------------
@test "FN-12: limit hit appends CWD to ~/.claude/.active-projects registry" {
  echo "You've hit your limit · resets 5:00am" > "$TMP_PROJECT/transcript.txt"
  echo "{\"transcript_path\":\"$TMP_PROJECT/transcript.txt\",\"cwd\":\"$TMP_PROJECT\"}" \
    | bash scripts/limit-watchdog.sh

  [ -f "$TMP_HOME/.claude/.active-projects" ]
  grep -qxF "$TMP_PROJECT" "$TMP_HOME/.claude/.active-projects"
}

# ---------------------------------------------------------------------------
# FN-13: Duplicate CWD not appended to registry
# ---------------------------------------------------------------------------
@test "FN-13: duplicate CWD not appended to registry (idempotent)" {
  echo "You've hit your limit · resets 5:00am" > "$TMP_PROJECT/transcript.txt"
  # Run watchdog twice with the same CWD
  echo "{\"transcript_path\":\"$TMP_PROJECT/transcript.txt\",\"cwd\":\"$TMP_PROJECT\"}" \
    | bash scripts/limit-watchdog.sh
  echo "{\"transcript_path\":\"$TMP_PROJECT/transcript.txt\",\"cwd\":\"$TMP_PROJECT\"}" \
    | bash scripts/limit-watchdog.sh

  [ "$(grep -cxF "$TMP_PROJECT" "$TMP_HOME/.claude/.active-projects")" -eq 1 ]
}

# ---------------------------------------------------------------------------
# FN-14: switchback writes handover markers for all projects in registry
# ---------------------------------------------------------------------------
@test "FN-14: switch-to-anthropic.sh (thin wrapper) removes override and exits 0 with multiple registry entries" {
  # Thin wrapper does not process per-project registry entries — it only removes override files
  TMP_PROJECT2=$(mktemp -d)
  mkdir -p "$TMP_PROJECT2/tasks"

  # Populate registry with two projects
  mkdir -p "$TMP_HOME/.claude"
  printf '%s\n%s\n' "$TMP_PROJECT" "$TMP_PROJECT2" > "$TMP_HOME/.claude/.active-projects"

  # Place override so switchback has something to remove
  echo "export ANTHROPIC_AUTH_TOKEN=ollama" > "$TMP_HOME/.claude/.ollama-override"

  HOME="$TMP_HOME" run bash scripts/switch-to-anthropic.sh

  [ "$status" -eq 0 ]
  [ ! -f "$TMP_HOME/.claude/.ollama-override" ]

  rm -rf "$TMP_PROJECT2"
}

# ---------------------------------------------------------------------------
# FN-15: limit hit writes limit-hit entry to tasks/tracker.md
# ---------------------------------------------------------------------------
@test "FN-15: limit hit writes limit-hit tracker entry to tasks/tracker.md" {
  echo "You've hit your limit · resets 6:00am" > "$TMP_PROJECT/transcript.txt"
  echo "{\"transcript_path\":\"$TMP_PROJECT/transcript.txt\",\"cwd\":\"$TMP_PROJECT\"}" \
    | bash scripts/limit-watchdog.sh

  [ -f "$TMP_PROJECT/tasks/tracker.md" ]
  grep -q 'Limit Hit' "$TMP_PROJECT/tasks/tracker.md"
  grep -q 'limit-hit' "$TMP_PROJECT/tasks/tracker.md"
}
