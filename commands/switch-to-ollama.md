---
description: Switch Claude Code to local Ollama model routing
---

Activate Ollama routing by running the switch-to-ollama.sh script. Use when the automatic Stop-hook detection missed the limit, or to route to a local model by choice.

## Step 1 — Run the activation script

Use the Bash tool to run:

```bash
bash ~/.claude/scripts/switch-to-ollama.sh
```

Note: the interactive model picker requires a TTY and will be skipped when Claude runs the script. The previously saved model (or default: kimi-k2.5:cloud) will be used. The user can change it at the routing prompt when they next run `claude`.

To set a specific reset time non-interactively (e.g. reset at 3:00 PM):

```bash
bash ~/.claude/scripts/switch-to-ollama.sh 15 0
```

## Step 2 — Verify the override was written

```bash
cat ~/.claude/.ollama-override
cat ~/.claude/.ollama-reset-time 2>/dev/null && echo "(reset time set)" || echo "(no reset time)"
```

## Step 3 — Tell the user

Inform the user that Ollama routing is now active. They should:

1. Run `claude` in their terminal — the wrapper will detect the override and route to Ollama
2. At the prompt `yes(Y) use Ollama / reset(r) switch back:` — press Enter to confirm Ollama
3. To switch back: run `switch-back` in the terminal
