# Format: tasks/tracker.md

Append-only. Newest at TOP. Two entry types.

## Entry type 1 — Task complete

```markdown
## YYYY-MM-DD HH:MM:SS — <one-line task summary>
**Type:** task-complete
**Outcome:** <what was achieved>
**Files changed:** <comma-separated list, or "none">
```

## Entry type 2 — Pre-compact snapshot

```markdown
## YYYY-MM-DD HH:MM:SS — [Pre-Compact Snapshot]
**Type:** pre-compact
**Working on:** <current task or goal>
**Completed this session:**
- <item>
**Key decisions:**
- <decision and rationale>
**Files changed:** <comma-separated list>
**Open / in-progress:** <what is unfinished>
**Resume from:** <exact state — enough detail for a cold-start in the next session>
```

## File header (create once if file does not exist)

```markdown
# Task Tracker
<!-- Append-only. Newest at TOP. -->
<!-- Format: ## YYYY-MM-DD HH:MM:SS — <summary> -->
```
