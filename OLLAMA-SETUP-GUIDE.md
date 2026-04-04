# Ollama Setup Guide

Step-by-step setup for running Claude Code locally via Ollama — the model that takes
over when your Anthropic usage limit hits.

---

## What This Sets Up

```
Anthropic limit hits
       │
       ▼
limit-watchdog.sh writes ~/.claude/.ollama-override
       │
       ▼
You start a new Claude Code session
       │
       ▼
Claude Code → Ollama (localhost:11434) → kimi-k2.5:cloud (cloud model, default)
       │
       ▼
At reset time: switch-to-anthropic.sh fires, Anthropic session resumes
```

---

## Prerequisites

- macOS (Apple Silicon or Intel) — also works on Linux
- Homebrew installed: `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`
- At least **8 GB RAM** for local models (or use `kimi-k2.5:cloud` — no local RAM needed, see cloud setup below)
- At least **10 GB free disk space**

---

## Step 1 — Install Ollama

```bash
brew install ollama
```

**Verify:**
```bash
ollama --version
# Expected output: ollama version X.Y.Z
```

---

## Step 2 — Start the Ollama Server

```bash
ollama serve
```

> Run this in a dedicated terminal tab and leave it open. Ollama must be running
> before you can pull models or use Ollama-routed Claude Code sessions.

**Alternative — run in background:**
```bash
ollama serve > ~/.ollama/server.log 2>&1 &
echo "Ollama running (PID $!)"
```

**Verify server is up:**
```bash
ollama list
# Expected: empty table (no models yet) — but no error
```

---

## Step 3 — Pull the Integration Model

The official Ollama × Claude Code docs ([docs.ollama.com/integrations/claude-code](https://docs.ollama.com/integrations/claude-code))
list two types of recommended models:

### Local models (run on your machine — true offline fallback)

| Model | RAM needed | Best for |
|---|---|---|
| `glm-4.7-flash` | ~8 GB | Local fallback — fast, works offline (no account needed) |
| `qwen3:4b` | ~3 GB | Compact, good for fast iteration |
| `qwen2.5-coder:7b` | ~5 GB | Strong code generation |
| `qwen3:30b` | ~20 GB | Best local reasoning, requires high-RAM machine |

### Cloud models (free via Ollama's servers — no local RAM, needs internet)

Use these if your machine does **not** have 8 GB+ free RAM for a local model.

| Model | Best for |
|---|---|
| `kimi-k2.5:cloud` | Best quality, used in Ollama's own docs examples |

> **Default model:** `kimi-k2.5:cloud` — best quality, no local RAM needed, free via Ollama's servers.
> Use `glm-4.7-flash` as a local fallback when you need true offline operation or have hit the Ollama cloud limit.

#### Cloud model prerequisites

Ollama cloud models require a free Ollama account with a Device Key registered:

1. **Create a free account** at [ollama.com](https://ollama.com)
2. **Register your machine** — go to [ollama.com/settings/keys](https://ollama.com/settings/keys) and create a Device Key, then run:
   ```bash
   ollama auth
   ```
   and paste the key when prompted.
3. **Usage limits** — cloud models have per-session and weekly usage caps.
   Track your remaining quota at [ollama.com/settings](https://ollama.com/settings).

> If you hit the Ollama cloud limit, fall back to a local model (`glm-4.7-flash` on 8GB RAM,
> `qwen3:4b` on 4GB RAM).

**Pull the default model (recommended):**
```bash
ollama pull kimi-k2.5:cloud
```

> Note: `kimi-k2.5:cloud` requires an Ollama account and Device Key — see cloud model prerequisites above.

**Or pull the local offline fallback:**
```bash
ollama pull glm-4.7-flash
```

**Verify:**
```bash
ollama list
# Should show your pulled model

# If you pulled glm-4.7-flash (local model):
ollama run glm-4.7-flash "reply with just the word: ready"
# Expected: ready
```

---

## Model Comparison & Selection Guide

All models offered by `bash install.sh` (via `scripts/setup-ollama.sh`). Pick based on your machine's available RAM.

### At a glance

| Model | Type | RAM needed | Context | Best for | Account needed? |
|-------|------|-----------|---------|----------|----------------|
| `kimi-k2.5:cloud` | Cloud | 0 (internet) | Large | **Default** — best quality, no local RAM | Yes (free) |
| `glm-4.7-flash` | Local | ~8 GB | 128K | Local offline fallback — fast, agentic | No |
| `qwen3:4b` | Local | ~3 GB | 128K | Low-RAM machines, fast iteration | No |
| `qwen2.5-coder:7b` | Local | ~5 GB | 32K | Pure code generation tasks | No |
| `qwen3:30b` | Local | ~20 GB | 128K | Best local reasoning, high-RAM machine | No |
| `smollm2:360m` | Local | ~500 MB | 8K | **bats unit tests only** — not for real sessions | No |

> **Default:** `kimi-k2.5:cloud` — best quality, free via Ollama's servers, no local RAM needed.
> Use `glm-4.7-flash` as a local offline fallback when you can't reach the internet or have hit the Ollama cloud limit.

---

### Detailed breakdown

#### `kimi-k2.5:cloud` — default

- Free via Ollama cloud routing — zero local GPU or RAM required
- Best overall output quality for Claude Code agentic sessions
- Requires internet + a registered Ollama account with a Device Key
- Has **per-session and weekly usage caps** (free tier) — track at [ollama.com/settings](https://ollama.com/settings)
- **Choose this** for the best default experience; fall back to a local model if offline or quota is exceeded

**Cloud setup (one-time):**
1. Create a free account at [ollama.com](https://ollama.com)
2. Generate a Device Key at [ollama.com/settings/keys](https://ollama.com/settings/keys)
3. Run `ollama auth` and paste the key when prompted

#### `glm-4.7-flash` — local fallback (offline)

- Officially listed in [Ollama × Claude Code integration docs](https://docs.ollama.com/integrations/claude-code)
- **128K context** — Claude Code's ~16K system prompt leaves ~112K for conversation + tool history
- Flash architecture (similar to Gemini Flash) — optimised for speed in agentic, tool-heavy loops
- Works fully offline after pull; no authentication required
- **Choose this** when you need true offline operation or have hit the Ollama cloud limit

#### `qwen3:4b` — compact local (low-RAM machines)

- Only ~3 GB RAM — runs on MacBook Air M1/M2 with 8 GB total
- 128K context window despite small size
- Good for fast iteration; weaker on complex multi-file reasoning
- **Choose this** if `glm-4.7-flash` is too slow or your RAM is constrained

#### `qwen2.5-coder:7b` — code-specialist local

- Purpose-built for code generation; strong benchmark scores for pure coding tasks
- **32K context** — tight for Claude Code's 16K system prompt; leaves ~16K for conversation
- Not optimised for Claude Code's agentic/tool-calling pattern (use `glm-4.7-flash` for that)
- **Choose this** if your workflow is primarily single-file code generation, not multi-step agentic work

#### `qwen3:30b` — best local quality, high-RAM machines

- Best reasoning quality of all local options; comparable to frontier models on coding tasks
- Requires ~20 GB free RAM — suitable for Mac Studio / Pro with 32 GB+ unified memory
- **Choose this** if you have a high-RAM machine and want maximum local quality without cloud dependency

#### `smollm2:360m` — test/CI only

- Used exclusively by the bats unit test suite (`tests/`)
- 8K context and ~360M parameters — far too small for real Claude Code sessions
- Auto-pulled by `bash install.sh`; do not use for actual coding sessions

---

### Context window sizing

Claude Code's system prompt is ~16K tokens. Remaining context for conversation + tool history:

| Model | Total context | Available for session |
|-------|-------------|----------------------|
| `kimi-k2.5:cloud` | Large | Ample ✓ |
| `glm-4.7-flash` | 128K | ~112K ✓ |
| `qwen3:4b` | 128K | ~112K ✓ |
| `qwen3:30b` | 128K | ~112K ✓ |
| `qwen2.5-coder:7b` | 32K | ~16K ⚠ tight |
| `smollm2:360m` | 8K | Insufficient ✗ |

For complex multi-file agentic sessions, context window size is the dominant factor — prefer 128K+ models.

---

### References

- [Ollama × Claude Code integration docs](https://docs.ollama.com/integrations/claude-code)
- [Ollama model library](https://ollama.com/library)
- [Ollama cloud usage & limits](https://ollama.com/settings)

---

## Interactive Model Picker

When the Anthropic limit override is active, running `claude` displays an interactive model selection menu:

```
[claude] Limit override active — select Ollama model:
  1) kimi-k2.5:cloud  <-- default (press Enter)
  2) glm-4.7-flash
  3) qwen3:4b
  4) qwen3:30b
  5) qwen2.5-coder:7b

Choice [Enter = kimi-k2.5:cloud]:
```

- Press **Enter** to use the default (`kimi-k2.5:cloud`, or whatever is saved in `~/.claude/.ollama-model`)
- Type a number and press **Enter** to select that model
- Your selection is saved to `~/.claude/.ollama-model` for next time

---

## Step 4 — Pull the Test/CI Model (optional but recommended)

A tiny model used by the bats unit tests. Fast to pull, low memory usage.

```bash
ollama pull smollm2:360m
```

**Verify:**
```bash
ollama run smollm2:360m "reply with just the word: ready"
# Expected: ready (may include extra text — that's fine)
```

---

## Step 5 — Deploy Scripts to ~/.claude/scripts/

The watchdog and switchback scripts need to be in `~/.claude/scripts/` for hooks
to call them. Run the installer:

```bash
bash install.sh
```

Or copy manually if you don't want to re-run the full install:
```bash
mkdir -p ~/.claude/scripts
cp scripts/limit-watchdog.sh ~/.claude/scripts/
cp scripts/switch-to-anthropic.sh ~/.claude/scripts/
chmod +x ~/.claude/scripts/limit-watchdog.sh ~/.claude/scripts/switch-to-anthropic.sh
```

**Verify:**
```bash
ls -la ~/.claude/scripts/
# Expected: limit-watchdog.sh, switch-to-anthropic.sh
```

---

## Step 5b — Quick Session Test

With Ollama running and a model pulled, just run:
```bash
claude
```
The `claude()` wrapper auto-detects the override and routes to Ollama. If no override exists, you can trigger one manually:
```bash
bash scripts/switch-to-ollama.sh
```

---

## Step 6 — Verify the Override File Works

When a limit is detected, `limit-watchdog.sh` writes `~/.claude/.ollama-override`.
Sourcing this file redirects Claude Code to your local Ollama server.

**Test it manually:**
```bash
# Simulate the watchdog writing the override
cat > /tmp/test-override <<'EOF'
export ANTHROPIC_AUTH_TOKEN=ollama
export ANTHROPIC_API_KEY=""
export ANTHROPIC_BASE_URL=http://localhost:11434
EOF

source /tmp/test-override
echo "AUTH_TOKEN : $ANTHROPIC_AUTH_TOKEN"   # should be: ollama
echo "BASE_URL   : $ANTHROPIC_BASE_URL"     # should be: http://localhost:11434

# Clean up
unset ANTHROPIC_AUTH_TOKEN ANTHROPIC_API_KEY ANTHROPIC_BASE_URL
rm /tmp/test-override
```

---

## Step 7 — Start an Ollama-Routed Claude Code Session

After a real limit hit, `~/.claude/.ollama-override` is written automatically by `limit-watchdog.sh`. Start a new Claude Code session:

```bash
claude
```

The wrapper detects the override, prompts for model selection, and routes to Ollama. The `SessionStart` hook detects `tasks/.session-handover` and suggests `/init-context` to restore prior context.

To manually activate Ollama routing (before a limit hits):
```bash
bash scripts/switch-to-ollama.sh
# or from inside Claude Code:
# /switch-local-model-on
```

---

## Step 8 — Switchback to Anthropic

No external scheduler is needed. The `claude()` wrapper performs a **lazy reset check** on every launch.

### Automatic (recommended)

When you hit a limit, `limit-watchdog.sh` records the reset time in `~/.claude/.ollama-reset-time`. Next time you run `claude`:

1. Wrapper reads the reset time
2. If the reset has passed: "Your Anthropic limit has reset. Switch back? [Y/n]"
3. Confirm → override deleted → Anthropic session starts

### Manual (any time)

Run `switch-back` in your terminal to immediately restore Anthropic routing:

```bash
switch-back
```

This unsets Ollama env vars, restores your API key from backup (or Keychain), removes the override file, and confirms you're ready to run `claude`.

> **No launchd, no `at`, no background scheduler.** The entire switchback lifecycle is handled by the `claude()` wrapper and `switch-back` shell function. Nothing runs while Claude Code is not in use.

---

## Step 9 — Run the Integration Test

With Ollama running and a model pulled (`kimi-k2.5:cloud` or `glm-4.7-flash`):

```bash
bash tests/test_integration_full_cycle.sh
```

Expected output: `12/12 passed — All integration tests PASSED`

---

## Full Readiness Check (one command)

```bash
echo "=== Ollama Readiness ===" && \
  ollama --version && echo "✓ Ollama installed" && \
  ollama list | grep -q . && echo "✓ Ollama server running" && \
  ollama list | grep -q smollm2 && echo "✓ smollm2:360m present (bats tests)" && \
  ollama list | grep -qE 'glm-4.7-flash|qwen3:4b|qwen3:30b|kimi-k2.5:cloud|qwen2.5-coder:7b' && echo "✓ Claude Code model present" && \
  ls ~/.claude/scripts/limit-watchdog.sh > /dev/null && echo "✓ limit-watchdog.sh deployed" && \
  ls ~/.claude/scripts/switch-to-anthropic.sh > /dev/null && echo "✓ switch-to-anthropic.sh deployed" && \
  echo "" && echo "All checks passed — ready for integration tests ✓"
```

---

## Known Limitations (Phase 2 Roadmap)

| Limitation | Impact | Planned Fix |
|-----------|--------|-------------|
| Registry append not atomic | Two sessions hitting limits simultaneously may create duplicate entries in `~/.claude/.active-projects` — harmless (duplicates are idempotent) but not optimal | File locking via `flock` |
| `_phase2` orphan on machine sleep | If Mac sleeps during 5-min switchback window, Phase 2 never fires. Manual recovery: delete `~/.claude/.ollama-override` and restart terminal | Background heartbeat monitor |

**Manual recovery for stuck-in-Ollama state:**
```bash
# Check if override file exists but Ollama is not running
ls ~/.claude/.ollama-override   # exists = Ollama routing active
pgrep -x ollama                 # no output = Ollama not running

# Manual recovery
rm ~/.claude/.ollama-override
# Open a new terminal — claude() will now route to Anthropic
```

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `ollama: command not found` | Run `brew install ollama` |
| `curl: connection refused` on port 11434 | Start server: `ollama serve` |
| `kimi-k2.5:cloud` not in `ollama list` | Pull it: `ollama pull kimi-k2.5:cloud` (requires Ollama account + `ollama auth`) |
| `glm-4.7-flash` not in `ollama list` | Pull it: `ollama pull glm-4.7-flash` |
| `ollama launch claude` not found | Update Ollama: `brew upgrade ollama` |
| Override sourced but Claude Code still hits Anthropic | Open a **new terminal** after sourcing (env vars don't propagate to existing shells) |
| `kimi-k2.5:cloud` returns auth error | Register a Device Key at [ollama.com/settings/keys](https://ollama.com/settings/keys) then run `ollama auth` |
| Cloud model returns quota/limit error | Check usage at [ollama.com/settings](https://ollama.com/settings); switch to a local model (`glm-4.7-flash`) until quota resets |
| Stuck in Ollama but limit has reset | Run `switch-back` in your terminal, or run `claude` and confirm "Y" when prompted to switch back |
| `bats tests/` fails test FN-09 | Ensure `scripts/limit-watchdog.sh` is deployed (not just in repo) |

---

## Quick Reference

```bash
# Install
brew install ollama

# Start server (pick one)
brew services start ollama        # auto-start at login (recommended)
ollama serve                      # manual foreground

# Pull models
ollama pull kimi-k2.5:cloud       # default — best quality, no RAM needed (requires Ollama account)
ollama pull glm-4.7-flash         # local offline fallback — fast, 8GB RAM
ollama pull qwen3:4b              # compact local — 3GB RAM
ollama pull qwen2.5-coder:7b      # strong code generation — 5GB RAM
ollama pull qwen3:30b             # best local quality — 20GB+ RAM
ollama pull smollm2:360m          # bats unit tests only

# Start Ollama-routed Claude Code (after limit hit or manual switch)
claude

# Manual switchback to Anthropic
switch-back

# Readiness check
ollama list && ls ~/.claude/scripts/limit-watchdog.sh
```
