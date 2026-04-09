#!/usr/bin/env bash
# scripts/switch-to-anthropic.sh — manual Anthropic restore (thin wrapper)
# NOTE: Running this script as a subprocess CANNOT restore env vars in your calling terminal.
# PREFERRED: run 'switch-back' directly (shell function installed by install.sh into ~/.zshrc)
#            It runs in-place and restores ANTHROPIC_API_KEY in the current terminal session.
# FALLBACK:  source this file instead of running it:
#            source ~/.claude/scripts/switch-to-anthropic.sh
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  echo "Tip: run 'switch-back' in your terminal instead -- it restores env vars in the current session."
  echo "   Or source this file: source ~/.claude/scripts/switch-to-anthropic.sh"
fi

unset ANTHROPIC_BASE_URL
unset ANTHROPIC_AUTH_TOKEN
unset OLLAMA_MODEL

# API key restore: backup file first, then macOS Keychain
_key_backup="$HOME/.claude/.ollama-anthropic-key-backup"
api_key=""
if [ -f "$_key_backup" ]; then
  api_key=$(cat "$_key_backup" 2>/dev/null | tr -d '[:space:]')
  rm -f "$_key_backup"
fi
if [ -z "$api_key" ] && command -v security &>/dev/null; then
  api_key=$(security find-generic-password -a claude -s "Claude API Key" -w 2>/dev/null || echo "")
fi
[ -n "$api_key" ] && export ANTHROPIC_API_KEY="$api_key"

rm -f "$HOME/.claude/.ollama-override" \
      "$HOME/.claude/.ollama-reset-time" \
      "$HOME/.claude/.pre-switchback" \
      "$HOME/.claude/.ollama-manual"

# Notify
if command -v osascript &>/dev/null; then
  osascript -e 'display notification "Switched back to Anthropic." with title "Claude Code"' 2>/dev/null || true
elif command -v notify-send &>/dev/null; then
  notify-send "Claude Code" "Switched back to Anthropic." 2>/dev/null || true
fi

echo "Switched back to Anthropic. Run: claude"
