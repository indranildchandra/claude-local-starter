---
description: Switch back to Anthropic Claude from local Ollama routing
---

Switch the current terminal back to Anthropic and clean up all Ollama override state.

## Step 1 — Run switch-back in terminal

Ask the user to run this in their terminal:

```bash
switch-back
```

If the shell function isn't available (install.sh not run yet):

```bash
source ~/.claude/scripts/switch-to-anthropic.sh
```

## Step 2 — Verify the switch

Ask the user to confirm:

```bash
echo "API key set: ${ANTHROPIC_API_KEY:+yes (${#ANTHROPIC_API_KEY} chars)}"
echo "Base URL: ${ANTHROPIC_BASE_URL:-<unset — correct>}"
echo "Ollama model: ${OLLAMA_MODEL:-<unset — correct>}"
```

Expected: API key present, `ANTHROPIC_BASE_URL` and `OLLAMA_MODEL` unset.

## Step 3 — Launch Anthropic session

The terminal is now ready. Run `claude` — no restart required.
