# Next Steps: Ollama Switchover — Redesign v2

**Date:** 2026-03-25
**Status:** Planning — approved, ready for implementation
**Context:** Three architectural bugs prevent reliable end-to-end Ollama switchover (see Root Cause Analysis below). This doc is the implementation spec. Non-blocking issues are parked in `KNOWN-ISSUES.md` at the repo root.

---

## Root Cause Analysis

### Bug 1 — Missing `claude()` wrapper (CRITICAL)
`install.sh` never writes a `claude()` wrapper function to `.zshrc`. Without it, `.ollama-override` is never sourced and `ANTHROPIC_BASE_URL` is never set in a new terminal. Auto-routing only works if the user manually runs `source ~/.claude/.ollama-override` before launching Claude.

### Bug 2 — launchd kills background phase-2 process
`switch-to-anthropic.sh` backgrounds its cleanup phase (`_phase2 &`) to let the launchd job exit quickly. On macOS, launchd kills orphaned child processes when the parent exits. Phase 2 never runs: `.ollama-override` is not deleted, the plist is not removed. The plist fires daily at 2:30 AM indefinitely.

### Bug 3 — External scheduler is OS-specific and unreliable
`at` is unreliable on macOS (SIP-disabled requirement). launchd is macOS-only. Claude Code's remote scheduler runs cloud agents that cannot write to the local filesystem. None of these are the right tool.

### Bug 4 — `mapfile` is bash-only (SILENT FAILURE in zsh)
The original model picker used `mapfile -t models < <(...)` which silently fails in zsh — produces an empty array with no error. Users see no models listed and the picker doesn't work.

---

## Design: No External Scheduler

The key insight: **no scheduler is needed**. Instead of proactively triggering a switchback, the `claude()` wrapper performs a lazy cleanup check on every launch. If the reset time has passed, it prompts the user before starting a new session.

```
claude()
  │
  ├─ .ollama-override exists?
  │     │
  │     ├─ YES → read .ollama-reset-time
  │     │          │
  │     │          ├─ current_time >= reset_time → PROMPT user: "Switch back to Anthropic? [Y/n]"
  │     │          │     ├─ Y → DELETE override + reset-time → launch Anthropic
  │     │          │     └─ N → stay on Ollama → health check → model picker → launch
  │     │          │
  │     │          └─ current_time < reset_time
  │     │              → health check Ollama (curl /api/tags)
  │     │              │   ├─ NOT running → warn → "Fall back to Anthropic? [Y/n]"
  │     │              │   └─ running → source override → _claude_pick_model → launch
  │     │
  │     └─ NO reset-time file → warn: "no reset time — use switch-back manually"
  │
  └─ NO override → normal Anthropic session
```

---

## Components to Build / Fix

### 1. `_claude_pick_model()` helper — ZSH-COMPATIBLE model picker

**Problem:** The original picker used `mapfile` (bash-only builtin) — silently fails in zsh.
**Fix:** Replace with `while IFS= read -r line; do models+=("$line"); done < <(...)`.

**Where it lives:** Written to `.zshrc` block by `install.sh`. Placed *before* `claude()` and `switch-back` since both depend on it. Also reads `~/.claude/ollama.conf` for `OLLAMA_DEFAULT_MODEL`.

```bash
_claude_pick_model() {
  # Reads OLLAMA_DEFAULT_MODEL from ollama.conf; saves chosen model to .ollama-model
  # Sets OLLAMA_MODEL in the current shell
  local conf="$HOME/.claude/ollama.conf"
  local default_model="glm4-flash"
  [ -f "$conf" ] && { source "$conf" 2>/dev/null; default_model="${OLLAMA_DEFAULT_MODEL:-$default_model}"; }

  local saved_model
  saved_model=$(cat "$HOME/.claude/.ollama-model" 2>/dev/null | tr -d '[:space:]')
  local chosen_model="${saved_model:-$default_model}"

  if [ -t 0 ] && [ -t 1 ] && command -v ollama &>/dev/null; then
    local models=()
    # zsh-compatible: while read loop instead of mapfile (mapfile is bash-only)
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
      read -r -p "Select model [Enter = $chosen_model]: " selection
      if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le "${#models[@]}" ]; then
        chosen_model="${models[$((selection-1))]}"
      fi
      echo "$chosen_model" > "$HOME/.claude/.ollama-model"
    fi
  fi
  export OLLAMA_MODEL="$chosen_model"
}
```

---

### 2. `claude()` wrapper — USER PROMPT ON BREACH + OLLAMA HEALTH CHECK

New behaviour vs previous design:
- **User prompt on reset breach** — instead of silently switching back, ask the user (they may want to stay on Ollama)
- **Warn when no reset-time file** — instead of silently assuming Anthropic is fine, warn that auto-switchback is disabled
- **Ollama health check** — if `.ollama-override` is active but Ollama isn't responding, warn and offer Anthropic fallback (prevents hard launch failures)
- **Delegates model picking** to `_claude_pick_model()` (DRY, fixes zsh bug)

**install.sh change:** Add this function inside the `# ── claude-local-starter managed ──` zshrc block, after `_claude_pick_model`. Guard with start/end markers (same pattern as the outer block) so re-running `install.sh` replaces rather than duplicates.

```bash
_claude_notify() {
  local msg="$1" title="${2:-Claude Code}"
  # macOS
  if command -v osascript &>/dev/null; then
    osascript -e "display notification \"$msg\" with title \"$title\"" 2>/dev/null || true
  # Linux (libnotify — install: apt install libnotify-bin)
  elif command -v notify-send &>/dev/null; then
    notify-send "$title" "$msg" 2>/dev/null || true
  fi
  # Terminal echo is the universal fallback — always runs
  echo "🔔 $title: $msg"
}

_claude_pick_model() {
  # ... (see Section 1)
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
        # Human-readable reset time — try macOS date -r, then GNU date -d, then epoch fallback
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
          # Fall through to health check + model picker below
        else
          rm -f "$override" "$reset_file"
          if [ -f "$registry" ]; then
            local tmp; tmp=$(mktemp)
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

    # Ollama health check — prevent hard failures if Ollama isn't running
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

    # Source override + pick model + launch
    # shellcheck disable=SC1090
    source "$override"
    _claude_pick_model
    echo "⚡ Routing to Ollama ($OLLAMA_MODEL)"
    command claude "$@"

  else
    # Normal Anthropic session — clean up registry entry for this CWD
    if [ -f "$registry" ]; then
      local tmp; tmp=$(mktemp)
      grep -vxF "$PWD" "$registry" > "$tmp" 2>/dev/null && mv "$tmp" "$registry" || rm -f "$tmp"
    fi
    command claude "$@"
  fi
}
```

---

### 3. `limit-watchdog.sh` — 3 ADDITIONS + REMOVE LAUNCHD

**File:** `scripts/limit-watchdog.sh`

#### Addition A — Source `ollama.conf` for configurable regex (add near top, before LIMIT_PATTERN)

Replace the hardcoded `LIMIT_PATTERN=` line with:

```bash
# Source ollama.conf for user-configurable overrides (LIMIT_PATTERN, OLLAMA_HOST, OLLAMA_DEFAULT_MODEL)
_conf="$HOME/.claude/ollama.conf"
[ -f "$_conf" ] && source "$_conf" 2>/dev/null

# Fall back to built-in pattern if user hasn't overridden
LIMIT_PATTERN="${LIMIT_PATTERN:-'(hit your limit|out of free messages|usage limit|at capacity|exceeded.*limit|limit.*exceeded|resets [0-9]+:[0-9]+(am|pm))'}"
```

#### Addition B — Write API key backup (add after `# --- Write override file ---` block, BEFORE the override zeros the key)

Insert immediately before the `cat > "$_override_tmp" <<OVERRIDE` heredoc:

```bash
# Backup current API key before override zeroes it — used by switch-back for restoration
_current_key="${ANTHROPIC_API_KEY:-}"
if [ -n "$_current_key" ]; then
  printf '%s' "$_current_key" > "$HOME/.claude/.ollama-anthropic-key-backup"
  chmod 600 "$HOME/.claude/.ollama-anthropic-key-backup"
fi
```

#### Addition C — Write reset-time epoch file (add after `mv -f "$_override_tmp" "$HOME/.claude/.ollama-override"`)

```bash
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
```

#### Removal — Delete entire `# --- Schedule switchback ---` section (lines 165-221)

Remove from `# --- Schedule switchback ---` through the closing `fi` (the entire launchd plist generation block). Replace with:

```bash
# (launchd scheduling removed — lazy cleanup in claude() wrapper handles switchback timing)
```

---

### 4. `ollama.conf` — NEW CONFIG FILE

**Repo file:** `ollama.conf` (new, at repo root)
**Install destination:** `~/.claude/ollama.conf`
**Install rule:** Write on first install only — never overwrite (user's customisations must survive `install.sh` re-runs).

```bash
# ~/.claude/ollama.conf — Ollama routing configuration
# Sourced by: limit-watchdog.sh (Stop hook) and claude() shell wrapper
# Edit freely — re-running install.sh will NOT overwrite this file.

# Regex matched against Claude's stop output to detect an Anthropic limit breach.
# Default covers standard Anthropic rate-limit messages. Extend with | to add alternatives.
# LIMIT_PATTERN="usage limit|rate limit|overloaded|529"

# Default Ollama model when no model has been saved via the interactive picker.
# OLLAMA_DEFAULT_MODEL="glm4-flash"

# Ollama server address. Change if running on a non-default port or remote host.
# OLLAMA_HOST="http://localhost:11434"
```

All entries are commented out by default so the built-in fallback values in the scripts apply unless the user explicitly overrides.

---

### 5. `switch-back` function — API KEY BACKUP FILE PRIORITY

**Problem with v1:** Only tried the macOS Keychain. On macOS, the keychain lookup works. But if `ANTHROPIC_API_KEY` was set as an env var (not Keychain), the Keychain lookup returns empty and the user has to set it manually.
**Fix:** Priority 1 = backup file written by `limit-watchdog.sh` *before* the override zeroed the key. Priority 2 = macOS Keychain fallback. Priority 3 = warn user.

```bash
switch-back() {
  # Step 1: Restore Anthropic env vars in the CURRENT shell (function runs in-place)
  unset ANTHROPIC_BASE_URL
  unset ANTHROPIC_AUTH_TOKEN
  unset OLLAMA_MODEL

  # Step 2: Restore API key
  local key_backup="$HOME/.claude/.ollama-anthropic-key-backup"
  local api_key=""

  # Priority 1: backup file written by limit-watchdog.sh before override zeroed the key
  if [ -f "$key_backup" ]; then
    api_key=$(cat "$key_backup" 2>/dev/null | tr -d '[:space:]')
    rm -f "$key_backup"
  fi

  # Priority 2: macOS Keychain (tested on macOS only — see KNOWN-ISSUES.md for Linux)
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

  # Step 3: Clean up state files
  rm -f "$HOME/.claude/.ollama-override" \
        "$HOME/.claude/.ollama-reset-time" \
        "$HOME/.claude/.pre-switchback"

  # Step 4: Remove this CWD from active-projects registry
  local registry="$HOME/.claude/.active-projects"
  if [ -f "$registry" ]; then
    local tmp; tmp=$(mktemp)
    grep -vxF "$PWD" "$registry" > "$tmp" 2>/dev/null && mv "$tmp" "$registry" || rm -f "$tmp"
  fi

  # Step 5: Notify
  _claude_notify "Switched back to Anthropic manually." "Claude Code"
  echo "✅ Ready — run: claude (same terminal, no restart needed)"
}
```

---

### 6. `scripts/switch-to-anthropic.sh` — THIN WRAPPER

The existing script is replaced with a thin wrapper that sources the `switch-back` shell function. The script itself cannot modify the calling terminal's env vars (subshell limitation) — it prints a tip instead.

```bash
#!/usr/bin/env bash
# switch-to-anthropic.sh — manual override cleanup
# Prefer: run 'switch-back' directly (shell function from install.sh) — restores env in current terminal.
# This script is a fallback for cases where the shell function isn't available.
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  echo "ℹ  Tip: run 'switch-back' in your terminal instead (restores env in current session)."
  echo "   Or: source ${BASH_SOURCE[0]}"
fi

unset ANTHROPIC_BASE_URL ANTHROPIC_AUTH_TOKEN OLLAMA_MODEL

# API key: backup file first, then Keychain
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
      "$HOME/.claude/.pre-switchback"

command -v osascript &>/dev/null && \
  osascript -e 'display notification "Switched back to Anthropic." with title "Claude Code"' 2>/dev/null || \
  command -v notify-send &>/dev/null && \
  notify-send "Claude Code" "Switched back to Anthropic." 2>/dev/null || true

echo "✅ Switched back to Anthropic. Run: claude"
```

---

### 7. `scripts/switch-to-ollama.sh` — NEW SCRIPT (paired with `/switch-local-model-on`)

**Why a script and not just the command:** The `/switch-local-model-on` command runs inside Claude — it can display instructions but cannot execute shell commands in the user's terminal. The `switch-to-ollama.sh` script is what actually writes the state files. The command delegates to it.

**Analogous to `switch-to-anthropic.sh`** — creates the same symmetry: one script per direction, one slash command per direction.

```bash
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
OLLAMA_DEFAULT_MODEL="${OLLAMA_DEFAULT_MODEL:-glm4-flash}"

# --- Health check ---
if ! curl -sf "${OLLAMA_HOST}/api/tags" >/dev/null 2>&1; then
  echo "❌ Ollama is not running at ${OLLAMA_HOST}."
  echo "   Start it with: ollama serve"
  exit 1
fi
echo "✅ Ollama is running."

# --- Model selection ---
ollama_model="${OLLAMA_DEFAULT_MODEL}"
if [ -f "$CLAUDE_DIR/.ollama-model" ]; then
  saved=$(cat "$CLAUDE_DIR/.ollama-model" 2>/dev/null | tr -d '[:space:]')
  [ -n "$saved" ] && ollama_model="$saved"
fi

if [ -t 0 ] && [ -t 1 ]; then
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
    read -r -p "Select model [Enter = $ollama_model]: " selection
    if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le "${#models[@]}" ]; then
      ollama_model="${models[$((selection-1))]}"
    fi
  fi
fi
# Sanitize — allow only safe characters
ollama_model=$(printf '%s' "$ollama_model" | tr -cd 'a-zA-Z0-9:._-')
[ -z "$ollama_model" ] && ollama_model="$OLLAMA_DEFAULT_MODEL"
echo "$ollama_model" > "$CLAUDE_DIR/.ollama-model"

# --- Write override ---
# Backup current API key before zeroing it
_current_key="${ANTHROPIC_API_KEY:-}"
if [ -n "$_current_key" ]; then
  printf '%s' "$_current_key" > "$CLAUDE_DIR/.ollama-anthropic-key-backup"
  chmod 600 "$CLAUDE_DIR/.ollama-anthropic-key-backup"
fi

_override_tmp=$(mktemp "$CLAUDE_DIR/.ollama-override.XXXXXX")
cat > "$_override_tmp" <<OVERRIDE
export ANTHROPIC_AUTH_TOKEN=ollama
export ANTHROPIC_API_KEY=""
export ANTHROPIC_BASE_URL=${OLLAMA_HOST}/v1
export OLLAMA_MODEL="${ollama_model}"
OVERRIDE
mv -f "$_override_tmp" "$CLAUDE_DIR/.ollama-override"

# --- Write reset time (optional: pass as args or prompt) ---
reset_hour="${1:-}"
reset_minute="${2:-}"

if [ -z "$reset_hour" ] && [ -t 0 ] && [ -t 1 ]; then
  echo ""
  read -r -p "Set reset time? Enter hour (24h, e.g. 15 for 3 PM) or press Enter to skip: " reset_hour
  if [ -n "$reset_hour" ]; then
    read -r -p "  Minute [0]: " reset_minute
    reset_minute="${reset_minute:-0}"
  fi
fi

if [ -n "$reset_hour" ]; then
  reset_epoch=$(python3 -c "
import datetime
now = datetime.datetime.now()
try:
    h, m = int('$reset_hour'), int('${reset_minute:-0}')
    reset = now.replace(hour=h, minute=m, second=0, microsecond=0)
    if reset <= now:
        reset += datetime.timedelta(days=1)
    print(int(reset.timestamp()))
except Exception:
    print('')
" 2>/dev/null) || reset_epoch=""
  if [ -n "$reset_epoch" ]; then
    printf '%s\n' "$reset_epoch" > "$CLAUDE_DIR/.ollama-reset-time"
    echo "✅ Reset time set: $(date -r "$reset_epoch" '+%H:%M' 2>/dev/null || date -d "@$reset_epoch" '+%H:%M' 2>/dev/null || echo "$reset_epoch")"
  fi
fi

echo ""
echo "⚡ Ollama override active (model: $ollama_model)."
echo "   Run: claude (the wrapper will route to Ollama automatically)"
echo "   To switch back: switch-back  OR  source ~/.claude/scripts/switch-to-anthropic.sh"
```

---

### 8. `settings.json` — RESTORE 3 MISSING HOOKS

Current `settings.json` (source of truth in repo) only has `PreCompact`. Three hooks are missing. Add to the `"hooks"` object:

#### Stop hooks (both watchdog and AIDLC guard)
```json
"Stop": [
  {
    "matcher": "",
    "hooks": [
      { "type": "command", "command": "~/.claude/scripts/limit-watchdog.sh" },
      { "type": "command", "command": "~/.claude/scripts/aidlc-guard.sh" }
    ]
  }
]
```

#### SessionStart hook (context resume hint)
```json
"SessionStart": [
  {
    "matcher": "",
    "hooks": [
      {
        "type": "command",
        "command": "[ -f ~/.claude/.handover-ready ] && echo 'Handover marker found — run /init-context to resume your last session.' || true"
      }
    ]
  }
]
```

#### PreToolUse hook (5-minute reset warning — time-based, no marker file, OS-independent)
```json
"PreToolUse": [
  {
    "matcher": "",
    "hooks": [
      {
        "type": "command",
        "command": "if [ -f \"$HOME/.claude/.ollama-override\" ] && [ -f \"$HOME/.claude/.ollama-reset-time\" ]; then reset_epoch=$(cat \"$HOME/.claude/.ollama-reset-time\" | tr -d '[:space:]'); now_epoch=$(date '+%s'); remaining=$((reset_epoch - now_epoch)); if [ \"$remaining\" -le 300 ] && [ \"$remaining\" -gt 0 ]; then echo \"WARNING: Anthropic limit resets in $((remaining / 60)) min — run /log-context NOW to preserve session state.\"; fi; fi"
      }
    ]
  }
]
```

---

### 9. New slash command: `/switch-local-model-off`

**File:** `commands/switch-local-model-off.md`
**Maps to:** `switch-back` shell function / `switch-to-anthropic.sh` script

```markdown
---
description: Switch back to Anthropic Claude from local Ollama routing
---

Switch the current terminal back to Anthropic and clean up all Ollama override state.

## Step 1 — Run switch-back in terminal

Ask the user to run this in their terminal:

​```bash
switch-back
​```

If the shell function isn't available (install.sh not run yet):

​```bash
source ~/.claude/scripts/switch-to-anthropic.sh
​```

## Step 2 — Verify the switch

Ask the user to confirm:

​```bash
echo "API key set: ${ANTHROPIC_API_KEY:+yes (${#ANTHROPIC_API_KEY} chars)}"
echo "Base URL: ${ANTHROPIC_BASE_URL:-<unset — correct>}"
echo "Ollama model: ${OLLAMA_MODEL:-<unset — correct>}"
​```

Expected: API key present, `ANTHROPIC_BASE_URL` and `OLLAMA_MODEL` unset.

## Step 3 — Launch Anthropic session

The terminal is now ready. Run `claude` — no restart required.
```

---

### 10. New slash command: `/switch-local-model-on`

**File:** `commands/switch-local-model-on.md`
**Maps to:** `switch-to-ollama.sh` script

```markdown
---
description: Manually switch to local Ollama model routing
---

Manually activate Ollama routing (use when the automatic Stop-hook detection missed the limit, or to test locally without hitting Anthropic). This command delegates all state-file work to `switch-to-ollama.sh`.

## Step 1 — Run the switch script in your terminal

Ask the user to run:

​```bash
bash ~/.claude/scripts/switch-to-ollama.sh
​```

The script will:
- Check Ollama is running (errors out if not)
- Present an interactive model picker (zsh + bash compatible)
- Write `.ollama-override` and `.ollama-anthropic-key-backup`
- Optionally prompt for a reset time and write `.ollama-reset-time`

To set a reset time non-interactively (e.g. reset at 3:00 PM):

​```bash
bash ~/.claude/scripts/switch-to-ollama.sh 15 0
​```

## Step 2 — Verify the switch

​```bash
echo "Base URL: ${ANTHROPIC_BASE_URL:-<unset>}"
cat ~/.claude/.ollama-override
cat ~/.claude/.ollama-reset-time 2>/dev/null && echo "(reset time set)" || echo "(no reset time)"
​```

## Step 3 — Launch Ollama session

Run `claude` — the wrapper detects the override, runs a health check, presents the model picker, and routes to Ollama.
```

---

### 11. `install.sh` — CHECKLIST OF CHANGES

- [ ] **Step 12 (zshrc block):** Add `_claude_notify()` helper (before all other functions)
- [ ] **Step 12 (zshrc block):** Add `_claude_pick_model()` helper (after `_claude_notify`, before `claude()`)
- [ ] **Step 12 (zshrc block):** Add `claude()` wrapper (after `_claude_pick_model`)
- [ ] **Step 12 (zshrc block):** Add `switch-back` function (after `claude()`)
- [ ] **Step 12 (zshrc block):** The outer `# ── claude-local-starter managed ──` / `# ── end claude-local-starter ──` block already handles idempotency via Python `re.sub` replacement — the 4 new functions are inside this block and will be replaced correctly on re-run
- [ ] **Step 13 (artefact sync):** Add deploy of `ollama.conf` to `~/.claude/ollama.conf` (skip if already exists: `[ -f "$HOME/.claude/ollama.conf" ] || cp ...`)
- [ ] **Step 13 (artefact sync):** Add deploy of `scripts/switch-to-ollama.sh` to `~/.claude/scripts/switch-to-ollama.sh`
- [ ] **Step 13 (artefact sync):** Add deploy of `commands/switch-local-model-off.md` and `commands/switch-local-model-on.md` to `~/.claude/commands/`
- [ ] **launchd cleanup step:** Before step 12, add: `launchctl bootout "gui/$(id -u)" ~/Library/LaunchAgents/com.claude.switchback.plist 2>/dev/null || true; rm -f ~/Library/LaunchAgents/com.claude.switchback.plist` (cleans up existing installs)
- [ ] **CLAUDE.md:** Update "Key Files" table and "Shell Functions Installed" section to reflect new functions, scripts, and commands

---

## Workflow Enhancements

Accepted items from the Design Notes Review. These are independent of the Ollama switchover and can be implemented in a separate pass.

---

### 12. Adversarial challenger persona — `skills/review-council/`

**Pattern decision: standalone persona file, not embedded in `SKILL.md`.**

The review-council runs each persona as an *isolated subagent* in Phase 3 — it sees only its own persona file + the domain profile, never the other personas' outputs. Embedding the adversarial role in `SKILL.md` would put it in the main context (it sees everything), destroy isolation, and make it impossible to tune independently. The right pattern is a standard persona file, consistent with all 23 existing personas.

**One `SKILL.md` change required:** Add `adversarial-challenger` to the Phase 2 mandatory inclusion list. Currently the rule is "must include at least one of: staff-engineer, cloud-cost-architect, appsec-architect." The adversarial challenger is domain-agnostic — it should run on every non-trivial review. Add it as a hard requirement alongside the existing mandatory list, so Phase 2 always selects it regardless of scope or complexity.

**Files:**
- `skills/review-council/standard-personas/adversarial-challenger.md` (new)
- `skills/review-council/SKILL.md` (update Phase 2 mandatory inclusion rule)

**Persona file spec** — follows the exact same schema as all 23 existing personas (role, review lens, typical concerns, challenge style; frontmatter with name/domain/model/council-domains):

```markdown
---
name: Adversarial Challenger
domain: Failure Mode Analysis
model: sonnet
council-domains: [backend, frontend, platform, api, data, security, ml, product]
---

## Role
Assumes every proposal will fail in production and proves it. Does not offer solutions — that is the other personas' job. Exclusively finds what the designer didn't think about: the edge case, the missing invariant, the assumption that doesn't hold under real conditions. Works best when the other personas have converged — a chorus of agreement is exactly when an adversarial voice is most needed.

## Review Lens
- What assumptions does this design make that are not stated and not tested?
- What happens when a dependency (file, process, network, external API) is absent, slow, or returns garbage?
- What is the failure mode — is it loud and immediate, or silent and accumulating?
- What path through this system has never been exercised by the designer?
- What changes in 6 months (team, load, OS, dependency version) that will silently break this?
- If an adversary controls the inputs, the environment, or the timing — what do they get?
- What does "working correctly" actually mean here, and is that definition anywhere in the code?

## Typical Concerns
- Designs that only describe the happy path — no error states, no partial failures, no concurrent access
- State files or env vars that are written but never validated before being read
- Silent fallbacks (`|| true`, `2>/dev/null`) that mask real failures and make debugging impossible
- Assumptions about execution order that hold in testing but break under load or parallelism
- Cleanup code that depends on the thing it's cleaning up still being in a good state

## Challenge Style
Adversarial and methodical. Works through failure dimensions one at a time: "What if this file doesn't exist? What if it exists but is empty? What if it's being written by another process right now?" Does not accept "that won't happen in practice" as an answer — demands either code that handles the case or an explicit, documented assumption that it cannot occur. Concedes only when shown a specific code path that handles the failure, or an explicit test that proves it.
```

**install.sh:** The `review-council` skill syncs from `skills/review-council/`. Both the new persona file and the updated `SKILL.md` deploy automatically on next `bash install.sh`.

---

### 13. AIDLC tracking format enhancements — code snippets + session tagging

**What:** Two related format changes to all tracking files:

1. **Session ID + name on every entry** — `$CLAUDE_SESSION_ID` is already available in hooks. Standardize it across all format specs so entries are traceable back to the session that produced them.

2. **Key change code block** — Add an optional `**Key change:**` fenced block (max 20 lines, prefer diff format) to `tracker.md` and `changelog.md` entries. Makes context recovery after compaction significantly faster — you see *what changed* not just *that something changed*.

**Files to update:**

`skills/aidlc-tracking/formats/tracker.md` — add to entry template:
```
**Session:** ${CLAUDE_SESSION_ID:-unknown} | ${CLAUDE_SESSION_NAME:-unnamed}
**Key change:** (optional — paste relevant diff or function signature, max 20 lines)
```

`skills/aidlc-tracking/formats/changelog.md` — add to entry template:
```
**Session:** ${CLAUDE_SESSION_ID:-unknown}
**Key change:**
\`\`\`diff
- old behaviour / removed code
+ new behaviour / added code
\`\`\`
```

`skills/aidlc-tracking/formats/plan.md` — add to plan header:
```
**Session:** ${CLAUDE_SESSION_ID:-unknown}
```

`claude-md-master/CLAUDE.md` — add to Tracking Discipline table note:
> Every tracking entry MUST include `**Session:** $CLAUDE_SESSION_ID`. When writing a `tracker.md` or `changelog.md` entry after an implementation task, include a `**Key change:**` block with the most significant diff or function signature (max 20 lines).

---

### 14. Plans and todos always live in the repo — CLAUDE.md rule

**What:** An explicit behavioral rule preventing Claude from writing plan/task files to `~/.claude/` instead of the active repo.

**Background:** `CLAUDE.md` already says *"All tracking files live inside the repo — never in a global location."* But plan mode creates files at `~/.claude/plans/<session-name>.md`. This is a system-level default we cannot override. However, for plans and todos that Claude creates *manually* (via Write/Edit), they must always target `docs/plan.md` and `tasks/todo.md` in `$PWD`.

**File:** `claude-md-master/CLAUDE.md` — add to Tracking Discipline section:

```
### Repo-First Rule (no exceptions)

All plan, todo, tracker, changelog, and lesson files MUST be written inside the active
repo (`$PWD`), never to `~/.claude/` or any global path.

- `docs/plan.md` — not `~/.claude/plans/*.md`
- `tasks/todo.md` — not `~/.claude/todos/*.md`
- `tasks/tracker.md` — not any global location

The plan-mode tool creates `~/.claude/plans/<name>.md` as a system default for the
approval workflow — this is acceptable. Once approved and implementation begins, write
the working plan to `docs/plan.md` in the repo and keep `~/.claude/plans/` as the
approval artifact only.
```

---

### 15. `.claudeignore` — sensitive file protection

**Verdict: ACCEPT.** This is the properly-scoped implementation of the credential protection idea. Unlike a blanket "block all .env edits" hook, `.claudeignore` is:
- **User-configurable** — ships with safe defaults; user extends it
- **Pattern-based** — gitignore-style; familiar mental model
- **Dual-level** — global (`~/.claude/.claudeignore`) and per-project (`.claudeignore` in repo root)
- **Read + write protection** — blocks `Read`, `Edit`, and `Write` tool calls (not Bash — see limitations)

**How it works:**

A `PreToolUse` hook script (`scripts/claudeignore-guard.sh`) intercepts every `Read`, `Edit`, and `Write` call, extracts the `file_path` from the tool input JSON, and checks it against patterns in both the global and project-level ignore files. Exit code 2 = skip (Claude sees the tool as skipped, not errored — no confusing error messages).

**`scripts/claudeignore-guard.sh`** (new):

```bash
#!/usr/bin/env bash
# claudeignore-guard.sh — PreToolUse hook: blocks Read/Edit/Write on .claudeignore patterns
# Exit 2 = skip (Claude Code treats this as "tool call skipped, not an error")

stdin_json=$(cat)
tool_name=$(echo "$stdin_json" | python3 -c \
  "import sys,json; print(json.load(sys.stdin).get('tool_name',''))" 2>/dev/null) || tool_name=""

# Only guard file-access tools
case "$tool_name" in
  Read|Edit|Write) ;;
  *) exit 0 ;;
esac

file_path=$(echo "$stdin_json" | python3 -c \
  "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('file_path',''))" \
  2>/dev/null) || file_path=""
[ -z "$file_path" ] && exit 0

# Resolve to absolute path for reliable matching
abs_path=$(python3 -c "import os,sys; print(os.path.realpath(sys.argv[1]))" "$file_path" 2>/dev/null) || abs_path="$file_path"

check_ignore_file() {
  local ignore_file="$1"
  [ -f "$ignore_file" ] || return 0
  while IFS= read -r pattern || [ -n "$pattern" ]; do
    [[ "$pattern" =~ ^#.*$ || -z "$pattern" ]] && continue
    matched=$(python3 -c "
import fnmatch, sys, os
pattern, path = sys.argv[1], sys.argv[2]
basename = os.path.basename(path)
if fnmatch.fnmatch(basename, pattern) or fnmatch.fnmatch(path, pattern):
    print('yes')
" "$pattern" "$abs_path" 2>/dev/null)
    if [ "$matched" = "yes" ]; then
      echo "Blocked by .claudeignore ($ignore_file, pattern: '$pattern'): $file_path" >&2
      exit 2
    fi
  done < "$ignore_file"
}

# Global ignore (applies to all sessions)
check_ignore_file "$HOME/.claude/.claudeignore"
# Project-level ignore (repo-specific sensitive files)
check_ignore_file "$(pwd)/.claudeignore"
```

**Default `~/.claude/.claudeignore`** (new, written by `install.sh` if not present):

```
# ~/.claude/.claudeignore — files Claude will never read or edit
# Syntax: one pattern per line, gitignore-style basename or path matching
# Comments start with #. Add a .claudeignore in any repo root for project-specific rules.

# Environment / secrets
.env
.env.*
.envrc
*.secret

# Private keys and certificates
*.pem
*.key
*.p12
*.pfx
id_rsa
id_ed25519
id_ecdsa
*.ppk

# Cloud credentials
.aws/credentials
.aws/config
gcloud/credentials.db
service-account*.json

# Application credential files
*credentials*
*secrets*
.htpasswd
.netrc
```

**`settings.json` change** — add to `PreToolUse` hooks array:

```json
{ "type": "command", "command": "~/.claude/scripts/claudeignore-guard.sh" }
```

**`install.sh` changes:**
- Deploy `scripts/claudeignore-guard.sh` to `~/.claude/scripts/`
- Write default `~/.claude/.claudeignore` if not already present (never overwrite — user customisations must survive reinstalls)

**Limitations (documented, not fixed now):**
- Bash tool calls (e.g. `cat .env`, `grep password .env`) are NOT intercepted — the hook only sees the tool name and input JSON, not the executed command content. Bash-level protection requires shell-level controls outside Claude Code's hook system.
- Symlinks: the `realpath` resolution handles most cases but not all (e.g. files accessed via creative relative paths above `$PWD`)
- The project-level `.claudeignore` should be added to `.gitignore` if it contains project-specific sensitive path names that shouldn't be shared (though the patterns themselves are not secrets)

---

## Files Affected

| File | Change |
|------|--------|
| `install.sh` | Add `_claude_notify`, `_claude_pick_model`, `claude()`, `switch-back` to zshrc block; deploy `ollama.conf` + `.claudeignore` (first-install only); deploy new scripts + commands; add launchd cleanup |
| `scripts/limit-watchdog.sh` | Add `ollama.conf` sourcing; add API key backup write; add reset-time epoch write; remove launchd plist section |
| `scripts/switch-to-anthropic.sh` | Replace with thin wrapper + source hint |
| `scripts/switch-to-ollama.sh` | New file — activate Ollama routing with health check + model picker |
| `scripts/claudeignore-guard.sh` | New file — PreToolUse hook enforcing `.claudeignore` patterns |
| `settings.json` | Add `Stop`, `SessionStart`, `PreToolUse` (timer + claudeignore) hooks |
| `commands/switch-local-model-off.md` | New file |
| `commands/switch-local-model-on.md` | New file |
| `ollama.conf` | New file (template, all entries commented) |
| `skills/review-council/standard-personas/adversarial-challenger.md` | New file — adversarial persona |
| `skills/review-council/SKILL.md` | Add adversarial-challenger to Phase 2 mandatory inclusion list |
| `skills/aidlc-tracking/formats/tracker.md` | Add session ID + key change fields to entry template |
| `skills/aidlc-tracking/formats/changelog.md` | Add session ID + key change diff block to entry template |
| `skills/aidlc-tracking/formats/plan.md` | Add session ID to plan header |
| `claude-md-master/CLAUDE.md` | Add repo-first rule; add session ID + code snippet requirement to tracking discipline |

---

## What Does NOT Need to Change

- `limit-watchdog.sh` detection logic (works well — triple fallback, history.jsonl primary)
- `setup-ollama.sh` (model pulling and interactive prompts are fine)
- `aidlc-guard.sh` (Stop hook for AIDLC discipline — keep as-is)
- `SessionStart` hook + `init-context.md` command (context resume flow works correctly)
- `.active-projects` registry (still useful for multi-session tracking)
- `log-context.md` command (unchanged)

---

## Testing Plan — 18 Cases with Sandbox Isolation

All tests use a temporary `SANDBOX` directory to avoid touching real `~/.claude` state:

```bash
SANDBOX=$(mktemp -d)
mkdir -p "$SANDBOX/.claude"
# Run each test as: HOME="$SANDBOX" <command>
```

| # | Scenario | Setup | Command | Expected |
|---|----------|-------|---------|----------|
| T1 | Fresh terminal, no override | No state files in `$SANDBOX/.claude` | `HOME="$SANDBOX" claude` | Passes through to Anthropic (no prompts) |
| T2 | Override + past reset time + user says **Y** | `touch $SANDBOX/.claude/.ollama-override`; write past epoch to `.ollama-reset-time` | `HOME="$SANDBOX" claude` | Prompts "Switch back?", Y → deletes both files, launches Anthropic |
| T3 | Override + past reset time + user says **N** | Same setup as T2 | `HOME="$SANDBOX" claude` | Stays on Ollama → health check → model picker |
| T4 | Override + future reset time | Write override + future epoch | `HOME="$SANDBOX" claude` | No prompt; health check → model picker → routes to Ollama |
| T5 | Override + **no** reset file | Write override only, no `.ollama-reset-time` | `HOME="$SANDBOX" claude` | Warns "no reset time — use switch-back manually"; continues to health check |
| T6 | Override + **Ollama not running** | Write override + future epoch; ensure Ollama stopped | `HOME="$SANDBOX" claude` | Warns "Ollama not running"; offers fallback; Y → launches Anthropic |
| T7 | `switch-back` with backup file | Write `.ollama-anthropic-key-backup` with test key | `switch-back` | Key restored from file; backup deleted; override + reset-time deleted |
| T8 | `switch-back` **without** backup file (macOS) | No backup file; API key in Keychain | `switch-back` | Key restored from Keychain |
| T9 | `PreToolUse` hook — 4 min 50 sec remaining | Set `.ollama-reset-time` = now + 290 | Any tool use in Claude | "WARNING: Anthropic limit resets in 4 min" printed before tool output |
| T10 | `limit-watchdog.sh` writes all 3 files | Simulate limit-hit Stop event with mock session JSON | `echo '{"session_id":"test","last_assistant_message":"usage limit resets 3:00pm"}' \| bash limit-watchdog.sh` | `.ollama-override` + `.ollama-anthropic-key-backup` + `.ollama-reset-time` all written; no plist created |
| T11 | `_claude_pick_model()` in **zsh** | Run in `zsh -c` | `zsh -c 'source ~/.zshrc; _claude_pick_model'` | Models listed correctly; no `mapfile` error; selection saved to `.ollama-model` |
| T12 | `ollama.conf` custom `LIMIT_PATTERN` | Write `LIMIT_PATTERN="my-custom-pattern"` to `$SANDBOX/.claude/ollama.conf` | Pipe mock JSON with "my-custom-pattern" to `limit-watchdog.sh` | Watchdog triggers on custom pattern |
| T13 | `switch-to-ollama.sh` end-to-end | Ollama running; no pre-existing state | `bash scripts/switch-to-ollama.sh 15 0` | Override written; key backup written; reset-time written; model saved; no errors |
| T14 | `switch-to-ollama.sh` Ollama not running | Stop Ollama | `bash scripts/switch-to-ollama.sh` | Exits with error "Ollama is not running"; no state files written |
| T15 | Paired flow: `switch-to-ollama.sh` → `switch-back` | Run T13, then run switch-back | `switch-back` | All state files deleted; API key restored; env vars unset |
| T16 | `.claudeignore` blocks Read on `.env` | Write `.env` in sandbox; default `.claudeignore` present | Claude attempts `Read(.env)` | Hook exits 2; Claude sees tool skipped; file not read |
| T17 | `.claudeignore` blocks Edit on `*.key` | Write `test.key` in sandbox | Claude attempts `Edit(test.key)` | Hook exits 2; file not edited |
| T18 | Project-level `.claudeignore` respected | Write `.claudeignore` in `$PWD` with pattern `secret-file.txt` | Claude attempts `Read(secret-file.txt)` | Blocked by project-level pattern; global pattern file unchanged |

---

## Migration for Existing Installs

Run once to clean up the old launchd setup before re-running `install.sh`:

```bash
launchctl bootout "gui/$(id -u)" ~/Library/LaunchAgents/com.claude.switchback.plist 2>/dev/null || true
rm -f ~/Library/LaunchAgents/com.claude.switchback.plist
rm -f ~/.claude/.pre-switchback ~/.claude/.ollama-reset-time ~/.claude/.ollama-override
```

Then re-run `bash install.sh` to get all new functions and config.

---

### 16. Auto permission mode in `claude()` wrapper

**Date:** 2026-03-27
**Status:** Planned

#### Problem

The current `claude()` wrapper always starts Claude in whatever `defaultMode` is set per-repo (typically `acceptEdits` via safe-yolo, or the global default for all other repos). This means:

- **safe-yolo repos**: allow/deny lists fire correctly, but anything not on the list still prompts the user — defeating the point of an allow list that was carefully curated to cover the common cases.
- **non-safe-yolo repos**: every Bash command, every tool outside of file edits triggers an approval prompt — even obviously safe operations like `git status` or `npm test`.

The intent is: **auto mode should be the baseline everywhere**, with safe-yolo's allow/deny lists providing the specific guardrails on top. The combination covers everything:

| Repo type | Permission model |
|-----------|-----------------|
| safe-yolo | explicit allow list + explicit deny list + `auto` for everything else |
| non-safe-yolo | `auto` for everything (no explicit guardrails — user trusts Claude in that repo) |

#### Decision: settings.json approach, not CLI flag

Two implementation paths exist:

**Option A — CLI flag in wrapper:** pass `--permission-mode auto` (or equivalent) on every `command claude "$@"` call in the wrapper. Fragile: if Claude Code renames or deprecates the flag, the wrapper silently breaks. Also produces confusing behavior if the user passes their own `--permission-mode` flag.

**Option B — `defaultMode: auto` in `~/.claude/settings.json`:** set the global default once at install time. Per-repo `.claude/settings.json` overrides take precedence, so safe-yolo repos can set whatever they need. This is the canonical Claude Code mechanism and survives CLI flag changes.

**Verdict: Option B.** `install.sh` already merges `settings.json` into `~/.claude/settings.json` — adding `"defaultMode": "auto"` there is zero-friction.

#### safe-yolo default mode update

`scripts/config/claude-safe-yolo-permissions.txt` currently sets `@defaultMode=acceptEdits`. Since safe-yolo repos will inherit `auto` from global settings, this override is now redundant *unless* we want safe-yolo repos to explicitly confirm `auto` (which they should, to be self-documenting).

**Change:** `@defaultMode=acceptEdits` → `@defaultMode=auto` in `claude-safe-yolo-permissions.txt`.

This way:
- Global settings: `defaultMode: auto`
- safe-yolo repos: explicitly confirm `auto` + their allow/deny list

#### Files to change

| File | Change |
|------|--------|
| `settings.json` | Add `"defaultMode": "auto"` to the top-level object |
| `scripts/config/claude-safe-yolo-permissions.txt` | `@defaultMode=acceptEdits` → `@defaultMode=auto` |
| `tests/test_settings_json.sh` | Add assertion that `defaultMode` is `"auto"` |

#### What this does NOT change

- The safe-yolo allow/deny lists are unaffected — they still fire before auto-approval.
- Per-repo `defaultMode` overrides in `.claude/settings.json` still take precedence.
- Users who want stricter control in a specific repo can set `"defaultMode": "default"` in that repo's `.claude/settings.json`.

---

### 17. Auto dream — daily 5am scheduled maintenance

**Date:** 2026-03-27
**Status:** DESCOPED — parked for a future phase. Design is complete (see below); implementation deferred until the core switchover system has been stable in production.

#### What is a dream?

A "dream" is a scheduled autonomous session that runs background maintenance and analysis while the user is away. Inspired by how the brain consolidates memory during sleep: low-cost, non-interactive, produces a log the user can review in the morning.

Two tiers of tasks:

**Tier 1 — lightweight maintenance (always runs, no Claude invocation):**
- Clean up expired `.jsonl` session files in `~/.claude/` older than 30 days
- Delete orphaned `.ollama-override` files where the reset epoch has already passed
- Refresh gitnexus graph (`npx gitnexus analyze`) for every repo in `~/.claude/.active-projects`
- Prune `~/.claude/.active-projects` entries for directories that no longer exist

**Tier 2 — intelligent summarisation (opt-in per-repo, invokes `claude -p`):**
- Write a morning briefing to `tasks/tracker.md`: what changed since yesterday, any failing tests, recent git commits
- Run `npx gitnexus analyze` for the repo and summarise impact hotspots
- Only runs for repos that set `dreamEnabled: true` (see opt-in mechanism below)

#### Root level vs per-repo — hybrid answer

| Layer | Where it lives | Who controls it |
|-------|---------------|-----------------|
| Cron entry | `~/.claude/` (root, global) | install.sh writes it once |
| Tier 1 tasks | `scripts/dream.sh` (root script) | always runs |
| Tier 2 tasks | `scripts/dream.sh` reads opt-in manifest | per-repo opt-in |
| Opt-in manifest | `~/.claude/dream-repos.txt` | `install.sh --enable-dream [path]` |

**Why one root cron, not per-repo cron entries:**
- One cron job to manage. Adding a dream to a repo does not require touching crontab.
- The root script iterates over the opt-in manifest — repos can join/leave without touching system cron.
- If a repo is deleted, the manifest cleanup (Tier 1) removes it automatically.

#### Scheduling: local 5am via cron

```
0 5 * * * ~/.claude/scripts/dream.sh >> ~/.claude/dream.log 2>&1
```

`cron` runs in the user's local system timezone. No timezone conversion needed — `0 5 * * *` = 5am local. `install.sh` registers this via:

```bash
# idempotent: only adds the line if it's not already present
( crontab -l 2>/dev/null | grep -qF 'dream.sh' ) || \
  ( crontab -l 2>/dev/null; echo "0 5 * * * ~/.claude/scripts/dream.sh >> ~/.claude/dream.log 2>&1" ) | crontab -
```

#### Per-repo opt-in mechanism

Two commands added to `install.sh` output and as slash commands:

```bash
# In terminal after install
enable-dream                     # registers $PWD in ~/.claude/dream-repos.txt
disable-dream                    # removes $PWD from dream-repos.txt
```

`dream.sh` reads the manifest and for each opted-in repo:
1. Verifies the directory still exists (prunes if not)
2. Runs `npx gitnexus analyze` in that repo
3. If `DREAM_INTELLIGENT=1` is set in the repo's `ollama.conf` or `~/.claude/ollama.conf`: invokes `claude -p` with a briefing prompt

#### `scripts/dream.sh` outline

```bash
#!/usr/bin/env bash
# dream.sh — daily 5am maintenance. Run via cron, logs to ~/.claude/dream.log.

CLAUDE_DIR="$HOME/.claude"
MANIFEST="$CLAUDE_DIR/dream-repos.txt"
ACTIVE="$CLAUDE_DIR/.active-projects"

echo "── Dream started $(date) ──"

# Tier 1: lightweight maintenance (always)
# 1. Prune session files older than 30 days
find "$CLAUDE_DIR" -maxdepth 1 -name '*.jsonl' -mtime +30 -delete

# 2. Clean up expired ollama-override (reset epoch passed)
if [ -f "$CLAUDE_DIR/.ollama-reset-time" ]; then
  reset_epoch=$(cat "$CLAUDE_DIR/.ollama-reset-time" | tr -d '[:space:]')
  now=$(date +%s)
  if [ -n "$reset_epoch" ] && [ "$now" -ge "$reset_epoch" ]; then
    rm -f "$CLAUDE_DIR/.ollama-override" "$CLAUDE_DIR/.ollama-reset-time"
    echo "Cleaned up expired ollama override."
  fi
fi

# 3. Prune .active-projects entries that no longer exist
if [ -f "$ACTIVE" ]; then
  tmp=$(mktemp) && while IFS= read -r repo; do
    [ -d "$repo" ] && echo "$repo"
  done < "$ACTIVE" > "$tmp" && mv "$tmp" "$ACTIVE"
fi

# Tier 2: per-repo tasks (opt-in)
[ -f "$MANIFEST" ] || { echo "No dream-repos.txt — Tier 2 skipped."; exit 0; }
while IFS= read -r repo_path || [ -n "$repo_path" ]; do
  [ -z "$repo_path" ] || [[ "$repo_path" =~ ^# ]] && continue
  if [ ! -d "$repo_path" ]; then
    echo "SKIP (gone): $repo_path"
    continue
  fi
  echo "Dream: $repo_path"
  cd "$repo_path" || continue
  npx gitnexus analyze --quiet 2>/dev/null && echo "  gitnexus refreshed"
  # Intelligent briefing (only if opted in)
  if grep -q 'DREAM_INTELLIGENT=1' "$HOME/.claude/ollama.conf" 2>/dev/null || \
     grep -q 'DREAM_INTELLIGENT=1' "$repo_path/.claude/ollama.conf" 2>/dev/null; then
    claude -p "Write a brief morning briefing to tasks/tracker.md: summarise recent git commits, any test failures, and one recommended next action. Keep it under 200 words." \
      --permission-mode auto 2>/dev/null && echo "  briefing written"
  fi
done < "$MANIFEST"

echo "── Dream complete $(date) ──"
```

#### `install.sh` changes

| Task | Where |
|------|-------|
| Deploy `scripts/dream.sh` → `~/.claude/scripts/dream.sh` + `chmod +x` | deploy block |
| Register cron entry (idempotent) | new function `_register_dream_cron` |
| Add `enable-dream` / `disable-dream` shell functions to `.zshrc` block | ZSHBLOCK |
| Create `~/.claude/dream-repos.txt` with header comment if not present | first-install |

#### `ollama.conf` additions

```bash
# ── Dream configuration ──────────────────────────────────────────────────────
# DREAM_INTELLIGENT=1    # enable claude -p briefing during dream (uses tokens)
```

#### Open questions / decisions deferred

1. **Dream log rotation**: `dream.log` will grow unboundedly. Add weekly rotation (keep last 7 days) in the dream script itself.
2. **Cron on macOS vs Linux**: `cron` works on both; launchd is NOT used here (we've moved away from it for v2 reasons documented in Root Cause Analysis). If `cron` is disabled on the machine, `install.sh` should detect this and warn.
3. **Intelligent dream token cost**: `claude -p` invocation consumes tokens. Document in `OLLAMA-SETUP-GUIDE.md` that `DREAM_INTELLIGENT=1` is opt-in precisely because it costs money. Consider routing the dream to an Ollama model instead when Ollama is available (`DREAM_MODEL` override in `ollama.conf`).
4. **Per-repo dream tasks beyond gitnexus**: future extension point — repos could define a `.claude/dream.sh` that the root dream calls. Deferred until we have concrete use cases.

---

## Design Notes Review

Objective assessment of proposed enhancements. Each item has a verdict with engineering rationale.

---

### Note 1 — Adversarial review in design council
**Proposal:** Add an adversarial "devil's advocate" persona to the review-council skill that actively challenges the consensus design.

**Verdict: ACCEPT → implemented in Section 12**

**Why:** The review-council currently converges toward consensus. An adversarial persona explicitly assigned to find fault — stress-test assumptions, challenge trade-offs, surface edge cases — improves review quality without adding noise. This is how staff engineering review panels work: you want someone whose job is to break the proposal.

---

### Note 2 — Pre-tool-use hook: block `.env` file edits (exit code 2 = skip)
**Proposal:** Add a `PreToolUse` hook that intercepts any Edit/Write targeting a `.env` file and returns exit code 2 (blocked/skipped).

**Verdict: SUPERSEDED by Section 15 (`.claudeignore`)**

**Why the original was too blunt:** Blocking all `.env` edits unconditionally would break legitimate workflows (bootstrapping, adding new entries). The right answer is a user-configurable pattern file with sane defaults — the `.claudeignore` approach. It covers `.env` and many other sensitive file types via the default ignore list, while letting users remove patterns for files they explicitly want Claude to touch. See Section 15 for the full implementation.

---

### Note 3 — Post-tool-use hook: auto-format all files after changes
**Proposal:** Add a `PostToolUse` hook that runs a formatter on every file edited by Claude.

**Verdict: SKIP — too much overhead, wrong place**

**Why:** Running a formatter after every single tool call (Edit, Write, Bash) would add latency to every operation and produce noise for binary files, markdown, config files, and anything that doesn't have a formatter configured. Most projects already enforce formatting via pre-commit hooks (`prettier`, `black`, `gofmt`) or CI — that's the right gate. If a specific project needs auto-format-on-save, configure it in that project's CLAUDE.md via a targeted PostToolUse hook scoped to specific file extensions. Not a global default.

---

### Note 4 — Include actual code snippets in `changelog.md` and `tracker.md`
**Proposal:** When writing tracking file entries, include relevant code diffs or snippets rather than just prose descriptions.

**Verdict: ACCEPT → implemented in Section 13**

**Why:** Pure prose entries lose the context needed to recover state after compaction. A 5-10 line diff or the key function signature tells the next session exactly what changed without re-reading the file. This is especially valuable in `tracker.md` pre-compact snapshots.

---

### Note 5 — Segregate tracking files by logical feature (not one big file)
**Proposal:** Instead of single monolithic `tracker.md` / `changelog.md`, split into per-feature files (e.g. `tracker-ollama.md`, `tracker-install.md`).

**Verdict: SKIP — tagging solves this better**

**Why:** File segregation creates a new problem: Claude must decide which file to write to, introducing ambiguity and inconsistency. The append-only single-file model is simple and reliable. The real need is *findability*, which tagging (Note 6 below) solves cleanly — you can `grep` by feature tag without managing multiple files. Per-feature splitting also breaks the "append newest at top" invariant when two features are worked on in the same session. Keep single files; improve search via tags.

---

### Note 6 — Tag each tracking entry with session ID and session name
**Proposal:** Each entry in `tracker.md`, `changelog.md`, etc. should include the Claude session ID and a human-readable session name so changes can be traced back to the session that made them.

**Verdict: ACCEPT → implemented in Section 13**

**Why:** Session IDs are available via `$CLAUDE_SESSION_ID` in hooks at zero cost. Making them standard in all tracking formats means you can always `grep` your way back to the exact session transcript (`.jsonl` file) that produced a given change. The `PreCompact` hook already uses `${CLAUDE_SESSION_ID:-unknown}` — normalizing this is a format-spec-only change.

---

### Note 7 — Store Claude's internal plans/todos in repo directory (not `~/.claude/`)
**Proposal:** Plans and todos that Claude creates internally (currently landing in `~/.claude/plans/`) should instead be stored inside the active repo at the AIDLC-defined paths (`docs/plan.md`, `tasks/todo.md`, etc.).

**Verdict: ACCEPT → implemented in Section 14**

**Why:** `CLAUDE.md` already states this, but the rule isn't enforced explicitly enough. Plan mode creates files at `~/.claude/plans/` as a system default for the approval workflow — that's fine. But once implementation begins, the working plan belongs in the repo. Needs an explicit behavioral rule to prevent drift.

---

### Note 8 — Use `--agent` and `/agent` commands to define reusable agents
**Proposal:** Use Claude Code's `--agent` flag and `/agent` command to define and invoke named agents for recurring tasks (e.g. a "watchdog-debugger" agent, a "switchover-tester" agent).

**Verdict: DEFER — exploratory, needs concrete use case first**

**Why:** The agent framework in Claude Code is still evolving. Before adding agent definitions, we need to identify which tasks in this repo are actually recurring and benefit from persistent agent context vs. one-off slash commands. Currently `/switch-local-model-on` and `/switch-local-model-off` cover the main use cases as simple commands. If we find ourselves repeatedly doing complex multi-step debugging of the watchdog system, that's when a dedicated agent becomes worth defining. Premature agent definitions add maintenance overhead without clear benefit.

**Track as:** Add a `docs/AGENTS.md` stub once we have 2+ concrete recurring agent workflows identified. Revisit after the core switchover redesign is stable and running in production for a few weeks.
