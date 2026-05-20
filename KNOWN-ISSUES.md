# Known Issues — Ollama Switchover System

These issues are documented but **not being fixed now**. Each entry describes the symptom, root cause, current workaround, and the conditions under which a proper fix would be worth building.

---

## Issue 1: Stop hook doesn't fire on Claude crash or kill

**Symptom:** If Claude Code is killed with `SIGKILL` (e.g. `kill -9`, OOM killer, force-quitting the terminal) or crashes abnormally, the `Stop` hook never fires. `limit-watchdog.sh` does not run, so `.ollama-override` is never written.

**Root cause:** Claude Code's `Stop` hook only executes during a *clean* session exit. It is not a signal handler — it cannot intercept `SIGKILL`.

**Workaround:**
```bash
# If Claude crashed and you're on Anthropic but keep hitting limits, manually trigger switchover:
~/.claude/scripts/limit-watchdog.sh <<< '{"session_id":"","last_assistant_message":"usage limit","transcript_path":""}'
```
Or just run `/switch-local-model-on` inside the next Claude session once it opens.

**Fix condition:** No reliable fix exists for `SIGKILL`. For crash detection, a watchdog daemon (separate process) could monitor for unexpected Claude exits. Not worth building until the core flow is stable.

---

## Issue 2: Multi-session race conditions

**Symptom:** Two simultaneous Claude sessions in different terminals (different projects) both hit their limits at approximately the same time. Both write `.ollama-override` concurrently. The second write clobbers the first. The `.active-projects` registry may be corrupted by concurrent `grep` + `mv` operations.

**Root cause:** All state files (`~/.claude/.ollama-override`, `~/.claude/.active-projects`) are uncoordinated single-writer files with no locking. `limit-watchdog.sh` uses atomic `mv` for the override file itself (prevents partial reads) but the registry append-then-read pattern is not atomic.

**Current mitigation:** `.active-projects` registry tracks which project directories have active Ollama sessions. The `claude()` wrapper and `switch-back` function remove the current CWD from the registry on each invocation, reducing stale entries.

**Workaround:** Run Claude sessions sequentially (one active at a time) to avoid races. If a race occurs, run `switch-back` in each affected terminal to restore clean state.

**Fix condition:** Proper fix requires `flock`-based file locking around all registry reads/writes. Worth building if multi-session usage becomes the norm.

---

## Issue 3: API key restoration on Linux / other platforms

**Symptom:** After `switch-back` (or `source ~/.claude/scripts/switch-to-anthropic.sh`), `ANTHROPIC_API_KEY` is empty on Linux. Claude Code fails to authenticate.

**Root cause:** The key restoration logic has two paths:
1. **Backup file** (`~/.claude/.ollama-anthropic-key-backup`) — written by `limit-watchdog.sh` immediately before the override zeroes the key. Reliable on all platforms *if* the Stop hook fired cleanly.
2. **macOS Keychain** (`security find-generic-password`) — macOS-only binary. Not available on Linux.

On Linux, Claude Code stores credentials in `~/.claude/.credentials` (JSON format) rather than the system keychain. This path is not currently read by `switch-back`.

**Workaround (Linux):**
```bash
# Option A: Read from Claude Code's credential store
export ANTHROPIC_API_KEY=$(python3 -c "
import json
print(json.load(open('$HOME/.claude/.credentials')).get('anthropicApiKey',''))
" 2>/dev/null)

# Option B: Set manually if you know the key
export ANTHROPIC_API_KEY="sk-ant-..."
```

**macOS — use `reset-to-anthropic.sh` with `--restore-api-key`:**
```bash
# Restores API key from backup file or Keychain, then clears all sentinel files:
source scripts/reset-to-anthropic.sh --restore-api-key
```
Without the flag the script clears sentinel files only — API key restoration is opt-in.

**Tested on:** macOS only (both backup file path and Keychain path).

**Fix condition:** Add Linux credential store path as Priority 2 in `switch-back`, between backup file and Keychain. Low priority — macOS is the primary dev platform and the backup file path works cross-platform when the Stop hook fires cleanly.

---

## Issue 4: Install idempotency for shell functions

**Symptom:** Re-running `install.sh` a second time may produce duplicate function definitions in `.zshrc` for `_claude_notify`, `_claude_pick_model`, `claude()`, and `switch-back`.

**Root cause:** The outer `# ── claude-local-starter managed ──` / `# ── end claude-local-starter ──` block uses Python `re.sub` to remove and rewrite the entire block on each install. This correctly handles idempotency for the block as a whole. However, if the block markers are malformed or missing (e.g. a partial previous install, or a user who edited `.zshrc` manually), the `re.sub` may fail to match and a second block gets appended.

**Workaround:**
```bash
# Check for duplicate definitions
grep -c "^claude()" ~/.zshrc  # Should be 1; if 2+, remove duplicates manually

# Quick fix: remove all managed blocks and reinstall
python3 -c "
import re, os
path = os.path.expanduser('~/.zshrc')
content = open(path).read()
content = re.sub(
    r'\n# ── claude-local-starter managed.*?# ── end claude-local-starter ──\n',
    '',
    content,
    flags=re.DOTALL
)
open(path, 'w').write(content)
print('Removed managed block(s).')
"
bash install.sh  # Reinstall cleanly
```

**Fix condition:** The current `re.sub` approach is already reasonable. This only becomes an issue if the user manually edits between the markers. Not worth hardening further until it causes real problems in the field.

---

## Issue 5: Pure-chat Ollama session — limit not auto-detected

**Symptom:** User is in an Ollama session doing only conversational exchanges (no tool calls). When they switch back to Anthropic, the Anthropic limit may already have reset but `limit-watchdog.sh` wasn't triggered (or was triggered but couldn't extract the reset time) because there was no tool call to produce a Stop event at the right moment.

**Root cause:** `limit-watchdog.sh` runs as a `Stop` hook — it fires at the end of every Claude session regardless of tool use. However, the reset time extraction (`$reset_time`) depends on the last assistant message containing text like "resets 3:00pm". In pure-chat Anthropic sessions where the limit is hit mid-conversation, the message may be truncated or reformatted before reaching the hook, making `$reset_time` empty. Without `$reset_time`, no `.ollama-reset-time` file is written, and the `claude()` wrapper falls back to the "no reset time found" warning path.

**Workaround:** Use `/switch-local-model-on` to manually activate Ollama routing and set a reset time explicitly:
```bash
# Set reset time manually (e.g. 3:00 PM)
python3 -c "
import datetime
now = datetime.datetime.now()
reset = now.replace(hour=15, minute=0, second=0, microsecond=0)
if reset <= now:
    reset += __import__('datetime').timedelta(days=1)
print(int(reset.timestamp()))
" > ~/.claude/.ollama-reset-time
```

**Fix condition:** Could be improved by prompting the user for the reset time when `$reset_time` is empty in `limit-watchdog.sh`. Medium priority.

---

## Issue 6: Stale sentinel files persisting after Anthropic limit resets — Mitigated

**Symptom:** Sentinel files (`.ollama-override`, `.ollama-reset-time`, `.handover-ready`) persist in `~/.claude/` long after the Anthropic rate limit has reset. Every `claude` launch in the terminal prompts for Ollama model selection even though the limit expired hours or days ago. Affects Mac app and IDE launches where the terminal `claude()` wrapper never runs, so the lazy reset check never fires.

**Root cause:** The `claude()` zsh wrapper performs a lazy cleanup check on every terminal launch — if `current_time >= reset_epoch`, it prompts the user and removes the sentinel files. But this only works when Claude is launched via the terminal wrapper. Mac app and JetBrains/VS Code IDE extensions launch Claude Code directly, bypassing the wrapper entirely. Sentinel files can persist indefinitely on machines that primarily use the Mac app or IDE.

**Mitigations added:**

1. **SessionStart auto-expire hook** — fires at every Claude Code session start regardless of launch method. If `.ollama-override` and `.ollama-reset-time` both exist and the reset epoch has already passed, the hook silently removes all three sentinel files and prints: `"[info] Anthropic limit has reset — Ollama override cleared automatically."` This covers Mac app and IDE launches.

2. **limit-watchdog.sh reset_time guard** — before writing `.ollama-override`, the hook parses `$reset_time` and checks whether the reset epoch is already in the past. If so, it exits without writing the override at all — preventing a sentinel from being written for a limit window that has already closed.

3. **Manual reset script** — `scripts/reset-to-anthropic.sh` clears all sentinel files on demand. Run `source scripts/reset-to-anthropic.sh` to clean up immediately. Use `--restore-api-key` to also restore the API key from backup or Keychain.

**Workaround (if mitigation doesn't fire):**
```bash
source ~/Documents/code/incheon/claude-local-starter/scripts/reset-to-anthropic.sh
```

4. **`.ollama-manual` flag** — `switch-to-ollama.sh` now writes `~/.claude/.ollama-manual` when you manually activate Ollama. The `claude()` wrapper uses this flag to distinguish manual sessions from automatic limit-triggered ones. Automatic switches with no reset time are auto-cleaned after 5 hours; manual sessions are not auto-expired — the `.ollama-manual` flag suppresses the 5h cleanup so intentional Ollama sessions persist until you explicitly type `r` at the routing prompt or run `switch-back`.

**Fix condition:** Fully mitigated for the common cases. Residual gap: if both `.ollama-override` and `.ollama-reset-time` exist but the reset time file is corrupted/missing, the SessionStart hook won't fire (it requires both files). In that case, run the reset script manually.
