#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
#  scripts/reset-to-anthropic.sh
#
#  Clears all Ollama switchover sentinel files and restores Claude
#  Code to Anthropic routing.
#
#  WHY THIS IS NEEDED:
#    The limit-watchdog.sh Stop hook detects Anthropic rate limits
#    (or false-positive pattern matches) and writes:
#      ~/.claude/.ollama-override      — env vars pointing to Ollama
#      ~/.claude/.ollama-reset-time    — epoch when Anthropic limit resets
#      ~/.claude/.handover-ready       — triggers "resume session" prompt
#    The claude() shell wrapper sources .ollama-override on every launch,
#    silently routing all traffic to Ollama until the files are removed.
#
#  USAGE:
#    bash scripts/reset-to-anthropic.sh                        # cleans files, prints env instructions
#    source scripts/reset-to-anthropic.sh                      # cleans files AND unsets vars in current shell
#    bash scripts/reset-to-anthropic.sh --restore-api-key      # also restore API key from backup/Keychain
#
# ════════════════════════════════════════════════════════════════

G='\033[0;32m' Y='\033[1;33m' C='\033[0;36m' RESET='\033[0m'

RESTORE_API_KEY=false
for arg in "$@"; do
  case $arg in
    --restore-api-key) RESTORE_API_KEY=true ;;
  esac
done

CLAUDE_DIR="${HOME}/.claude"

# ── 1. Remove sentinel files ────────────────────────────────────
removed=()
for f in \
  "${CLAUDE_DIR}/.ollama-override" \
  "${CLAUDE_DIR}/.ollama-reset-time" \
  "${CLAUDE_DIR}/.handover-ready" \
  "${CLAUDE_DIR}/.pre-switchback"; do
  if [ -f "$f" ]; then
    rm -f "$f"
    removed+=("$(basename "$f")")
  fi
done

if [ "${#removed[@]}" -gt 0 ]; then
  echo -e "${G}[done]${RESET}  Removed: ${removed[*]}"
else
  echo -e "${Y}[info]${RESET}  No sentinel files found — already clean."
fi

# ── 2. Restore API key (opt-in via --restore-api-key) ──────────
if $RESTORE_API_KEY; then
  KEY_BACKUP="${CLAUDE_DIR}/.ollama-anthropic-key-backup"
  api_key=""
  if [ -f "$KEY_BACKUP" ]; then
    api_key=$(cat "$KEY_BACKUP" 2>/dev/null | tr -d '[:space:]')
    rm -f "$KEY_BACKUP"
    [ -n "$api_key" ] && echo -e "${G}[done]${RESET}  API key restored from backup file."
  fi
  if [ -z "$api_key" ] && command -v security &>/dev/null; then
    api_key=$(security find-generic-password -a claude -s "Claude API Key" -w 2>/dev/null || echo "")
    [ -n "$api_key" ] && echo -e "${G}[done]${RESET}  API key restored from macOS Keychain."
  fi
  [ -n "$api_key" ] && export ANTHROPIC_API_KEY="$api_key"
fi

# ── 3. Unset override env vars ──────────────────────────────────
unset ANTHROPIC_BASE_URL
unset ANTHROPIC_AUTH_TOKEN
unset OLLAMA_MODEL

# ── 4. Report ──────────────────────────────────────────────────
# Check if running as a sourced script or subprocess
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  # Running as subprocess — env var changes won't persist in calling shell
  echo ""
  echo -e "${Y}[note]${RESET}  Script ran as subprocess — env vars unset inside script only."
  echo -e "        To unset them in your current terminal, run:"
  echo -e "        ${C}unset ANTHROPIC_BASE_URL ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN OLLAMA_MODEL${RESET}"
  echo -e "        Or use the built-in shell function: ${C}switch-back${RESET}"
else
  # Sourced — env changes ARE applied to calling shell
  echo -e "${G}[done]${RESET}  Env vars unset in current shell."
fi

echo ""
echo -e "${G}[done]${RESET}  Ready. Run: claude"
