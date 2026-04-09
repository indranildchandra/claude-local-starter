#!/usr/bin/env bash
# scripts/switch-to-ollama.sh — manually activate Ollama routing
# Prefer: run '/switch-local-model-on' inside Claude, which guides you through this.
# Direct use: bash ~/.claude/scripts/switch-to-ollama.sh [reset_hour reset_minute]
#   e.g. bash ~/.claude/scripts/switch-to-ollama.sh 15 0   (reset at 3:00 PM)
set -euo pipefail

CLAUDE_DIR="$HOME/.claude"
mkdir -p "$CLAUDE_DIR"

conf="$CLAUDE_DIR/ollama.conf"
[ -f "$conf" ] && source "$conf" 2>/dev/null
OLLAMA_HOST="${OLLAMA_HOST:-http://localhost:11434}"
OLLAMA_DEFAULT_MODEL="${OLLAMA_DEFAULT_MODEL:-kimi-k2.5:cloud}"

# --- Health check ---
if ! curl -sf "${OLLAMA_HOST}/api/tags" >/dev/null 2>&1; then
  echo "Ollama is not running at ${OLLAMA_HOST}."
  echo "   Start it with: ollama serve"
  exit 1
fi
echo "Ollama is running."

# --- Model selection ---
ollama_model="${OLLAMA_DEFAULT_MODEL}"
if [ -f "$CLAUDE_DIR/.ollama-model" ]; then
  saved=$(cat "$CLAUDE_DIR/.ollama-model" 2>/dev/null | tr -d '[:space:]')
  [ -n "$saved" ] && ollama_model="$saved"
fi

# _OLLAMA_FORCE_INTERACTIVE=1 bypasses the tty check — used by bats tests only, never set in production
if { [ -t 0 ] && [ -t 1 ] || [ "${_OLLAMA_FORCE_INTERACTIVE:-}" = "1" ]; } && command -v ollama &>/dev/null; then
  models=()
  while IFS= read -r line; do
    models+=("$line")
  done < <(ollama list 2>/dev/null | awk 'NR>1 {print $1}')

  if [ "${#models[@]}" -gt 0 ]; then
    echo ""
    echo "Ollama models available:"
    i=1
    for m in "${models[@]}"; do
      [ "$m" = "$ollama_model" ] && echo "  $i) $m  ← default" || echo "  $i) $m"
      (( i++ ))
    done
    echo ""
    read -r -p "Select model [Enter = $ollama_model]: " selection || selection=""
    if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le "${#models[@]}" ]; then
      ollama_model="${models[$((selection - 1))]}"  # bash arrays are 0-indexed: selection 1 → index 0
    fi
  fi
fi
# Sanitize — allow only safe characters
ollama_model=$(printf '%s' "$ollama_model" | tr -cd 'a-zA-Z0-9:._-')
[ -z "$ollama_model" ] && ollama_model="$OLLAMA_DEFAULT_MODEL"
echo "$ollama_model" > "$CLAUDE_DIR/.ollama-model"

# --- Write override ---
# Backup current API key before zeroing it.
# Use atomic tmp+mv (chmod BEFORE mv) to prevent a race window where the file
# exists but contains an empty or partial key.
_current_key="${ANTHROPIC_API_KEY:-}"
if [ -n "$_current_key" ]; then
  _key_tmp=$(mktemp "$CLAUDE_DIR/.ollama-anthropic-key-backup.XXXXXX")
  printf '%s' "$_current_key" > "$_key_tmp"
  chmod 600 "$_key_tmp"
  mv -f "$_key_tmp" "$CLAUDE_DIR/.ollama-anthropic-key-backup"
fi

# chmod BEFORE mv so the override file is never world-readable even briefly after rename.
_override_tmp=$(mktemp "$CLAUDE_DIR/.ollama-override.XXXXXX")
cat > "$_override_tmp" <<OVERRIDE
export ANTHROPIC_AUTH_TOKEN=ollama
export ANTHROPIC_API_KEY=""
export ANTHROPIC_BASE_URL="${OLLAMA_HOST}/v1"
export OLLAMA_MODEL="${ollama_model}"
OVERRIDE
chmod 600 "$_override_tmp"
mv -f "$_override_tmp" "$CLAUDE_DIR/.ollama-override"

# --- Write reset time (optional: pass as args or prompt) ---
reset_hour="${1:-}"
reset_minute="${2:-}"

if [ -z "$reset_hour" ] && [ -t 0 ] && [ -t 1 ]; then
  echo ""
  read -r -p "Set reset time? Enter hour (24h, e.g. 15 for 3 PM) or press Enter to skip: " reset_hour || reset_hour=""
  if [ -n "$reset_hour" ]; then
    read -r -p "  Minute [0]: " reset_minute || reset_minute=""
    reset_minute="${reset_minute:-0}"
  fi
fi

if [ -n "$reset_hour" ]; then
  # Pass values via env vars — never interpolate user-supplied strings into Python
  # string literals (prevents code injection if the value contains quotes or parens).
  reset_epoch=$(RESET_HOUR="$reset_hour" RESET_MINUTE="${reset_minute:-0}" python3 -c "
import datetime, os
now = datetime.datetime.now()
try:
    h, m = int(os.environ['RESET_HOUR']), int(os.environ['RESET_MINUTE'])
    reset = now.replace(hour=h, minute=m, second=0, microsecond=0)
    if reset <= now:
        reset += datetime.timedelta(days=1)
    print(int(reset.timestamp()))
except Exception:
    print('')
" 2>/dev/null) || reset_epoch=""
  if [ -n "$reset_epoch" ]; then
    printf '%s\n' "$reset_epoch" > "$CLAUDE_DIR/.ollama-reset-time"
    echo "Reset time set: $(date -r "$reset_epoch" '+%H:%M' 2>/dev/null || date -d "@$reset_epoch" '+%H:%M' 2>/dev/null || echo "$reset_epoch")"
  fi
fi

touch "$CLAUDE_DIR/.ollama-manual"

echo ""
echo "Ollama override active (model: $ollama_model)."
echo "Run: claude (the wrapper will route to Ollama automatically)"
echo "To switch back: switch-back"
