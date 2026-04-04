---
description: Manually switch to local Ollama model routing
---

Manually activate Ollama routing (use when the automatic Stop-hook detection missed the limit, or to test locally without hitting Anthropic). This command delegates all state-file work to `switch-to-ollama.sh`.

## Step 1 — Run the switch script in your terminal

Ask the user to run:

```bash
bash ~/.claude/scripts/switch-to-ollama.sh
```

The script will:
- Check Ollama is running (errors out if not)
- Present an interactive model picker (zsh + bash compatible)
- Write `.ollama-override` and `.ollama-anthropic-key-backup`
- Optionally prompt for a reset time and write `.ollama-reset-time`

To set a reset time non-interactively (e.g. reset at 3:00 PM):

```bash
bash ~/.claude/scripts/switch-to-ollama.sh 15 0
```

## Step 2 — Verify the switch

```bash
echo "Base URL: ${ANTHROPIC_BASE_URL:-<unset>}"
cat ~/.claude/.ollama-override
cat ~/.claude/.ollama-reset-time 2>/dev/null && echo "(reset time set)" || echo "(no reset time)"
```

## Step 3 — Launch Ollama session

Run `claude` — the wrapper detects the override, runs a health check, presents the model picker, and routes to Ollama.
