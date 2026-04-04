# Format: audit/changelog.md

Append-only. Newest at TOP. Written AFTER implementation is complete.

## Changelog entry

```markdown
---

YYYY-MM-DD HH:MM:SS - <one-line summary of what changed>

**Session:** ${CLAUDE_SESSION_ID:-unknown}

### Changes
- <what changed and why>

### Files
- `path/to/file` — <created | modified | deleted>

**Key change:**
```diff
- old behaviour / removed code
+ new behaviour / added code
```
```

## File header (create once if file does not exist)

```markdown
# Change Log
<!-- Append-only. Newest at TOP. Written AFTER implementation is complete. -->
<!-- Format: YYYY-MM-DD HH:MM:SS - <one line summary> -->
```
