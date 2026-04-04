# Format: tasks/tracker.md

Append-only. Newest at TOP. Two entry types.

## Entry type 1 — Task complete

```markdown
## YYYY-MM-DD HH:MM:SS — <one-line task summary>
**Type:** task-complete
**Session:** ${CLAUDE_SESSION_ID:-unknown} | ${CLAUDE_SESSION_NAME:-unnamed}
**Outcome:** <what was achieved>
**Files changed:** <comma-separated list, or "none">
**Key change:** (optional — paste relevant diff or function signature, max 20 lines)
```

## Entry type 2 — Pre-compact snapshot

```markdown
## YYYY-MM-DD HH:MM:SS — [Pre-Compact Snapshot]
**Type:** pre-compact
**Session:** ${CLAUDE_SESSION_ID:-unknown} | ${CLAUDE_SESSION_NAME:-unnamed}
**Working on:** <current task or goal>
**Completed this session:**
- <item>
**Key decisions:**
- <decision and rationale>
**Files changed:** <comma-separated list>
**Open / in-progress:** <what is unfinished>
**Resume from:** <exact state — enough detail for a cold-start in the next session>
**Key change:** (optional — paste relevant diff or function signature, max 20 lines)
```

## File header (create once if file does not exist)

```markdown
# Task Tracker
<!-- Append-only. Newest at TOP. -->
<!-- Format: ## YYYY-MM-DD HH:MM:SS — <summary> -->
```
