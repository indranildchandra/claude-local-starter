#!/usr/bin/env bash
# tests/helpers/shell_functions.sh
# Verbatim copy of the four shell functions from install.sh's ZSHBLOCK.
# Source this file in tests to get the functions without running install.sh.
#
# Functions provided:
#   _claude_notify
#   _claude_pick_model
#   claude   (the wrapper — calls `command claude` internally)
#   switch-back

# ── Ollama routing — limit-triggered auto-switchover ─────────────────

_claude_notify() {
  local msg="$1" title="${2:-Claude Code}"
  if command -v osascript &>/dev/null; then
    osascript -e 'display notification "'"$msg"'" with title "'"$title"'"' 2>/dev/null || true
  elif command -v notify-send &>/dev/null; then
    notify-send "$title" "$msg" 2>/dev/null || true
  fi
  echo "🔔 $title: $msg"
}

_claude_pick_model() {
  local conf="$HOME/.claude/ollama.conf"
  local default_model="kimi-k2.5:cloud"
  [ -f "$conf" ] && { source "$conf" 2>/dev/null; default_model="${OLLAMA_DEFAULT_MODEL:-$default_model}"; }

  local saved_model
  saved_model=$(cat "$HOME/.claude/.ollama-model" 2>/dev/null | tr -d '[:space:]')
  local chosen_model="${saved_model:-$default_model}"

  if [ -t 0 ] && [ -t 1 ] && command -v ollama &>/dev/null; then
    local models=()
    while IFS= read -r line; do
      models+=("$line")
    done < <(ollama list 2>/dev/null | awk 'NR>1 {print $1}')

    if [ "${#models[@]}" -gt 0 ]; then
      echo ""
      echo "Ollama models available:"
      local i=1
      for m in "${models[@]}"; do
        [ "$m" = "$chosen_model" ] && echo "  $i) $m  ← default" || echo "  $i) $m"
        (( i++ ))
      done
      echo ""
      read -r -p "Select model [Enter = $chosen_model]: " selection || selection=""
      if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le "${#models[@]}" ]; then
        # Walk array with counter — portable across bash (0-indexed) and zsh (1-indexed)
        local _idx=1
        for _m in "${models[@]}"; do
          if [ "$_idx" -eq "$selection" ]; then chosen_model="$_m"; break; fi
          (( _idx++ ))
        done
      fi
      echo "$chosen_model" > "$HOME/.claude/.ollama-model"
    fi
  fi
  export OLLAMA_MODEL="$chosen_model"
}

claude() {
  local override="$HOME/.claude/.ollama-override"
  local reset_file="$HOME/.claude/.ollama-reset-time"
  local registry="$HOME/.claude/.active-projects"
  local conf="$HOME/.claude/ollama.conf"
  local ollama_host="http://localhost:11434"
  [ -f "$conf" ] && { source "$conf" 2>/dev/null; ollama_host="${OLLAMA_HOST:-$ollama_host}"; }

  if [ -f "$override" ]; then
    if [ -f "$reset_file" ]; then
      local reset_epoch now_epoch
      reset_epoch=$(cat "$reset_file" 2>/dev/null | tr -d '[:space:]')
      now_epoch=$(date '+%s')
      if [ -n "$reset_epoch" ] && [ "$now_epoch" -ge "$reset_epoch" ] 2>/dev/null; then
        local reset_human
        reset_human=$(date -r "$reset_epoch" '+%H:%M' 2>/dev/null \
          || date -d "@$reset_epoch" '+%H:%M' 2>/dev/null \
          || echo "epoch $reset_epoch")
        echo ""
        echo "ℹ  Your Anthropic limit has reset (was due: $reset_human)."
        printf "Switch back to Anthropic Claude now? [Y/n] "
        read -r _switch_ans
        if [[ "$_switch_ans" =~ ^[Nn] ]]; then
          echo "Staying on Ollama. Run 'switch-back' when ready to return to Anthropic."
        else
          rm -f "$override" "$reset_file"
          if [ -f "$registry" ]; then
            local tmp; tmp=$(mktemp) || return 0
            grep -vxF "$PWD" "$registry" > "$tmp" 2>/dev/null && mv "$tmp" "$registry" || rm -f "$tmp"
          fi
          echo "✅ Switched back to Anthropic. Starting session."
          command claude "$@"
          return
        fi
      fi
    else
      echo "⚠  Ollama override is active but no reset time was recorded."
      echo "   Auto-switchback is disabled. Run 'switch-back' manually when you want to return to Anthropic."
    fi

    if ! curl -sf "${ollama_host}/api/tags" >/dev/null 2>&1; then
      echo "⚠  Ollama is not running at ${ollama_host}."
      echo "   Start it with: ollama serve"
      echo "   (Or update OLLAMA_HOST in ~/.claude/ollama.conf)"
      printf "Fall back to Anthropic for this session? [Y/n] "
      read -r _fallback_ans
      if [[ "$_fallback_ans" =~ ^[Nn] ]]; then
        echo "Aborted. Start Ollama and retry."
        return 1
      fi
      echo "Falling back to Anthropic for this session (override still active for next launch)."
      command claude "$@"
      return
    fi

    # shellcheck disable=SC1090
    source "$override" || { echo "⚠  Failed to load Ollama override — check ~/.claude/.ollama-override"; return 1; }
    _claude_pick_model
    echo "⚡ Routing to Ollama ($OLLAMA_MODEL)"
    command claude "$@"

  else
    if [ -f "$registry" ]; then
      local tmp; tmp=$(mktemp) || return 0
      grep -vxF "$PWD" "$registry" > "$tmp" 2>/dev/null && mv "$tmp" "$registry" || rm -f "$tmp"
    fi
    command claude "$@"
  fi
}

switch-back() {
  unset ANTHROPIC_BASE_URL
  unset ANTHROPIC_AUTH_TOKEN
  unset OLLAMA_MODEL

  local key_backup="$HOME/.claude/.ollama-anthropic-key-backup"
  local api_key=""

  if [ -f "$key_backup" ]; then
    api_key=$(cat "$key_backup" 2>/dev/null | tr -d '[:space:]')
    rm -f "$key_backup"
  fi

  if [ -z "$api_key" ] && command -v security &>/dev/null; then
    api_key=$(security find-generic-password -a claude -s "Claude API Key" -w 2>/dev/null || echo "")
  fi

  if [ -n "$api_key" ]; then
    export ANTHROPIC_API_KEY="$api_key"
    echo "✅ ANTHROPIC_API_KEY restored."
  else
    echo "⚠  Could not restore API key automatically."
    echo "   Set manually: export ANTHROPIC_API_KEY='sk-ant-...'"
    echo "   See KNOWN-ISSUES.md — 'API key restoration on Linux' for details."
  fi

  rm -f "$HOME/.claude/.ollama-override" \
        "$HOME/.claude/.ollama-reset-time" \
        "$HOME/.claude/.pre-switchback"

  local registry="$HOME/.claude/.active-projects"
  if [ -f "$registry" ]; then
    local tmp; tmp=$(mktemp) || return 0
    grep -vxF "$PWD" "$registry" > "$tmp" 2>/dev/null && mv "$tmp" "$registry" || rm -f "$tmp"
  fi

  _claude_notify "Switched back to Anthropic manually." "Claude Code"
  echo "✅ Ready — run: claude (same terminal, no restart needed)"
}
