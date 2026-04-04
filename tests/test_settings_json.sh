#!/usr/bin/env bash
# tests/test_settings_json.sh
# Validates settings.json structure and required hooks.
# Exit 0 if all checks pass; exit 1 with a specific message on any failure.

set -euo pipefail

SETTINGS="$(cd "$(dirname "$0")/.." && pwd)/settings.json"

fail() {
  echo "FAIL: $1"
  exit 1
}

pass() {
  echo "PASS: $1"
}

# 1. Valid JSON
python3 -c "
import json, sys
try:
    json.load(open('$SETTINGS'))
    print('valid')
except Exception as e:
    print(f'invalid: {e}', file=sys.stderr)
    sys.exit(1)
" > /dev/null && pass "settings.json is valid JSON" || fail "settings.json is not valid JSON"

# 2. Stop hooks contain limit-watchdog.sh and aidlc-guard.sh
python3 -c "
import json, sys
data = json.load(open('$SETTINGS'))
stop_hooks = data.get('hooks', {}).get('Stop', [])
commands = []
for block in stop_hooks:
    for h in block.get('hooks', []):
        commands.append(h.get('command', ''))
all_cmds = ' '.join(commands)
missing = []
if 'limit-watchdog.sh' not in all_cmds:
    missing.append('limit-watchdog.sh')
if 'aidlc-guard.sh' not in all_cmds:
    missing.append('aidlc-guard.sh')
if missing:
    print('MISSING in Stop hooks: ' + ', '.join(missing), file=sys.stderr)
    sys.exit(1)
" && pass "Stop hooks contain limit-watchdog.sh and aidlc-guard.sh" || fail "Stop hooks missing limit-watchdog.sh or aidlc-guard.sh"

# 3. SessionStart hook contains handover hint
python3 -c "
import json, sys
data = json.load(open('$SETTINGS'))
ss_hooks = data.get('hooks', {}).get('SessionStart', [])
commands = []
for block in ss_hooks:
    for h in block.get('hooks', []):
        commands.append(h.get('command', ''))
all_cmds = ' '.join(commands)
if '.handover-ready' not in all_cmds and 'init-context' not in all_cmds:
    print('MISSING: SessionStart hook does not contain handover hint', file=sys.stderr)
    sys.exit(1)
" && pass "SessionStart hook contains handover hint" || fail "SessionStart hook missing handover hint"

# 4. PreToolUse hooks contain reset-time warning and claudeignore-guard.sh
python3 -c "
import json, sys
data = json.load(open('$SETTINGS'))
pt_hooks = data.get('hooks', {}).get('PreToolUse', [])
commands = []
for block in pt_hooks:
    for h in block.get('hooks', []):
        commands.append(h.get('command', ''))
all_cmds = ' '.join(commands)
missing = []
if 'ollama-reset-time' not in all_cmds:
    missing.append('reset-time warning (.ollama-reset-time)')
if 'claudeignore-guard.sh' not in all_cmds:
    missing.append('claudeignore-guard.sh')
if missing:
    print('MISSING in PreToolUse hooks: ' + ', '.join(missing), file=sys.stderr)
    sys.exit(1)
" && pass "PreToolUse hooks contain reset-time warning and claudeignore-guard.sh" || fail "PreToolUse hooks missing reset-time warning or claudeignore-guard.sh"

# 5. defaultMode is "auto"
python3 -c "
import json, sys
data = json.load(open('$SETTINGS'))
mode = data.get('permissions', {}).get('defaultMode', '')
if mode != 'auto':
    print(f'WRONG defaultMode: expected \"auto\", got \"{mode}\"', file=sys.stderr)
    sys.exit(1)
" && pass "permissions.defaultMode is \"auto\"" || fail "permissions.defaultMode is not \"auto\""

# 6. PreCompact hook is present and unchanged (contains tasks/tracker.md logic)
python3 -c "
import json, sys
data = json.load(open('$SETTINGS'))
pc_hooks = data.get('hooks', {}).get('PreCompact', [])
commands = []
for block in pc_hooks:
    for h in block.get('hooks', []):
        commands.append(h.get('command', ''))
all_cmds = ' '.join(commands)
if 'tasks/tracker.md' not in all_cmds:
    print('MISSING: PreCompact hook does not reference tasks/tracker.md', file=sys.stderr)
    sys.exit(1)
if 'Auto-Compact Snapshot' not in all_cmds:
    print('MISSING: PreCompact hook does not contain Auto-Compact Snapshot marker', file=sys.stderr)
    sys.exit(1)
" && pass "PreCompact hook present and contains tasks/tracker.md logic" || fail "PreCompact hook missing or changed"

echo ""
echo "All settings.json checks passed."
