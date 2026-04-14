#!/usr/bin/env bash
# scripts/limit-watchdog.sh
# Stop / StopFailure hook: detects Anthropic usage limits and switches Claude Code to Ollama.
# Reads a session JSON from stdin, checks last_assistant_message first (fastest path),
# falls back to reading the transcript file, then writes env-var overrides, a handover
# marker. Switchback is handled lazily by the claude() wrapper on next launch.

set -euo pipefail

# Source ollama.conf for user-configurable overrides (LIMIT_PATTERN, OLLAMA_HOST, OLLAMA_DEFAULT_MODEL)
_conf="$HOME/.claude/ollama.conf"
[ -f "$_conf" ] && source "$_conf" 2>/dev/null

# Fall back to built-in pattern if user hasn't overridden.
# Intentionally narrow — broad terms like "usage limit" / "at capacity" produce false positives
# in normal Claude conversations. Only match phrases specific to Anthropic rate-limit messages.
LIMIT_PATTERN="${LIMIT_PATTERN:-(hit your limit|out of free messages|rate.?limit.*exceeded|exceeded.*rate.?limit|resets [0-9]+:[0-9]+(am|pm))}"
OLLAMA_HOST="${OLLAMA_HOST:-http://localhost:11434}"
# Text-based detection (SECONDARY) is opt-in — PRIMARY (history.jsonl) is reliable and sufficient.
# Set ENABLE_TEXT_DETECTION=true in ~/.claude/ollama.conf to also match on last_assistant_message.
ENABLE_TEXT_DETECTION="${ENABLE_TEXT_DETECTION:-false}"
HISTORY_FILE="$HOME/.claude/history.jsonl"

# --- Parse stdin JSON ---
# Pipe via stdin to python3 to avoid ARG_MAX limits on large session JSON
stdin_json=$(cat)

# Parse all four fields in a single python3 invocation (atomically, one process)
_parsed=$(echo "$stdin_json" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('session_id',''))
    print(d.get('last_assistant_message',''))
    print(d.get('transcript_path',''))
    print(d.get('cwd',''))
except Exception:
    print('')
    print('')
    print('')
    print('')
" 2>/dev/null) || _parsed=""

session_id=$(echo "$_parsed" | sed -n '1p' | tr -d '\r')
last_assistant_message=$(echo "$_parsed" | sed -n '2p' | tr -d '\r')
transcript_path=$(echo "$_parsed" | sed -n '3p' | tr -d '\r')
cwd=$(echo "$_parsed" | sed -n '4p' | tr -d '\r')

# Validate cwd is a real directory
if [ -n "${cwd:-}" ] && [ ! -d "$cwd" ]; then
  cwd=""
fi

# --- PRIMARY DETECTION: check history.jsonl for /rate-limit-options (deterministic signal) ---
# Claude Code writes {"display": "/rate-limit-options", "sessionId": "...", "project": "..."} to
# history.jsonl whenever a rate limit is hit. This is machine-written — no text pattern needed.
limit_detected=0
reset_time=""

if [ -f "$HISTORY_FILE" ] && [ -n "${session_id:-}" ]; then
  # Check for /rate-limit-options entry in the last 120 seconds for this session
  now_ms=$(python3 -c "import time; print(int(time.time()*1000))" 2>/dev/null) || now_ms=0
  # Guard: if now_ms is 0 (python3 failed), skip history check to avoid false positives
  # (cutoff_ms would be -120000 and ALL history entries would match)
  if [ "$now_ms" -gt 0 ] 2>/dev/null; then
    cutoff_ms=$(( now_ms - 120000 ))
    # Pass values via env vars — never interpolate session_id into Python string literals
    # (prevents injection if session_id ever contains quotes or special chars)
    if TARGET_SID="$session_id" CUTOFF_MS="$cutoff_ms" python3 -c "
import sys, json, os
target_sid = os.environ['TARGET_SID']
cutoff = int(os.environ['CUTOFF_MS'])
hfile = os.path.expanduser('~/.claude/history.jsonl')
found = False
with open(hfile) as f:
    for line in f:
        try:
            d = json.loads(line)
            if (d.get('display') == '/rate-limit-options' and
                    d.get('sessionId') == target_sid and
                    d.get('timestamp', 0) >= cutoff):
                found = True
                break
        except Exception:
            pass
sys.exit(0 if found else 1)
" 2>/dev/null
    then
      limit_detected=1
    fi
  fi
fi

# If history match found, also try to extract CWD from history entry (more reliable than stdin cwd)
# Scoped to session_id to avoid picking up a different project's CWD on multi-session machines
if [ "$limit_detected" -eq 1 ] && [ -z "${cwd:-}" ] && [ -f "$HISTORY_FILE" ]; then
  cwd=$(TARGET_SID="$session_id" python3 -c "
import json, os
target_sid = os.environ.get('TARGET_SID', '')
hfile = os.path.expanduser('~/.claude/history.jsonl')
with open(hfile) as f:
    for line in f:
        try:
            d = json.loads(line)
            if (d.get('display') == '/rate-limit-options' and
                    d.get('sessionId') == target_sid):
                p = d.get('project','')
                if p and os.path.isdir(p):
                    print(p)
        except Exception:
            pass
" 2>/dev/null | tail -1) || cwd=""
fi

# --- SECONDARY DETECTION: last_assistant_message text pattern (opt-in via ENABLE_TEXT_DETECTION) ---
# Disabled by default — broad text patterns produce false positives in normal conversation.
# Enable in ~/.claude/ollama.conf: ENABLE_TEXT_DETECTION=true
if [ "$limit_detected" -eq 0 ] && [ "$ENABLE_TEXT_DETECTION" = "true" ] && [ -n "${last_assistant_message:-}" ]; then
  if echo "$last_assistant_message" | grep -qiE "$LIMIT_PATTERN"; then
    limit_detected=1
    reset_time=$(echo "$last_assistant_message" | grep -oiE '(resets? [0-9]+:[0-9]+(am|pm)|until [0-9]+:[0-9]+ ?(am|pm))' | head -1 | sed -E 's/(resets? |until )//i' || true)
  fi
fi

# TERTIARY DETECTION (full transcript grep) removed — it matched normal conversation content
# (e.g. Claude discussing rate limits in code reviews) and was the primary source of false positives.
# PRIMARY detection via history.jsonl is deterministic and sufficient for all genuine limit events.
[ "$limit_detected" -eq 0 ] && exit 0

# --- Write override file ---
# OLLAMA_MODEL: use ~/.claude/.ollama-model if set, else default to kimi-k2.5:cloud
mkdir -p "$HOME/.claude"
ollama_model="kimi-k2.5:cloud"
if [ -f "$HOME/.claude/.ollama-model" ]; then
  ollama_model=$(cat "$HOME/.claude/.ollama-model" | tr -d '[:space:]')
fi
# Sanitize model name — allow only safe characters to prevent heredoc injection
ollama_model=$(printf '%s' "$ollama_model" | tr -cd 'a-zA-Z0-9:._-')
[ -z "$ollama_model" ] && ollama_model="kimi-k2.5:cloud"
# Backup current API key before override zeroes it — used by switch-back for restoration
# Use atomic tmp+mv (chmod BEFORE mv) to prevent a race window where the file exists
# but contains an empty or partial key.
_current_key="${ANTHROPIC_API_KEY:-}"
if [ -n "$_current_key" ]; then
  _key_tmp=$(mktemp "$HOME/.claude/.ollama-anthropic-key-backup.XXXXXX")
  printf '%s' "$_current_key" > "$_key_tmp"
  chmod 600 "$_key_tmp"
  mv -f "$_key_tmp" "$HOME/.claude/.ollama-anthropic-key-backup"
fi
# Atomic write via tmp file + mv to prevent partial reads during concurrent invocations
# chmod BEFORE mv so the file is never world-readable even briefly after the rename.
_override_tmp=$(mktemp "$HOME/.claude/.ollama-override.XXXXXX")
cat > "$_override_tmp" <<OVERRIDE
export ANTHROPIC_AUTH_TOKEN=ollama
export ANTHROPIC_API_KEY=""
export ANTHROPIC_BASE_URL="${OLLAMA_HOST}/v1"
export OLLAMA_MODEL="${ollama_model}"
OVERRIDE
chmod 600 "$_override_tmp"
mv -f "$_override_tmp" "$HOME/.claude/.ollama-override"

# Write reset time as epoch seconds — used by claude() wrapper for lazy cleanup check
if [ -n "${reset_time:-}" ]; then
  _reset_epoch=$(python3 -c "
import datetime, sys
t = sys.argv[1].strip().upper()
try:
    dt = datetime.datetime.strptime(t, '%I:%M%p')
    now = datetime.datetime.now()
    reset = now.replace(hour=dt.hour, minute=dt.minute, second=0, microsecond=0)
    if reset <= now:
        reset += datetime.timedelta(days=1)
    print(int(reset.timestamp()))
except Exception:
    print('')
" "$reset_time" 2>/dev/null) || _reset_epoch=""
  if [ -n "$_reset_epoch" ]; then
    printf '%s\n' "$_reset_epoch" > "$HOME/.claude/.ollama-reset-time"
  fi
fi

# --- Write handover marker ---
if [ -n "$cwd" ]; then
  mkdir -p "$cwd/tasks"
  touch "$cwd/tasks/.session-handover"
fi

# --- Append CWD to multi-session registry ---
REGISTRY="$HOME/.claude/.active-projects"
if [ -n "$cwd" ]; then
  mkdir -p "$HOME/.claude"
  # Avoid duplicates: only append if CWD not already in registry
  if ! grep -qxF "$cwd" "$REGISTRY" 2>/dev/null; then
    echo "$cwd" >> "$REGISTRY"
  fi
fi

# --- Write limit-hit tracker entry to tasks/tracker.md ---
if [ -n "$cwd" ]; then
  mkdir -p "$cwd/tasks"
  ts=$(date '+%Y-%m-%d %H:%M:%S')
  tracker_entry="
## $ts — [Limit Hit — Session Terminated]
**Type:** limit-hit
**Reason:** Anthropic usage limit detected — session ended
**Override written:** ~/.claude/.ollama-override
**Registry:** $cwd added to ~/.claude/.active-projects
**Next:** Start Ollama session — /init-context will restore context
"
  tracker_file="$cwd/tasks/tracker.md"
  if [ -f "$tracker_file" ]; then
    tmp=$(mktemp "$cwd/tasks/.tracker-tmp.XXXXXX")
    # Insert new entry after header block (before first ## entry), falling back to head-3
    _insert_line=$(grep -n '^## ' "$tracker_file" 2>/dev/null | head -1 | cut -d: -f1)
    if [ -n "$_insert_line" ] && [ "$_insert_line" -gt 1 ]; then
      _header_lines=$(( _insert_line - 1 ))
      { head -"$_header_lines" "$tracker_file"; printf '%s\n' "$tracker_entry"; tail -n +"$_insert_line" "$tracker_file"; } > "$tmp" && mv "$tmp" "$tracker_file"
    else
      { head -3 "$tracker_file"; printf '%s\n' "$tracker_entry"; tail -n +4 "$tracker_file"; } > "$tmp" && mv "$tmp" "$tracker_file"
    fi
  else
    printf '# Task Tracker\n<!-- Append-only. Newest at TOP. Two entry types: task-complete and pre-compact. -->\n<!-- Format: ## YYYY-MM-DD HH:MM:SS — <summary> -->\n%s\n' "$tracker_entry" > "$tracker_file"
  fi
fi

# (launchd scheduling removed — lazy cleanup in claude() wrapper handles switchback timing)
