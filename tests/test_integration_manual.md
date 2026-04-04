# Manual Integration Test Checklist — Full 5-Phase Switchover Cycle (v2)

Live validation. Complete in order. Each step has an expected observable outcome.

---

## Pre-flight

- [ ] `ollama serve &` — Ollama server running in background
- [ ] `ollama list` shows at least one model (e.g. `qwen3-coder`, `glm-4.7-flash`, or `kimi-k2.5:cloud`)
- [ ] `echo $ANTHROPIC_API_KEY | head -c 10` — real Anthropic key is set
- [ ] `cat ~/.claude/settings.json | python3 -m json.tool | grep -A2 StopFailure` — StopFailure hook present
- [ ] No stale `~/.claude/.ollama-override` file: `ls ~/.claude/.ollama-override 2>/dev/null && echo EXISTS || echo clean`
- [ ] No stale reset-time file: `ls ~/.claude/.ollama-reset-time 2>/dev/null && echo EXISTS || echo clean`
- [ ] `switch-back` shell function is installed: `type switch-back` — should print a function definition, not "not found"

---

## Phase 1 — Normal Anthropic Session

**Action:** `claude` (start a normal Claude Code session in your demo repo)

**Expected:**

- [ ] Claude Code starts with Anthropic model (sonnet/opus)
- [ ] `claude()` wrapper runs — no override file found, no reset-time prompt
- [ ] Session works normally — make a small code change or ask a question
- [ ] AIDLC files exist: `tasks/todo.md`, `tasks/tracker.md`

---

## Phase 2 — Simulate Limit Hit

> In a real demo, you'd wait for an actual limit. For the talk, simulate it:

**Action:**

```bash
# In a separate terminal (don't stop current session):
bash ~/.claude/scripts/limit-watchdog.sh <<'JSON'
{
  "last_assistant_message": "You've hit your limit · resets 12:30am",
  "transcript_path": "/dev/null",
  "cwd": "/path/to/your/demo/repo"
}
JSON
```

**Expected:**

- [ ] `~/.claude/.ollama-override` file created — verify contents:

  ```bash
  cat ~/.claude/.ollama-override
  ```

  Should contain (note `/v1` suffix):

  ```bash
  export ANTHROPIC_AUTH_TOKEN=ollama
  export ANTHROPIC_API_KEY=""
  export ANTHROPIC_BASE_URL=http://localhost:11434/v1
  ```

- [ ] `.ollama-reset-time` epoch file created:

  ```bash
  cat ~/.claude/.ollama-reset-time   # prints a Unix epoch seconds value
  ```

- [ ] `.ollama-anthropic-key-backup` created (API key saved before zeroing):

  ```bash
  ls ~/.claude/.ollama-anthropic-key-backup
  ```

- [ ] No launchd plist created (v2 removes launchd entirely):

  ```bash
  ls ~/Library/LaunchAgents/com.claude.switchback.plist 2>/dev/null || echo "no plist — correct"
  ```

- [ ] `tasks/.session-handover` marker created: `ls tasks/.session-handover`

---

## Phase 3 — Ollama Session with AIDLC Handover

**Action:**

```bash
# In a new terminal (the claude() wrapper in ~/.zshrc handles routing automatically):
claude
```

> **Note:** Do NOT manually `source ~/.claude/.ollama-override`. The `claude()` shell function
> installed by `install.sh` detects the override file automatically and routes to Ollama.
> It also shows an interactive model picker if multiple Ollama models are available.

**Expected:**

- [ ] `[claude] Limit override active` message shown (model picker appears if models available)
- [ ] Claude Code starts (now routing to local Ollama)
- [ ] `echo $ANTHROPIC_BASE_URL` inside the session shows `http://localhost:11434/v1` (WITH `/v1`)
- [ ] SessionStart hook fires: Claude checks for `tasks/.session-handover`
- [ ] Claude announces: "Resumed session detected — running /init-context"
- [ ] `/init-context` output shows tracker.md, todo.md, plan.md contents loaded
- [ ] `tasks/.session-handover` marker is deleted after context load
- [ ] Coding continues — Claude has full context of prior work
- [ ] Responses come from local Ollama model

---

## Phase 4 — Manual Switchback

> **v2:** There is no two-phase background script. The primary switchback method is the
> `switch-back` shell function, which runs in-process and can actually update env vars in
> the current terminal. `switch-to-anthropic.sh` is now a thin wrapper for subprocess use only.

### Preferred method — `switch-back` function

**Action (same terminal you want to keep using):**

```bash
switch-back
```

**Expected:**

- [ ] `~/.claude/.ollama-override` removed: `ls ~/.claude/.ollama-override 2>/dev/null || echo "gone — correct"`
- [ ] `~/.claude/.ollama-reset-time` removed: `ls ~/.claude/.ollama-reset-time 2>/dev/null || echo "gone — correct"`
- [ ] `~/.claude/.ollama-anthropic-key-backup` removed: `ls ~/.claude/.ollama-anthropic-key-backup 2>/dev/null || echo "gone — correct"`
- [ ] API key restored in the current shell: `echo $ANTHROPIC_API_KEY | head -c 10` shows the key prefix
- [ ] `echo $ANTHROPIC_BASE_URL` is empty or restored to Anthropic default (no `localhost`)

### Fallback method — subprocess script

**Action (when you cannot use the function directly):**

```bash
bash ~/.claude/scripts/switch-to-anthropic.sh
```

> **Note:** Because this runs as a subprocess, it cannot update env vars in the caller's
> terminal. It cleans up state files and prints a reminder to run `switch-back` or open a
> fresh terminal. After running this script, open a new terminal to pick up the clean env.

### Lazy auto-detect path (no manual action needed)

If `.ollama-reset-time` has passed and you simply run `claude`, the wrapper detects it:

```
[claude] Anthropic limits may have reset. Switch back? [Y/n]
```

Answer `Y` and it runs `switch-back` inline before launching.

---

## Phase 5 — Anthropic Session Resumes

**Action:**

```bash
# New terminal or after switch-back (fresh env):
claude
```

**Expected:**

- [ ] `claude()` wrapper runs — no override file, no reset-time file present
- [ ] Claude Code starts with Anthropic model (verify: `echo $ANTHROPIC_BASE_URL` is empty/default)
- [ ] SessionStart hook fires: Claude checks for `tasks/.session-handover`
- [ ] Claude announces: "Resumed session — running /init-context"
- [ ] Context loaded from tracker.md / todo.md (includes Ollama session work)
- [ ] `tasks/.session-handover` deleted after context load
- [ ] Normal Anthropic API coding resumes with full continuity

---

## Bonus Phase — Manual Ollama Activation (v2 addition)

> You don't need to wait for a real limit hit. Use `switch-to-ollama.sh` to manually
> activate Ollama routing at any time — useful for cost control or offline work.

**Action:**

```bash
bash ~/.claude/scripts/switch-to-ollama.sh
```

**Expected:**

- [ ] Ollama health check runs: confirms `ollama serve` is reachable
- [ ] Interactive model picker shown (reads default from `~/.claude/ollama.conf`)
- [ ] API key backed up to `~/.claude/.ollama-anthropic-key-backup` before zeroing
- [ ] `~/.claude/.ollama-override` written with `ANTHROPIC_BASE_URL=http://localhost:11434/v1`
- [ ] `~/.claude/.ollama-reset-time` written (optional — sets a future epoch for auto-detect)
- [ ] Running `claude` in a new terminal now routes to Ollama

> This is the same flow that the `/switch-local-model-on` slash command guides you through.

---

## Post-Demo Cleanup

```bash
# Remove any leftover state files and restore Anthropic routing:
rm -f ~/.claude/.ollama-override ~/.claude/.ollama-reset-time ~/.claude/.ollama-anthropic-key-backup
rm -f tasks/.session-handover

# If switch-back function is available, run it to also restore env vars in current shell:
switch-back
```

---

## Talk Demo Script (condensed)

| Slide / Beat | Action | Show audience |
| --- | --- | --- |
| "Normal session" | `claude` in demo repo | Claude Code running, Anthropic model, no override |
| "Limit hits" | Run watchdog with fake JSON | Override file + reset-time file appear; no launchd plist |
| "Switch to local" | `claude` in new terminal (wrapper auto-detects override) | Model picker → Ollama session, /init-context fires |
| "Work continues" | Ask Claude to continue the todo | Response from local model, context intact, BASE_URL has `/v1` |
| "Switchback" | `switch-back` in current terminal | State files gone, API key restored in-place |
| "Back to Anthropic" | `claude` in new terminal | Context loaded again, full continuity, Anthropic model |
| "Manual activation" | `bash switch-to-ollama.sh` | Health check + model picker, override written without hitting a limit |
