---
description: Load AIDLC context on session resume (handover marker must exist)
---

Check for a session handover from an Ollama switchover and load context if found.

**Step 1: Check for handover marker**

Run this Bash command:
```
[ -f tasks/.session-handover ] && echo "HANDOVER_FOUND" || echo "NO_HANDOVER"
```

If the output is `NO_HANDOVER`: this is a fresh session — stop here and respond normally to the user. Do not output anything about this check.

If the output is `HANDOVER_FOUND`: this is a resumed session after an Ollama switchover — proceed with the steps below.

**Step 2: Check for AIDLC files**

Check if these files exist:
- `tasks/tracker.md`
- `tasks/todo.md`
- `docs/plan.md`

If any are missing, run `/init-repo` to create stub files, then continue.

**Step 3: Read rich context (run all in parallel)**

- `head -100 tasks/tracker.md` — read top 100 lines to capture both the shell-written `limit-hit` entry AND the richer `pre-compact` snapshot below it. The `**Resume from:**` field in the pre-compact entry is the authoritative context line.
- Read `tasks/todo.md` (full file)
- `head -25 docs/plan.md`
- If `tasks/lessons.md` exists: `head -40 tasks/lessons.md` — load learned rules so this session continues with established patterns from prior work

**Step 4: Synthesize briefing**

Write a 2–3 paragraph summary:
- **Active task**: What was in progress (look for `**Working on:**` and `**Resume from:**` fields — if the top entry is type `limit-hit`, look at the second entry for the richer pre-compact context)
- **Next step**: The exact first action to take
- **Learned rules**: Any lessons from `tasks/lessons.md` directly relevant to the current work — cite the rule and apply it immediately

**Step 5: Delete the handover marker** *(only after successful context load)*

**Only run this step if Steps 2–4 completed without error.** If any step failed (files missing, parse error), do NOT delete the marker — the user needs it for the next attempt.

Run:
```
rm -f tasks/.session-handover
```

Confirm: "Handover marker cleared — context loaded. Ready to resume."
