# Ollama Infra Setup Runbook

Pre-requisite checklist before running `tests/test_integration_full_cycle.sh`.
Complete every step in order; each step has a verification command.

---

## Step 1 — Install Ollama

```bash
brew install ollama
```

**Verify:**
```bash
ollama --version
# Expected: ollama version X.Y.Z
```

---

## Step 2 — Start Ollama Server

```bash
ollama serve &
```

> Leave running in background. On subsequent runs: `pkill ollama && ollama serve &`

**Verify:**
```bash
curl -s http://localhost:11434/api/tags | python3 -m json.tool | head -5
# Expected: JSON with "models" key (may be empty list on fresh install)
```

---

## Step 3 — Pull Test Model (unit/CI use)

Small model for CI and bats tests (726 MB, 8K context). Not used for actual Claude
Code sessions — only for `ollama run` smoke tests in integration script.

```bash
ollama pull smollm2:360m
```

**Verify:**
```bash
ollama run smollm2:360m "reply with the single word: ready"
# Expected: "ready" (or similar short response)
```

---

## Step 4 — Pull Integration Model

Full-context model for actual Ollama-routed Claude Code sessions. Requires 64K+
context window per Ollama Claude Code integration docs.

```bash
# Option A: qwen3-coder (preferred — designed for coding tasks)
ollama pull qwen3-coder

# Option B: smaller alternative if disk is constrained
ollama pull qwen2.5-coder:7b
```

**Verify:**
```bash
ollama run qwen3-coder "reply with the single word: ready"
# Expected: "ready" (or similar)
```

---

## Step 5 — Verify Anthropic API Connection (baseline)

Confirm your normal Anthropic API key is set before testing the override path.

```bash
echo $ANTHROPIC_API_KEY | head -c 10
# Expected: sk-ant-... (first 10 chars only — never print full key)
```

---

## Step 6 — Verify Env Override Works

Test that sourcing the override file redirects Claude Code to Ollama.

```bash
# Simulate what watchdog writes
cat > /tmp/test-override <<'EOF'
export ANTHROPIC_AUTH_TOKEN=ollama
export ANTHROPIC_API_KEY=""
export ANTHROPIC_BASE_URL=http://localhost:11434
EOF

source /tmp/test-override
echo "AUTH_TOKEN=$ANTHROPIC_AUTH_TOKEN"
echo "BASE_URL=$ANTHROPIC_BASE_URL"
# Expected:
#   AUTH_TOKEN=ollama
#   BASE_URL=http://localhost:11434

# Clean up
unset ANTHROPIC_AUTH_TOKEN ANTHROPIC_API_KEY ANTHROPIC_BASE_URL
rm /tmp/test-override
```

**Then launch Ollama-routed Claude Code:**
```bash
source ~/.claude/.ollama-override   # written by limit-watchdog.sh
ollama launch claude --model qwen3-coder
# Expected: Claude Code starts, routes to local Ollama
```

---

## Step 7 — Set Up Scheduled Switchback

### Option A — Demo path (simplest, no setup needed)

Call `switch-to-anthropic.sh` manually when you want to switch back:

```bash
bash ~/.claude/scripts/switch-to-anthropic.sh "$PWD"
```

Or simulate the 2-minute delay with a background sleep:

```bash
(sleep 120 && bash ~/.claude/scripts/switch-to-anthropic.sh "$PWD") &
echo "Switchback scheduled in 2 minutes (PID $!)"
```

### Option B — Production path (launchd user agent, no sudo)

Creates a one-shot launchd agent that fires at a specific wall-clock time.
The `limit-watchdog.sh` script will write this plist dynamically with the actual
reset time extracted from the Anthropic limit message.

**Manual setup for testing:**
```bash
RESET_TIME="02:30"   # 24h format HH:MM
PROJECT_CWD="$PWD"

# Write plist
mkdir -p ~/Library/LaunchAgents
cat > ~/Library/LaunchAgents/com.claude.switchback.plist <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.claude.switchback</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>$HOME/.claude/scripts/switch-to-anthropic.sh</string>
    <string>$PROJECT_CWD</string>
  </array>
  <key>StartCalendarInterval</key>
  <dict>
    <key>Hour</key>
    <integer>$(echo $RESET_TIME | cut -d: -f1 | sed 's/^0//')</integer>
    <key>Minute</key>
    <integer>$(echo $RESET_TIME | cut -d: -f2 | sed 's/^0//')</integer>
  </dict>
  <key>RunAtLoad</key>
  <false/>
</dict>
</plist>
EOF

launchctl load ~/Library/LaunchAgents/com.claude.switchback.plist
echo "Switchback agent loaded — will fire at $RESET_TIME"
```

**Remove after use:**
```bash
launchctl unload ~/Library/LaunchAgents/com.claude.switchback.plist
rm ~/Library/LaunchAgents/com.claude.switchback.plist
```

### Option C — Enable atrun (requires sudo, macOS 15 only)

> **Note:** `atrun` / `at` is disabled by default on macOS 15 (Sequoia). `at` will
> silently queue jobs that never fire unless you enable it.

```bash
sudo launchctl load -w /System/Library/LaunchDaemons/com.apple.atrun.plist

# Verify atrun is running
sudo launchctl list | grep atrun
# Expected: shows com.apple.atrun

# Test at job
echo "touch /tmp/at-test-fired" | at now + 1 minute
sleep 65
ls /tmp/at-test-fired && echo "at is working" || echo "at NOT working"
```

---

## Step 8 — Verify settings.json Has StopFailure Hook

```bash
python3 -c "
import json
with open('settings.json') as f:
    s = json.load(f)
hooks = s.get('hooks', {})
has_stop = 'Stop' in hooks
has_stop_failure = 'StopFailure' in hooks
print(f'Stop hook:        {has_stop}')
print(f'StopFailure hook: {has_stop_failure}')
assert has_stop, 'MISSING: Stop hook'
assert has_stop_failure, 'MISSING: StopFailure hook'
print('PASS: both hooks present')
"
```

---

## Full Readiness Checklist

Run this before starting integration tests:

```bash
echo "=== Ollama Infra Readiness ===" && \
  ollama --version && echo "✓ Ollama installed" && \
  curl -sf http://localhost:11434/api/tags > /dev/null && echo "✓ Ollama server running" && \
  ollama list | grep -q smollm2 && echo "✓ smollm2:360m present" && \
  ollama list | grep -qE 'qwen3-coder|qwen2.5-coder' && echo "✓ integration model present" && \
  echo "✓ All checks passed — ready for integration tests"
```
