#!/usr/bin/env bash
# scripts/switch-to-anthropic.sh — restore Anthropic routing and clean up all Ollama sentinel files.
#
# Usage modes:
#   source ~/.claude/scripts/switch-to-anthropic.sh   (preferred) — restores env vars in current shell
#   bash ~/.claude/scripts/switch-to-anthropic.sh     — cleans sentinel files; prints env commands to run
#   switch-back                                        (easiest) — shell function installed by install.sh

CLAUDE_DIR="$HOME/.claude"

# --- Key restoration (three paths, priority order) ---
_key_backup="$CLAUDE_DIR/.ollama-anthropic-key-backup"
api_key=""

# Path 1: backup file (most reliable — written by watchdog/switch-to-ollama before key was zeroed)
if [ -f "$_key_backup" ]; then
  api_key=$(cat "$_key_backup" 2>/dev/null | tr -d '[:space:]')
  rm -f "$_key_backup"
fi

# Path 2: Linux / cross-platform — Claude Code native credential store (~/.claude/.credentials)
if [ -z "$api_key" ] && [ -f "$CLAUDE_DIR/.credentials" ]; then
  api_key=$(python3 -c "
import json, os, sys
p = os.path.join(os.path.expanduser('~'), '.claude', '.credentials')
try:
    d = json.load(open(p))
    k = d.get('anthropicApiKey', '') or d.get('apiKey', '')
    print(k.strip() if k else '')
except Exception:
    pass
" 2>/dev/null) || api_key=""
fi

# Path 3: macOS Keychain
if [ -z "$api_key" ] && command -v security &>/dev/null; then
  api_key=$(security find-generic-password -a claude -s "Claude API Key" -w 2>/dev/null || echo "")
fi

# --- Apply to current shell (only effective when sourced, not when run as subprocess) ---
unset ANTHROPIC_BASE_URL
unset ANTHROPIC_AUTH_TOKEN
unset OLLAMA_MODEL
[ -n "$api_key" ] && export ANTHROPIC_API_KEY="$api_key"

# --- Clean up all sentinel files ---
rm -f "$CLAUDE_DIR/.ollama-override" \
      "$CLAUDE_DIR/.ollama-reset-time" \
      "$CLAUDE_DIR/.pre-switchback" \
      "$CLAUDE_DIR/.ollama-manual"

# --- Desktop notification ---
if command -v osascript &>/dev/null; then
  osascript -e 'display notification "Switched back to Anthropic." with title "Claude Code"' 2>/dev/null || true
elif command -v notify-send &>/dev/null; then
  notify-send "Claude Code" "Switched back to Anthropic." 2>/dev/null || true
fi

# --- Output ---
echo "Anthropic routing restored. Sentinel files cleared."
if [ -n "$api_key" ]; then
  echo "ANTHROPIC_API_KEY: restored (${#api_key} chars)"
else
  echo "ANTHROPIC_API_KEY: not found automatically."
  echo "  Set manually:  export ANTHROPIC_API_KEY='sk-ant-...'"
  echo "  See KNOWN-ISSUES.md — 'API key restoration on Linux' for details."
fi

# When run as a subprocess (not sourced): env var changes above don't affect the calling shell.
# Print a reminder with the exact commands to run.
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  echo ""
  echo "NOTE: run as script — env vars cannot propagate to the calling shell."
  echo "Run these in your terminal, or just run 'switch-back':"
  echo "  unset ANTHROPIC_BASE_URL ANTHROPIC_AUTH_TOKEN OLLAMA_MODEL"
  [ -z "$api_key" ] && echo "  export ANTHROPIC_API_KEY='sk-ant-...'"
  echo ""
  echo "Or source this file:  source ~/.claude/scripts/switch-to-anthropic.sh"
  echo "Or use the function:  switch-back"
fi

echo "Run: claude"
