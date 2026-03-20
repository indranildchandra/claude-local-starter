Enable safe-yolo permissions for a repository.

Writes `permissions.allow`, `permissions.deny`, and `permissions.defaultMode` into `<repo>/.claude/settings.json`
based on `~/.claude/claude-safe-yolo-permissions.txt`.
Idempotent — only adds entries
not already present; manually added permissions are never touched.
Feel free to edit `~/.claude/claude-safe-yolo-permissions.txt` as your need evolves.

Example invocations (natural language):
- `/enable-safe-yolo`
- `/enable-safe-yolo in the current repo`
- `/enable-safe-yolo for your-directory/your-repo`
- `/enable-safe-yolo dry run` — preview what would be written without making changes

## Step 1 — Determine target directory

Check if the user passed a path or natural language hint in the arguments:
- If a path is mentioned (e.g. "for /some/path", "in /some/path") → use that path directly, skip to Step 2.
- If the user says "dry run", "preview", or "show me" → note this for Step 2.
- Otherwise, auto-detect using this logic:

1. From your environment context, collect all known working directories (primary + additional).
2. Filter out non-repo paths — exclude anything under `~/.claude`, `~/.claude-work`, `/tmp`, or `/var`.
3. Count what remains:
   - **Exactly one** candidate → announce it and proceed directly to Step 2 (no confirmation yet):
     > "The only non-excluded working directory is **<DIR>**."
   - **Multiple** candidates → list them and ask:
     > "Which directory should I enable safe-yolo in?"
     Wait for reply before continuing.
   - **Zero** candidates → ask the user to paste the full path.

## Step 2 — Show dry-run summary and confirm with user

Run the dry-run to show exactly what permissions would be added:
```bash
~/.claude/enable-safe-yolo.sh --dry-run --dir="<RESOLVED_DIR>"
```

Then ask the user directly in the conversation:
> "Safe-yolo will be enabled in **<RESOLVED_DIR>**. Does this directory look correct and do you want to proceed? (y/n)"

Wait for the user's reply before doing anything else.

## Step 3 — Apply or abort

- If the user replies **y** (or yes), OR if they said "dry run" in Step 1 (no actual apply needed): run:
  ```bash
  ~/.claude/enable-safe-yolo.sh --yes --dir="<RESOLVED_DIR>"
  ```
  Print the output verbatim.

- If the user replies **n** (or no, or anything else): reply "Aborted — no changes made." and stop.
