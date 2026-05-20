---
description: Switch Claude Code back to Anthropic from Ollama routing
---

Restore Anthropic routing by cleaning up all Ollama sentinel files and recovering the API key.

## Step 1 — Run the restore script

Use the Bash tool to run:

```bash
bash ~/.claude/scripts/switch-to-anthropic.sh
```

This will:
- Remove all sentinel files: `.ollama-override`, `.ollama-reset-time`, `.pre-switchback`, `.ollama-manual`
- Attempt to restore `ANTHROPIC_API_KEY` from the backup file, Linux credential store, or macOS Keychain
- Print instructions for the env var cleanup the user must run in their terminal

## Step 2 — Tell the user to run in their terminal

Sentinel files are now cleared. Env vars cannot be changed from inside Claude, so the user must run one of these in their terminal:

```bash
# Easiest — shell function (installed by install.sh):
switch-back

# Or source the script directly:
source ~/.claude/scripts/switch-to-anthropic.sh

# Or manually unset:
unset ANTHROPIC_BASE_URL ANTHROPIC_AUTH_TOKEN OLLAMA_MODEL
```

## Step 3 — Verify

Ask the user to confirm the override is gone:

```bash
ls ~/.claude/.ollama-override 2>/dev/null && echo "STILL PRESENT — rerun step 2" || echo "Override cleared"
echo "API key set: ${ANTHROPIC_API_KEY:+yes (${#ANTHROPIC_API_KEY} chars)}"
echo "Base URL: ${ANTHROPIC_BASE_URL:-<unset — correct>}"
```

Expected: override not present, API key present, `ANTHROPIC_BASE_URL` unset.

## Step 4 — Launch Anthropic session

Once the user confirms the above, they can run `claude` — it will connect to Anthropic normally.
