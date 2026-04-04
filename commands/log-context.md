---
description: Write a detailed session snapshot to tasks/tracker.md before compaction or on demand. Preserves enough context for a cold-start in the next session.
---

You are writing a pre-compact context snapshot. Follow these steps exactly.

## Step 1 — Load the format

Read `aidlc-tracking` skill formats.md for the **pre-compact snapshot** entry format before writing anything.

## Step 2 — Gather session context

Reflect on the current conversation and identify:
- **Working on:** What is the current task or goal?
- **Completed this session:** What has been finished since the session started or since the last snapshot?
- **Key decisions:** What significant decisions were made and why?
- **Files changed:** Which files were created, modified, or deleted?
- **Open / in-progress:** What is unfinished or blocked?
- **Resume from:** The exact state a fresh session would need to pick up — specific file, function, step, or error being worked on. Be precise enough that no context is required from the conversation history.

## Step 3 — Write to tasks/tracker.md

Prepend the pre-compact snapshot entry to `tasks/tracker.md` so the newest entry is at the top.

If `tasks/tracker.md` does not exist: create it with the header from aidlc-tracking formats.md, then write the entry below the header.

If `tasks/tracker.md` already exists: insert the new entry immediately after the file header (first 3 lines), pushing all prior entries down. Do NOT append to the end of the file.

## Step 4 — Update tasks/todo.md

Rewrite `tasks/todo.md` to reflect current state:
- Move completed items to **Done (this session)**
- Keep active items in **In Progress**
- Clear stale **Up Next** items that are now done or irrelevant

## Step 5 — Capture lessons (REQUIRED, not optional)

Check `tasks/lessons.md`. Write a lesson entry for anything learned, corrected, or discovered this session that a future session should know:

1. If `tasks/lessons.md` does not exist: create it with the header from aidlc-tracking formats.md
2. Prepend at least one entry if any of the following happened this session:
   - A bug was found and fixed
   - A design decision was made with non-obvious rationale
   - A tool or pattern proved problematic or worked better than expected
   - The user corrected your approach
3. If nothing noteworthy happened, write a single entry: `## YYYY-MM-DD — No new lessons` with `**Rule:** No new patterns this session.`

## Step 6 — Check docs/plan.md checklist

Scan `docs/plan.md` for the most recent plan entry's checklist:
- Change `- [ ]` to `- [x]` for every step completed this session
- Leave pending steps unchanged
- If all steps are done, note it in your confirmation

## Step 7 — Confirm

Tell the user:
- "Context logged to tasks/tracker.md — safe to /compact."
- Show the **Resume from:** line verbatim so the user can verify it captures the current state
- Summary: "Lessons written: N | Plan items checked: N"
